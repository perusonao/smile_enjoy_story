# SES NON-HOME-UI — Accounting UI Phase 1 Implementation Result

STATUS: **完了（Phase 1）**

SSOT: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`

## SOURCE AUDIT について

タスクで指定された `docs/reports/SES_NON-HOME-UI_ACCOUNTING_Phase1_Fresh-Audit.md`
は、着手前に`git fetch origin`した最新mainおよびリポジトリ全ブランチを検索したが
存在しなかった（`SES HOME Final Density`が同様の状況で
`docs/reports/SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_PreImplementation_Audit.md`
を実測ベースで新規作成した前例と同じ状況）。そのため本タスクでは、既存の会計タブ
実装（`_buildAccountingTab`）と関連コンポーネント（`PublicDemoFinanceSummarySection`、
`PublicDemoMonthlyCashFlowCard`、`PublicDemoCashForecast`等）を実測・精読し、
Fresh Audit相当の調査を本タスク内で自ら実施した上で実装した。調査で確認した
「B. READY WITH CONDITIONS」に相当する事実:

- 会計タブは月次収支カード・支出サマリー・夏季賞与決定・8月開始結果・Year-End
  カードが単一の`Column`にフラットに並んでいるのみで、情報階層（現在→今月→将来→
  判断→結果）がなかった。
- `PublicDemoFinanceSummarySection`の見出し「今月の支出予定」は、実際には
  `PublicDemoState.latestMonthlyCashFlow`（直近に確定した月の実績）を表示して
  おり、5月以降は実質的に「先月実績」を「今月の予定」と偽って表示していた
  （IMPORTANT FIXの指摘と一致）。
- 将来の資金予測（`PublicDemoCashForecast`）はHOMEのNavigatorアドバイス
  （`_cashForecastAdvice`）内部でのみ使われており、会計タブ自体には資金予測・
  リスクを示すセクションが存在しなかった。

## BASE / HEAD

- BASE SHA: `f04ae434cfb7150dad587778f71100bc8fa3844d`（PR #189 "Employee UI
  Phase 1" merge SHA — `git fetch origin`で確認した着手時点の最新main）
- Final integration base: `8387e9369389665bc38525f54430fb8930cd3808`
  （PR #191 "Sales UI Phase 1" merge SHA — 着手後にSalesがmainへ統合された
  ため、PR作成前に再取得してマージ統合した）
- Branch: `claude/accounting-ui-phase-1-p5myb8`（着手前、ローカルブランチが
  古いコミット `f4ca78f`（Phase 0A/0B相当、mainへ統合済み・独自work無し）に
  取り残されていたため、`git checkout -B claude/accounting-ui-phase-1-p5myb8
  origin/main`で最新mainから作り直した）
- Accounting実装コミット: `7753c73`
- Sales統合マージコミット: `8ef5238`
- 最終HEAD SHA: `8ef52382a4dc8c0c56b5b54243f7508c617118c9`

Sales UI Phase 1（PR #191）は着手時点でCI進行中・main未統合だったため、
Salesファイル（`_buildSalesTab`および関連メソッド）には一切触れずに実装を
進めた。実装・テストが完了した時点で PR #191 がmainへマージされたことを確認し
（`git fetch origin main` → `8387e93...`）、`git merge origin/main`で
Accountingブランチへ安全に統合した。マージはコンフリクトなし（`ort`戦略で
自動マージ）— Sales側は`_buildSalesTab`付近、Accounting側は`_buildAccountingTab`
付近と、同一ファイル内でも変更範囲が完全に分離していたため。

## 目的

会計タブを、プレイヤーが上から

1. 現在の資金状態
2. 今月の収支
3. 将来の資金予測・リスク
4. 今月必要な経営判断
5. 月次結果 / Year-End

を理解できる情報階層へ再設計する。Phase 1はpresentation-onlyを原則とし、
Domain/Save/Finance計算/Balance/Month transition/Year-End authorityは
一切変更しない。

## 実施内容

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`の
`_buildAccountingTab`を、単一の`Column`（月次収支カード→支出サマリー→
（7月のみ）夏季賞与カード→（8月のみ）開始結果テキスト→（完了時のみ）
Year-Endカード）から、5つのセクションメソッドへ再構成した。

