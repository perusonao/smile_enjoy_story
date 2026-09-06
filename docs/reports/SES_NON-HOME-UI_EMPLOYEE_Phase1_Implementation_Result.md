# SES NON-HOME-UI — Employee UI Phase 1 Implementation Result

STATUS: **完了（Phase 1）**

SSOT: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`

## BASE / HEAD

- BASE: `origin/main` = `32ccad6cafc82eebd47c69951babab0e713dbe1d`（PR #188 "SES Active Project Visibility Phase 1" merge SHA — 作業開始時に`git fetch origin main`で確認した最新main）
- Branch: `claude/employee-ui-phase-1-2i4fu8`（着手前、ローカルブランチが古いコミット（`f4ca78f`, Phase 0A/0B相当）に取り残されていたため、`git checkout -B claude/employee-ui-phase-1-2i4fu8 origin/main`で最新mainから作り直した）
- HEAD（本コミット時点）: 下記コミット参照

## 目的

社員タブを単なるカードの縦並びから、以下の4段階の情報階層を持つ画面へ再設計する。

1. 社員一覧 / 現在状態
2. 今やるべき社員アクション
3. 参画中案件（Active Project Visibility Phase 1, PR #188 を統合）
4. 成長 / SkillSheet / 研修

併せて、SSOTの次項目「stale「翌月参画予定」... 等の小規模UX修正」のうち、社員タブ側に残っていたケースを解消する。

## 実施内容

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`の`_buildEmployeesTab`を、1つの`Column`にすべてのカードを条件分岐で並べる実装から、4つのセクションメソッドの呼び出しへ再構成した。

### 新しい構造

```
_buildEmployeesTab
├── _employeeRosterSection()          … Section 1: 社員一覧・現在状態（新規）
├── _employeeNextActionsSection()      … Section 2: 今やるべき社員アクション
├── _employeeActiveProjectsSection()   … Section 3: 参画中案件（APV Phase 1）
└── _employeeGrowthSection()           … Section 4: 成長・SkillSheet・研修
```

- **Section 2〜4は、既存の`_buildEmployeesTab`が持っていた月ゲート・eligibility・カード・key を一切変更せず、そのままセクションメソッド内へ移動しただけ。** 新しい判断・新しいゲームルールは追加していない。
  - Section 2 = 旧`ec(i)`の3レンダーサイト（4月／6月の継続営業中applicant出身社員／RECOVERY-LOOP-1の7〜14月）＋`employeeConditionCard`（6月以降）＋`founderFollowUpCard`（Issue #167の8〜14月ウィンドウ）。
  - Section 3 = PR #188の`activeProjectStatusCard`ループをそのまま移動（フィルタ・key・表示項目`engineerName`/`projectName`/`deliveryPressure`/`budgetHealth`は無変更、`fieldEvaluation`は引き続き非表示）。
  - Section 4 = `_growthResultsSection()`（今月の成長）＋`internalTrainingCard`の月5以降ループ。SkillSheetはタブ内に単独カードを持たず、既存の導線（Section 2内`ec(i)`の「SkillSheet確認」ボタン）のまま。
  - 各セクションのヘッダーは、その月に表示するカードが1枚もない場合は非表示にした（POST-HOME-FREEZE Small-UX-Fixで確立済みの「空見出しを出さない」方針を踏襲）。

- **Section 1（新規）** は、`workflow.engineers`（founding engineers + 入社済みapplicantを含む、既存の「全社員」ロースター）を1行ずつ列挙し、各社員の名前と現在状態バッジを表示する。集計行（「待機 N・参画中 N・合計 N」）は`PublicDemoState.engineersWaiting`/`engineersAssigned`（HOMEのKPIが既に読んでいるのと同じ authoritative field）をそのまま表示するのみで、新しい集計ロジックは追加していない。

### stale「翌月参画予定」の社員タブ内解消

