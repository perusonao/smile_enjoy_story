import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { snapshotScreen, hasText, enabledButton, extractInterviewCandidateName, findDoubledParticles, firstEnabledDialogButton, type ScreenSnapshot } from '../helpers/game-state';
import { watchForErrors, captureMilestone } from '../helpers/artifacts';
import { parseSeeds } from '../helpers/seeds';

const DEFAULT_SEEDS = [100001];
const parsedSeeds = parseSeeds(process.env.SES_E2E_WAITING_RECRUITMENT_SEEDS, DEFAULT_SEEDS);

const FOUNDING_MAX_WEEKS = 12;
const FOUNDING_MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;
const CLOSE = ['閉じる', 'OK', '会社状況を見る', '面談依頼を見る', '採用を見る', '社員環境を見る', 'それでも進む', '社員に任せて進む', '採用画面へ戻る'];

async function settleAndScan(
  page: import('@playwright/test').Page,
  textOffenders: string[],
  stopWhen?: (snap: ScreenSnapshot) => boolean,
): Promise<ScreenSnapshot | null> {
  for (let i = 0; i < 15; i++) {
    const snap = await snapshotScreen(page);
    textOffenders.push(...findDoubledParticles(snap));
    if (stopWhen?.(snap)) return snap;
    const close = firstEnabledDialogButton(snap, CLOSE);
    if (!close) return null;
    await page.getByRole('button', { name: close.name, exact: true }).click();
    await page.waitForTimeout(500);
    const homeTab = page.getByRole('tab', { name: 'ホーム', exact: true });
    if (await isVisibleTab(homeTab)) {
      const cur = await snapshotScreen(page);
      if (!cur.buttons.some((b) => b.name.startsWith('次の週へ'))) {
        await homeTab.click().catch(() => {});
        await page.waitForTimeout(400);
      }
    }
  }
  return null;
}

async function isVisibleTab(tab: import('@playwright/test').Locator): Promise<boolean> {
  return tab.isVisible().catch(() => false);
}

async function advanceWeekAndFind(
  page: import('@playwright/test').Page,
  textOffenders: string[],
  stopWhen: (snap: ScreenSnapshot) => boolean,
): Promise<ScreenSnapshot | null> {
  await settleAndScan(page, textOffenders);
  const snap = await snapshotScreen(page);
  const nextBtn = snap.buttons.find((b) => b.enabled && b.name.startsWith('次の週へ'));
  if (!nextBtn) return null;
  await clickResilient(page, byButton(page, nextBtn.name), nextBtn.name);
  await page.waitForTimeout(700);
  return settleAndScan(page, textOffenders, stopWhen);
}

async function waitForTabBar(page: import('@playwright/test').Page, textOffenders: string[], tabName: string): Promise<boolean> {
  const tab = page.getByRole('tab', { name: tabName, exact: true });
  const dialogScope = page.locator('[role="dialog"], [role="alertdialog"]');
  for (let i = 0; i < 60; i++) {
    if (await isVisibleTab(tab)) return true;
    let dismissed = false;
    for (const label of CLOSE) {
      const btn = dialogScope.getByRole('button', { name: label, exact: true });
      if (await btn.count()) {
        await btn.click().catch(() => {});
        dismissed = true;
        break;
      }
    }
    if (!dismissed) {
      await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 500 }).catch(() => {});
    }
    if (!dismissed && i % 5 === 4) {
      await page.getByRole('tab', { name: tabName, exact: true }).click({ timeout: 500 }).catch(() => {});
    }
    await page.waitForTimeout(500);
  }
  return isVisibleTab(tab);
}

/**
 * The tab shell can remain visible in Flutter semantics while
 * ApplicantDetailScreen is still the foreground route. Keep recovering until
 * the detail CTA is gone and the recruitment tab is both visible and active.
 */
async function returnToRecruitmentRoot(
  page: import('@playwright/test').Page,
  textOffenders: string[],
): Promise<boolean> {
  const recruitmentTab = page.getByRole('tab', { name: '採用', exact: true });
  const detailCta = page.getByRole('button', { name: /^(面接する|面接を再開する)$/ });

  for (let i = 0; i < 60; i++) {
    if (!await waitForTabBar(page, textOffenders, '採用')) return false;

    if (await detailCta.first().isVisible().catch(() => false)) {
      await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 750 }).catch(() => {});
      await page.waitForTimeout(300);
      continue;
    }

    if (await recruitmentTab.getAttribute('aria-selected').catch(() => null) !== 'true') {
      await recruitmentTab.click({ timeout: 750 }).catch(() => {});
      await page.waitForTimeout(300);
      continue;
    }

    if (await isVisibleTab(recruitmentTab)) return true;
    await page.waitForTimeout(300);
  }
  return false;
}

