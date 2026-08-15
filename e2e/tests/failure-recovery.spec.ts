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
import { emptyPlayResult, playFoundingToFirstAssignment, type PlayResult } from '../helpers/ses-player';
import { buildResultJson, captureMilestone, watchForErrors, writeArtifacts } from '../helpers/artifacts';

const SEED = 900001;
const MAX_WEEKS = 12;
const MAX_ACTIONS = 100;
const IDLE_TIMEOUT_MS = 30_000;
const STALL_REPEAT_THRESHOLD = 5;

test(`Failure Recovery — explicit 不採用 still reaches first assignment (seed ${SEED})`, async ({ page }, testInfo) => {
  const errors = watchForErrors(page);
  const startedAt = Date.now();
  let result: PlayResult | null = null;
  let playError: unknown = null;

  // try/finally (Codex follow-up §15): custom artifacts must land even if
  // something throws before the normal end of the test body.
  try {
    await page.goto(`/?e2e=1&seed=${SEED}`);

    result = await playFoundingToFirstAssignment(page, {
      maxWeeks: MAX_WEEKS,
      maxActions: MAX_ACTIONS,
      idleTimeoutMs: IDLE_TIMEOUT_MS,
      stallRepeatThreshold: STALL_REPEAT_THRESHOLD,
      forceRejectFirstCandidate: true,
    });

    await captureMilestone(page, testInfo, result.completed ? 'recovered-to-first-assignment' : 'stopped-here');
  } catch (err) {
    playError = err;
  } finally {
    const finalResult = result ?? emptyPlayResult(`playFoundingToFirstAssignment threw before returning: ${String(playError)}`);
    const resultJson = buildResultJson({
      scenario: 'failure-recovery-recruitment-reject',
      device: testInfo.project.name,
      seed: SEED,
      play: finalResult,
      errors,
      durationMs: Date.now() - startedAt,
    });
    await writeArtifacts(testInfo, resultJson, finalResult.actionTrace);
  }

  if (playError) throw playError;
  const finalResult = result!;

  // The rejection actually happened — otherwise this test isn't exercising
  // what it claims to.
  const rejectedAction = finalResult.actionTrace.find((a) => a.clicked === '不採用');
  expect(rejectedAction, 'expected an explicit 不採用 action in the trace').toBeTruthy();

  // ...and the flow recovered: at least one more "次の週へ" / recruitment
  // cycle happened after the rejection, on the way to completion.
  const rejectedAt = rejectedAction!.action;
  const actionsAfterReject = finalResult.actionTrace.filter((a) => a.action > rejectedAt);
  expect(actionsAfterReject.length, 'no further actions were possible after 不採用 (dead-end)').toBeGreaterThan(0);

  // Identity (Codex follow-up §12, re-review §14): the rejected candidate
  // and the one eventually hired must be different people, not the same
  // name recorded twice — both names come straight off the
  // recruitment-interview screen's own AppBar title, never GameState (see
  // extractInterviewCandidateName in helpers/game-state.ts). Both names
  // must actually be recoverable — a `null` here silently hid a real
  // identity-tracking gap behind a UI-visibility excuse; now it's a hard
  // failure rather than a skip.
  test.info().annotations.push({
    type: 'candidate-identity',
    description: `rejected="${finalResult.rejectedCandidateName}" accepted="${finalResult.acceptedCandidateName}"`,
  });
  expect(finalResult.rejectedCandidateName, 'rejected candidate name was not recoverable from the recruitment-interview screen').toBeTruthy();
  expect(finalResult.acceptedCandidateName, 'accepted candidate name was not recoverable from the recruitment-interview screen').toBeTruthy();
  expect(finalResult.acceptedCandidateName, 'the hired candidate must not be the same person who was rejected').not.toBe(
    finalResult.rejectedCandidateName,
  );

  expect(errors.pageErrors, 'uncaught page errors').toEqual([]);
  expect(errors.crashed, 'page crashed').toBe(false);
  expect(errors.consoleErrors, 'unallowlisted console.error').toEqual([]);
  expect(finalResult.stallDetected, `dead-end/stall after Failure Recovery: ${finalResult.stallReason}`).toBe(false);
  expect(finalResult.completed, 'did not recover to a first assignment after the explicit 不採用').toBe(true);
});