- `engineerStatus(e)`は`PublicDemoSalesStage.ordered`を常に「翌月参画予定」と表示する。しかし`ordered`は一度到達すると二度と変化しない終端stageのため、実際に案件へ参画済み（`workflow.assignedEngineerIds(month:)`に含まれる）になった後もこの文言が残り続ける、という既知の矛盾があった（POST-HOME-FREEZE Small-UX-Fixで**HOMEのOffice Stage表示のみ**修正済み。社員タブの`ec(i)`バッジ側は当時明示的にスコープ外とされていた）。
- 本Phaseで、社員タブ専用の`_currentEmployeeStatusLabel(engineer)`を新規追加。ロジックはHOME側の`_officeStageStatusFor`と全く同じ（`stage == ordered && 現在参画中` なら「参画中」、それ以外は`engineerStatus(e)`のまま）だが、**HOME側のコードパス（`_officeStageStatusFor`/`_officeStageDisplay`）は一切変更していない** — HOME Freezeを厳守するため、共通化リファクタではなく独立した同一ロジックのメソッドとして追加した。
- Section 1のロースター行、および`ec(i)`カードのバッジ（後述）でこの新しいラベルを使用する。

### 重複情報の削減（`ec(i)`バッジの削除）

- 実装中に`test/ui/public_demo/public_demo_01_home_consolidation_test.dart`の既存テスト（「4: the legacy KPI row is gone, not duplicated」）が、社員タブ上の「待機」というテキストが正確に2件（4月の創業社員2名分）であることを既に検証していると判明した。Section 1のロースターに現在状態バッジを追加したことで、`ec(i)`カード自身のバッジと合わせて重複（4件）してしまい、この既存テストが赤くなった。
- これはSSOTが明示的に求めている「不要な巨大カード・重複情報・過剰な余白を減らす」に反する重複だったため、`ec(i)`カードのヘッダーから名前+バッジの`Row`を削除し、名前のみのシンプルな`Text`に変更した。現在状態はSection 1のロースターが一元的に表示し、`ec(i)`（Section 2）は「次にすべき行動」に専念する — という設計意図をそのままコードに反映した形になり、既存テストも無変更で緑に戻った。

### 禁止事項の遵守

