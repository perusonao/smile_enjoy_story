// Issue #117 — PUBLIC-DEMO-UX-1A Screen Verification Gate.
//
// This is a verification spec, not a feature test: it drives the *deployed*
// Public Demo bundle (the exact `github-pages` payload built from
// 7488ff176be86cb829014ea361414837d7b89340 / PR #131) at two explicitly set
// mobile viewport widths and records the evidence the gate asks for —
// numbered milestone screenshots, video, and a trace — while asserting the
// seven gate steps.
//
// It never weakens or replaces e2e/tests/public-demo-fresh-start.spec.ts; it
// reuses that harness's `watchForErrors` and adds geometric/visual assertions
// (bounding boxes, viewport containment, overlap, horizontal overflow) so a
// node's mere presence in the accessibility tree can never produce a PASS.
import fs from 'fs';
import path from 'path';
import { test, expect, type Page, type Locator } from '@playwright/test';
import { watchForErrors } from '../../helpers/artifacts';

const SHOT_ROOT = path.resolve(__dirname, '../../../.verification/screenshots');

/** GitHub Pages project path of the deployed demo. */
const PROJECT_PATH = process.env.SES_VERIFY_PROJECT_PATH || '/smile_enjoy_story/';
/** The published external entry point under test. */
const PUBLIC_DEMO_ENTRY = `${PROJECT_PATH}public-demo/`;
/** Same app, semantics forced on so the flow can be driven (see lib/main.dart). */
const DRIVABLE_ENTRY = `${PROJECT_PATH}?e2e=1#/public-demo-01`;

interface Box { x: number; y: number; width: number; height: number }

/** Findings are collected rather than thrown one at a time so a single run
 * reports every visual problem it can see, not just the first. Hard flow
 * failures still assert immediately. */
const findings: string[] = [];

function record(width: number, step: string, message: string): void {
  findings.push(`[${width}px][${step}] ${message}`);
}

/** Two captures per milestone: the numbered viewport shot the gate asks for
 * (what the phone screen actually shows), plus a `-scrolled` companion taken
 * after scrolling down to the 社員ステージ card, where the card-level
 * SkillSheet確認 / 営業開始 buttons live — that half of HOME is what the
 * duplicate-primary-CTA and stage-badge judgements need to see.
 *
 * Playwright's own `fullPage: true` is useless here: Flutter Web paints into
 * a viewport-sized view and scrolls internally, so a "full page" capture is
 * byte-identical to the viewport one. The scroll has to be a real in-app
 * wheel gesture (`watchForErrors` installs the repo's portable-wheel
 * fallback for mobile WebKit; Chromium uses the native path). */
async function shot(page: Page, width: number, name: string): Promise<string> {
  const dir = path.join(SHOT_ROOT, String(width));
  fs.mkdirSync(dir, { recursive: true });
  const file = path.join(dir, `${name}.png`);
  await page.screenshot({ path: file });

  // Flutter only keeps semantics nodes for what the scroll view currently
  // realises, so the visual audit has to be re-run at each scroll position
  // rather than once at the top — otherwise the lower half of HOME (the
  // engineer cards, the month-end action) would never be inspected at all.
  // Flutter hit-tests wheel events at the pointer's position, and Playwright
  // parks an untouched pointer at (0,0) — inside the fixed AppBar, which does
  // not scroll. Park it over the body first (caught by this run: `01-home`'s
  // scrolled/bottom captures came back byte-identical to the top-of-page one
  // until the pointer was moved). Flutter's scroll physics also ignore one
  // oversized delta, so the scroll is applied in ordinary-sized increments.
  const centreY = (page.viewportSize()?.height ?? 800) / 2;
  await page.mouse.move(width / 2, centreY);
  let scrolled = 0;
  const step = async (increments: number, label: string) => {
    for (let i = 0; i < increments; i++) {
      await page.mouse.wheel(0, 600);
      scrolled += 600;
      await page.waitForTimeout(120);
    }
    await page.waitForTimeout(400);
    await page.screenshot({ path: path.join(dir, `${name}-${label}.png`) });
    await assertNoHorizontalOverflow(page, width, `${name}/${label}`);
    await auditButtons(page, width, `${name}/${label}`);
  };
  await step(4, 'scrolled');
  await step(10, 'bottom');

  for (let i = 0; i < scrolled / 600; i++) {
    await page.mouse.wheel(0, -600);
    await page.waitForTimeout(80);
  }
  await page.waitForTimeout(500);
  return file;
}