const CLICK_RESILIENT_TOTAL_MS = 15_000;
const CLICK_RESILIENT_ATTEMPT_MS = 3_000;

async function clickResilient(page: import('@playwright/test').Page, locate: () => import('@playwright/test').Locator, label: string): Promise<void> {
  const deadline = Date.now() + CLICK_RESILIENT_TOTAL_MS;
  while (true) {
    const remaining = deadline - Date.now();
    const attemptTimeout = Math.max(500, Math.min(CLICK_RESILIENT_ATTEMPT_MS, remaining));
    try {
      await locate().click({ timeout: attemptTimeout });
      return;
    } catch (err) {
      if (Date.now() >= deadline) throw err;
      const snap = await snapshotScreen(page);
      const close = firstEnabledDialogButton(snap, CLOSE.filter((name) => name !== label));
      if (close) {
        await page.getByRole('button', { name: close.name, exact: true }).click().catch(() => {});
        await page.waitForTimeout(300);
      }
    }
  }
}

const byButton = (page: import('@playwright/test').Page, name: string) => () => page.getByRole('button', { name, exact: true }).first();
const byTab = (page: import('@playwright/test').Page, name: string) => () => page.getByRole('tab', { name, exact: true });

/**
 * ApplicantDetailScreen puts its interview CTA below a long CV ListView on
 * mobile. Flutter does not always materialize the off-screen CTA in the
 * accessibility tree, so waiting alone can falsely conclude there is no
 * interview action. While there are no enabled semantic buttons, scroll the
 * foreground ListView and re-snapshot until the CTA (or another real action)
 * is materialized. This is bounded and only runs on the no-action state.
 */
async function waitForAnyEnabledButton(page: import('@playwright/test').Page): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  for (let i = 0; i < 40 && !snap.buttons.some((b) => b.enabled); i++) {
    const viewport = page.viewportSize();
    if (viewport) {
      await page.mouse.move(Math.floor(viewport.width / 2), Math.floor(viewport.height / 2));
      await page.mouse.wheel(0, Math.max(420, Math.floor(viewport.height * 0.75)));
    }
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
  }
  return snap;
}

function isInterviewScreenReady(snap: ScreenSnapshot): boolean {
  const stillOnApplicantDetail = snap.buttons.some((b) => b.enabled && (b.name === '面接する' || b.name === '面接を再開する'));
  if (stillOnApplicantDetail) return false;
  return extractInterviewCandidateName(snap) !== null;
}

async function waitForInterviewScreenTransition(page: import('@playwright/test').Page): Promise<ScreenSnapshot> {
  let snap = await snapshotScreen(page);
  for (let i = 0; i < 40 && !isInterviewScreenReady(snap); i++) {
    await page.waitForTimeout(300);
    snap = await snapshotScreen(page);
  }
  return snap;
}

async function clickAndWaitForChange(
  page: import('@playwright/test').Page,
  buttonName: string,
  beforeSnap: ScreenSnapshot,
): Promise<ScreenSnapshot> {
  await clickResilient(page, byButton(page, buttonName), buttonName);
  const beforeKey = JSON.stringify(beforeSnap.texts);
  for (let i = 0; i < 40; i++) {
    await page.waitForTimeout(300);
    const snap = await snapshotScreen(page);
    if (JSON.stringify(snap.texts) !== beforeKey) return snap;
  }
  return snapshotScreen(page);
}

if (parsedSeeds.error) {
  test('SES_E2E_WAITING_RECRUITMENT_SEEDS is invalid', () => {
    throw new Error(parsedSeeds.error!);
  });
}

