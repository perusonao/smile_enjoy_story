# SES Active Project Visibility — Phase 1 Implementation Result

STATUS: **完了（Phase 1）**

SSOT: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`（本Result Reportの内容で同時更新済み）

## BASE / HEAD

- BASE: `origin/main` = `592fd675b7b617f8709bf176247e75cdf88bbe8e`（Year-End Phase 1 merge SHA、= 現時点のorigin/main HEADと一致していることを確認済み）
- Branch: `claude/ses-active-project-visibility-xkkpn0`（最新mainから作り直した新規作業ブランチ）
- HEAD: commit予定（本コミット。実際のSHAは最後のGitログを参照）

## 目的

8月〜翌3月（fiscal-year-extension、internal month 8-15）でも、参画中社員が「どの案件に入り、どのような状態か」を社員タブから確認できるようにする。

## 実施内容

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`の社員タブ（`_buildEmployeesTab`）に、新規メソッド`activeProjectStatusCard(PublicDemoAssignment a)`を追加した。

### 表示項目（Phase 1）

- `engineerName`
- `projectName`
- `deliveryPressure`
- `budgetHealth`

いずれも既存の`PublicDemoAssignment`（authoritative source: `PublicDemoWorkflowState.assignments` / `assignedEngineerIds(month:)`）が既に持つフィールドをそのまま読み取るのみ。新規のdomainフィールド・persist・save-schema変更は一切ない。

`fieldEvaluation`はPhase 1では**意図的に非表示**とした。調査の結果、production経路のどこも`withAssignmentUpdate`に`fieldEvaluation:`を渡していないため、`PublicDemoAssignment.fieldEvaluation`は常にコンストラクタ既定値（50）のままであり、すべてのプレイ可能な状態で実質固定値であることを確認済み。意味のある評価として提示できないため表示しない、という指示どおりの判断。

### 表示対象・タイミング

`workflow.assignedEngineerIds(month: s.month)`に含まれる社員（＝その月に実際に参画中の社員）についてのみ、対応する`PublicDemoAssignment`からカードを1枚表示する。月による除外は設けていない — 4月〜翌3月のどの月でも、参画が続く限り継続して表示される。これにより、8月〜2月の間`ec(i)`カードが（RECOVERY-LOOP-1により）待機社員限定に絞られ、参画中の非創業社員や、すでにフォロー判断済みの創業社員には社員タブに一切カードがなかったギャップを埋める。

待機（waiting）社員 — `assignedEngineerIds(month:)`に含まれない社員 — にはカードを表示しない。

### 実装場所

社員タブのみ（`_buildEmployeesTab`内、既存の`founderFollowUpCard`ループの直前に新規`for`ループを追加）。同一`Column`の兄弟要素として追加しており、既存カード（`ec(i)`、`employeeConditionCard`、`founderFollowUpCard`、`internalTrainingCard`）のレイアウト・キー・ロジックは一切変更していない。

### 禁止事項の遵守

- HOME（`lib/presentation/home/`配下、および`_homeDashboardData`/`_officeStageDisplay`等のHOME専用projection）は無変更。
- Year-End（`PublicDemoYearEndDisplayData`/`PublicDemoYearEndResultCard`）は無変更。
- 営業タブ（`_buildSalesTab`/`_salesTabItems`）は無変更。
- Employee UI（既存の`ec(i)`/`employeeConditionCard`等）は無変更・再設計なし。
- Domain（`PublicDemoAssignment`/`PublicDemoWorkflowState`）は無変更 — 既存フィールド・既存メソッドの読み取りのみ。
- Save/schema、Finance/Balance計算、Month transition、workflow authorityは無変更。
- `fieldEvaluation`の意味・扱いは無変更（表示しないだけで、値の計算・更新ロジックには一切触れていない）。
- 顧客名・会社名・単価・契約金額・契約期間など、`PublicDemoAssignment`が保持していない情報は生成していない。
- Issue #167 founder follow-upカードとは共存させ、そのロジック・キー・レイアウトは無変更。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `activeProjectStatusCard`ウィジェット新規追加、`_buildEmployeesTab`に参画中社員向けレンダリングループを追加 |
| `test/ui/public_demo/public_demo_active_project_visibility_test.dart` | 新規テストファイル（後述） |
| `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` | Active Project Visibility Phase 1完了の反映、次優先順位の更新 |
| `docs/reports/SES_ACTIVE-PROJECT-VISIBILITY_Phase1_Implementation_Result.md` | 本結果報告（新規） |