/** A box is "really shown": non-degenerate, and horizontally inside the
 * viewport with a 0.5px tolerance for sub-pixel layout. */
async function assertVisibleBox(
  locator: Locator,
  label: string,
  width: number,
  step: string,
): Promise<Box> {
  await expect(locator, `${label} must be visible`).toBeVisible();
  const box = await locator.boundingBox();
  expect(box, `${label} must have a layout box`).not.toBeNull();
  const b = box as Box;
  expect(b.width, `${label} width`).toBeGreaterThan(0);
  expect(b.height, `${label} height`).toBeGreaterThan(0);
  if (b.x < -0.5) record(width, step, `${label} starts left of the viewport (x=${b.x.toFixed(1)})`);
  if (b.x + b.width > width + 0.5) {
    record(
      width,
      step,
      `${label} extends past the right viewport edge (right=${(b.x + b.width).toFixed(1)} > ${width})`,
    );
  }
  return b;
}

/** Horizontal overflow — the observable release-build symptom of a too-wide
 * row/RenderFlex, since Flutter's striped overflow indicator and its
 * "A RenderFlex overflowed" console message are both debug-only.
 *
 * Three independent measures, deliberately *not* `document.body.scrollWidth`:
 * Flutter Web's accessibility mirror parents everything under `flutter-view`,
 * and both the engine's hidden typography ruler (`position: fixed`, ~320000px
 * wide, `visibility: hidden`) and the intrinsic text extents it stamps on
 * `flt-semantics` nodes inflate that one number without anything being
 * painted, laid out, or scrollable off-screen. Verified directly on this
 * build: with the SkillSheet dialog open at 390px, `body.scrollWidth` reads
 * 695 while `documentElement.scrollWidth` is exactly 390, no non-fixed
 * element's rect is wider than 390, every inflated `flt-semantics` node is
 * `overflow-x: visible` with `scrollLeft` pinned at 0, and the page cannot be
 * scrolled sideways at all.
 *
 * What is checked instead is strictly stronger than the document number: no
 * *element* may lay out past the viewport edge, and the page must not be
 * horizontally scrollable. */
async function assertNoHorizontalOverflow(page: Page, width: number, step: string): Promise<void> {
  const metrics = await page.evaluate(() => {
    const vw = window.innerWidth;
    const wide: { tag: string; label: string; x: number; width: number }[] = [];
    document.querySelectorAll('flutter-view *').forEach((el) => {
      // The engine's own hidden measurement ruler is not app layout.
      if (getComputedStyle(el).position === 'fixed') return;
      const r = el.getBoundingClientRect();
      if (r.width <= 0 || r.height <= 0) return;
      if (r.right > vw + 1 || r.left < -1) {
        wide.push({
          tag: el.tagName.toLowerCase(),
          label: (el.getAttribute('aria-label') || el.textContent || '').trim().slice(0, 40),
          x: Math.round(r.left),
          width: Math.round(r.width),
        });
      }
    });
    return {
      docScrollWidth: document.documentElement.scrollWidth,
      innerWidth: vw,
      scrollLeftMax: (() => {
        const before = window.scrollX;
        window.scrollTo(10_000, window.scrollY);
        const max = window.scrollX;
        window.scrollTo(before, window.scrollY);
        return max;
      })(),
      wide: wide.slice(0, 10),
    };
  });
  if (metrics.docScrollWidth > metrics.innerWidth + 1) {
    record(
      width,
      step,
      `document scrollWidth ${metrics.docScrollWidth} exceeds viewport ${metrics.innerWidth}`,
    );
  }
  if (metrics.scrollLeftMax > 1) {
    record(width, step, `page can be scrolled horizontally to x=${metrics.scrollLeftMax}`);
  }
  for (const el of metrics.wide) {
    record(
      width,
      step,
      `<${el.tag}> "${el.label}" lays out outside the viewport (x=${el.x}, width=${el.width}, viewport=${width})`,
    );
  }
}