```
_buildAccountingTab
├── _accountingFundStatusSection()      … Section 1: 現在の資金状態（新規、常時表示）
├── _accountingMonthlyBalanceSection()  … Section 2: 今月の収支（既存カード2つを移動）
├── _accountingForecastSection()        … Section 3: 将来の資金予測・リスク（新規）
├── _accountingDecisionSection()        … Section 4: 今月必要な経営判断（既存カードを移動）
└── _accountingMonthlyResultSection(c)  … Section 5: 月次結果 / Year-End（既存を移動）
```

### Section 1 — 現在の資金状態（新規）

`PublicDemoState.cash`と`financialStatus`という、このスクリーンが既に
（HOMEの`PublicDemoCashShortageCard`等で）読んでいる2つの既存authoritative
フィールドのみから構築した、常時表示の読み取り専用スナップショット。
`_financialStatusLabel`は`PublicDemoFinancialStatus`の4状態（normal/
cashShortage/bankruptcy/marchCashShortageFailure）に日本語ラベルを
付けるだけで、新しい閾値・集計・authorityは一切追加していない。

### Section 2 — 今月の収支

既存の`_monthlyCashFlowSection()`（`PublicDemoMonthlyCashFlowCard`、直近
確定月の現預金内訳）と`PublicDemoFinanceSummarySection`（給与・固定費の
サマリー）を、見出し付きセクションへそのまま移動しただけ。カード自体・key・
`_financeSummary`の計算ロジックは無変更。

**IMPORTANT FIX（Fresh Audit相当・ラベル真実性の修正）**: `_financeSummary`
（`s.latestMonthlyCashFlow`から給与・固定費を読む既存getter）に
`isSettled`（`latest != null`）を追加し、`PublicDemoFinanceSummaryModel`の
新フィールドとして渡すようにした。`PublicDemoFinanceSummarySection`の見出しは
これに応じて:

- 初回決算前（4月、`isSettled == false`）: 「今月の支出予定」（この場合は
  ベースライン定数がそのまま今月適用される予定であり、真実に沿った表現）
- 初回決算後（5月〜、`isSettled == true`）: 「前回確定の支出（給与・固定費）」
  （直近に確定した月の実績であり、今月の予定ではないことを明示）

**給与・固定費の金額（payroll/fixedCosts）自体は1円も変更していない** —
変更したのは見出しの文言のみ。`isSettled`はデフォルト`false`のオプション
引数としたため、既存の`PublicDemoFinanceSummaryModel(payroll:...,
fixedCosts:...)`という2箇所のテスト構築（`public_demo_home_presentation_
components_test.dart`）は無修正のまま緑のままとなる（既定でpre-close表示に
フォールバックするため）。

### Section 3 — 将来の資金予測・リスク（新規）

既存の`PublicDemoCashForecast.forecast(state:, workflow:)`（HOMEの
`_cashForecastAdvice`が既に使っている、確定情報のみに基づく純粋な3か月先
予測モデル、PR #153由来）と`PublicDemoCashStatusPresentation.fromForecast`
（safe/shortage/unavailableの3状態判定、PR #154由来）を、会計タブから直接
読み取り専用で表示する新セクション。**新しい計算式・閾値は一切追加していない**
— 既存の2つの純粋モデルをそのまま呼び出し、その出力をテーブル表示している
だけ。

- 予測期間内（`PublicDemoCashForecast.defaultMonthsAhead` = 3か月）に資金
  ショートが見込まれる場合: 該当月と「◯月に資金がマイナスになる見込みです。」
  という見出し（HOMEの`_cashForecastAdvice`と同一文言・同一ロジック）。
- 見込まれない場合: 「今後N回の決算見込みでは資金不足はありません。」
- 各予測月について「◯月末 現預金見込み ¥X」を列挙し、マイナスの月は赤字・
  太字で強調（`PublicDemoCashForecastMonth.isNegative`をそのまま読むのみ）。
- 予測window自体が空（`isCloseBlocked` — 年度完了または財務的に
  terminal）の場合はセクションごと非表示（既存の「空見出しを出さない」
  precedentに準拠）。

HOME側の`PublicDemoCashShortageCard`（実際に`cashShortage`へ陥った際の
リアクティブな警告カード）とは役割が異なり、本セクションは`financialStatus`
が`normal`の間も含めた常時のプロアクティブな3か月先見通しであり、
どちらもHOME/会計それぞれの既存・新規の役割を保ったまま共存する（同じ
見出し文言を二重に出す設計にはしていない）。

