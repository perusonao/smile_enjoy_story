# SES NON-HOME-UI — Sales UI Phase 1 Implementation Result

STATUS: **完了（Phase 1）**

SSOT: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`

## BASE / HEAD

- BASE: `origin/main` = `f04ae434cfb7150dad587778f71100bc8fa3844d`（PR #189 "SES Employee UI Phase 1" merge SHA — 作業開始時に`git fetch origin main`で確認した最新main）
- Branch: `claude/sales-ui-phase-1-xayla5`（着手前、ローカルブランチが古いコミット（`f4ca78f`, Phase 0A/0B相当、PR未作成・独自work無し）に取り残されていたため、`git checkout -B claude/sales-ui-phase-1-xayla5 origin/main`で最新mainから作り直した）
- HEAD（本コミット時点）: 下記コミット参照

## 目的

営業タブを「月限定カードの置き場」から、以下の4段階の情報階層を持つ画面へ再設計する。

1. 現在の営業・採用状況
2. 今やるべき営業アクション
3. 採用・候補者進捗
4. 案件・参画/継続状況

Employee UI Phase 1（PR #189）が確立した「情報階層セクション」パターンを営業タブへ適用する。

## 実施内容

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`の`_buildSalesTab`を、単一の平坦なカードリスト（`_salesTabItems`、月ゲートで中身が変わるだけで、何もない月は全体が空白＋PUBLIC-DEMO-HOME-UI-3Cの空状態カードのみ）から、4つのセクションへ再構成した。

### 新しい構造

```
_buildSalesTab
├── _salesOverviewSection()           … Section 1: 現在の営業・採用状況（新規、常に表示）
├── (全セクション空の場合) _salesTabEmptyState()   … 既存の真実の空状態（無変更）
├── _salesSection('今やるべき営業アクション', _salesNextActionCards())     … Section 2
├── _salesSection('採用・候補者進捗', _salesApplicantProgressCards())     … Section 3
└── _salesSection('案件・参画/継続状況', _salesProjectStatusCards())      … Section 4
```

- **Section 2〜4は、旧`_salesTabItems`が持っていた月ゲート・eligibility・カード・keyを一切変更せず、そのまま3つのメソッドへ分割して移動しただけ。** 新しい判断・新しい営業ルールは追加していない。
  - Section 2（今やるべき営業アクション）= 求人媒体カード（`_RecruitmentMediaCard`、`s.month == 5`、`_openRecruitmentMedia`ハンドラ、無変更）。
  - Section 3（採用・候補者進捗）= 応募者ファネル（`ac(i)`ループ、`s.month == 5`、無変更）。
  - Section 4（案件・参画/継続状況）= 6月の案件決定カード（`assignmentCard(i)`ループ、`s.month == 6`、無変更）＋7月の結果ナラティブ（`s.month == 7`、無変更）。
  - 各セクションは、その月に表示するカードが1枚もなければヘッダーごと非表示にする（POST-HOME-FREEZE Small-UX-Fixで確立済みの「空見出しを出さない」方針を踏襲）。
  - 3セクションすべてが空の場合にのみ、既存の`_salesTabEmptyState()`（PUBLIC-DEMO-HOME-UI-3C由来、Issue #173／PR #174 Codexレビュー分を含め**1バイトも変更していない**）を表示する。この条件は旧`_salesTabItems.isEmpty`と完全に同一（3つの新メソッドの出力を`||`で結合しているだけ）。

- **Section 1（新規）** は、既存フィールドのみから構築した常時表示の読み取り専用サマリー:
  - `営業残 ${s.salesRemaining}回（上限${s.salesCapacity}回）` — HOMEの推奨アクションが既に読んでいるのと同じ`PublicDemoState.salesRemaining`/`salesCapacity`。
  - `候補者 N名・案件 M件（うち検討中 K件）` — `workflow.applicants`（`hasJoined`でフィルタ）と`workflow.assignments`（`nextOrderStatus`でフィルタ）の単純なカウントのみ。新しい集計フィールド・永続フィールドは一切追加していない。
  - 待機/参画中の社員頭数（HOME KPI・Employee roster既存表示と同一）はこのSectionでは意図的に表示していない — 同じ情報の3箇所目の重複になり、SCOPEが明示的に求める「不要なカード重複を減らす」に反するため。