/** The labels that stand for "the one thing to do next" in this flow — the
 * HOME Recommended Action CTAs and their engineer-card counterparts, plus the
 * month-end action. Two of any of these on screen at once is the duplicate
 * primary CTA the gate forbids. (`SkillSheetを確認` vs `SkillSheet確認` and
 * `営業を開始` vs `営業開始` are deliberately distinct strings in the product;
 * both spellings are listed so either being doubled is caught.) */
const PRIMARY_CTA_LABELS = new Set([
  'SkillSheetを確認',
  'SkillSheet確認',
  '営業を開始',
  '営業開始',
  '案件を紹介',
  '案件紹介',
  '上位会社面談',
  '客先面談',
  '内容を確認',
  '戻る',
]);

/** Labels that drive the same intent under different wording. Two members of
 * one group visible in the same viewport would be the duplicate primary CTA
 * the gate forbids. */
const SAME_INTENT_CTA_GROUPS: Set<string>[] = [
  new Set(['SkillSheetを確認', 'SkillSheet確認']),
  new Set(['営業を開始', '営業開始']),
  new Set(['案件を紹介', '案件紹介']),
];

/** Two interactive controls must not sit on top of each other. */
function overlaps(a: Box, b: Box): boolean {
  const ix = Math.min(a.x + a.width, b.x + b.width) - Math.max(a.x, b.x);
  const iy = Math.min(a.y + a.height, b.y + b.height) - Math.max(a.y, b.y);
  return ix > 1 && iy > 1;
}

/** Every button currently exposed by the accessibility tree, with its box —
 * the input for the overlap / off-viewport / duplicate-CTA checks. */
async function buttonBoxes(page: Page): Promise<{ name: string; box: Box }[]> {
  const buttons = page.getByRole('button');
  const count = await buttons.count();
  const out: { name: string; box: Box }[] = [];
  for (let i = 0; i < count; i++) {
    const b = buttons.nth(i);
    if (!(await b.isVisible())) continue;
    const box = await b.boundingBox();
    if (!box || box.width <= 0 || box.height <= 0) continue;
    out.push({ name: (await b.getAttribute('aria-label')) ?? (await b.innerText()).trim(), box });
  }
  return out;
}

/** Flutter renders a dialog's `ModalBarrier` as a full-screen semantics
 * button labelled "Dismiss". It is *supposed* to sit under the whole viewport
 * — that is what makes tapping outside close the dialog — so it is excluded
 * from the control-overlap check and audited separately (below) for the thing
 * that would actually be a defect: swallowing taps meant for the dialog's own
 * buttons. */
function isModalBarrier(name: string, box: Box, width: number, height: number): boolean {
  return name === 'Dismiss' && box.width >= width * 0.9 && box.height >= height * 0.9;
}