for (const seed of parsedSeeds.seeds) {
  test(`Phase 3A: recruitment flow stays operable in real UI, no dead-end (seed ${seed})`, async ({ page }, testInfo) => {
    test.setTimeout(6 * 60 * 1000);
    const errors = watchForErrors(page);
    const textOffenders: string[] = [];

    await page.goto(`/?e2e=1&seed=${seed}`);
    await playFoundingToFirstAssignment(page, {
      maxWeeks: FOUNDING_MAX_WEEKS,
      maxActions: FOUNDING_MAX_ACTIONS,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
    });
    await clickResilient(page, byButton(page, '経営を始める'), '経営を始める').catch(() => {});
    await page.waitForTimeout(1000);
    await settleAndScan(page, textOffenders);

    for (let i = 0; i < 4; i++) {
      await advanceWeekAndFind(page, textOffenders, () => false);
    }
    await captureMilestone(page, testInfo, '01-recruitment-unlocked');

    await clickResilient(page, byTab(page, '採用'), '採用タブ');
    await page.waitForTimeout(500);
    await clickResilient(page, byButton(page, '掲載する'), '掲載する');
    await page.waitForTimeout(600);
    const after = await snapshotScreen(page);
    expect(after.buttons.some((b) => b.name.startsWith('掲載中')), 'second listing did not actually post').toBe(true);

    await clickResilient(page, byTab(page, 'ホーム'), 'ホームタブ');
    await page.waitForTimeout(500);
    const tradeoffDialog = await advanceWeekAndFind(page, textOffenders, (snap) => hasText(snap, '採用のトレードオフ'));
    expect(tradeoffDialog, `採用のトレードオフ dialog never appeared after posting a second listing (seed=${seed})`).not.toBeNull();
    expect(hasText(tradeoffDialog!, '固定支出')).toBe(true);
    await captureMilestone(page, testInfo, '02-recruitment-tradeoff-dialog');
    await settleAndScan(page, textOffenders);

    expect(
      await returnToRecruitmentRoot(page, textOffenders),
      'Recruitment root never became visible and active before the first hire attempt',
    ).toBe(true);

    const HIRE_ATTEMPTS = 3;
    for (let attempt = 0; attempt < HIRE_ATTEMPTS; attempt++) {
      expect(
        await returnToRecruitmentRoot(page, textOffenders),
        `Recruitment root was not stable before candidate query for attempt ${attempt} (seed=${seed})`,
      ).toBe(true);
      const candidate = page.getByRole('button', { name: /未面接/ }).first();
      if ((await candidate.count()) === 0) break;
      await clickResilient(page, () => page.getByRole('button', { name: /未面接/ }).first(), '未面接候補者');

      const snapAfterOpen = await waitForAnyEnabledButton(page);
      const interviewBtn = enabledButton(snapAfterOpen, '面接する') ?? enabledButton(snapAfterOpen, '面接を再開する');
      if (!interviewBtn) {
        expect(
          await returnToRecruitmentRoot(page, textOffenders),
          `Recruitment root was not stable after skipping attempt ${attempt} (seed=${seed})`,
        ).toBe(true);
        continue;
      }
      await clickResilient(page, byButton(page, interviewBtn.name), interviewBtn.name);
      await waitForInterviewScreenTransition(page);

      for (let step = 0; step < 12; step++) {
        const snap = await snapshotScreen(page);
        textOffenders.push(...findDoubledParticles(snap));
        if (hasText(snap, '面接まとめ')) {
          await clickResilient(page, byButton(page, '採用する'), '採用する');
          break;
        }
        const anyBtn = snap.buttons.find((b) => b.enabled && b.name !== 'back');
        if (!anyBtn) break;
        await clickAndWaitForChange(page, anyBtn.name, snap);
      }

      expect(
        await returnToRecruitmentRoot(page, textOffenders),
        `Recruitment root was not stable after hire attempt ${attempt} (seed=${seed})`,
      ).toBe(true);
    }
    await captureMilestone(page, testInfo, '03-applicants-interviewed');

    expect(
      await waitForTabBar(page, textOffenders, 'ホーム'),
      `ホーム tab never became visible before final week advancement (seed=${seed})`,
    ).toBe(true);
    await clickResilient(page, byTab(page, 'ホーム'), 'ホームタブ');
    await page.waitForTimeout(500);
    for (let i = 0; i < 3; i++) {
      await advanceWeekAndFind(page, textOffenders, () => false);
    }
    await settleAndScan(page, textOffenders);

    expect(errors.pageErrors, `uncaught page errors (seed=${seed})`).toEqual([]);
    expect(errors.crashed, `page crashed (seed=${seed})`).toBe(false);
    expect(errors.consoleErrors, `unallowlisted console.error (seed=${seed})`).toEqual([]);
    expect(textOffenders, `doubled-particle text observed (seed=${seed}): ${JSON.stringify(textOffenders)}`).toEqual([]);
  });
}