## テスト

新規ファイル`test/ui/public_demo/public_demo_active_project_visibility_test.dart`に8件のwidgetテストを追加。すべて`PublicDemoAggregate.initial()`から実際のdomainコマンド（`publicDemoAggregateAtMonth`/`publicDemoAdvanceEngineerToOrdered`/`recoverAssignment`/`closeOrdinaryMonth`/`applyFounderFollowUpDecision`）を連鎖させて構築した決定論的fixtureを使用（`public_demo_01_year_end_result_test.dart`の`_FixedSaveService`パターンを踏襲）。

1. assigned社員（eng-01, 8月）に案件カードが表示される
2. engineerName一致（`PublicDemoAssignment.engineerName`と突合）
3. projectName一致
4. deliveryPressure一致
5. budgetHealth一致（同テスト内でカード内のText数が4件ちょうど＝fieldEvaluationの5件目が存在しないことも検証）
6. waiting社員（eng-02）は除外される
7. March（month 15、fiscal year close前）でも継続して表示される
8. 8月〜3月まで実際の`closeOrdinaryMonth`連鎖を通して毎月カードが表示され続ける
9. Issue #167 founder follow-upカードとの共存（8月、未決定の創業社員で両カードが同時表示）
10. HOME Freeze回帰（ホームタブに切り替えてもHOMEダッシュボードは不変、かつ新規カードはHOMEに漏れない）
11. Year-End回帰（fiscal year completion時、会計タブの年度末カードは新規カードの影響を受けず表示される）
12. #167回帰（follow-up決定済みの創業社員は`founder-follow-up-card`が消えるが、`active-project-status`カードは残る）

（上記は`docs/decisions`側「テスト」節の12項目に対応。widgetテストの`testWidgets`ブロック数としては8件。)

### テスト実行結果

```
flutter test test/ui/public_demo/public_demo_active_project_visibility_test.dart
→ 8/8 tests passed
```

関連Public Demo regressionテスト（社員タブ・founder follow-up・Recovery関連）:

```
flutter test test/ui/public_demo/ \
  test/game/public_demo/public_demo_founder_follow_up_test.dart \
  test/game/public_demo/public_demo_recovery_aggregate_test.dart
→ 334/334 tests passed, 0 failed
```

## flutter analyze

```
flutter analyze
→ No issues found!
```

（Flutter 3.44.8, CIの`public-demo-validation.yml`が固定しているバージョンと一致させて実行）

## git diff --check

```
git diff --cached --check
→ (no output, exit 0 — whitespace error なし)
```

## Known limitations

- Phase 1は`engineerName`/`projectName`/`deliveryPressure`/`budgetHealth`の4項目のみで、`fieldEvaluation`（常に固定値50）は意図的に非表示。将来`fieldEvaluation`が実際に変動する値になった場合は、表示要否を再検討する必要がある。
- カードは各参画中社員につき1枚、常に表示（月による段階的な情報開示や、値の変化に対する強調表示は行っていない）。UXとしての「小規模UX修正」（stale表示の解消等）は次の優先タスクであり、本Phaseのスコープ外。
- 表示レイアウトは既存の`founderFollowUpCard`と同一のCard/Column構造を踏襲した最小実装であり、視覚的な差別化（色分け・アイコン等によるdeliveryPressure/budgetHealthの危険度表示等）は行っていない。
- April→March human replayによる実プレイ確認は本タスクのスコープ外（次の優先タスク）。

## Merge Readiness

**Ready for review.** `flutter analyze`・関連Public Demo regressionテスト・`git diff --check`すべてPASS。HOME/Year-End/#167の既存挙動は回帰テストで確認済み。auto-mergeは行わない。