- **HOME**: `lib/presentation/home/`配下・`_officeStageDisplay`/`_officeStageStatusFor`/`_homeDashboardData`等のHOME専用projectionは一切変更していない。`_currentEmployeeStatusLabel`は独立した新規メソッドであり、HOME側の既存メソッドを1行も書き換えていない。
- **Domain**: `lib/game/public_demo/`配下のドメインクラス（`PublicDemoAssignment`/`PublicDemoWorkflowState`/`PublicDemoSalesStage`等）は無変更。既存フィールド・既存メソッドの読み取りのみ。
- **Save/schema**: 変更なし。
- **Finance/Balance**: 変更なし。
- **Month transition**: 変更なし。
- **Sales/Employee gameplay authority**: 変更なし — 全てのボタン・コマンド・eligibility判定は既存のまま、レンダリングされる位置（どのセクションか）のみが変わった。
- **fake data**: 追加していない。Section 1の集計行・バッジは全て既存の authoritative field（`PublicDemoState.engineersWaiting`/`engineersAssigned`、`PublicDemoEngineerSales.stage`、`PublicDemoWorkflowState.assignedEngineerIds`）を直接読むのみ。
- **fieldEvaluation**: 表示していない（APV Phase 1の既存方針を継続）。
- **Year-End**: 変更なし。
- **営業タブ/会計タブ**: 変更なし（本PRは社員タブのみ）。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_buildEmployeesTab`を4セクション構成へ再編成。新規: `_employeeRosterSection`, `_employeeNextActionsSection`, `_employeeActiveProjectsSection`, `_employeeGrowthSection`, `_sectionHeader`, `_currentEmployeeStatusLabel`。既存: `ec(i)`のバッジをヘッダーから削除（Section 1へ集約）。他の既存カード・ロジック・keyは無変更 |
| `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` | 新規テストファイル（後述） |
| `docs/reports/SES_NON-HOME-UI_EMPLOYEE_Phase1_Implementation_Result.md` | 本結果報告（新規） |

## UI Before / After

**Before**: `_growthResultsSection()` → 月ごとの`ec(i)`／`employeeConditionCard`／`ec(i)`（RECOVERY-LOOP-1）／`employeeConditionCard`／`activeProjectStatusCard`ループ／`founderFollowUpCard`ループ／`internalTrainingCard`ループ、という1本の条件分岐の列。見出しはなく、「今、誰がどういう状態か」を把握するには全カードを読む必要があった。

**After**: 見出し付き4セクション（社員一覧・現在状態 → 今やるべき社員アクション → 参画中案件 → 成長・SkillSheet・研修）。最上部のロースターで全社員の名前と現在状態（待機／営業中／参画中等）と集計を即座に把握でき、その下に「今すべきこと」「参画中の案件状況」「成長・研修」が続く。カード自体の内容・ボタン・keyは1つも変わっていない。

## Authoritative data source

- Section 1 集計: `PublicDemoState.engineersWaiting` / `engineersAssigned`（HOME KPIと同一source）
- Section 1 各行の状態: `PublicDemoEngineerSales.stage` + `PublicDemoWorkflowState.assignedEngineerIds(month:)`（HOMEの`_officeStageStatusFor`と同一の2つのauthoritative factのみ参照）
- Section 2/3/4: 全て既存の`workflow`/`s`読み取り（無変更）

新しいstate・新しい永続フィールド・新しい集計ロジックは一切追加していない。

## テスト

### 新規: `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart`（15 testWidgets）

`PublicDemoAggregate.initial()`から実際のdomainコマンド（`publicDemoAggregateAtMonth`/`publicDemoAdvanceEngineerToOrdered`/`recoverAssignment`/`closeOrdinaryMonth`）を連鎖させた決定論的fixtureを使用（APVスイートと同じ手法）。

1. **waiting employee**: 4月、創業社員2名とも「待機」、ロースター集計「待機 2・参画中 0・合計 2」
2. **assigned employee + APV**: 8月、Recovery-assignedのeng-01がロースターで「参画中」、Section 3に案件カード表示。eng-02（待機継続）は無影響
3. **stale status regression（2件）**: 同一eng-01を①ordered+recoverAssignment済み→「参画中」、②ordered だが未assign→「翌月参画予定」の2つの独立した`testWidgets`で検証（同一tester内で2回pumpWidgetすると要素再利用でStateが使い回されるため、fixtureごとに独立したtestWidgetsへ分離）
4. **next actionable employee state**: 4月、capability十分（78）なeng-01は「営業準備OK」+「SkillSheet確認」、capability不足（52）なeng-02はロック banner
5. **SkillSheet / training existing routes（2件）**: 「SkillSheet確認」タップで実際の`PublicDemoSkillSheetSheet`が開くこと、6月の研修カードがSection 4見出し下で到達可能なこと
6. **March/month15**: 8月から実際の`closeOrdinaryMonth`連鎖で15月まで進めても、assigned社員は「参画中」とSection 3カードを維持
7. **HOME Freeze regression**: 社員タブ→ホームタブ切替後、`PublicDemoHomeDashboardSection`は不変、社員タブ専用のセクション見出し・APV key はHOMEに一切現れない
8. **360×800 / 390×844 × TextScaler 1.0/1.3/2.0（6件）**: `SesTheme.build()`を使った実画面で、`tester.takeException()`がnullであること（RenderFlex/RenderBoxオーバーフローなし）、ロースター・各行・APVカードのrectが画面幅内に収まること

```
flutter test test/ui/public_demo/public_demo_employee_ui_phase1_test.dart
→ 15/15 tests passed
```

### 関連既存回帰テスト（個別実行、いずれも変更前に一度赤くなったものを含め最終的に全緑）

```
flutter test test/ui/public_demo/public_demo_active_project_visibility_test.dart
→ 8/8 passed

flutter test test/ui/public_demo/public_demo_01_home_office_stage_test.dart \
  test/ui/public_demo/public_demo_founder_follow_up_dialog_test.dart \
  test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart \
  test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart \
  test/ui/public_demo/public_demo_growth_result_card_test.dart \
  test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart \
  test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart \
  test/ui/public_demo/public_demo_raise_dialog_test.dart
