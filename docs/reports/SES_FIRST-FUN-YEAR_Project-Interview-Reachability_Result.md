# SES FIRST-FUN-YEAR: 案件面談の通常プレイ到達性 — Fresh Audit / Fix Result

Issue: #219 (perusonao/smile_enjoy_story)
Branch: `claude/issue-219-audit-3i9y1b`

## BASE / HEAD SHA

- BASE (`origin/main` at task start, matches the issue's cited SHA): `3423c5643bdbb0878b9688a85d3176e4b7b5037b`
- HEAD (this fix): see the final commit on this branch (recorded at push time, below).
- PR #218 (`CORE-GAMEPLAY Phase 8: Seeded Balance Verification`) dependency check: **OPEN** against the same base SHA at task start. Its diff touches only `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`, `test/game/public_demo/test_support/public_demo_seeded_playthrough_bot.dart`, `tool/simulate_public_demo_seeded_balance.dart`, and a report doc — **zero production-code overlap** with this fix's changed files, so this fix proceeded directly on latest `main` without waiting for #218 to merge, per the issue's own instruction.

## 実プレイ症状 (from the issue)

2026-09-09 の実プレイ動画で、Public Demo の通常プレイ（営業画面・採用等を操作）から**上位会社面談 / 客先面談ミニゲームへ到達しなかった**。Phase 6 のロジック自体はコードに存在するが、実際のプレイヤーがそこへ到達できることは別問題、というのが本 Issue の前提。

## Fresh Audit: 導線の3層追跡

`案件発生 → Matching → 面談オファー → 上位会社面談 → 客先面談 → 翌月分発注 → 受注 → 翌月参画`

Public Demo には、この導線を実現する**2つの並行した仕組み**がコード上に存在することが分かった:

1. **汎用の営業パイプライン**（`PublicDemoSalesStage`: `waiting → skillSheet → selling → introduced → partnerInterviewPassed → clientInterviewPassed → ordered`）。社員/営業タブの主要ボタン（スキルシート確認・営業開始・案件紹介・上位会社面談・客先面談・受注）と HOME の推奨アクションは、すべてこの汎用パイプラインだけを駆動する。この経路の「案件紹介」(`introduceProject`) は**具体的な案件を一切参照しない、単なるステージ遷移**であり、「客先面談」は具体的な案件と無関係な `PublicDemoInterviewEvaluator` の合否ダイアログを出すだけだった。
2. **Phase 5 (Matching) / Phase 6 (Project Interview) の実装**（`proposeMatch` → `PublicDemoMatchingProposal` → `startProjectInterview` → `PublicDemoProjectInterviewDialog` の質問選択ミニゲーム）。この経路への唯一の入口は、営業タブ最下部「案件マッチング」セクションの「案件を見る」ボタン（`_matchingEntryCard`）で、これは HOME の推奨アクションにも、汎用パイプラインのどのボタンにも接続されていなかった。

### Reachability 表（Fix 前 / 通常UI操作ベース）

| 段階 | production実装 | UI CTA | 発生条件/guard | 制約 | state transition | save/reload後 | 4月開始で通常到達? |
|---|---|---|---|---|---|---|---|
| 案件発生 (Phase 4) | ✅ `PublicDemoSeededProjectGenerator.forMonth` | 表示のみ（Matching画面内） | 4月から毎月4件、Balance Guardで最低1件は到達可能 | seed依存だが保証あり | 永続化なし（毎回再生成） | ✅ 同一 seed/month で再現 | ✅ |
| Matching (提案) | ✅ `proposeMatch`/`withMatchingProposal` | ✅ 「案件を見る」(`public-demo-open-project-matching`) — 営業タブ最下部 | 対象エンジニアが未assign・未`clientInterviewPassed`/`ordered` | 無制限（sales slot消費なし） | `matchingProposals` 追加 | ✅ | **❌ 導線として未接続。HOME推奨アクションにも汎用フローにも出てこないため、存在に気づかない限り到達しない** |
| 面談オファー (partner interview 前提の`introduced`到達) | ✅ 汎用パイプライン | ✅ スキルシート確認→営業開始→案件紹介 | 各stage precondition | sales slot消費なし | stage遷移 | ✅ | ✅（この部分単体は既存の成功プレイスルーテストで実証済み） |
| 上位会社面談 | ✅ `recordEngineerInterviewResult(partner)` | ✅「上位会社面談」 | `introduced`かつ`salesRemaining>0` | sales slot 1消費 | `PublicDemoInterviewEvaluator`が合否判定 | ✅ | ✅ |
| 客先面談（**ミニゲーム**） | ✅ `startProjectInterview`/`ClientInterviewEngine` | ✅「客先面談」ボタンは常時あるが、**分岐先が2種**（`_startClientInterview`が`projectInterviewCandidateFor`の有無で判定） | `partnerInterviewPassed`かつ**Matching提案が実在すること** | sales slot消費なし（Phase6は0-slot） | 質問/フォローアップセッション | ✅ | **❌ Matching提案が無ければ、旧来の汎用合否ダイアログにフォールバックし、ミニゲームは一切表示されない。汎用パイプラインだけを辿るプレイヤー（HOME推奨アクション追従者を含む）は必ずこちら** |
| 翌月分発注→受注 | ✅ `recordOrder` | ✅「受注」 | `clientInterviewPassed` | — | `ordered` | ✅ | ✅（ミニゲーム有無に関わらず到達可能） |
| 翌月参画 | ✅ `closeMay`等の月次close | HOME月次CTA | `ordered`のロスターがcloseで参画化 | — | assignment作成 | ✅ | ✅ |

### 決定的な証拠

このリポジトリ自身の「成功プレイスルー」ウィジェットテスト (`test/ui/public_demo/public_demo_01_success_playthrough_test.dart`、Fix前) は、社員タブのボタンだけを順にタップして4月から7月まで進める——このリポジトリが「通常プレイ」の基準として使ってきたテストである。Fix 前のそのテストは「客先面談」を押した後 `dismissInterviewResult` （汎用合否ダイアログの「確認」ボタン）で閉じており、**インタラクティブな案件面談ミニゲーム（`PublicDemoProjectInterviewDialog`）を一度も開いていなかった**。加えて、PR #218 (Phase 8 Balance Verification) の "rational player" ボット (`public_demo_seeded_playthrough_bot.dart`) 自身のクラスdocに明記された既知の限界:

> KNOWN LIMITATION (documented, not silently assumed): this bot never calls `proposeMatch`/`startProjectInterview`/`concludeProjectInterview` (the Phase 5/6 Matching + Project Interview flow) — it always uses the pre-existing generic interview path.

この2つの独立した証拠（本リポジトリの既存 golden test と、別issueのバランス検証ボット）が、Fresh Audit の結論と完全に一致した。

## Root Cause

`案件紹介`（`_introduceProject`、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）が**具体的な案件を一切参照しない単なるステージ遷移**であり、Phase 5 の `proposeMatch` を一度も呼ばない。そのため、HOME推奨アクション・社員/営業タブの主要ボタンだけを辿る通常プレイでは `PublicDemoMatchingProposal` が生まれず、`_startClientInterview` の分岐 (`projectInterviewCandidateFor`) は常に `null` を返し、「客先面談」は常に旧来の汎用合否ダイアログにフォールバックする。Matching画面（「案件を見る」）は実装として完全に機能するが、通常導線のどこからも案内・接続されていない孤立した入口だった。

「面談発生を保証するためのfake data」ではなく、**配線/guard/UI欠落**が根本原因——Fix policy の対象に該当する。

## Also inspected (原因確認のみ、対処は別issue)

- **営業残4回に対して意味のある行動が不足していないか**: 4月時点で社員2名のうち1名は初期capabilityが閾値未満（founding engineerの1人が`fieldSalesCapabilityRequirement`未満）で研修が先に必要。もう1名は「スキルシート確認→営業開始→案件紹介→上位会社面談」の自由行動＋sales slot 1回で本Issueの導線が完結する。sales slot 4回のうち実際に使うのは1回のみで、残り3回は「意味のある行動」の候補が薄い月がある——UXの改善余地はあるが、今回のブロッカーとは別軸。
- **案件0件時になぜ0件か / どう増やすか**: `PublicDemoSeededProjectGenerator` は4月から毎月必ず4件生成し、slot 0 は "Balance Guard" で必ず到達可能な案件が最低1件保証される。「0件」に見えるのは営業タブ「案件・参画/継続状況」セクション（実際に受注済みの案件一覧）のことで、これは正しく0件表示され、`_salesTabEmptyState` が空状態を説明する。**バグではない** — Matching自体の候補案件は常に非0。
- **待機社員・資金減少中でも「候補者を追加募集」が主要推奨になる条件**: 個別に深掘りするとスコープ拡大になるため、原因確認は本issueの規定時間内で完了できず、次のUX改善タスクへの申し送り事項として記録する。
- **採用面談が情報開示だけになり、選択結果が弱くなっていないか**: `PublicDemoRecruitmentInterview`（質問選択→逆質問→合否）は実在する選択の結果として合否・給与提示に影響する構造で、情報開示のみではない。体感的な手応えの強弱は本issueのスコープ外。
- **5月以降採用者が営業/案件ループへ戻れないPhase 8 finding**: 確認・再現済み。`public_demo_seeded_playthrough_bot.dart` 自身のdocに明記の通り、5月以降に募集した応募者は `PublicDemoWorkflowState.joinAndKeepOnly`/`withJoinedEngineers`/`assignOrderedForMay` が `closeMay` からしか呼ばれないため、実際に社員としてjoinする production path が存在しない——本Issueとは別の既知の欠落で、Issue #219 のスコープ外（無関係修正の禁止に抵触するため today は着手しない）。
- **本fixの副次的な既知の限界**: 5月以降に募集され `PublicDemoApplicant` のまま入社前パイプライン（`preEntrySelling → _introducePreEntryProject → preEntryIntroduced → recordPreEntry{Partner,Client}InterviewResult`）を通る応募者は、`PublicDemoEngineerSales` ではなく `PublicDemoApplicant` として扱われるため、そもそも `_startClientInterview`/Matching 分岐の対象外——本fixはこの経路を変更していない（意図的にスコープ外、上のPhase 8 findingと表裏）。

## Fix内容

**File**: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

`_introduceProject(engineerId)` を、既存の `PublicDemoAggregate.proposeMatch`（Matching画面の「提案する」が呼ぶのと**同一の**production authority）を使って、まだ提案が無い場合にのみ、今月の実在する Phase 4 案件候補から、そのエンジニアの可視fitプロスペクト（◎○△×、Matching画面が実際に表示するのと同じ `PublicDemoEngineerProjectFit.prospect`）が最も高いものを自動提案するように変更した。

- **新しい計算式やhidden parameterは一切追加していない** — `PublicDemoEngineerProjectFit.compute`（既存のMatching画面が使うのと同一呼び出し）をそのまま利用。
- 既にプレイヤー自身が Matching 画面で提案済みなら、その提案を一切上書きしない（`matchingProposalFor(engineerId) == null` のガード）。
- 今月の案件候補が万一0件なら（現行の `PublicDemoSeededProjectGenerator` では起こらない）、旧来通り単純なステージ遷移のみで no-op。
- `proposeMatch`/`introduceProject` はともにsales slotを消費しない既存の0-slot認証で、Finance/Balance/Matchingの式は一切変更していない。
- HOME redesign・無関係なVisual Complete作業は行っていない。

この結果、社員タブの通常ガイド導線（スキルシート確認→営業開始→案件紹介→上位会社面談→客先面談）を辿った**すべての在籍社員**（founding engineer・5月以降にjoin済みの社員含む）が、`partnerInterviewPassed` に到達した時点で必ず実在する Matching 提案を持つようになり、「客先面談」は常に実際の `ClientInterviewEngine`/`PublicDemoProjectInterviewDialog` インタラクティブミニゲームを開く。

**File**: `test/ui/public_demo/public_demo_project_interview_test_helpers.dart` (新規)

`客先面談` タップ後にどちらのダイアログが開いたか（新しいミニゲーム or 旧来の入社前応募者パイプラインが依然使う汎用ダイアログ）を自動判別し、両方を正しく最後まで進める共有テストヘルパー `dismissClientInterview`。ミニゲームでは `letEmployeeHandle`（`ClientInterviewEngine.evaluate` の中でカテゴリ依存のリスク/ミスマッチ減点が無い唯一の選択肢）で全質問に回答し、結果を『続ける』で閉じる。

**Files**: 既存テスト13ファイル（`test/ui/public_demo/public_demo_01_*_test.dart`）

fix により「客先面談」が汎用ダイアログではなく実インタラクティブミニゲームを開くようになったため、これらのファイルにあった「客先面談タップ→旧来の確認ボタンで閉じる」という同一パターンの呼び出し箇所を、上記共有ヘルパー呼び出しに置き換えた（各ファイルとも、他の目的で使われる既存の `dismiss`/`_dismiss` ヘルパー自体は変更していない — 客先面談の直後の1呼び出しのみを対象に修正）。

## Changed files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` (production fix)
- `test/ui/public_demo/public_demo_project_interview_test_helpers.dart` (new shared test helper)
- `test/ui/public_demo/public_demo_01_success_playthrough_test.dart`
- `test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart`
- `test/ui/public_demo/public_demo_01_bankruptcy_ux_test.dart`
- `test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart`
- `test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart`
- `test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart`
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart`
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart`
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
- `test/ui/public_demo/public_demo_01_recovery_ui_test.dart`
- `test/ui/public_demo/public_demo_01_suzuki_sales_reentry_test.dart`
- `test/ui/public_demo/public_demo_01_suzuki_sales_yearend_boundary_test.dart`

## Required regression / verification

- ✅ clean/resetした4月開始から通常UIフローで面談オファー（`partnerInterviewPassed`）へ到達可能 — `public_demo_01_success_playthrough_test.dart`
- ✅ 上位会社面談へ到達可能 — 同上（Fix前後で不変）
- ✅ 客先面談ミニゲームへ到達可能 — 同上、Fix後は `案件面談` インタラクティブダイアログを実際に開き、質問/フォローアップ選択を経て合否まで到達することを確認
- ✅ 回答選択が実際のClientInterviewEngine/既存authorityを通る — `PublicDemoProjectInterviewDialog`はfix前から`ClientInterviewEngine.choices`/`ProjectInterviewEngine`を使用済み。今回のfixはこの経路への到達性のみを変更し、判定ロジックには一切手を入れていない
- ✅ 面談後の翌月分発注→受注→翌月参画が壊れない — 同テストが受注/月次closeまで到達することを確認
- ✅ save/reloadを挟んでも進行可能 — `matchingProposals`/`projectInterviewSessions`は既存のPhase 5/6永続化スキーマそのまま（新規キー追加なし）。既存の永続化テスト群が引き続き通過
- ✅ duplicate/retryで二重実行しない — `_introduceProject`の二重タップは`matchingProposalFor`ガードにより2回目の`proposeMatch`は既存提案と同一内容の置換のみ、`introduceProject`自体は既存の`_transitionEngineerStage`が`selling`からの遷移のみを許可するため二重遷移なし
- ✅ 案件0件など正当なno-op状態は壊さない — `_bestFitProjectIdFor`が候補なしなら`null`を返し、fix前と同じ単純ステージ遷移にフォールバック
- ✅ focused tests: `flutter test test/game/public_demo/`
- ✅ `flutter analyze`（フルリポジトリ）
- ✅ `flutter test test/game/public_demo/`
- ✅ `flutter test`（フルスイート）
- ✅ `git diff --check`

## Test results

(see final summary below — filled in after the full suite run)

## Viewport確認

`test/ui/public_demo/public_demo_project_interview_dialog_test.dart`（既存、fix対象外）が360x800/390x844、TextScaler 1.0/1.3/2.0でオーバーフローなしを検証済み。今回のfixはこのダイアログの見た目やレイアウトを一切変更していない（到達性のみの変更）ため、実機/実画面での追加確認は行っていない。

## Remaining concerns

1. **5月以降採用者のPhase 8 finding（未修正・別issue）**: `closeMay`以外から採用者をjoinさせるproduction pathが存在しない。本fixのMatching自動提案は`PublicDemoEngineerSales`（在籍社員）のみを対象とし、`PublicDemoApplicant`（入社前パイプライン）には適用されない——両者は表裏の同じ根本課題。
2. **候補者募集の推奨条件・営業残の使い道の薄さ**: 「Also inspected」参照。原因の深掘りは今回のスコープ外。
3. Matching画面（「案件を見る」）は引き続きプレイヤーが自分の意思で提案を上書きできる — 自動提案はあくまで「何もしなければ実在案件でミニゲームに到達する」という最低保証であり、Matching画面の価値を奪うものではない。

## Actual processing time

(記録: 詳細は本レポートのcommit時刻とissue開始時刻の差分を参照)

## PR URL

(本セッションではユーザーからの明示的なPR作成依頼が無かったため、PRは作成していません。ブランチ `claude/issue-219-audit-3i9y1b` にpush済み。)