### 既知の重要な事前発見: 候補者カウントの月ゲート

`PublicDemoWorkflowState.initial()`は`applicants: publicDemoMayApplicants`という既定の候補者プール（2名）を**4月時点から**既に保持している（求人媒体を一度も使わなくても存在する既存ドメインの事実）。しかし応募者ファネル自体（`ac(i)`、Section 3）は`s.month == 5`より前には一切描画されない（この既存ゲートは変更していない）。

そのため、Section 1の「候補者」カウントをそのまま`workflow.applicants`から無条件に計算すると、4月の時点で「候補者2名」という、画面上どこからも確認・操作できない数字を表示してしまう。これは「actionがない月は理由と確認先をtruthfulに表示」というGOALに反する（見えない・触れない数字を見せる方が誤解を招く）ため、Section 1の候補者カウントは`s.month < 5`のとき常に`0`を返すよう明示的にガードした。これは新しい営業ルールではなく、「このタブから実際に確認・操作できる候補者だけを数える」という表示上の判断であり、応募者ファネル（Section 3）自体の既存ゲート条件と完全に一致させただけである。

### 求人媒体の月ウィンドウについて（変更していない、Known Issueとして記録）

`PublicDemoState.canUseRecruitmentMediaInMonth`はドメイン上4〜8月を求人媒体の利用可能ウィンドウとして既に許可している（コード内コメントに"12MONTH-3-FIX1 P1-2"として明記済みの既存事実）。しかし営業タブのUI（Section 2, `_salesNextActionCards`）は旧実装から変更せず`s.month == 5`のときのみ求人媒体カードを描画する。6〜8月に理論上ドメインが許可している求人媒体アクションは、本Phaseでも引き続きUIから到達不能である。