### Section 4 — 今月必要な経営判断

既存の夏季賞与決定カード（`s.month == 7`、`_summerBonusDecisionRequired`、
`decideSummerBonus`）を、同一key・同一ロジックのままセクションへ移動した
だけ。7月以外は「空見出しを出さない」precedentに従いセクション自体を
非表示にする。

### Section 5 — 月次結果 / Year-End

既存の8月開始結果ナラティブ（`s.month == 8`、給与・夏季賞与反映テキスト、
POST-HOME-FREEZE Small-UX-Fix由来）と、年度完了時の`PublicDemoYearEndResultCard`
（`public-demo-fiscal-year-complete`キー、`_confirmRestartFromApril` →
`_restartGame`のcanonical restartへの配線を含む、YEAR-END-PHASE-1由来）を、
同一key・同一ロジックのまま1つのセクションへ統合した。どちらも該当しない
月（9〜14月、完了前の3月）はセクション自体を非表示にし、既存の
`public_demo_01_accounting_tab_empty_heading_test.dart`が引き続き
`findsNothing`を検証できるようにしている。

### 追加修正: `PublicDemoMonthlyCashFlowCard`の潜在的横overflow

新規テスト（TextScaler 2.0 × 360px/390px）で、既存の
`PublicDemoMonthlyCashFlowCard`内の`_Row`（支出内訳の各行）が、ラベル側
のみ`Expanded`で値側（金額）が非flexibleだったため、大きな金額＋長いラベル
（例:「売掛金（来月入金予定）」）の組み合わせでTextScaler 2.0時に横方向へ
overflowする既存の潜在バグを発見した。これはAccountingタブ再構成前の
既存コードに元々あったバグで、これまでTextScaler 2.0での検証が
このカードに対して一度も行われていなかったため未発見だった。

