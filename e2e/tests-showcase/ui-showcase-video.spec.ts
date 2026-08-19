// **Video-showcase spec — manual run only, never part of the normal E2E
// suite.** Purpose is different from every spec under ../tests/: those
// exist to prove the UI never dead-ends; this one exists purely so a human
// can *watch* a real playthrough exercise the UI改修 implemented so far —
// Home, 社員タブ Phase 2 (すべて/参画中/待機中 filter, サマリー, 稼働率,
// 平均Morale/Trust, EngineerAvatar), 案件タブ Phase 2 (営業中/選考中/オファー
// /参画中サマリー, 要対応, 営業状況, フィルターChip, Fit ◎○△×, 参画中案件,
// 「案件一覧を見る」導線), and — if reachable in this run — an image-backed
// event modal (画像付きイベントモーダル Phase 1).
//
// Run with `npm run showcase:video` (see package.json), which points
// Playwright at ../playwright.showcase.config.ts — a dedicated config/testDir
// (tests-showcase/) `npm test`/CI's own `playwright test` never looks
// inside, so this spec adds zero time to the normal suite. See
// e2e/README.md's "Video showcase (manual only)" section.
//
// Every action here is a real tap on real production UI, driven by
// helpers/ses-player.ts's already-validated Founding driver plus this
// file's own hand-driven steps (via helpers/showcase-player.ts) once that
// driver hands off — never a debug/state API (see e2e/README.md "Why no
// debug API"). Fixed seed (`SES_E2E_SHOWCASE_SEED`, default 100001): every
// RNG draw this scenario touches is a pure function of (state.seed,
// state.week, salt), so a fixed seed plus this file's fixed action sequence
// reproduces the same state/order every run (§ task brief).
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { watchForErrors, captureMilestone } from '../helpers/artifacts';
import { hasText, snapshotScreen } from '../helpers/game-state';
import {
  HOME_TAB,
  EMPLOYEES_TAB,
  RECRUITMENT_TAB,
  PROJECTS_TAB,
  START_SALES,
  CONFIRM_START_SALES,
  POST_LISTING,
  VIEW_PROJECT_LIST,
  byButton,
  byTab,
  clickResilient,
  clickChipByPrefix,
  settleDialogs,
  advanceOneWeek,
  isImageEventModal,
  findFirstEngineerCard,
  hireFirstAvailableApplicant,
  readEmployeeCounts,
  scrollUntilButtonFound,
  scrollToTop,
  pauseForViewing,
} from '../helpers/showcase-player';

const SHOWCASE_SEED = Number(process.env.SES_E2E_SHOWCASE_SEED || 100001);

const FOUNDING_MAX_WEEKS = 12;
const FOUNDING_MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;

// How many "次の週へ" advances the enrichment phase gets, total, to build up
// a 社員/案件タブ worth actually showcasing (recruit a second employee,
// start their sales, and — best effort — let a first interview
// offer/request arrive for them). Bounded, ordinary weekly progression, the
// same shape every other driver in this harness uses — never an unbounded
// wait. A hire decision here can (a) be declined by the candidate
// (`RecruitmentEngine.rollAcceptance` — a real per-seed roll, same as
// phase-3b1-fit-reason.spec.ts's own file-level doc comment describes for
// its analogous interview-offer wait) and, even when accepted, (b) only
// actually join the roster 1-2 weeks later (`RecruitmentEngine.
// joinDelayWeeks`) — so this budget has to cover several candidates/weeks,
// not just one, while staying well short of this config's own 15-minute
// test timeout.
const MAX_ENRICHMENT_WEEKS = 10;

// How long each main screen stays on screen for a human to actually read it
// (§ task brief: "各主要画面を人間が確認できる程度の短い表示時間"). This is
// this spec's own, separate viewing-pace constant — it changes nothing in
// playwright.config.ts's actionTimeout/navigationTimeout/expect.timeout, or
// in any existing spec's own timing.
const VIEW_MS = 2_600;
const EVENT_MODAL_VIEW_MS = 3_800;