→ all passed

flutter test test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart \
  test/ui/public_demo/public_demo_01_home_final_density_test.dart \
  test/ui/public_demo/public_demo_01_home_consolidation_test.dart \
  test/ui/public_demo/public_demo_01_home3_integration_test.dart \
  test/ui/public_demo/public_demo_01_home_runtime_read_test.dart
→ all passed
  （実装の最初のバージョンで
    「4: the legacy KPI row is gone, not duplicated」が
    重複「待機」テキスト(4件、期待2件)で1件失敗 → ec(i)のバッジ削除で修正、再実行で全緑）

flutter test test/presentation/home/ \
  test/game/public_demo/public_demo_founder_follow_up_test.dart
→ 212/212 passed
```

### Public Demo regression（フルスイート）

```
flutter test
→ 1630/1630 tests passed, 0 failed
```

（BASE SHAとの差分比較が必要な既知の無関係failureは0件だった — 修正が必要な既存failureは発生しなかったため、BASE SHAでの再現確認は不要だった。）

## flutter analyze

```
flutter analyze
→ No issues found!
```

（Flutter 3.47.2 / Dart 3.13.2、本セッションで`/opt/flutter`にstable channelをcloneして使用）

## git diff --check

```
git diff --check
→ (no output, exit 0 — whitespace error なし)
```

なお、`flutter pub get`実行時に発生した`pubspec.lock`の無関係な依存バージョン差分（本タスクと無関係なtransitive依存の更新）は`git checkout -- pubspec.lock`で元に戻し、diffを本タスクのスコープのみに保った。

## HOME Freeze verification

- `lib/presentation/home/`配下のファイルは1バイトも変更していない。
- `_officeStageDisplay`/`_officeStageStatusFor`/`_homeDashboardData`等、HOME専用のprojectionメソッドは無変更。
- `test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`（360×800/390×844でHOMEが1画面に収まる、TextScaler 1.3/2.0でオーバーフローしない）を含む全HOME回帰テストが緑のまま。
- 新規テストの「HOME Freeze regression」ケースで、社員タブの新しいセクション見出し・APV keyがHOME側に一切現れないことを直接検証済み。

## Domain / Save / Finance / Balance / Month authority unchanged

- `lib/game/public_demo/`配下のドメインファイルは1つも変更していない（`git diff --stat`で確認済み、変更ファイルは`lib/ui/`配下のみ）。
- 全てのボタン・コマンド呼び出し・eligibility判定式は既存のものをそのまま移動しただけで、1文字も書き換えていない（`_employeeNextActionsSection`/`_employeeActiveProjectsSection`/`_employeeGrowthSection`のdocコメントに、それぞれ元のレンダーサイトとの対応関係を明記）。
- Save/schema・Finance/Balance計算・Month transitionロジックへの変更はゼロ。

## Known issues

- 現時点で確認されている既知の問題はない。フルスイート1630件全て緑、`flutter analyze`もクリーン。
- Section 1のロースター行は`Wrap`で名前+バッジを配置しており、極端に長い社員名や非常に大きいTextScalerでも折り返しでオーバーフローを回避する設計だが、将来的に社員名が可変長・多言語になる場合は追加のUI検証が望ましい。
- SkillSheet・成長・研修は「既存導線の整理」の範囲に留めた。SkillSheetシート自体の表示内容（stale表示の有無等）には手を入れていない — 調査の結果、SkillSheetシートは`engineerStatus`/stale文言を表示していないことを確認済みのため、対象外で問題ない。

## Next recommended task

SSOTの実行順どおり、次はSales UI Phase 1（営業タブの情報設計）。続いてAccounting UI Phase 1、April→March human replayの順。

## Merge Readiness

**Ready for review.** `flutter analyze`・新規/既存の関連テスト・フルテストスイート（1630/1630）・`git diff --check`すべてPASS。HOME/Domain/Save/Finance/Month authorityの既存挙動は回帰テストで確認済み。auto-mergeは行わない。