修正は`_Row`の値`Text`を`Flexible` + `FittedBox(fit: BoxFit.scaleDown)`で
包むのみ（`public_demo_cash_shortage_card.dart`の`_Tile`が既に使っている
同じパターン）。**表示のスケーリングのみの変更で、金額そのもの・文字列
そのもの・Finance計算は一切変更していない** — 既存の`find.text(value)`系
アサーションは全て無修正のまま緑（`public_demo_monthly_cash_flow_card_test.dart`
15/15 pass）。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_buildAccountingTab`を5セクション構成へ再編成。新規: `_accountingFundStatusSection`, `_financialStatusLabel`, `_accountingMonthlyBalanceSection`, `_accountingForecastSection`, `_accountingDecisionSection`, `_accountingMonthlyResultSection`。`_financeSummary`に`isSettled`計算を追加。既存カード・key・月ゲート・eligibility判定は全て無変更（そのまま新メソッドへ移動） |
| `lib/ui/public_demo/public_demo_home_presentation_components.dart` | `PublicDemoFinanceSummaryModel`に`isSettled`（既定`false`）を追加。`PublicDemoFinanceSummarySection`の見出しを`isSettled`に応じて真実に沿った文言へ分岐 |
| `lib/ui/public_demo/public_demo_monthly_cash_flow_card.dart` | `_Row`の値表示を`Flexible`+`FittedBox(scaleDown)`化し、TextScaler 2.0での潜在的横overflowを解消（表示のみ、金額・文字列は無変更） |
| `test/ui/public_demo/public_demo_accounting_ui_phase1_test.dart` | 新規テストファイル（後述） |

## UI Before / After

**Before**: 会計タブは月次収支カード→支出サマリー→（月により）夏季賞与
カード/8月開始結果→（完了時）Year-Endカードが単一`Column`にフラットに
並ぶのみで、見出しのない状態だった。支出サマリーの見出し「今月の支出予定」
は5月以降、実際には先月実績を表示していた。将来の資金リスクを確認できる
場所は会計タブ自体には存在しなかった（HOMEのNavigatorが資金ショート
発生"前"の予兆をたまたま示すのみ）。

**After**: 見出し付き5セクション（現在の資金状態 → 今月の収支 →
将来の資金予測・リスク → 今月必要な経営判断 → 月次結果/Year-End）。
最上部で現在の現預金・財務状態を即座に把握でき、続いて今月の収支詳細、
今後3か月の資金見通し・リスク、その月に必要な判断、月次/年度末の結果が
この順で並ぶ。支出サマリーの見出しは決算前後で真実に沿って切り替わる。

## Authoritative data sources（再利用のみ、新規計算なし）

- Section 1: `PublicDemoState.cash`, `PublicDemoState.financialStatus`
- Section 2: `PublicDemoState.latestMonthlyCashFlow`（`_monthlyCashFlowSection`
  経由）、`_financeSummary`（既存の`salaryPaid`/`fixedCostsPaid`読み取り、
  `isSettled`は`latest != null`の再利用のみ）
- Section 3: `PublicDemoCashForecast.forecast(state:, workflow:)`（PR #153）、
  `PublicDemoCashStatusPresentation.fromForecast`（PR #154） — どちらも
  HOMEの`_cashForecastAdvice`が既に使っている同一の純粋モデル
- Section 4: `PublicDemoState.summerBonusSelection`, `_summerBonusDecisionRequired`,
  `decideSummerBonus`（既存コマンド）
- Section 5: `PublicDemoState.summerBonusPaidAmount`,
  `PublicDemoYearEndDisplayData.fromPublicDemoState(s)`,
  `PublicDemoYearEndResultCard`, `_confirmRestartFromApril`/`_restartGame`
  （既存canonical restart経路）

新しいstate・永続フィールド・集計ロジック・財務ルールは一切追加していない
（`isSettled`はUI表示分岐のみのbool、永続化されない）。

## Forecast reuse（詳細）

`PublicDemoCashForecast`は元々HOME内部（`_cashForecastAdvice`）でしか
消費されていなかった。今回、会計タブSection 3で**同じ関数を第二の呼び出し
元として直接呼ぶ**形で再利用した — フォーク・改変・別実装は一切行っていない。
`PublicDemoCashForecast.forecast`自体・`PublicDemoCashStatusPresentation`
自体は1行も変更していない。

## Label correction（詳細）

| 状態 | Before | After |
|---|---|---|
| 4月（決算前） | 今月の支出予定 | 今月の支出予定（変更なし — この場合は真実） |
| 5月〜（決算後） | 今月の支出予定（誤り: 実際は先月実績） | 前回確定の支出（給与・固定費） |

金額（`payroll`/`fixedCosts`）は両状態とも既存の`_financeSummary`ロジック
のまま — 変更したのは見出し文言のみ。

## テスト

### 新規: `test/ui/public_demo/public_demo_accounting_ui_phase1_test.dart`（36 testWidgets）

`PublicDemoAggregate.initial()`/`publicDemoAggregateAtMonth`ヘルパーから
実際のdomainコマンド（`closeOrdinaryMonth`等）を連鎖させた決定論的
fixtureを使用。

1. **Section 1 現在の資金状態（2件）**: 4月は現在の現預金・「健全」ラベルが
   `PublicDemoState`と一致、実際の資金ショート状態（`shortageAtMonth9`
   — 売上ゼロのまま高額な`monthlyExpenses`で複数月連続クローズし、実際に
   `financialStatus == cashShortage`へ到達する決定論的fixture）では
   「資金不足（猶予期間中）」を表示し「健全」は表示されないことを確認
2. **Section 2 truthful labels（2件）**: 4月（決算前）は「今月の支出予定」、
   5月（決算後）は「前回確定の支出（給与・固定費）」が表示され、互いに
   排他的であることを確認（Fresh Audit fixの直接検証）
3. **Sep-Feb normal accounting（6件: 9〜14月）**: 現在の資金状態・今月の
   収支・将来予測は表示され、経営判断・月次結果セクションは非表示
4. **July summer bonus（1件）**: 経営判断セクション配下に既存の夏季賞与
   カード・CTA（`public-demo-summer-bonus-decision`）がそのまま表示
5. **August start result（1件）**: 月次結果セクション配下に既存の
   「8月開始結果」ナラティブがそのまま表示
6. **Cash forecast / risk（3件）**: 健全時は全予測月が
   `PublicDemoCashForecast.forecast`の実出力と厳密一致、実際の資金
   ショート時は見出しが実際の`shortageMonth`と一致、年度完了時は予測
   windowが空になりセクション自体が非表示になることを確認
7. **March/month15 Year-End・restart route（2件）**: 年度完了fixtureで
   Year-Endカードが月次結果セクション配下に表示され、リプレイCTAが
   既存のcanonical restart確認ダイアログ（`public-demo-restart-april-dialog`
   → `public-demo-restart-april-confirm`）を経て実際に4月へリセットする
   ことを確認。完了前の3月ではYear-Endカード・月次結果セクションとも
   非表示
8. **360×800/390×844 × TextScaler 1.0/1.3/2.0（18件）**: 7月（最も内容が
   多い月）・資金ショート状態・年度完了状態の3シナリオそれぞれで、
   `tester.takeException()`がnull（RenderFlexオーバーフローなし）である
   ことを確認
9. **HOME Freeze / Employee UI / Sales UI regression（1件）**: 会計→社員→
   営業→ホーム→会計とタブを往復しても、会計タブ専用のセクションkeyが
   他タブへ一切漏れず、他タブ自身の既存keyも不変であることを確認

```
flutter test test/ui/public_demo/public_demo_accounting_ui_phase1_test.dart
→ 36/36 tests passed
```

### 関連既存回帰テスト（個別実行、いずれも無修正で緑）

```
flutter test test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart
→ 9/9 passed（8月/9-14月/完了前3月の「空見出しを出さない」既存回帰、無修正）