test('S.E.S. UI Showcase Video — Home / 社員タブPhase2 / 案件タブPhase2 / event modal', async ({ page }, testInfo) => {
  const errors = watchForErrors(page);
  let imageEventModalCaptured = false;

  await page.goto(`/?e2e=1&seed=${SHOWCASE_SEED}`);
  await page.locator('flt-semantics').first().waitFor({ state: 'attached', timeout: 45_000 });

  // --- Founding -> first assignment --------------------------------------
  // Reuses the existing, already-validated driver completely unchanged —
  // this spec never reimplements Founding navigation.
  const founding = await playFoundingToFirstAssignment(page, {
    maxWeeks: FOUNDING_MAX_WEEKS,
    maxActions: FOUNDING_MAX_ACTIONS,
    idleTimeoutMs: IDLE_TIMEOUT_MS,
    stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
  });
  expect(founding.stallDetected, `founding dead-end/stall: ${founding.stallReason}`).toBe(false);
  expect(founding.completed, 'did not reach first assignment').toBe(true);
  await captureMilestone(page, testInfo, '01-first-assignment');
  await pauseForViewing(page, VIEW_MS);

  await clickResilient(page, byButton(page, '経営を始める'), '経営を始める').catch(() => {});
  await page.waitForTimeout(500);
  await settleDialogs(page);

  // --- Enrichment: recruit a second employee, put them into 営業中, and
  // give them a real chance at an interview offer, so 社員タブ/案件タブ
  // Phase 2 have more than a single participating engineer to show
  // (要対応・営業状況・Fitバッジ all need a non-assigned, actively-selling
  // engineer to render at all — see sales_overview_screen.dart). Entirely
  // best-effort: wrapped so a step not panning out for this seed/timing
  // still leaves a complete, watchable video of whatever real state exists,
  // never a failed/aborted recording. ---
  let recruitmentAttempted = false;
  // True once 社員タブ's own "すべて N" count actually grew past the single
  // founding hire — not "an interview/hire decision happened" (see
  // readEmployeeCounts's own doc comment for why those two are different
  // things: acceptance is a real per-seed roll, and even an accepted offer
  // only joins the roster 1-2 weeks later).
  let secondEngineerJoined = false;
  let salesStarted = false;
  // How many real hire *decisions* ("採用する" tapped at "面接まとめ") this
  // run has made so far — capped independently of secondEngineerJoined.
  // Found and fixed via two real reproductions during development: without
  // this cap, the "keep trying every week until secondEngineerJoined" loop
  // kept interviewing and hiring *further* candidates during the 1-2 week
  // lag between an accepted decision and the roster actually growing
  // (`RecruitmentEngine.joinDelayWeeks`) — because `secondEngineerJoined`
  // doesn't flip true until the join actually lands. Even capped at 2
  // attempts (the second reproduction: exactly 2 accepted hires, 3
  // employees total, mostly idle/待機中 collecting salary against this
  // seed's single active contract's revenue) the company still went
  // bankrupt (倒産) — the showcase only ever needs *one* extra, actively-
  // selling engineer, so this stays at 1: enough to demonstrate 社員タブ/
  // 案件タブ Phase 2 with more than the single founding hire, without
  // outrunning cash flow over this phase's own multi-week budget.
  let hireAttempts = 0;
  const MAX_HIRE_ATTEMPTS = 1;

  /** Best-effort: does the 社員タブ roster already have more than 1 engineer
   * (i.e. did a previously-hired candidate actually join)? Navigates to the
   * 社員 tab to check, leaving the app there. */
  async function checkSecondEngineerJoined(): Promise<boolean> {
    await clickResilient(page, byTab(page, EMPLOYEES_TAB), '社員タブ').catch(() => {});
    await page.waitForTimeout(300);
    const counts = await readEmployeeCounts(page);
    return !!counts && counts.all >= 2;
  }

  /** Opens the first 待機中-filtered engineer's own detail screen and taps
   * "営業を開始する" -> "営業開始" (a real, always-legal action for a
   * non-selling engineer — engineer_detail_screen.dart's own
   * `_confirmSalesStart`). Returns whether it actually started. */
  async function startSalesForFirstWaitingEngineer(): Promise<boolean> {
    await clickResilient(page, byTab(page, EMPLOYEES_TAB), '社員タブ').catch(() => {});
    await page.waitForTimeout(400);
    const startedFilter = await clickChipByPrefix(page, '待機中 ');
    if (!startedFilter) return false;
    await page.waitForTimeout(300);
    const snap = await snapshotScreen(page);
    const card = findFirstEngineerCard(snap);
    if (!card) return false;
    await clickResilient(page, byButton(page, card.name), card.name);
    await page.waitForTimeout(500);

    const detail = await snapshotScreen(page);
    const startBtn = detail.buttons.find((b) => b.enabled && b.name === START_SALES);
    if (!startBtn) {
      await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 2_000 }).catch(() => {});
      return false;
    }
    await clickResilient(page, byButton(page, START_SALES), START_SALES);
    await page.waitForTimeout(400);
    await clickResilient(page, byButton(page, CONFIRM_START_SALES), CONFIRM_START_SALES).catch(() => {});
    await page.waitForTimeout(400);
    await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 2_000 }).catch(() => {});
    return true;
  }

  async function enrichAndCaptureEventModal(): Promise<void> {
    await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ').catch(() => {});
    await page.waitForTimeout(400);

    for (let week = 0; week < MAX_ENRICHMENT_WEEKS; week++) {
      // advanceOneWeek only ever finds "次の週へ" on Home — the previous
      // iteration can end on the 採用/社員 tab (recruitment check / sales
      // start below), so every iteration starts by returning to Home first.
      await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ').catch(() => {});
      await page.waitForTimeout(300);
      // advanceOneWeek drains *every* dialog this advance produces (a
      // single week can queue several — e.g. an interview-offer
      // celebration whose own tap-through navigates to a detail screen,
      // followed by a Beginner Mode milestone dialog on top of that same
      // screen), inspecting each one via this callback before dismissing
      // it — pausing/capturing the first image-backed one encountered.
      const afterAdvance = await advanceOneWeek(page, async (dialogSnap) => {
        if (!imageEventModalCaptured && isImageEventModal(dialogSnap)) {
          await captureMilestone(page, testInfo, '30-image-event-modal');
          await pauseForViewing(page, EVENT_MODAL_VIEW_MS);
          imageEventModalCaptured = true;
        }
      });
      if (!afterAdvance) break;

      // 採用 unlocks (UnlockEngine.weeksBeforeCompanyGrowth = 2 weeks after
      // first assignment) partway through this loop — the bottom-nav "採用"
      // tab itself is *always* present (it just shows
      // recruitment_screen.dart's own `_RecruitmentLockedScreen`, its own
      // "🔒" + "採用" heading, until then), so lock state has to be read off
      // the screen itself, not off tab presence.
      if (!secondEngineerJoined && hireAttempts < MAX_HIRE_ATTEMPTS) {
        await clickResilient(page, byTab(page, RECRUITMENT_TAB), '採用タブ').catch(() => {});
        await page.waitForTimeout(400);
        const recruitSnap = await snapshotScreen(page);
        const locked = hasText(recruitSnap, '🔒');
        if (!locked) {
          if (!recruitmentAttempted) {
            const postBtn = recruitSnap.buttons.find((b) => b.enabled && b.name === POST_LISTING);
            if (postBtn) {
              recruitmentAttempted = true;
              await clickResilient(page, byButton(page, POST_LISTING), POST_LISTING).catch(() => {});
              await page.waitForTimeout(500);
            }
          }
          // Bounded by MAX_HIRE_ATTEMPTS (see hireAttempts's own doc
          // comment) — never keeps interviewing/hiring further candidates
          // just because the roster hasn't visibly grown yet.
          const outcome = await hireFirstAvailableApplicant(page);
          if (outcome === 'decided') hireAttempts++;
        }
      }
      secondEngineerJoined = await checkSecondEngineerJoined();

      if (secondEngineerJoined && !salesStarted) {
        salesStarted = await startSalesForFirstWaitingEngineer();
      }

      // Deliberately no early break once secondEngineerJoined && salesStarted:
      // the remaining budget keeps advancing weeks (cheap once both gates are
      // already satisfied — the recruitment/sales-start blocks above are then
      // both skipped) purely to give the newly-selling engineer a real chance
      // at an interview offer/request before this phase ends, so 案件タブ
      // Phase 2's own 要対応/Fitバッジ have something real to show (§ same
      // ~2-week-observed timing phase-3b1-fit-reason.spec.ts documents for
      // an analogous wait, with margin here since this run's own timing
      // hasn't been separately profiled).
    }
  }

  try {
    await enrichAndCaptureEventModal();
  } catch (err) {
    // eslint-disable-next-line no-console
    console.log('[showcase] enrichment step did not complete, continuing with the state reached so far:', err);
  }

  // --- ① Home画面 ---------------------------------------------------------
  await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ').catch(() => {});
  await settleDialogs(page);
  await expect(async () => {
    const snap = await snapshotScreen(page);
    expect(hasText(snap, '会社の状況') || hasText(snap, '今やること')).toBe(true);
  }).toPass({ timeout: 15_000 });
  await captureMilestone(page, testInfo, '10-home');
  await pauseForViewing(page, VIEW_MS);

  // --- ② 社員タブ Phase 2 --------------------------------------------------
  await clickResilient(page, byTab(page, EMPLOYEES_TAB), '社員タブ');
  await expect(async () => {
    const snap = await snapshotScreen(page);
    // すべて/参画中/待機中フィルター + 社員サマリー(稼働率/平均Morale/平均Trust)。
    expect(hasText(snap, '稼働率') && hasText(snap, '平均Morale') && hasText(snap, '平均Trust')).toBe(true);
  }).toPass({ timeout: 15_000 });
  await captureMilestone(page, testInfo, '20-employees-all');
  await pauseForViewing(page, VIEW_MS);

  // 参画中 / 待機中 / すべて フィルター切り替え — EngineerAvatar はどのカードに
  // も既に表示されている（engineer_list_screen.dart の _EngineerCard）。
  if (await clickChipByPrefix(page, '参画中 ')) {
    await captureMilestone(page, testInfo, '21-employees-assigned');
    await pauseForViewing(page, VIEW_MS);
  }
  if (await clickChipByPrefix(page, '待機中 ')) {
    await captureMilestone(page, testInfo, '22-employees-waiting');
    await pauseForViewing(page, VIEW_MS);
  }
  await clickChipByPrefix(page, 'すべて ');
  await pauseForViewing(page, 1_200);

  // --- ③ 案件タブ Phase 2 --------------------------------------------------
  await clickResilient(page, byTab(page, PROJECTS_TAB), '案件タブ');
  await expect(async () => {
    const snap = await snapshotScreen(page);
    // 営業中/選考中/オファー/参画中サマリー。
    expect(hasText(snap, '営業中') && hasText(snap, '選考中') && hasText(snap, 'オファー')).toBe(true);
  }).toPass({ timeout: 15_000 });
  await captureMilestone(page, testInfo, '40-projects-overview');
  await pauseForViewing(page, VIEW_MS);

  // フィルターChip: 営業中/選考中/オファー/すべて (要対応・Fitバッジ・
  // 参画中案件は enrichment 次第で内容が変わるため、あれば映る)。
  for (const prefix of ['営業中 ', '選考中 ', 'オファー ', 'すべて ']) {
    if (await clickChipByPrefix(page, prefix)) {
      await pauseForViewing(page, 1_400);
    }
  }
  await captureMilestone(page, testInfo, '41-projects-filtered');

  // 「案件一覧を見る」導線 — 末尾までスクロールしてから開く。
  const scrolled = await scrollUntilButtonFound(page, VIEW_PROJECT_LIST);
  if (scrolled.buttons.some((b) => b.enabled && b.name === VIEW_PROJECT_LIST)) {
    await captureMilestone(page, testInfo, '42-projects-explore-cta');
    await pauseForViewing(page, 1_600);
    await clickResilient(page, byButton(page, VIEW_PROJECT_LIST), VIEW_PROJECT_LIST);
    await page.waitForTimeout(600);
    await captureMilestone(page, testInfo, '43-project-list-screen');
    await pauseForViewing(page, VIEW_MS);
    await page.getByRole('button', { name: /^Back\b/i }).first().click({ timeout: 5_000 }).catch(() => {});
    await page.waitForTimeout(400);
  }
  await scrollToTop(page);

  // --- ④ 画像付きイベントモーダル (到達可能なら) ---------------------------
  // Enrichment 中に既に捕捉できていればそれで十分 — まだなら、この動画の
  // 予算内でもう少しだけ週を進めて探す（best-effort、失敗しても動画自体は
  // 完成させる）。
  if (!imageEventModalCaptured) {
    try {
      await clickResilient(page, byTab(page, HOME_TAB), 'ホームタブ').catch(() => {});
      for (let i = 0; i < 6 && !imageEventModalCaptured; i++) {
        const afterAdvance = await advanceOneWeek(page, async (dialogSnap) => {
          if (!imageEventModalCaptured && isImageEventModal(dialogSnap)) {
            await captureMilestone(page, testInfo, '30-image-event-modal');
            await pauseForViewing(page, EVENT_MODAL_VIEW_MS);
            imageEventModalCaptured = true;
          }
        });
        if (!afterAdvance) break;
      }
    } catch (err) {
      // eslint-disable-next-line no-console
      console.log('[showcase] no image-backed event modal reached within this run\'s budget:', err);
    }
  }

  // eslint-disable-next-line no-console
  console.log(
    `[showcase] seed=${SHOWCASE_SEED} device=${testInfo.project.name} imageEventModalCaptured=${imageEventModalCaptured} ` +
      `recruitmentAttempted=${recruitmentAttempted} secondEngineerJoined=${secondEngineerJoined} salesStarted=${salesStarted} ` +
      `consoleErrors=${errors.consoleErrors.length} pageErrors=${errors.pageErrors.length}`,
  );

  // This spec exists for the recording, not as a correctness gate — but a
  // crashed page or an uncaught error mid-recording means the video isn't
  // showing real, working UI, so those still fail the run.
  expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
  expect(errors.crashed, 'page crashed').toBe(false);
});
