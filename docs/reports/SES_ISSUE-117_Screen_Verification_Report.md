# SES — Issue #117 Screen Verification Report

**Issue:** [#117 — PUBLIC-DEMO-UX-1A: restore SkillSheet reachability and first actionable flow](https://github.com/perusonao/smile_enjoy_story/issues/117)
**PR under verification:** [#131 — feat: make Public Demo SkillSheet inspectable](https://github.com/perusonao/smile_enjoy_story/pull/131) (merged 2026-08-31T10:57:36Z)
**Deployment commit:** `7488ff176be86cb829014ea361414837d7b89340`
**Target deployment:** https://perusonao.github.io/smile_enjoy_story/public-demo/
**Verified viewports:** 360 × 800 and 390 × 800 CSS px (explicit widths, no device preset)
**Date:** 2026-08-31

---

## VERIFICATION RESULT: **PASS** (automated screen verification)

Every step and every visual condition of the Issue #117 Screen Verification Gate was
executed and evidenced at both 360px and 390px. Zero findings at either viewport.

**Human visual verification is still required before closing #117** — see
[§8 Human verification still required](#8-human-verification-still-required). The issue
text makes approval of the screen verification an explicit precondition
(*"Do not close this issue or start the next UI issue until this screen verification is
approved"*), which automated evidence supports but does not replace.

---

## 1. What was verified, and against what

### 1.1 Deployment identity

| Fact | Evidence |
| --- | --- |
| PR #131 merged into `main` | GitHub API: `merged: true`, `merged_at 2026-08-31T10:57:36Z`, merge commit `7488ff1` |
| `7488ff1` is the PR #131 merge commit | `git log`: `7488ff1 Merge pull request #131 from perusonao/agent/issue-117-public-demo-skill-sheet` |
| CI on `7488ff1` was green | Workflow run [33384743903](https://github.com/perusonao/smile_enjoy_story/actions/runs/33384743903) — `validate`, `e2e-chromium`, `e2e-webkit`, `replay-package`, `check-latest`, `build`, `deploy` all `success` |
| Pages deploy actually ran for this commit | Job `deploy` (99470610466): `Re-verify main has not moved since this run started` → success; `Stale at deploy time — skip deploy-pages` → **skipped**; `actions/deploy-pages@v4` → **success** at 11:22:25Z |
| The deployed payload | Run artifact `github-pages`, 36,412,311 bytes, digest `sha256:136f736d65aa74d70b5d9d9ca5e6539b9b64cb32e367b434fcfd036b10f42fc1`, built from `head_sha 7488ff1` |
| The running build says so on screen | Header reads **`Deploy: PR #131 · 7488ff1`** in all 36 screenshots (asserted, not just eyeballed — see `assertVisibleBox('deploy build label')`) |

### 1.2 Important deviation — the live URL could not be reached from this environment

`https://perusonao.github.io/...` is **blocked by this session's egress policy**. Both the
verification tooling and a bare `curl` get `403` on `CONNECT perusonao.github.io:443` from
the agent proxy, and the proxy's own status endpoint records the denial:

```
"kind": "connect_rejected",
"detail": "gateway answered 403 to CONNECT (policy denial or upstream failure)",
"host": "perusonao.github.io:443"
```

The `github-pages` artifact download URL (`*.blob.core.windows.net`) is blocked the same way,
so the deployed bytes could not be fetched directly either.

**What was verified instead:** the deployed bundle was *reproduced byte-for-byte-equivalently*
from the deployed commit and served over the same URL shape, then driven for real:

| Deployment property | Reproduction |
| --- | --- |
| Source commit | `7488ff176be86cb829014ea361414837d7b89340` (checked out) |
| Flutter version | 3.44.8 stable, revision `058e0af2c2`, downloaded from `storage.googleapis.com/flutter_infra_release` and **SHA-256 verified** against the official release manifest (`672089e001571a9fbb209a495c583580c0c6c73ef98999264ba07fa93ace332d`) — the exact version `.github/workflows/e2e.yml` pins |
| Build command | `flutter build web --release --base-href "/smile_enjoy_story/" --no-web-resources-cdn --dart-define=BUILD_COMMIT_SHA=7488ff17… --dart-define=BUILD_PR_NUMBER=131` — identical to the `build` job's Pages step |
| URL shape | Served at `/smile_enjoy_story/`, entered via `/smile_enjoy_story/public-demo/` (the committed `web/public-demo/index.html` redirect), exactly as GitHub Pages serves it |
| Running identity | In-app header renders `Deploy: PR #131 · 7488ff1`, the same string the live deployment renders |

**Consequently:** *the deployed application build* is verified. *The live hosting layer*
(GitHub Pages CDN, TLS, caching, actual public reachability of the URL) is **not** verified
from this session, and remains part of the human check.

### 1.3 Reused existing SES E2E infrastructure

- `e2e/helpers/artifacts.ts` → `watchForErrors` (console/page-error capture, allowlist, crash
  detection) **and** its portable mobile-WebKit wheel fallback.
- The repo's Playwright/`@playwright/test` harness, its `webServer` pattern, its
  `SES_E2E_CHROMIUM_PATH` escape hatch, and its video/trace conventions.
- Nothing existing was modified. No production code was changed. No test was weakened,
  skipped, retried, slept through, or had an assertion relaxed.

New verification-only files (additive):

- `e2e/verification/issue-117/screen-verification.spec.ts`
- `e2e/verification/issue-117/playwright.verification.config.ts`
- `e2e/verification/issue-117/pages-static-server.js`

---

## 2. Method

Two Playwright projects, `mobile-360` and `mobile-390`, each with an **explicitly set**
`viewport.width` (360 / 390), `deviceScaleFactor: 3`, `isMobile: true`, `hasTouch: true`.
No `devices[...]` preset is used, so the width cannot be inferred from a device profile.

Both projects run with `trace: 'on'` and `video: 'on'` — evidence on the **passing** path, not
just on failure (the main `e2e/playwright.config.ts` keeps both at `retain-on-failure`; that
config is untouched).

Evidence is captured at three scroll positions per milestone (`*.png` = top of HOME,
`*-scrolled.png`, `*-bottom.png`), because Flutter Web only realises semantics for the part of
the scroll view currently on screen — auditing only the top fold would leave the engineer cards
and the month-end action unexamined. `fullPage: true` is useless here and was discarded: Flutter
paints into a viewport-sized view and scrolls internally, so a "full page" capture comes back
byte-identical to the viewport one.

**DOM presence alone can never produce a PASS.** Every required element is checked with
`assertVisibleBox`: visible *and* non-degenerate bounding box *and* horizontally inside the
viewport. On top of that, per scroll position: element-level overflow scan, page horizontal
scrollability, button clipping, button overlap, tap-blocking overlay detection, duplicate
primary CTA, and competing same-intent CTAs.

---

## 3. Gate steps — results

The seven numbered steps of the issue's **Screen Verification Gate**, plus the fuller flow
requested for this run. Identical outcome at 360px and 390px.

| # | Gate step | 360px | 390px | Evidence |
| --- | --- | --- | --- | --- |
| — | Public Demo fresh start via the deployed entry `/public-demo/` | PASS | PASS | URL polled until it lands on `#/public-demo-01` |
| 1 | HOME clearly exposes the intended next action | PASS | PASS | `01-home.png` — 「次にやること / 佐藤 健のSkillSheetを確認」 with one filled CTA 「SkillSheetを確認」; month `1年目 4月`; 佐藤 健 `営業準備前` |
| 2 | Tap Sato / SkillSheet | PASS | PASS | `02-skillsheet-open.png` |
| 3 | Real SkillSheet content visible (not an acknowledgement/state jump) | PASS | PASS | `02-skillsheet-open.png` — see §4 |
| 4 | Back/cancel does not advance the workflow | PASS | PASS | `03-after-back.png` is **byte-identical** to `01-home.png` (SHA-256 match, both viewports); stage still `営業準備前`; `SkillSheet確認中` absent; `営業を開始` and `営業開始` both count 0 |
| 5 | Re-open and explicitly confirm/continue | PASS | PASS | `04-skillsheet-reopen.png` is **byte-identical** to `02-skillsheet-open.png` (SHA-256 match) — the sheet is genuinely re-inspectable, not one-shot |
| 6 | Return and continue to sales start | PASS | PASS | `05-after-confirm.png` — dialog closed, back on HOME, stage badge now `SkillSheet確認中`, CTA now 「営業を開始」 |
| 7 | No dead end or duplicate primary CTA | PASS | PASS | `06-sales-start.png` — see §5, §6 |

### Requested flow, step by step

| Requested step | 360px | 390px |
| --- | --- | --- |
| 1. Public Demo fresh start | PASS | PASS |
| 2. HOME displayed | PASS | PASS |
| 3. Open 佐藤 健's SkillSheet | PASS | PASS |
| 4. Real content visible (佐藤 健 / 営業用SkillSheet / Java / SQL / 開発経験3年 / 営業・面談プロフィール / 戻る / 内容を確認) | PASS | PASS |
| 5. 「戻る」 | PASS | PASS |
| 6. Back on HOME | PASS | PASS |
| 7. **Not** treated as SkillSheet-confirmed | PASS | PASS |
| 8. Re-open the SkillSheet | PASS | PASS |
| 9. 「内容を確認」 | PASS | PASS |
| 10. Back on HOME | PASS | PASS |
| 11. 「営業開始」 becomes available | PASS | PASS |
| 12. Execute sales start | PASS | PASS |
| 13. No dead end | PASS | PASS |

---

## 4. SkillSheet content actually rendered (step 4 detail)

Each item below was asserted **visible with a real, in-viewport bounding box**, and is legible in
`screenshots/{360,390}/02-skillsheet-open.png`:

| Required item | Rendered as |
| --- | --- |
| 佐藤健 | `佐藤 健` (dialog title, line 1) |
| 営業用SkillSheet | `営業用SkillSheet` (dialog title, line 2) |
| Java / SQL, 開発経験3年 | `経歴・スキル要約` → `Java / SQL・開発経験3年` |
| 営業・面談プロフィール | section heading, with `案件スキル適合 78`, `ヒューマンスキル 70`, `モチベーション 72`, `取引先からの信頼 60` |
| 戻る | text button, bottom-left of the dialog |
| 内容を確認 | filled button, bottom-right of the dialog |

Also present: the framing line 「取引先へ提示する営業用プロフィールです。内容を確認してから営業開始へ進みます。」
and the scope note 「Public Demoでは現在の営業用情報を閲覧できます。」 — consistent with the issue's
requirement that the demo present a sales-facing profile without inventing actual-vs-displayed
values or risk levels.

This is real content, not a state-only acknowledgement: the dialog is `showDialog`-driven and the
stage transition (`_startSkillSheetReview`) is committed **only** on the `内容を確認` result — proven
behaviourally by the byte-identical before/after-cancel screenshots.

---

## 5. Dead-end check

After 「営業を開始」, HOME was swept across its full scroll height and every enabled action collected.
At **both** viewports:

```
詳しく見る, 案件を紹介, 4月を終了して5月へ, 案件紹介, 研修する
```

佐藤 健's card shows `営業中` with the 営業進捗 stepper at `✓ SkillSheet → ● 営業 → 紹介 → 上位面談 → 客先面談 → 受注`,
and the month can be closed via 「4月を終了して5月へ」. The playthrough is non-terminal
(`このプレイスルーは終了しました。` absent, `倒産` absent). **No dead end.**

---

## 6. Visual checks — results

All checks run at all three scroll positions of all six milestones, at both viewports.
**Findings: none.** (`screenshots/360/findings.json`, `screenshots/390/findings.json` → `"findings": []`)

| Visual condition | Result | How it was measured |
| --- | --- | --- |
| No RenderFlex overflow | PASS | See note below |
| No horizontal cut-off | PASS | No element under `flutter-view` lays out past either viewport edge; `document.documentElement.scrollWidth == innerWidth`; page cannot be scrolled horizontally |
| No CTA text clipping | PASS | Every CTA's box is fully in-viewport, and every CTA label is read intact off the screenshots (「SkillSheetを確認」「営業を開始」「内容を確認」「戻る」「案件紹介」「研修する」「4月を終了して5月へ」) |
| No button overlap | PASS | Pairwise bounding-box intersection over all visible buttons |
| No fatal modal viewport overflow | PASS | Dialog box measured inside the viewport at both widths; `戻る` and `内容を確認` measured non-overlapping |
| No duplicate primary CTA | PASS | See §6.1 |
| SkillSheet key info readable | PASS | §4, plus visual read of every screenshot |
| 「戻る」 vs 「内容を確認」 distinguishable | PASS | Different labels, different Material roles (text vs filled), different colours, non-overlapping boxes, and opposite behaviour proven by the byte-identical cancel screenshots |
| No inoperable dead end | PASS | §5 |
| No uncaught page errors / crashes / console errors | PASS | `watchForErrors`: `pageErrors []`, `crashed false`, `consoleErrors []` |

**RenderFlex overflow note.** Flutter's striped overflow indicator *and* its
`A RenderFlex overflowed by N pixels` console message are both `assert`-guarded and therefore
**debug-only**; the deployed bundle is `--release`, so neither can appear regardless of layout.
Verifying "no RenderFlex overflow" on the deployed artifact therefore has to be done by
observable effect, which is what was measured: no element lays out past the viewport edge, at any
scroll position, in any of the six states, at either width. That is the release-mode symptom a
RenderFlex overflow would produce. A debug-build assertion sweep would be a stronger direct
signal and is listed in §9 as an optional follow-up; it is *not* a check of the deployed artifact.

### 6.1 Duplicate primary CTA — measured, and one thing for the reviewer to look at

Two rules were applied:

1. No label from the workflow's primary-CTA vocabulary is rendered more than once in one view.
2. No two buttons that drive the *same intent under different wording* are in the viewport
   together — the pairs 「SkillSheetを確認」/「SkillSheet確認」 and 「営業を開始」/「営業開始」.

Both pass everywhere. **Deliberately not flagged:** the two 「研修する」 buttons at the bottom of HOME.
They are one per engineer card, each scoped to its own subject — list UX, not a duplicated next
action.

**Observation for human review (not a defect, no fix proposed):** HOME's Recommended Action card
(「次にやること → SkillSheetを確認」) and 佐藤 健's engineer card (「SkillSheet確認」) are two
similarly-styled filled primary buttons that invoke the same handler. They are measurably never on
screen at the same time (verified at every scroll position), they are worded distinctly, and the
codebase treats the distinction intentionally
(`lib/presentation/home/models/home_recommended_action.dart:277`). By the gate's criterion this is
**not** a duplicate primary CTA. It is flagged only so the human reviewer can confirm that reading.

**Cosmetic observation (informational, severity: trivial, no fix proposed):** at 360px the
`内容を確認` filled button's label sits close to its horizontal padding limit (~2 CSS px of slack).
Nothing is clipped at either width — all five characters render — but the actions row has little
headroom if that label ever gets longer or the user's text scale increases. Not part of the gate.

---

## 7. Issue #117 Acceptance Criteria — cross-check

The gate is the screen-level subset; for completeness, the criteria that a screen verification can
speak to:

| Acceptance criterion | Screen verification says |
| --- | --- |
| Sato's SkillSheet reachable from the expected HOME flow | Confirmed, both widths |
| Opens as actual inspectable content, not a silent state transition | Confirmed (§4) |
| Recognisably the main-game concept: sales-facing profile before sales start | Confirmed — framing copy, 経歴・スキル要約, 営業・面談プロフィール |
| Does not invent actual-vs-displayed values / risk / career rows / certifications | Confirmed — read-only sheet, no risk labels, no actual-vs-displayed rows, explicit scope note |
| Cancel/back does not advance the sales stage | Confirmed — byte-identical screenshots |
| Explicit confirm/continue, then safe return to HOME | Confirmed |
| Can continue to sales start when eligible | Confirmed |
| Primary next action understandable without external instructions | Confirmed for these six states; the *subjective* half stays with human review |
| No gameplay/finance/balance/save authority recomputed in UI | Out of scope for a screen check — covered by the merged widget/unit tests and CI |
| Focused widget + Public Demo tests cover the flow | Out of scope here — `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart` (+134 lines) and the extended `e2e/tests/public-demo-fresh-start.spec.ts` landed in PR #131 and passed CI on `7488ff1` |
| Chromium/WebKit smoke preserved; no weakening | Confirmed on record — `e2e-chromium` and `e2e-webkit` both `success` on `7488ff1`; this verification added files only |

---

## 8. Human verification still required

**Yes.** Do not close #117 on this report alone.

The issue states: *"Do not close this issue or start the next UI issue until this screen
verification is approved."* Approval is a human act, and two things specifically are outside what
this run can establish:

1. **Live hosting.** The public URL `https://perusonao.github.io/smile_enjoy_story/public-demo/`
   could not be opened from this session (egress policy, §1.2). A human should open it on a real
   phone and confirm the header reads `Deploy: PR #131 · 7488ff1`.
2. **Subjective judgement.** "The primary next action is understandable without external
   instructions" and "the presentation is recognisably consistent with the main-game SkillSheet
   concept" are human judgements. This report supplies the evidence; it does not substitute for
   the verdict.

Also worth a human eye, though measured clean here: real-device WebKit/iOS Safari rendering
(this run drove Chromium 141 with an explicit mobile viewport; CI covers mobile-WebKit separately),
and behaviour at larger OS text-scale settings.

Recommended human checklist:

- [ ] Open the live URL on a real 360px-class Android device and a 390px-class iPhone
- [ ] Confirm header shows `Deploy: PR #131 · 7488ff1`
- [ ] Walk gate steps 1–7 by hand
- [ ] Confirm 「戻る」 vs 「内容を確認」 read as clearly different actions
- [ ] Confirm the Recommended Action card and the engineer card do not feel like competing CTAs (§6.1)

---

## 9. Findings

**No defects found.** No production code was changed, and none is proposed.

Two non-defect observations are recorded in §6.1 (near-duplicate CTA wording; tight `内容を確認`
button padding at 360px). Both are informational, neither is a gate failure, and no fix is
implemented in this task per its explicit instruction.

Optional follow-up, not required by the gate: a debug-build (`assert`-enabled) pass over the same
six states would turn "no observable overflow" into a direct `RenderFlex overflowed` assertion
check. That would be a check of the *source*, not of the deployed release artifact.

---

## 10. Artifacts

**ZIP:** `SES_ISSUE-117_Screen_Verification_Artifacts.zip`

```
SES_ISSUE-117_Screen_Verification_Report.md
screenshots/360/   01..06 × {viewport, -scrolled, -bottom} + findings.json   (18 PNG, 1080×2400)
screenshots/390/   01..06 × {viewport, -scrolled, -bottom} + findings.json   (18 PNG, 1170×2400)
videos/360/360px-full-flow.webm      full 360px flow, recorded at 360×800
videos/390/390px-full-flow.webm      full 390px flow, recorded at 390×800
traces/360px-trace.zip               Playwright trace (npx playwright show-trace)
traces/390px-trace.zip               Playwright trace
playwright-results.json              machine-readable run result
```

Screenshot pixel dimensions confirm the viewports: 1080 = 360 × DPR 3, 1170 = 390 × DPR 3.

### Reproducing this run

```bash
# 1. Build the deployed artifact from the deployed commit
git checkout 7488ff176be86cb829014ea361414837d7b89340
flutter build web --release --base-href "/smile_enjoy_story/" --no-web-resources-cdn \
  --dart-define="BUILD_COMMIT_SHA=7488ff176be86cb829014ea361414837d7b89340" \
  --dart-define="BUILD_PR_NUMBER=131"

# 2. Lay it out the way GitHub Pages serves it
mkdir -p .verification/pages-root && cp -r build/web .verification/pages-root/smile_enjoy_story

# 3. Run the gate
cd e2e && npm ci
npx playwright test --config=verification/issue-117/playwright.verification.config.ts
```

Against the real live deployment instead, from an environment that can reach it:

```bash
# point the config's baseURL at the live origin; no local server needed
```