flutter test test/ui/public_demo/public_demo_home_presentation_components_test.dart
→ 全件 passed（`PublicDemoFinanceSummaryModel`の2箇所の既存テスト構築を
  含め、`isSettled`が既定`false`のため無修正のまま緑）

flutter test test/ui/public_demo/public_demo_01_home3_integration_test.dart
→ 全件 passed（HOME側finance summary/labelの既存アサーションは無修正で緑
  — 4月の`isSettled==false`ケースを検証していたため影響なし）

flutter test test/ui/public_demo/public_demo_summer_bonus_dialog_test.dart
→ 全件 passed

flutter test test/ui/public_demo/public_demo_01_year_end_result_test.dart
→ 全件 passed（Year-Endカード自体・restart flowは無修正のまま緑）

flutter test test/ui/public_demo/public_demo_monthly_cash_flow_card_test.dart
→ 15/15 passed（`_Row`のFittedBox化後も既存の`find.text(value)`系
  アサーションは全て無修正のまま緑）

flutter test test/ui/public_demo/public_demo_sales_ui_phase1_test.dart
→ 26/26 passed（Sales UI Phase 1、mainからマージ後も無修正のまま緑
  — Sales main統合後のSales UI regression確認）

flutter test test/ui/public_demo/public_demo_employee_ui_phase1_test.dart \
  test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart \
  test/ui/public_demo/public_demo_01_home_final_density_test.dart