async function auditButtons(page: Page, width: number, step: string): Promise<void> {
  const all = await buttonBoxes(page);
  const viewportHeight = page.viewportSize()?.height ?? 800;
  const boxes = all.filter(({ name, box }) => !isModalBarrier(name, box, width, viewportHeight));

  for (const { name, box } of boxes) {
    if (box.x < -0.5 || box.x + box.width > width + 0.5) {
      record(
        width,
        step,
        `button "${name}" is horizontally clipped (x=${box.x.toFixed(1)}, right=${(box.x + box.width).toFixed(1)}, viewport=${width})`,
      );
    }
  }
  for (let i = 0; i < boxes.length; i++) {
    for (let j = i + 1; j < boxes.length; j++) {
      if (overlaps(boxes[i].box, boxes[j].box)) {
        record(width, step, `buttons "${boxes[i].name}" and "${boxes[j].name}" overlap`);
      }
    }
  }
  // Whatever is layered on top (scrim included) must not steal a control's
  // own centre point — an overlay that does is a real, tap-blocking defect.
  for (const { name, box } of boxes) {
    const cx = box.x + box.width / 2;
    const cy = box.y + box.height / 2;
    if (cx < 0 || cx > width || cy < 0 || cy > viewportHeight) continue;
    const topLabel = await page.evaluate(
      ([x, y]) => {
        const el = document.elementFromPoint(x as number, y as number);
        const owner = el?.closest('[role="button"], flt-semantics[role="button"]') ?? el;
        return owner?.getAttribute('aria-label') ?? owner?.tagName?.toLowerCase() ?? null;
      },
      [cx, cy],
    );
    if (topLabel && topLabel !== name && topLabel === 'Dismiss') {
      record(width, step, `modal scrim covers the centre of button "${name}" — taps would not reach it`);
    }
  }
  // Duplicate *primary* CTA — the gate's concern is two competing "do this
  // next" buttons, not a per-row action repeated once per list item. HOME's
  // 社員ステージ / engineer cards legitimately render one 研修する per
  // engineer, each scoped to its own card and its own subject; that is list
  // UX, not a duplicated next action. So only the workflow's own primary
  // next-action vocabulary is checked for repetition.
  const seen = new Map<string, number>();
  for (const { name } of boxes) seen.set(name, (seen.get(name) ?? 0) + 1);
  for (const [name, n] of seen) {
    if (n > 1 && PRIMARY_CTA_LABELS.has(name)) {
      record(width, step, `duplicate primary CTA "${name}" rendered ${n} times`);
    }
  }

  // The sharper form of the same rule: two buttons that drive the *same*
  // intent under different wording must never be on screen together. HOME's
  // Recommended Action card and the engineer card each carry one — the
  // deliberately distinct 「SkillSheetを確認」/「SkillSheet確認」 and
  // 「営業を開始」/「営業開始」 pairs — so this checks they stay on separate
  // folds rather than competing in one viewport.
  const onScreen = boxes.filter(
    ({ box }) => box.y + box.height > 0 && box.y < viewportHeight,
  );
  for (const group of SAME_INTENT_CTA_GROUPS) {
    const hits = onScreen.filter(({ name }) => group.has(name));
    if (hits.length > 1) {
      record(
        width,
        step,
        `competing primary CTAs visible in one viewport: ${hits.map((h) => `"${h.name}" @y=${Math.round(h.box.y)}`).join(', ')}`,
      );
    }
  }
}

/** The one screen the gate calls "HOME": the Public Demo month surface. */
async function waitForHome(page: Page): Promise<void> {
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 60_000 });
  await expect(async () => {
    const raw = await page.locator('body').ariaSnapshot();
    expect(raw, 'Public Demo identity').toContain('S.E.S. Public Demo 0.1');
    expect(raw, 'employee stage section').toContain('社員ステージ');
  }).toPass({ timeout: 30_000 });
}