これは「Sales gameplay authority/eligibility変更禁止」の指示を厳守するため意図的に手を付けなかった — 求人媒体カードの描画月を広げると、応募者ファネルの月ゲートや、6〜8月に生成される応募者への導線（現状皆無）まで連鎖的に見直す必要があり、Sales UI Phase 1の「レイアウト再設計」というスコープを超える。**将来候補としてここに記録する**（GOAL文書が求める「既存stateで表現できない情報は作らず、Result Reportに『将来候補』として記録する」方針に従う）。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_buildSalesTab`を4セクション構成へ再編成。新規: `_salesOverviewSection`, `_salesNextActionCards`, `_salesApplicantProgressCards`, `_salesProjectStatusCards`, `_salesSection`。既存: `_salesTabEmptyState`・全カード・全月ゲート・全eligibility判定は無変更（1文字も書き換えていない） |
| `test/ui/public_demo/public_demo_sales_ui_phase1_test.dart` | 新規テストファイル（後述） |
| `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` | Update history追記、次優先度をAccounting UI Phase 1へ更新 |
| `docs/reports/SES_NON-HOME-UI_SALES_Phase1_Implementation_Result.md` | 本結果報告（新規） |

## UI Before / After

**Before**: `_salesTabItems`が月ごとに条件分岐で1本のカードリストを返し、空なら`_salesTabEmptyState()`のみを表示。「今、営業・採用がどういう状況か」を把握する常時表示のサマリーは存在せず、4月・8月〜3月は見出しも文脈もない単一の空状態カードのみだった。

**After**: 見出し付き4セクション（現在の営業・採用状況 → 今やるべき営業アクション → 採用・候補者進捗 → 案件・参画/継続状況）。最上部のSection 1で営業残・候補者数・案件数を年間を通じて即座に把握でき、その下に月ごとの実際のアクション/進捗/案件状況が続く。アクションが無い月（4月・8月〜3月）は、Section 1の下に既存の真実の理由付き空状態が表示される — カード自体の内容・ボタン・keyは1つも変わっていない。

## Authoritative data source

- Section 1: `PublicDemoState.salesRemaining`/`salesCapacity`（HOME推奨アクションと同一source）、`workflow.applicants`（`PublicDemoApplicant.hasJoined`でフィルタ、`s.month >= 5`でゲート）、`workflow.assignments`（`PublicDemoAssignment.nextOrderStatus`でフィルタ）
- Section 2/3/4: 全て既存の`workflow`/`s`読み取り（無変更） — `_RecruitmentMediaCard`, `ac(i)`, `assignmentCard(i)`, `julyResult(a)`

新しいstate・新しい永続フィールド・新しい集計ロジック・新しい営業ルールは一切追加していない。

## テスト

### 新規: `test/ui/public_demo/public_demo_sales_ui_phase1_test.dart`（26 testWidgets）

`PublicDemoAggregate.initial()`から実際のdomainコマンド（`closeApril`/`closeMay`/`closeJune`/`closeOrdinaryMonth`/`recruit`/`withAssignmentUpdate`、および既存の`publicDemoAggregateAtMonth`ヘルパー）を連鎖させた決定論的fixtureを使用。

1. **Section 1 overview（3件）**: 4月は営業残がフル・候補者0名・案件0件、5月は候補者数が実際のパイプライン数と一致、6月は案件数と「うち検討中」件数が実際の`nextOrderStatus`と一致
2. **April empty/pre-sales state**: Section 1は表示されるが、Section 2/3/4見出しは一切現れず、既存の真実の空状態のみが表示される
3. **May recruitment/applicant state（3件）**: 求人媒体カード・応募者ファネルが正しいセクション見出し下に表示、空状態は非表示。CTA/eligibility不変の直接検証2件（求人媒体ボタンが実際の媒体選択シートを開く、「経歴書確認」が実際に`reviewResume`コマンドで応募者ステージを進める）
4. **June assignment state**: 案件決定カードが正しいセクション見出し下に表示、空状態・応募者進捗見出しは非表示
5. **July result**: 7月結果ナラティブが正しいセクション見出し下に表示、空状態は非表示
6. **Aug-Feb no-action/employee-routing state（3件: 8月・11月・14月）**: 何も起きていない各月で、Section 1は表示されつつ真実の空状態が現れ、そのCTAが実際に社員タブ（index 1）へ遷移する
7. **March/month15**: 15月でも同じ真実の空状態が表示され、営業タブ独自のYear-End的挙動を一切導入していないことを確認
8. **360×800/390×844 × TextScaler 1.0/1.3/2.0（12件）**: 5月（最も内容が多い月）と8月（空状態）の両方で、`tester.takeException()`がnullであること（RenderFlexオーバーフローなし）、各セクションのrectが画面幅内に収まること
9. **HOME Freeze / Employee UI regression**: 社員→営業→ホーム、営業→社員とタブを往復しても、営業タブ専用のセクションkeyがHOME/社員タブに一切現れず、HOME/社員タブ自身の既存keyは不変

```
flutter test test/ui/public_demo/public_demo_sales_ui_phase1_test.dart
→ 26/26 tests passed
```

### 関連既存回帰テスト（個別実行、いずれも無変更で緑）

```
flutter test test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart
→ 8/8 passed（Issue #173/PR #174由来の営業タブ空状態の既存回帰スイート、1バイトも変更せず全緑）

flutter test test/ui/public_demo/public_demo_employee_ui_phase1_test.dart \
  test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart \
  test/ui/public_demo/public_demo_01_home_final_density_test.dart
→ 33/33 passed（Employee UI Phase 1 / HOME Freeze回帰）
```

### Public Demo regression

```
flutter test test/game/public_demo
→ 520/520 tests passed

flutter test test/ui/public_demo
→ 348/348 tests passed
```

上記2ディレクトリは、本タスクが変更したファイル（`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）に関連するdomain/UIテストの全量であり、いずれも無変更のまま全緑（既存の失敗は0件）。

リポジトリ全体の`flutter test`（本タスクと無関係な`test/presentation`・`test/domain`・`test/widget_test.dart`等を含むフルスイート）も並行してバックグラウンド実行し、完了を確認した:

```
flutter test
→ 1656/1656 tests passed, 0 failed
```

