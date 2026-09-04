# SES Issue #147 — Deployed Screen Verification Root-Cause Report

## STATUS

**Root cause identified. No production code change made — none is safe or
warranted.** This is a READ-ONLY investigation session, per the task's own
instruction that a URL-only cause must not trigger a production edit.

## SUMMARY

Issue #147's "Deployed Screen Verification" was reported FAIL because
opening `https://perusonao.github.io/smile_enjoy_story/` (the bare
production root URL) on a real device shows the old Development-experience
Founding Prologue screen ("創業プロローグ・3月3週"), not the approved
Public Demo HOME rebuilt by PR #150 and re-audited/merged via PR #170.

**This is not a deploy defect and not a routing bug.** The bare root URL is,
by long-standing, tested, and already-documented design, the **Development**
experience entry point — a separate product experience from Public Demo
0.1. The rebuilt Public Demo HOME *is* live on production at SHA
`76ca2b0b6dd598e5d18ed9a88379bf20b95ed79c`, but only at the Public Demo
entry routes, not at the bare root. The verification check opened the wrong
URL.

## ROOT CAUSE — EVIDENCE CHAIN

1. **`lib/app/app_entry.dart` → `resolveAppExperience(Uri uri)`** switches
   on `uri.fragment`: only the literal `public-demo-01` fragment resolves to
   `AppExperience.publicDemo01`. Every other fragment, **including no
   fragment at all (the bare root URL)**, resolves to
   `AppExperience.development`. This is the single source of truth for
   which experience boots.

2. **`lib/main.dart` → `_GameRootState.build`**: whenever the resolved
   experience is not `publicDemo01`, the widget tree falls through to the
   Development experience — `StartChoiceScreen` (fresh device) or, if a
   Development save already exists on that device/browser,
   `PrologueScreen`/`MainShell` resuming that save's actual progress. It
   never shows `PublicDemo01PlaceholderScreen` (the rebuilt HOME) unless the
   resolved experience is `publicDemo01`.

3. **`lib/game/persistence/save_service.dart` → `SaveService.forExperience`**:
   Development and Public Demo 0.1 saves are stored under two separate,
   isolated `SharedPreferences`/`localStorage` keys
   (`developmentKey` / `publicDemo01Key`). A Development save from any
   earlier use of that same browser persists independently and is exactly
   what gets resumed at the bare root — which explains why the screenshot
   shows a **specific**, already-in-progress prologue state
   ("3月3週") rather than a fresh start-choice screen: that device had
   Development-experience save data from a prior visit, and root URL
   correctly resumed it. This is expected persistence behavior, not
   corruption or a stale build.

4. **`lib/app/app_entry.dart` doc comment on
   `resolveAppExperienceWithSaveFallback`** (SES-FIRST-FUN-YEAR-RELOAD-1,
   PR #164 P1 review fix) documents that this was a *deliberate* decision,
   arrived at after an earlier version of this exact fallback was rejected
   as a bug: mere *presence* of a Public Demo save must never hijack a
   genuine Development/root visit. Only an explicit `#/public-demo-01` URL,
   or a same-tab `sessionStorage` marker written the moment that tab first
   showed Public Demo, resumes Public Demo from the root path. A fresh
   real-device visit — or any visit from a browser/tab that has never shown
   Public Demo — has neither, so it correctly stays on Development.

5. **`web/public-demo/index.html`** is the already-existing, already-tested
   stable Public Demo entry page: a static redirect
   (`location.replace('../#/public-demo-01')` + meta-refresh fallback) into
   the canonical hash route. `flutter build web` copies everything under
   `web/` verbatim except `web/index.html` itself (only that file receives
   `--base-href` templating), so this file is copied unmodified into
   `build/web/public-demo/index.html` on every build — confirmed both by
   the comment in `test/web/public_demo_entry_page_test.dart` and by that
   test's own regression assertions (file exists, contains the relative
   `../#/public-demo-01` redirect, uses `location.replace`, has no
   absolute-URL literal).

6. **`README.md` (lines 18–28, "Public Demo 0.1 (external playtesters)")**
   already documents this exact contract in writing:
   > Share this stable URL with external testers:
   > `https://perusonao.github.io/smile_enjoy_story/public-demo/`
   > It's a static redirect... into the existing `#/public-demo-01` route...
   > This is separate from the development root
   > (`https://perusonao.github.io/smile_enjoy_story/`), which keeps
   > launching the normal development experience.