→ 全件 passed（Employee UI Phase 1 / HOME Freeze回帰）
```

### Public Demo regression（マージ後）

```
flutter test test/game/public_demo test/ui/public_demo
→ 904/904 tests passed
```

### フルスイート（マージ後、リポジトリ全体）

```
flutter test
→ 1692/1692 tests passed, 0 failed
```

## flutter analyze

```
flutter analyze
→ No issues found!
```

（Flutter 3.44.8 stable / Dart 3.12.2、本セッションで`/home/user/flutter-sdk`
にstable channel 3.44.8タグをcloneして使用 — 本リポジトリのCIワークフロー
`public-demo-validation.yml`/`public-demo-preview.yml`と同一バージョン）

## git diff --check

```
git diff --check
→ (no output, exit 0 — whitespace error なし)
```

## HOME Freeze verification

- `lib/presentation/home/`配下のファイルは1バイトも変更していない。
- `_homeDashboardData`/`_officeStageDisplay`/`_cashForecastAdvice`等、HOME
  専用のprojectionメソッド・HOME向けgetterは無変更（`_cashForecastAdvice`は
  読み取りのみで、`PublicDemoCashForecast`という同じ下位モデルをAccounting
  Section 3が別途呼び出しているだけで、HOME側の呼び出し・出力は無変更）。
- `public_demo_01_home_one_screen_final_fit_test.dart` /
  `public_demo_01_home_final_density_test.dart` /
  `public_demo_01_home3_integration_test.dart`を含む全HOME回帰テストが
  緑のまま。
- 新規テストの「HOME Freeze / Employee UI / Sales UI regression」ケースで、
  会計タブの新しいセクションkeyがHOME/社員/営業タブ側に一切現れないことを
  直接検証済み。

## Employee UI regression

- `_buildEmployeesTab`および4つの`_employee*Section`は1行も変更していない
  （`git diff`で確認済み — 差分は`_buildAccountingTab`とその周辺の新規
  メソッド、および`PublicDemoFinanceSummaryModel`/`_Row`のみ）。
- `public_demo_employee_ui_phase1_test.dart`（15 testWidgets）が無修正の
  まま全緑。

## Sales UI regression（Sales main統合後）

- PR #191（Sales UI Phase 1）がタスク進行中にmainへマージされたことを
  確認後、`git fetch origin main` → `git merge origin/main`で
  Accountingブランチへ統合した。マージはコンフリクトなし（Sales側の
  `_buildSalesTab`関連メソッドとAccounting側の`_buildAccountingTab`関連
  メソッドが同一ファイル内でも完全に分離した位置にあったため）。
- マージ後、`_buildSalesTab`・4つの`_sales*`メソッドは1行も変更されて
  いないことを確認。
- `public_demo_sales_ui_phase1_test.dart`（26 testWidgets、Sales側が追加
  した新規テスト）がマージ後も無修正のまま全緑。

## Domain / Save / Finance / Balance / Month / Year-End authority unchanged

- `lib/game/public_demo/`配下のドメインファイルは1つも変更していない
  （`git diff --stat`で確認済み、変更ファイルは`lib/ui/public_demo/`配下
  3ファイルのみ）。
- `PublicDemoCashForecast`・`PublicDemoCashStatusPresentation`自体は
  1行も変更していない（既存の純粋関数をAccounting Section 3から新たに
  呼び出しているだけ）。
- Save/schema・Finance/Balance計算・Month transitionロジック・Year-End
  仕様への変更はゼロ。`isSettled`はUI表示分岐専用のbool値で、永続化・
  save schemaには一切含まれない。
- 夏季賞与決定・8月開始結果・Year-Endの各ボタン/コマンド呼び出し
  （`decideSummerBonus`、`_confirmRestartFromApril`等）は既存のものを
  そのまま新メソッドへ分割移動しただけで、1文字も書き換えていない。

## Known issues / 将来候補

1. **Section 3の予測期間は固定3か月**（`PublicDemoCashForecast
   .defaultMonthsAhead`）。これは既存モデルのデフォルトをそのまま使用した
   結果であり、本Phaseでは新しい期間パラメータを導入していない。より長い
   期間の予測が必要になった場合はPhase 2以降の検討事項。
2. **Section 1と3の間で「現在の現預金」と「◯月末現預金見込み」という類似
   表現が並ぶ**が、前者は確定済みの現在値、後者は将来の projected 値であり、
   意図的に区別されたラベルにしている。ユーザーテストで混同が見られた場合は
   ラベル文言の追加調整をPhase 2で検討する。
3. **`PublicDemoMonthlyCashFlowCard`の`_Row` FittedBox化**は本Phaseの
   スコープ（会計タブの情報階層再設計）に付随して発見・修正した既存バグ
   だが、当該ウィジェットは会計タブ以外から呼ばれていないため影響範囲は
   会計タブのみ。

## Human Replay readiness

会計タブの情報階層が確立され、支出サマリーの見出しも真実に沿った表示へ
修正された。Domain/Save/Finance/Balance/Month/Year-End authorityは無変更、
HOME/Employee UI/Sales UIの既存回帰も全て緑であることを確認済みであり、
次タスク「April→March Human Replay」に進む前提条件を満たしている。

## Merge Readiness

**Ready for review.** `flutter analyze`・新規/既存の関連テスト・
`git diff --check`すべてPASS。HOME/Employee UI/Sales UI/Domain/Save/
Finance/Month/Year-End authorityの既存挙動は回帰テストで確認済み。
Sales UI Phase 1（PR #191）のmain統合を確認した上で本ブランチへ
安全に再統合し、統合後に全focused testsを再実行して緑を確認した。
AUTO-MERGEは行わない。
