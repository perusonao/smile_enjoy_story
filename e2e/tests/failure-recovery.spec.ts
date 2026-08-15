// Failure Recovery (§11 of the E2E brief): a real, always-legal rejection
// ("不採用" on the first recruitment candidate) must never dead-end the
// Guided Founding flow — the player has to land back in a fresh sales
// opportunity and still be able to reach the first assignment.
//
// Deliberately uses a player *choice* (explicit reject) rather than hunting
// for an RNG-unlucky seed to force a failure — the same pattern
// tool/simulate_prologue.dart's `forceRejectFirst` cohort already uses for
// exactly this scenario, so this is exercising a documented, intentional
// game-design path, not a contrived one.
import { test, expect } from '@playwright/test';
import { playFoundingToFirstAssignment } from '../helpers/ses-player';
import { buildResultJson, captureMilestone, watchForErrors, writeArtifacts } from '../helpers/artifacts';

const SEED = 900001;
const MAX_WEEKS = 12;
const MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;

test(`Failure Recovery — explicit 不採用 still reaches first assignment (seed ${SEED})`, async ({ page }, testInfo) => {
  const errors = watchForErrors(page);
  const startedAt = Date.now();

  await page.goto(`/?e2e=1&seed=${SEED}`);

  const result = await playFoundingToFirstAssignment(page, {
    maxWeeks: MAX_WEEKS,
    maxActions: MAX_ACTIONS,
    idleTimeoutMs: IDLE_TIMEOUT_MS,
    stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
    forceRejectFirstCandidate: true,
  });

  await captureMilestone(page, testInfo, result.completed ? 'recovered-to-first-assignment' : 'stopped-here');

  const resultJson = buildResultJson({
    scenario: 'failure-recovery-recruitment-reject',
    device: testInfo.project.name,
    seed: SEED,
    play: result,
    errors,
    durationMs: Date.now() - startedAt,
  });
  await writeArtifacts(testInfo, resultJson, result.actionTrace);

  // The rejection actually happened — otherwise this test isn't exercising
  // what it claims to.
  const rejectedAction = result.actionTrace.find((a) => a.clicked === '不採用');
  expect(rejectedAction, 'expected an explicit 不採用 action in the trace').toBeTruthy();

  // ...and the flow recovered: at least one more "次の週へ" / recruitment
  // cycle happened after the rejection, on the way to completion.
  const rejectedAt = rejectedAction!.action;
  const actionsAfterReject = result.actionTrace.filter((a) => a.action > rejectedAt);
  expect(actionsAfterReject.length, 'no further actions were possible after 不採用 (dead-end)').toBeGreaterThan(0);

  expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
  expect(errors.crashed, 'page crashed').toBe(false);
  expect(result.stallDetected, `dead-end/stall after Failure Recovery: ${result.stallReason}`).toBe(false);
  expect(result.completed, 'did not recover to a first assignment after the explicit 不採用').toBe(true);
});