7. **CI/deploy pipeline is healthy and did deploy the correct commit.**
   `.github/workflows/e2e.yml` builds with
   `--base-href "/${{ github.event.repository.name }}/"`, i.e.
   `/smile_enjoy_story/`, matching the reported production URL exactly.
   Confirmed via the GitHub Actions API for the exact run named in the
   task:
   - Workflow run **#443** (`id 33893651181`), event `push`, head
     `76ca2b0b6dd598e5d18ed9a88379bf20b95ed79c` (`main`, merge commit for
     PR #170) — `conclusion: success`.
   - All 7 jobs green: `validate` (flutter analyze / flutter test /
     flutter build web, all `success`), `replay-unit`, `smoke-e2e`,
     `check-latest`, `replay-package`, `build`
     (`actions/upload-pages-artifact@v3` succeeded), and **`deploy`**
     (`actions/deploy-pages@v4` completed successfully at
     2026-09-04T16:24:54Z).
   - So the currently-live production build is confirmed to be built from
     `76ca2b0`, which already contains the merged Public Demo HOME work
     (PR #150, re-audited and merged via PR #170). There is no evidence of
     a stale or failed deploy.

8. **Changing the root URL to default into Public Demo would break an
   existing, tested, documented contract**, which the task explicitly asked
   this session not to do unilaterally:
   - It contradicts the written contract in `README.md` above.
   - It reverses the deliberate PR #164
     (SES-FIRST-FUN-YEAR-RELOAD-1) fix, whose own doc comment in
     `app_entry.dart` specifically warns against exactly this kind of
     URL/save conflation (an earlier, *wrong* version of that fallback did
     something close to this and was rejected in review as P1).
   - It would break `e2e/tests/founding-first-assignment.spec.ts` and
     `e2e/tests/beginner-mode-april-june.spec.ts`, two Playwright suites
     that are part of the required CI gate and that intentionally
     `page.goto('/?e2e=1&seed=...')` — root, no hash — expecting the
     Development experience (Founding Prologue → first案件参画) to boot
     there. Redirecting root to Public Demo would fail both suites and
     weaken/change E2E behavior, which the task explicitly forbade.

   Per the task's own instruction ("root URLをPublic Demoへ変更することが
   既存仕様を壊すなら、勝手に変更せず報告する"), this session did **not**
   make that change and is reporting it here instead.

## WHY THE SCREENSHOT SHOWS THE OLD PROLOGUE SCREEN

The device that produced the attached screenshot opened the bare root URL.
`Uri.base` at boot therefore carried no `#/public-demo-01` fragment, and
that browser/tab had no Public Demo session marker (it had never shown
Public Demo in that tab), so `resolveAppExperience` /
`resolveAppExperienceWithSaveFallback` correctly resolved to
`AppExperience.development`. Because that same device already had an
in-progress Development save from earlier use (isolated under
`SaveService.developmentKey`), the app resumed straight into that save's
actual state — the Founding Prologue at "3月3週" — instead of showing a
fresh start-choice screen. Everything here is existing, already-audited,
already-tested behavior; none of it touches the Public Demo HOME work done
for Issue #147.

## THE CORRECT PUBLIC DEMO URL(S)

- **Documented stable alias (recommended for verification/testers):**
  `https://perusonao.github.io/smile_enjoy_story/public-demo/`
- **Canonical hash route it redirects into:**
  `https://perusonao.github.io/smile_enjoy_story/#/public-demo-01`

Opening either of these on the same production deploy should show the
approved Public Demo HOME (header, month/phase band, KPI grid, 佐倉ひより
Navigator card, office/employee summary, important tasks, quick access,
bottom navigation) — not the Development prologue.

## CHANGED FILES

None in production code. This report is the only file added by this
session.

## TESTS

Not run — no source was changed, so there is nothing new to validate.
Instead, this session verified the already-recorded CI evidence for the
exact commit named in the task via the GitHub Actions API (see item 7
above): Fast CI run #443 on `76ca2b0b6dd598e5d18ed9a88379bf20b95ed79c` —
`flutter analyze`, `flutter test`, `flutter build web --release`,
`smoke-e2e`, and the `deploy` job (`actions/deploy-pages@v4`) all
`success`.

## FLUTTER ANALYZE

Not run — no Flutter SDK is available in this session's sandbox, and none
was needed: no `lib/`, `web/`, or test source was modified.

## DOMAIN / FINANCE / SAVE-SCHEMA / MONTH-SETTLEMENT IMPACT

None. No file under `lib/domain/**`, no save schema, no finance/payroll
calculation, and no month-settlement logic was read for modification or
touched in any way — this session was routing/deploy investigation only.

## COMMIT / BRANCH / PR

- This session's commit: adds this report only (see the branch's push log
  for the exact SHA).
- Branch: `claude/ses-147-deployed-route-viu41v` (pushed).
- PR: **not opened.** The task's instruction to commit/push and open a PR
  is conditioned on a fix being made ("修正した場合は"); this session made
  no production fix, since the confirmed root cause is a verification-URL
  mismatch, not a code defect. A PR can be opened on request if the
  repository owner wants this report reviewed/merged through the normal
  process.

## URLS TO CHECK AFTER ANY FUTURE REDEPLOY

- `https://perusonao.github.io/smile_enjoy_story/#/public-demo-01` — must
  show the approved Public Demo HOME.
- `https://perusonao.github.io/smile_enjoy_story/public-demo/` — must
  redirect (near-instantly, no visible intermediate page) into the URL
  above.
- `https://perusonao.github.io/smile_enjoy_story/` (bare root) — expected,
  **by design**, to show the Development experience (a fresh
  `StartChoiceScreen`, or a resumed in-progress Development save such as
  the Founding Prologue), never the Public Demo HOME. A screenshot of this
  URL is not valid evidence against Issue #147's Deployed Screen
  Verification.

## RECOMMENDATION FOR ISSUE #147

Re-run Deployed Screen Verification against
`https://perusonao.github.io/smile_enjoy_story/public-demo/` (or the
`#/public-demo-01` route directly) on the same real device. If the screen
shown there matches the approved target image, Issue #147's Deployed Screen
Verification criterion is satisfied and the issue can be closed on that
basis; the bare-root screenshot does not represent a failure of the HOME
rebuild.

If, after checking the correct URL, an actual mismatch against the approved
target is still observed there, that would be a genuine follow-up — this
session did not find one and did not attempt a fresh UI comparison, per the
task's explicit "no UI redesign" scope.