for (const viewportWidth of [360, 390]) {
  test.describe(`Issue #117 screen verification @ ${viewportWidth}px`, () => {
    test.skip(({ viewport }) => viewport?.width !== viewportWidth, 'other viewport project');

    test(`gate steps 1-7 on the deployed Public Demo (${viewportWidth}px)`, async ({ page }, testInfo) => {
      const errors = watchForErrors(page);

      // --- Deployed entry point: the published /public-demo/ URL itself ----
      await page.goto(PUBLIC_DEMO_ENTRY);
      await expect
        .poll(() => page.url(), { timeout: 30_000 })
        .toContain('#/public-demo-01');

      // --- Step 1: fresh start, HOME exposes the intended next action ------
      // Re-entered with semantics forced on so the flow is drivable; the
      // painted pixels are identical (lib/main.dart only calls
      // ensureSemantics, which adds no visible chrome).
      await page.goto(DRIVABLE_ENTRY);
      await waitForHome(page);

      const home = await page.locator('body').ariaSnapshot();
      expect(home, 'fresh-start month').toContain('4月');
      expect(home, 'target engineer').toContain('佐藤 健');
      expect(home, 'fresh-start sales stage').toContain('営業準備前');
      expect(home, 'fresh start must not be terminal').not.toContain('このプレイスルーは終了しました。');
      expect(home, 'fresh start must not be bankrupt').not.toContain('倒産');

      // The deployed build identity must be the one under verification.
      const buildLabel = page.getByText(/Deploy: PR #131 · 7488ff1/);
      await assertVisibleBox(buildLabel, 'deploy build label', viewportWidth, '01-home');

      const recommendedCta = page.getByRole('button', { name: 'SkillSheetを確認', exact: true });
      await assertVisibleBox(recommendedCta, 'HOME recommended CTA (SkillSheetを確認)', viewportWidth, '01-home');
      await expect(
        page.getByRole('button', { name: '営業を開始', exact: true }),
        'sales start must not be offered before SkillSheet confirmation',
      ).toHaveCount(0);
      await assertNoHorizontalOverflow(page, viewportWidth, '01-home');
      await auditButtons(page, viewportWidth, '01-home');
      await shot(page, viewportWidth, '01-home');

      // --- Steps 2-3: open Sato's SkillSheet, real content is visible -----
      await recommendedCta.click();
      const sheetTitle = page.getByText('営業用SkillSheet', { exact: false });
      await assertVisibleBox(sheetTitle, 'SkillSheet dialog title', viewportWidth, '02-skillsheet-open');

      const required: [string, Locator][] = [
        ['佐藤 健 (name in dialog)', page.getByText('佐藤 健', { exact: false }).last()],
        ['Java / SQL・開発経験3年 (career/skill summary)', page.getByText('Java / SQL・開発経験3年', { exact: true })],
        ['経歴・スキル要約 (section)', page.getByText('経歴・スキル要約', { exact: true })],
        ['営業・面談プロフィール (section)', page.getByText('営業・面談プロフィール', { exact: true })],
        ['案件スキル適合 (row)', page.getByText('案件スキル適合', { exact: true })],
        ['ヒューマンスキル (row)', page.getByText('ヒューマンスキル', { exact: true })],
      ];
      for (const [label, locator] of required) {
        await assertVisibleBox(locator, label, viewportWidth, '02-skillsheet-open');
      }

      const backBtn = page.getByRole('button', { name: '戻る', exact: true });
      const confirmBtn = page.getByRole('button', { name: '内容を確認', exact: true });
      const backBox = await assertVisibleBox(backBtn, '戻る button', viewportWidth, '02-skillsheet-open');
      const confirmBox = await assertVisibleBox(confirmBtn, '内容を確認 button', viewportWidth, '02-skillsheet-open');
      expect(overlaps(backBox, confirmBox), '戻る and 内容を確認 must not overlap').toBe(false);

      // Modal must not overflow the viewport in either axis beyond scroll.
      const dialog = page.locator('flt-semantics', { hasText: '営業用SkillSheet' }).first();
      const dialogBox = await dialog.boundingBox();
      if (dialogBox) {
        if (dialogBox.x < -0.5 || dialogBox.x + dialogBox.width > viewportWidth + 0.5) {
          record(
            viewportWidth,
            '02-skillsheet-open',
            `SkillSheet modal overflows horizontally (x=${dialogBox.x.toFixed(1)}, right=${(dialogBox.x + dialogBox.width).toFixed(1)})`,
          );
        }
      }
      await expect(
        page.getByRole('button', { name: '営業を開始', exact: true }),
        'opening the SkillSheet must not advance to sales start',
      ).toHaveCount(0);
      await assertNoHorizontalOverflow(page, viewportWidth, '02-skillsheet-open');
      await auditButtons(page, viewportWidth, '02-skillsheet-open');
      await shot(page, viewportWidth, '02-skillsheet-open');

      // --- Step 4: back/cancel does not advance the workflow --------------
      await backBtn.click();
      await expect(sheetTitle).toHaveCount(0);
      await assertVisibleBox(recommendedCta, 'HOME recommended CTA after back', viewportWidth, '03-after-back');
      const afterBack = await page.locator('body').ariaSnapshot();
      expect(afterBack, 'stage must still be 営業準備前 after cancel').toContain('営業準備前');
      expect(afterBack, 'cancel must not advance to SkillSheet確認中').not.toContain('SkillSheet確認中');
      await expect(
        page.getByRole('button', { name: '営業を開始', exact: true }),
        'cancel must not unlock sales start',
      ).toHaveCount(0);
      await expect(
        page.getByRole('button', { name: '営業開始', exact: true }),
        'cancel must not unlock the card-level sales start either',
      ).toHaveCount(0);
      await assertNoHorizontalOverflow(page, viewportWidth, '03-after-back');
      await auditButtons(page, viewportWidth, '03-after-back');
      await shot(page, viewportWidth, '03-after-back');

      // --- Step 5: re-open ------------------------------------------------
      await recommendedCta.click();
      await assertVisibleBox(sheetTitle, 'SkillSheet dialog title on re-open', viewportWidth, '04-skillsheet-reopen');
      await assertVisibleBox(
        page.getByText('Java / SQL・開発経験3年', { exact: true }),
        'career/skill summary on re-open',
        viewportWidth,
        '04-skillsheet-reopen',
      );
      await assertNoHorizontalOverflow(page, viewportWidth, '04-skillsheet-reopen');
      await auditButtons(page, viewportWidth, '04-skillsheet-reopen');
      await shot(page, viewportWidth, '04-skillsheet-reopen');

      // --- Step 6: explicit confirmation returns to HOME and unlocks sales -
      await confirmBtn.click();
      await expect(sheetTitle).toHaveCount(0);
      const salesCta = page.getByRole('button', { name: '営業を開始', exact: true });
      await assertVisibleBox(salesCta, 'HOME sales-start CTA (営業を開始)', viewportWidth, '05-after-confirm');
      const afterConfirm = await page.locator('body').ariaSnapshot();
      expect(afterConfirm, 'confirmation advances the stage').toContain('SkillSheet確認中');
      expect(afterConfirm, 'must stay on the Public Demo HOME surface').toContain('社員ステージ');
      expect(afterConfirm, 'must not be terminal after confirming').not.toContain('このプレイスルーは終了しました。');
      await assertNoHorizontalOverflow(page, viewportWidth, '05-after-confirm');
      await auditButtons(page, viewportWidth, '05-after-confirm');
      await shot(page, viewportWidth, '05-after-confirm');

      // --- Step 7: sales start actually runs, and leaves a live next step --
      await salesCta.click();
      await expect(async () => {
        const raw = await page.locator('body').ariaSnapshot();
        expect(raw, 'sales must have started').toContain('営業中');
      }).toPass({ timeout: 20_000 });

      const afterSales = await page.locator('body').ariaSnapshot();
      expect(afterSales, 'must not be terminal after sales start').not.toContain('このプレイスルーは終了しました。');
      expect(afterSales, 'must not be bankrupt after sales start').not.toContain('倒産');

      // Dead-end check: sweep the whole scrollable HOME, not just the top
      // fold, and require a real enabled action to still be offered.
      const enabled = new Set<string>();
      let swept = 0;
      await page.mouse.move(viewportWidth / 2, (page.viewportSize()?.height ?? 800) / 2);
      for (let i = 0; i < 12; i++) {
        for (const { name } of await buttonBoxes(page)) {
          const btn = page.getByRole('button', { name, exact: true }).first();
          if (name && name !== 'Dismiss' && (await btn.isEnabled())) enabled.add(name);
        }
        await page.mouse.wheel(0, 700);
        swept += 700;
        await page.waitForTimeout(250);
      }
      await page.mouse.wheel(0, -swept);
      await page.waitForTimeout(500);
      expect(enabled.size, 'dead end: no enabled action anywhere on HOME after sales start').toBeGreaterThan(0);

      await assertNoHorizontalOverflow(page, viewportWidth, '06-sales-start');
      await auditButtons(page, viewportWidth, '06-sales-start');
      await shot(page, viewportWidth, '06-sales-start');

      // --- Runtime health -------------------------------------------------
      expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
      expect(errors.crashed, 'page crashed').toBe(false);
      expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);

      const findingsPath = path.join(SHOT_ROOT, String(viewportWidth), 'findings.json');
      fs.writeFileSync(
        findingsPath,
        JSON.stringify({ viewportWidth, enabledActionsAfterSalesStart: [...enabled], findings }, null, 2),
        'utf-8',
      );
      await testInfo.attach(`findings-${viewportWidth}`, { path: findingsPath, contentType: 'application/json' });

      expect(findings, `visual findings at ${viewportWidth}px`).toEqual([]);
    });
  });
}
