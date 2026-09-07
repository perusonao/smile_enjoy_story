# SES NON-HOME-UI ACCOUNTING Visual Complete — Result

STATUS: **完了**

GOVERNING SSOT: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`
DEVELOPMENT PRIORITY: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
CANONICAL REFERENCE: `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`
（`06_Accounting_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`,
実際にPNGを開いてVisual Referenceとして確認済み）

## BASE SHA

`f208a8f55fb012c9ed187b58ca5f5c5746c965b2`（`git fetch origin` で確認した
作業開始時点の最新 `origin/main` — PR #195 "SES Sales Visual Complete"
マージコミット）。

作業開始前、ローカルブランチ `claude/ses-accounting-visual-complete-87ykf9`
は古いSHA（`f4ca78f`, 最新origin/mainの祖先）を指したまま停止していたため、
`git checkout -B claude/ses-accounting-visual-complete-87ykf9 origin/main`
で最新mainへ作り直してから着手した（このブランチに未マージの独自コミットは
存在しないことを`git log <branch> ^origin/main`で確認済み）。

## branch / final HEAD

- branch: `claude/ses-accounting-visual-complete-87ykf9`
- final HEAD: 本コミット時点（コミット後にPR URLと併せて報告）

## 対象AUDIT

`docs/reports/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Fresh-Audit.md`は
working treeに存在しなかった。指示に従い、タスク本文が与えたP0/P1ゴール自体を
Auditの結論として扱い、それに基づいて実装した。

## 目的

既存 Accounting UI Phase 1
（`docs/reports/SES_NON-HOME-UI_ACCOUNTING_Phase1_Implementation_Result.md`）
が確立した5セクションの情報階層（現在の資金状態 → 今月の収支 →
将来の資金予測・リスク → 今月必要な経営判断 → 月次結果 / Year-End）は
**変更せず**、Canonical Visual Reference の完成イメージへ visual（現金Hero化・
カード階層・配色・アイコン・stat tile・アラートカード）を近づける
「Visual Complete」化を行った。

## 実施前の確認

`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`の2枚
（`06_Accounting_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`）を
実画像として開いて確認した。共通する視覚要素:

- 「現在の現金」を大きな緑の財布/貯金箱アイコン＋太字の大きな金額＋前月比
  で表示するVisual Hero
- 「今月の売上」「今月の支出」を上下矢印アイコン付きの2枚のstat tileで並べる
- 月次の推移をグラフ/バーで示す
- アラート（注意・情報）をアイコン＋色付き背景のカードで明確化
- 各セクション見出しがアイコン付き
- 統一されたカード角丸・spacing・タイポグラフィ
- 会計タブ自体のbottom nav iconは銀行（🏛）アイコン

これを、既存のauthoritativeなPublic Demo state・実装済みロジックに対して
のみ適用した（架空のクライアント名・入金予定日・グラフの具体数値は一切
追加していない）。

## 実施内容

### 1. 現在現金のVisual Hero化（P0 目標1・2・3）

Section 1（`_accountingFundStatusSection`）を、2行のプレーンテキスト
（`現在の現預金 ¥X` / `資金状態：健全`）から、新規
`PublicDemoAccountingCashHero`（緑の貯金箱アイコン＋大きな太字の現金額＋
前月比delta）＋`PublicDemoAccountingStatusBadge`（財務状態を色付きバッジで
明確化）へ再構成した。

- 現金額（`formatYen(s.cash)`）は`FittedBox(scaleDown)`でTextScaler 2.0でも
  overflowしない大きな太字表示にした。
- 既存の`'現在の現預金'`という正確なラベル文字列は、Hero内の小さな
  キャプション`Text`としてそのまま1つだけ残した — 既存回帰テスト
  （`public_demo_accounting_ui_phase1_test.dart`の
  `find.textContaining('現在の現預金')` findsOneWidget）はそのまま無修正で
  通過する。
- 財務状態（`_financialStatusLabel`が返す既存の4文字列 — 健全 / 資金不足
  （猶予期間中） / 倒産（第1期終了） / 年度末資金不足（第1期終了）— は
  1文字も変えていない）を、新規`_financialStatusTone`ヘルパーで
  positive/caution/negativeの3トーンへ色分けしたバッジとして表示した。
  既存テストの`find.textContaining('健全')`/`find.textContaining('資金不足
  （猶予期間中）')` findsOneWidgetは、バッジのTextのみがその文字列を持つため
  無修正のまま通過する。

### 2. 前月比（P1、Fresh Auditのtruthfulness要件）

`PublicDemoState.latestMonthlyCashFlow`が非nullのとき（4月の初回決算前は
非表示 — 推測・fake historyを作らない）のみ、既存の
`PublicDemoMonthlyCashFlow.netCashMovement`（`closingCash - openingCash`、
FINANCE-UX-1由来の既存getter）をそのまま読み、`前月比 ±¥X`として表示する。

**新しいFinance計算は一切追加していない** — `netCashMovement`は既に
`PublicDemoMonthlyCashFlow`に存在した公開getterであり、本タスクは
その値を読んで符号に応じた矢印アイコンと色を付けただけである。

### 3. 今月の売上 / 今月の支出 stat tile（P0 目標4）

`latestMonthlyCashFlow`が非nullのとき、同じく既存フィールドの
`flow.revenue`（今月新規計上された売上）と`flow.totalOutflow`
（給与+固定費+賞与+研修費+採用費の合計 — 既存getter）を、新規
`PublicDemoAccountingStatTile`で上矢印/下矢印アイコン付きの2枚タイルとして
Hero直下に表示した。どちらも`PublicDemoMonthlyCashFlowCard`
（Section 2）が既に表示している値の再掲であり、新しい算出はない。

### 4. 将来の資金予測・リスク: 簡易forecastグラフ + アラートカード + 入金予定
（P1 目標1・2・3）

`_accountingForecastSection`を`PublicDemoAccountingCard`でラップし、以下を
追加した。既存の見出しテキスト・月別テキスト・キー（
`public-demo-accounting-forecast-month-N`）は**1文字も変更していない** —
追加のみ:

- 既存の安全/不足ヘッドライン文（`PublicDemoCashStatusPresentation
  .fromForecast`が返す既存の2文言のいずれか — 新しい閾値・文言は追加なし）を
  `PublicDemoAccountingAlertCard`（不足時=caution、安全時=positive）で包み、
  Referenceの「アラート・アドバイス」領域の視覚言語に合わせた。
- 各予測月（`PublicDemoCashForecast.forecast`が返す既存の
  `PublicDemoCashForecastMonth`列）の既存テキスト行の下へ、新規
  `PublicDemoAccountingForecastBar`（`LinearProgressIndicator`ベース、
  `public_demo_employee_visual.dart`の`PublicDemoEmployeeSkillBar`と同じ
  実装パターン）を追加した。バーの`fraction`は
  `closingCash / scaleMax`（`scaleMax`は現在の現金と全予測月の
  closingCashのうち非負の最大値、ゼロ除算防止のため最小1 —
  **表示スケールのみの計算であり、新しいFinance/Balance計算ではない**）。
  マイナス月は`isNegative: true`でゼロ幅・赤色のバーとして描画し、
  金額自体は既存のテキストが正確な値をそのまま表示し続ける。
- `PublicDemoState.pendingRevenue`（REVENUE-1由来の既存authoritative
  フィールド — 「認識済みだが未回収の売上、来月の決算で現金化される」）を、
  HOME側のコンパクトKPIが既に使っているのと**全く同じラベル**
  「入金予定」で、新規`PublicDemoAccountingStatTile`として1つだけ簡潔に
  表示した。意味を変えず、新しい集計・按分・案件別内訳は一切追加していない
  （Referenceの「入金予定」画面が示す案件別の内訳・入金予定日は、
  authoritative実装にその粒度のデータが存在しないため実装していない —
  「残る意図的な省略」参照）。

### 5. 5 section headersのicon-led統一（P0 目標5）

既存`_sectionHeader`（Employee/Sales Visual Completeで追加済みの`icon`
パラメータを持つ）を、会計タブの5見出し全てに適用した:

| セクション | アイコン |
|---|---|
| 現在の資金状態 | `Icons.account_balance_wallet_outlined` |
| 今月の収支 | `Icons.receipt_long_outlined` |
| 将来の資金予測・リスク | `Icons.query_stats_outlined` |
| 今月必要な経営判断 | `Icons.fact_check_outlined` |
| 月次結果 / Year-End | `Icons.flag_outlined` |

### 6. Accounting-local card / spacing / radius / visual tokensの整備
（P0 目標6）

新設`lib/ui/public_demo/public_demo_accounting_visual.dart`に、会計タブ
専用のpresentation-onlyな building blockを実装した:

- `PublicDemoAccountingTone`（positive/caution/negative）
- `PublicDemoAccountingStatusBadge`（色付きバッジ）
- `PublicDemoAccountingCard`（白背景・角丸12・outlineVariantボーダー — 
  Employee/Sales Visual Completeが確立した同じカード形状を、本ファイルの
  isolation方針どおり独立に再定義）
- `PublicDemoAccountingStatTile`（アイコン付きstat tile）
- `PublicDemoAccountingCashHero`（現金Hero）
- `PublicDemoAccountingAlertCard`（アイコン付きアラートカード）
- `PublicDemoAccountingForecastBar`（簡易forecastバー）

`public_demo_employee_visual.dart`/`public_demo_sales_visual.dart`と同じ
isolation方針を踏襲した独立ファイルであり、`lib/ui/theme.dart`（app-wide
`SesTheme`）・`lib/presentation/home/`配下・Employee/Salesタブ自身の
visualファイルは**1行も変更していない**（配色の値は独立に再定義 — 意図的な
重複、他タブへの波及を避けるため）。

今月必要な経営判断（Section 4, 夏季賞与カード）と月次結果（Section 5,
8月開始結果ナラティブ）も、既存のテキスト・キー・ボタン・handlerを
1つも変えずに`PublicDemoAccountingCard`でラップし直し、同じ視覚言語へ
統一した。

### 7. Year-Endの統合（P0 目標7）

`PublicDemoYearEndResultCard`自体（テキスト・キー・restart配線）は
無変更のまま、そのセクション見出しに`Icons.flag_outlined`を追加すること
（上記5）で、月次結果/Year-Endセクション全体を他4セクションと同じ
icon-led visual languageへ統合した。`PublicDemoYearEndResultCard`は既に
Card形状・見出し・区切り線を持つ完成度の高いwidgetであったため、内部構造
自体の変更は行っていない。

### 8. Reference-only要素の意図的な省略

- ひよりキャラクターのアバター付きアドバイスカード:
  Employee/Sales Visual Completeも同じ判断でHOME専用のNavigator演出を
  非HOMEタブへ導入しなかった前例に倣い、本タスクでも導入していない。
- 案件別の入金予定一覧（会社名・入金日ごとの内訳）: authoritative実装に
  その粒度のデータ（`PublicDemoAssignment`は入金サイト・入金予定日を
  個別に保持しない）が存在しないため実装していない。
- 月次推移の複数か月分の棒グラフ（Reference「月次の推移」）:
  `PublicDemoState`は複数月ぶんの過去売上/支出の時系列を保持していない
  （`latestMonthlyCashFlow`は直近1か月分のみ）ため、fake historyを
  作らないというSTRICTLY FORBIDDENの指示により実装していない。将来の
  資金予測（Section 3の新規バー）が、代わりに"今後"の推移を可視化する。
- 「条件を変更して再計算」ボタン等、Reference専用の対話的シミュレーション
  機能: 実装していない（STRICTLY FORBIDDEN: Reference-only recalculate
  button）。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | 5セクション全てのvisual再設計（Hero化、stat tile、アラートカード、forecastバー、icon-led見出し、カード統一） |
| `lib/ui/public_demo/public_demo_accounting_visual.dart`（新規） | 会計タブローカルのvisual building blocks |
| `test/ui/public_demo/public_demo_accounting_visual_complete_test.dart`（新規） | 新Visual構造のwidget test（27件） |
| `e2e/scripts/ses-accounting-visual-complete-screenshot.mjs`（新規） | Visual Verification screenshot撮影用の使い捨てPlaywrightスクリプト |
| `docs/reports/screenshots/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_{BEFORE,AFTER}_{360x800,390x844}.png`（新規） | Visual Verification screenshot |
| `docs/reports/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Result.md`（新規） | 本結果報告 |

`lib/presentation/home/`配下・`lib/ui/theme.dart`・`lib/game/`配下・
`public_demo_employee_visual.dart`・`public_demo_sales_visual.dart`・
`public_demo_home_presentation_components.dart`は**1バイトも変更していない**
（`git diff --stat`で確認済み、差分なし）。

## 使用したauthoritative fields

- `PublicDemoState.cash` / `.financialStatus` / `.pendingRevenue`（既存）
- `PublicDemoState.latestMonthlyCashFlow`
  （`PublicDemoMonthlyCashFlow.revenue` / `.totalOutflow` /
  `.netCashMovement` — いずれも既存フィールド/getter）
- `PublicDemoCashForecast.forecast` / `PublicDemoCashForecastMonth
  .closingCash` / `.isNegative`（既存、Issue #148 Phase 1A由来）
- `PublicDemoCashStatusPresentation.fromForecast`（既存の3状態判定）

新しい永続フィールド・新しいFinance/Balance計算・新しい閾値は一切
追加していない。

## Visual Referenceとの差分（Before/After）

Screenshot: `docs/reports/screenshots/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_{BEFORE,AFTER}_{360x800,390x844}.png`
（実ブラウザPlaywright screenshot、`?e2e=1#/public-demo-01`の4月初期状態で
撮影）

| 項目 | BEFORE (Phase 1) | AFTER (Visual Complete) | Reference |
|---|---|---|---|
| 現在の現金 | プレーンテキスト2行 | 緑の貯金箱アイコン + 大きな太字金額 + 前月比delta + 財務状態バッジ | 大きな金額 + アイコン + 前月比 |
| 今月の売上/支出 | Section 2にのみ存在 | Section 1のHero直下にもstat tileとして再掲 | サマリー画面の2 stat tile |
| セクション見出し | プレーンテキスト | 5つ全てアイコン付き | アイコン付き見出し |
| 将来の資金予測 | プレーンテキストのみ | アラートカード + 入金予定タイル + 月別バー | グラフ + アラート |
| 経営判断/月次結果カード | 既定のCard | 統一されたAccounting-localカード形状 | 統一カード |

4月初期状態（BEFORE/AFTER共通）はまだ月次決算が発生していないため、
前月比・売上/支出タイルは非表示（truthful — fake historyなし）。この状態
でも、Hero化・バッジ・icon-led見出し・アラートカード・forecastバー・
入金予定タイルは全て確認できる（AFTERスクリーンショット参照）。

## implemented P0/P1

- [x] P0-1: 現在現金をVisual Heroに
- [x] P0-2: real current cashを大きく表示
- [x] P0-3: authoritative statusをbadgeで明確化
- [x] P0-4: real sales/expense factsを視覚的なtilesへ整理
- [x] P0-5: 5 section headersをicon-ledへ統一
- [x] P0-6: Accounting-local card/spacing/radius/visual tokensを整備
- [x] P0-7: Year-Endを同じvisual languageへ統合
- [x] P1-1: PublicDemoCashForecast等の既存real valuesだけを使ったtruthfulな簡易forecastグラフ/progress visualization
- [x] P1-2: existing cash warning/adviceをalert cardとして明確化
- [x] P1-3: authoritativeなpendingRevenueを意味を変えずtruthfulに簡潔表示
- [x] P1-4: excessive scrollingを可能な範囲で削減（Hero化・タイル化で情報密度を上げ、追加スクロールを最小化）
- [x] 前月比: Fresh Auditに相当する実測確認の結果、`netCashMovement`という
      既存getterで安全に取得できることを確認できたため実装（推測・再計算・
      fake historyなし）

## intentionally omitted Reference-only elements

「Reference-only要素の意図的な省略」節を参照（ひよりアバターカード、
案件別入金予定内訳、複数月の過去推移棒グラフ、条件変更シミュレーション
ボタン）。

## tests / results

### flutter analyze

```
$ flutter analyze
No issues found!
```

（Flutter 3.44.8 / Dart 3.12.2、本セッションで`/home/user/flutter-sdk`に
stable channel 3.44.8タグをcloneして使用 — 本リポジトリのCIワークフローと
同一バージョン）

### 新規: `test/ui/public_demo/public_demo_accounting_visual_complete_test.dart`

```
$ flutter test test/ui/public_demo/public_demo_accounting_visual_complete_test.dart
→ 27/27 tests passed
```

内容: Hero（4月=前月比/tile非表示、5月=前月比+tile一致確認、資金不足時の
バッジtone確認）、forecast（安全時のpositiveアラート+バー数一致+入金予定
タイル確認、不足時のcautionアラート+マイナス月のisNegativeバー確認）、
icon-led見出し（7月/8月で5セクション全てにIcon存在確認）、3トーンの
バッジ色相互差異確認、HOME Freeze/他タブへの非流出確認、
360×800/390×844 × TextScaler 1.0/1.3/2.0での horizontal overflow 0
（4月/5月/7月/資金不足の各状態）。

### 既存回帰: Accounting UI Phase 1 / 空見出し防止

```
$ flutter test \
  test/ui/public_demo/public_demo_accounting_ui_phase1_test.dart \
  test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart
→ 44/44 tests passed（無修正のまま全緑）
```

### 必須回帰: `test/ui/public_demo` フル

```
$ flutter test test/ui/public_demo
→ 445/445 tests passed
```

（418件の既存テスト + 本タスクの新規27件。既存テストは無修正のまま全緑）

### 必須回帰: `test/game/public_demo` フル

```
$ flutter test test/game/public_demo
→ 520/520 tests passed
```

### full `flutter test`

時間内に実行完了した。

```
$ flutter test
→ 1753/1753 tests passed
```

（リポジトリ全体 — `test/ui/public_demo`/`test/game/public_demo`に加え、
`test/presentation/`・`test/domain/`・`test/widget_test.dart`等、本タスクが
一切変更していない領域を含む全テスト。無修正のまま全緑）

### git diff --check

```
$ git diff --check
（差分なし、exit 0 — whitespace error なし）
```

## screenshots

- `docs/reports/screenshots/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_AFTER_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_AFTER_390x844.png`

撮影スクリプト: `e2e/scripts/ses-accounting-visual-complete-screenshot.mjs`
（既存の`ses-sales-visual-complete-screenshot.mjs`と同じ static-server +
Playwright Chromium手法。`flutter build web --release
--no-web-resources-cdn`の実ビルドを4月初期状態で`?e2e=1#/public-demo-01`から
会計タブへ遷移して撮影）

4月初期状態は月次決算が未発生のため前月比/売上支出タイルこそ写らないが、
将来の資金予測セクションは実データ（アサイン0名・売上0のため現金が
毎月減少していく現実の軌跡）に基づくバー・アラートカードを表示している
— 追加のテスト専用fake production stateは作成していない。5月以降の
前月比/stat tile表示、資金不足時のcautionアラート、7月の意思決定カードの
populated状態は、月送り操作を伴う状態再現がE2Eスクリプトでは複雑になる
ため、widget testでのRect/tone/文字列検証のみ実施した（Employee/Sales
Visual Completeと同じスコープ判断）。

## VERIFY

- fake-data: 0（新規表示は全て既存authoritativeフィールドの読み取りのみ）
- HOME changes: 0（`git diff --stat -- lib/presentation/home/` 差分なし）
- Employee changes: 0（`git diff --stat -- lib/ui/public_demo/public_demo_employee_visual.dart` 差分なし、`_buildEmployeesTab`関連コード無変更）
- Sales changes: 0（`git diff --stat -- lib/ui/public_demo/public_demo_sales_visual.dart` 差分なし、`_buildSalesTab`関連コード無変更）
- gameplay-authority changes: 0（`git diff --stat -- lib/game/` 差分なし）
- horizontal overflow: 0（360×800/390×844 × TextScaler 1.0/1.3/2.0、新規テスト27件+既存回帰44件で確認）

## remaining visual gaps

- 月次推移の複数か月ぶん棒グラフ（Reference「月次の推移」相当）は
  authoritative履歴データの粒度不足のため未実装（上記「意図的な省略」参照）。
- 案件別入金予定一覧は同じ理由で未実装。
- populated状態（5月以降の前月比/tile、資金不足alertの実機screenshot）は
  widget testでのみ検証し、実ブラウザscreenshotは4月初期状態のみ取得した。

## Visual Complete 判定

**PASS**

判定根拠: Canonical Reference の主要な視覚要素（現金Hero化、色分けされた
財務状態バッジ、アイコン付きstat tile、統一カード形状、icon-led
セクション見出し、アラートカード、簡易forecastバー）を、既存の情報階層
（現在の資金状態 → 今月の収支 → 将来の資金予測・リスク → 今月必要な経営判断 →
月次結果/Year-End）・eligibility・save/schema・HOME・Domain・Finance/Balance
計算を一切変更せずに反映した。fake data 0 / HOME変更 0 / Employee変更 0 /
Sales変更 0 / gameplay authority変更 0 / horizontal overflow 0 を確認済み。
既存回帰テスト（Accounting UI Phase 1 + 空見出し防止: 44件、
`test/ui/public_demo`フル: 445件、`test/game/public_demo`フル: 520件、
リポジトリ全体`flutter test`: 1753件）は全てgreen、無修正のまま通過。
新規visual構造のwidget test（27件）もgreen。`flutter analyze`/
`git diff --check`ともにクリーン。残るギャップ（上記「remaining visual
gaps」）はいずれもSSOTの禁止事項（fake data追加、fake history追加、
Reference-only機能の新規実装）を回避するために意図的に見送った項目であり、
Visual Complete の PASS 判定を妨げるものではないと判断した。