（BASE SHAとの差分比較が必要な既知の無関係failureは0件だった — 修正が必要な既存failureは発生しなかったため、BASE SHAでの再現確認は不要だった。）

## flutter analyze

```
flutter analyze
→ No issues found!
```

（Flutter 3.44.8 / Dart 3.12.2、本セッションで`/home/user/flutter-sdk`にstable channel 3.44.8タグをcloneして使用 — 本リポジトリのCIワークフロー`public-demo-validation.yml`/`public-demo-preview.yml`と同一バージョン）

## git diff --check

```
git diff --check
→ (no output, exit 0 — whitespace error なし)
```

## HOME Freeze verification

- `lib/presentation/home/`配下のファイルは1バイトも変更していない。
- `_officeStageDisplay`/`_officeStageStatusFor`/`_homeDashboardData`等、HOME専用のprojectionメソッドは無変更。
- `test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`・`public_demo_01_home_final_density_test.dart`を含む全HOME回帰テストが緑のまま。
- 新規テストの「HOME Freeze / Employee UI regression」ケースで、営業タブの新しいセクション見出しkeyがHOME/社員タブ側に一切現れないことを直接検証済み。

## Employee UI verification

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`内の`_buildEmployeesTab`および4つの`_employee*Section`メソッドは1行も変更していない（`git diff`で確認済み — 差分は`_buildSalesTab`とその周辺の新規メソッドのみ）。
- `public_demo_employee_ui_phase1_test.dart`（15 testWidgets）が無変更のまま全緑。

## Domain / Save / Finance / Balance / Month / Sales authority unchanged

- `lib/game/public_demo/`配下のドメインファイルは1つも変更していない（`git diff --stat`で確認済み、変更ファイルは`lib/ui/`配下1ファイルのみ）。
- 全てのボタン・コマンド呼び出し・eligibility判定式（`s.salesRemaining > 0`、`s.month == 5/6/7`、`PublicDemoNextOrderStatus`/`PublicDemoReplacementStage`の各分岐等）は既存のものをそのまま3つのメソッドへ分割移動しただけで、1文字も書き換えていない。
- Save/schema・Finance/Balance計算・Month transitionロジック・Year-End仕様への変更はゼロ。
- Sales gameplay authority/eligibility（`canUseRecruitmentMediaInMonth`、応募者/案件の各stage遷移コマンド）は無変更 — 「求人媒体の月ウィンドウについて」節に記載の通り、UI側の月ゲートも意図的に据え置いた。

## Known issues / 将来候補

1. **求人媒体UIの月ウィンドウ（4〜8月）とタブ描画（5月のみ）の不一致**: ドメインは4〜8月の求人媒体利用を許可しているが、営業タブは旧実装から変更せず5月のみ求人媒体カードを描画する。6〜8月にこの既存eligibilityを実際にUIから使えるようにするには、応募者ファネル（Section 3）の月ゲートおよび6〜8月に生成される応募者への導線も合わせて再設計する必要があり、Sales UI Phase 1（レイアウト再設計）のスコープを超えるため、Phase 2以降の将来候補として記録する。
2. **案件・参画/継続状況（Section 4）の年間持続表示**: 現状Section 4は6月（決定カード）・7月（結果ナラティブ）にのみ内容を持つ。8月以降も継続中の案件（`workflow.assignments`）を営業タブ側から読み取り専用で確認したい場合、Employee UI Phase 1の`activeProjectStatusCard`（社員タブSection 3）と情報が重複しないよう、営業視点独自の切り口（例: 契約継続履歴等、現状ドメインが保持しない情報）を設計する必要があり、本Phaseでは意図的に着手していない。

## Next recommended task

SSOTの実行順どおり、次はAccounting UI Phase 1（会計タブの情報設計）。続いてApril→March human replay。

## Merge Readiness

**Ready for review.** `flutter analyze`・新規/既存の関連テスト・`git diff --check`すべてPASS。HOME/Employee UI/Domain/Save/Finance/Month/Sales authorityの既存挙動は回帰テストで確認済み。auto-mergeは行わない。
