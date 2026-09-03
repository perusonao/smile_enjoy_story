# SES HOME-COMPACT-1B.4 — Public Demo HOME Visual Polish — Result Report

## 概要

Issue #148 Phase 1B.3 で月・KPI・ひよりの主行動・月次CTAは初期表示へ移ったが、実画面
（360×800 / 390×844）は「経営ダッシュボード＋ゲームの案内役」という完成イメージと
まだ差があった。本フェーズは **Public Demo 専用 HOME の視覚表現のみ** を対象に、
`PublicDemo01PlaceholderScreen` と既存 HOME presentation/widget 層を最小変更して
その差を解消した。

- **Base SHA**: `eb275aeb0ca6156d29d171b70f33ef19d0740c16` (`origin/main`。作業開始前に
  `git fetch origin` で確認済み。指定 SHA と一致)
- **Head SHA**: `1390fdcf81cce6762203fb53f06735f5c4fb3e2f`（初回実装 `04e9d92` +
  FIX1 `1390fdc`。下記「FIX1」節を参照）
- **Branch**: `claude/home-compact-1b4-visual-polish-qrn9ki`
- **PR**: https://github.com/perusonao/smile_enjoy_story/pull/160

## FIX1（追記）: 実資金不足時の社員概要初期可視化

初回実装（`04e9d92`）では、実資金不足状態（`financialStatus == cashShortage`）
のときだけ既存の `PublicDemoCashShortageCard` が画面最上部に表示され、その
カード単体が360×800で約245ptを占めるため、社員概要（`HomeOfficeStageSection`）
が初期表示外になっていた（下記「初回実装時点の既知の制限」参照）。

追加のPRコメント依頼（PR #160）を受け、`PublicDemoCashShortageCard` **自体の
表示密度のみ**を圧縮し、実資金不足時だけ `HomeNavigatorSection` 側の重複説明も
省略することで、実資金不足状態でも社員概要が初期表示に収まるようにした
（コミット `1390fdc`）。

### 変更内容（FIX1）

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_cash_shortage_card.dart` | 3本の根拠数値行（現在の現預金／不足額／次回入金予定）を、縦積みの3行からKPIコンパクトタイルと同じ「ラベル上・値下・FittedBoxで縮小」形式の横並び3タイルへ再設計。ラベル・値は元のまま個別の`Text`ウィジェットとして保持しているため、既存の`find.text('現在の現預金')`等の個別assertionは無変更で通過する。2つの説明文を1つの段落へ統合（両方の必須部分文字列は維持）。padding/gap/フォントサイズを圧縮。360×800で **約245pt → 約123pt**。警告文言・根拠数値・CTA・カードの優先順位（`MonthHeaderBar`/`PublicDemoHomeDashboardSection`より上、Keyも同じ）は無変更。 |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_isActualCashShortage`（`s.financialStatus == PublicDemoFinancialStatus.cashShortage`、`PublicDemoCashShortageCard`自身と同じ authoritative なフィールドを参照）を追加。この状態のときだけ: (1) ひよりカードの補助CTA「他の行動を確認する」を非表示（`PublicDemoCashShortageCard`が既に同じ収支詳細への導線を提供しているため）、(2) 「ひよりからのアドバイス」説明バブルを非表示（`PublicDemoCashShortageCard`の詳細説明と重複するジェネリックな一般論のため）。主メッセージ・見出し・CTA・その dispatch 先は無変更。通常・予防的資金注意状態はこの2つの省略の対象外（`_compactedForShortage`は`_isActualCashShortage`が`false`のとき何もしない）。 |

### FIX1のテスト

`test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart` に
新しいグループを追加。`public_demo_01_bankruptcy_ux_test.dart`の
`_driveToNovemberBankruptcy`と同じ実際のUI操作列（4月のSkillSheet確認〜受注、
5〜7月の月次決算、8〜2月の通常決算）を2月決算の直後（3月開始、
`financialStatus == cashShortage`、`isCloseBlocked == false`）で止め、
360×800／390×844の両方で以下を検証:

- `public-demo-cash-shortage-card`（既存の優先導線）が初期ビューポート内
- 月表示「1年目 3月」が初期ビューポート内
- `home-recommended-action-cta`（内容は「資金不足を確認」、既存の
  `cashShortageResponse` candidate）が初期ビューポート内
- `public-demo-monthly-primary-cta` が初期ビューポート内、かつ画面内に1つだけ
- `home-office-stage` と `home-office-stage-headcount-summary`（社員概要）が
  初期ビューポート内
- `home-navigator-secondary-cta` が存在しない（重複CTAを追加していないことの
  裏付け）

既存の `public_demo_cash_shortage_card_test.dart`（根拠数値の個別assertion含む）、
`public_demo_01_home_cash_forecast_advice_test.dart`（予防的caution状態の
既存導線）、`public_demo_01_bankruptcy_ux_test.dart`（実資金不足〜倒産の遷移・
Recommended Actionダイアログ）はすべて無変更のまま green。

## 変更方針・スコープ

- GameState、月次ルール、財務、保存schema、営業成功率、`PublicDemoCashForecast`、
  `PublicDemoCashStatusPresentation`、`PublicDemoCashAdviceSelector`、
  SkillSheet／営業の業務ルールは**変更していない**。
- KPIの値・意味・計算式は変更していない（表示色・アイコン背景のみ変更）。
- ListView全体の構造（単一Columnラップの回避策含む）は維持し、各既存Widgetの
  表示密度（padding/gap/フォントサイズ）のみ調整した。
- 既存の資金注意（予防的キャッシュフォーキャスト由来のひより案内）は、ひより
  領域の優先表示として維持した。新しい大型資金警告カードは追加していない。
- 月次進行CTAは画面内に1つのまま（`PublicDemoMonthlyPrimaryCtaSection` は元々
  唯一の呼び出し箇所であり、今回もその一箇所のみ）。

## 変更ファイル

### 実装 (`lib/`)

| ファイル | 変更内容 |
|---|---|
| `lib/presentation/home/widgets/kpi_section.dart` | 現金/参画/待機/営業残（行A）に色分けアイコンバッジ＋薄い背景トーンを追加する `_KpiEmphasis` を導入。行B（社員/売上/入金予定）は従来どおり中立配色。値・ラベル・アイコン・Keyは無変更。 |
| `lib/presentation/home/widgets/home_navigator_section.dart` | ひよりの肖像サイズを 44/48pt → 60/68pt に拡大（テキスト列の高さが既にカード全体の高さを決めていたため追加コスト無し）。「ひよりからのアドバイス」バブルの余白を縮小し、説明文を2行キャップ（`maxLines: 2` + ellipsis）。主メッセージ（常時表示・無制限）は無変更。 |
| `lib/presentation/home/widgets/month_header_bar.dart` | 月ヘッダーの高さを48pt→36ptへ圧縮（表示文言は無変更）。 |
| `lib/ui/public_demo/public_demo_home_presentation_components.dart` | `PublicDemoMonthlyPrimaryCtaSection` を「今月の主要行動」大型タイトルカードから、アンバー系アクセントの薄型バー（"月次処理" アイコンラベル＋説明1〜2行＋既存ボタン）へ再設計。ひよりのCTA（青）と視覚的に区別。キー・ラベル・enabled契約は無変更。 |
| `lib/presentation/home/models/home_office_stage_display.dart` | `HomeOfficeStageDisplay` に任意の `employeeCount`/`waitingCount`（両方nullなら非表示）を追加。KPIと同じ authoritative な数値をそのまま渡すのみで、新しい計算は行わない。 |
| `lib/presentation/home/widgets/home_office_stage_section.dart` | 社員写真の右上に「社員N名・待機N名」の集計チップをオーバーレイ表示（既存シーンの上に重ねるのみで、カードの高さ予算は変えていない）。`compactSceneHeight`/各種paddingも圧縮。 |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_officeStageDisplay` に `employeeCount`/`waitingCount` を配線。月次CTAとオフィスステージ間の余白を圧縮。コメント更新。 |
| `lib/ui/public_demo/public_demo_home_dashboard_section.dart` | セクション間の余白（gap）を圧縮。 |

### テスト (`test/`) — 意図的な仕様変更に追従

| ファイル | 変更理由 |
|---|---|
| `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart` | 受け入れ条件1（月・KPI・ひよりの主CTA・月次CTA・**社員概要**が初期表示でスクロールなしに見える）に合わせ、`home-office-stage` と集計チップ（`home-office-stage-headcount-summary`）も初期ビューポート内であることを検証する assertion を追加。 |
| `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` | 実画面が新しい集計チップ（"社員N名・待機N名"）を表示するようになったため、「社員の様子は参画/待機の内訳を主張しない」テストを「社員個別の参画/待機は依然として主張しない（集計値のみKPIと同じ authority から表示）」に更新。 |
| `test/ui/public_demo/public_demo_01_home3_integration_test.dart` | 月次CTAカードの旧タイトル文言「今月の主要行動」が新デザインの「月次処理」アイコンラベルに置き換わったことに追従。 |

いずれも「無関係なリファクタリング」ではなく、今回の視覚仕様変更が既存テストの
アサーションと直接衝突した箇所のみを、変更後の意図どおりに更新したもの。

## 初期表示の構成（変更後）

`PublicDemo01PlaceholderScreen` の `ListView` 内、上から:

1. （資金不足/倒産時のみ）`PublicDemoCashShortageCard`（FIX1で表示密度を圧縮） / 倒産カード — 優先順位は既存のまま、最優先で表示
2. `MonthHeaderBar`（月表示、36pt）
3. `KpiSection.compact`（現金/参画/待機/営業残 を色分け表示 + 社員/売上/入金予定）
4. `HomeNavigatorSection`（ひよりの拡大ポートレート＋主CTA＋補助CTA＋圧縮したアドバイスバブル）
5. `PublicDemoMonthlyPrimaryCtaSection`（薄型アンバーバー、月次CTA唯一のインスタンス）
6. `HomeOfficeStageSection`（社員写真＋"社員N名・待機N名" 集計チップ）
7. （初期表示の外）今月の重要タスク／クイックアクセス／収支詳細／個別営業操作 — 既存のスクロール/クイックアクセス/ボトムナビ導線のまま到達可能

## 完成イメージとの差分解消

| 完成イメージの要件 | 対応 |
|---|---|
| A. KPIの優先度が分かるコンパクトな帯 | 行Aを色分け（現金=ブルー、参画=グリーン、待機=オレンジ、営業残=シアン）。360pxで横はみ出しなし（既存レイアウト構造を維持） |
| B. ひよりが案内役として認識できるサイズ・配置 | ポートレート 44/48→60/68pt。既存の優先順位・文言契約（通常/caution/shortage）は無変更 |
| C. 月次進行CTAがひよりの案内と視覚的に連続 | 薄型バーへ再設計し、ひようのカード直後（gap=2px）に配置。ひよりのCTA（青）と色を分離し混同を防止 |
| D. 社員の様子が初期表示で見える | オフィス写真＋集計チップを圧縮済みレイアウトの中で初期ビューポート内に収めた（通常・予防的caution・実資金不足の全3状態で確認済み。実資金不足時はFIX1で`PublicDemoCashShortageCard`自体の表示密度圧縮も併せて実施） |
| E. 重要タスク・クイックアクセス・支出予定・個別操作は初期表示外 | 変更なし（元々初期表示外） |

## 360px / 390pxの結果

`test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`（通常状態、
"gameplay is untouched" を含む全ケース）で自動検証。加えて実際に Chromium
(Playwright, ヘッドレス, ソフトウェアレンダリング) で3状態×2解像度=6パターンを
確認した。

| 状態 | 360×800 | 390×844 |
|---|---|---|
| 通常 (4月開始) | ✅ 月・KPI・ひよりの主CTA・月次CTA・社員概要すべて初期表示で確認可能 | ✅ 同左 |
| 予防的資金注意 (10月、`financialStatus` はまだ `normal`、フォーキャストが将来の資金ショートを検知) | ✅ 同上。ひよりのカードが `PublicDemoCashForecast`/`CashAdviceSelector` 由来の警告CTAへ切り替わり、月次CTA・社員概要とも初期表示内 | ✅ 同左 |
| 実資金不足 (2月決算直後、`financialStatus == cashShortage`、`isCloseBlocked == false`) | ✅ **FIX1で解消**。資金不足の優先導線（`PublicDemoCashShortageCard`）・月・KPI・ひよりの主CTA「資金不足を確認」・月次CTA・社員概要（"社員2名・待機1名"集計含む）すべて初期表示で確認可能 | ✅ 同左 |

全6パターン（3状態×2解像度）とも受け入れ条件1（5要素すべての初期可視性）・
条件3（優先導線・CTA重複防止の維持）・条件4（月次CTAは1つだけ）を満たす。

### 初回実装時点の既知の制限（FIX1で解消済み）

初回実装（`04e9d92`、PR #160オープン時点）では、実際の資金不足状態において
既存の `PublicDemoCashShortageCard`（当時は変更対象外としていた既存の大型
カード）が画面最上部を占め、月・KPI・ひよりの主CTA・月次CTAまでは初期表示内に
収まるが社員概要はスクロールしないと見えない、という制限があった。この制限は
上記「FIX1」節の変更により解消済み。

## スクリーンショット

`docs/reports/screenshots/` に保存（Chromium, Playwright, ヘッドレス）:

- `ses-home-1b4-360-normal.png` / `ses-home-1b4-390-normal.png` — 通常状態（4月開始）
- `ses-home-1b4-360-caution.png` / `ses-home-1b4-390-caution.png` — 予防的資金注意（10月、フォーキャスト由来の caution）
- `ses-home-1b4-360-shortage.png` / `ses-home-1b4-390-shortage.png` — 実資金不足（2月決算直後、`financialStatus == cashShortage`）

caution/shortage の2状態は、既存のwidgetテストが使うのと同一の
`PublicDemoAggregate` ドメインコマンド列（`playApril` 相当 → `closeApril` →
`closeMay` → …）で実際に到達した状態を、既存の `PublicDemoSaveCodec`
（変更なし）でエンコードし、ブラウザの `localStorage` へ投入して起動時に
`PublicDemoSaveService.load()` が読み込む形で再現した（UIタップの多段トレース
をこのサンドボックス環境のソフトウェアレンダリングで毎回踏むと非常に低速な
ため）。フォーマット・スキーマは実装のものをそのまま使用しており、
fabricatedなデータではない。

## テスト結果

実行環境: Flutter 3.44.8 (stable) をこのセッションに新規インストール（リポジトリの
CI ワークフロー `.github/workflows/public-demo-validation.yml` が固定しているバージョンに
合わせた）。

- `dart format`（変更対象ファイルのみ）: 適用済み
- `flutter analyze`: No issues found
- `flutter test test/ui/public_demo/`: 228 tests, all pass（FIX1で2件追加）
- `flutter test test/presentation/`: 200 tests, all pass
- `flutter test test/game/public_demo/`: 500 tests, all pass
- 既存 SkillSheet flow test (`test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`): 2 tests, all pass（開く→戻る→確認→営業開始のフローは無変更）
- 既存 `public_demo_cash_shortage_card_test.dart` / `public_demo_01_home_cash_forecast_advice_test.dart` / `public_demo_01_bankruptcy_ux_test.dart`: all pass（優先導線・CTA重複防止の既存契約を無変更で確認）
- 上記3ディレクトリ合計: **928 tests, all pass**（初回実装時926件 + FIX1で2件追加）

## 未実行の検証

- `flutter build web` は実行しGitHub PagesプレビューやE2Eのフル一式（`e2e/` の
  Playwright回帰スイート、`npm run test`）は実行していない（本タスクの検証範囲外。
  スクリーンショット取得のためのビルドとサーブのみ実施）。
- 実機・実ブラウザ（iOS Safari / 実Android Chrome）での確認は行っていない
  （このリモート環境ではソフトウェアレンダリングのヘッドレスChromiumのみ）。
- テキストスケール 1.15〜2.0 での初期表示ノースクロール要件は、既存テスト
  （`test/presentation/home/home_navigator_section_test.dart` の compactCeiling
  テストなど）で個々のコンポーネントのオーバーフロー safety は検証しているが、
  「5要素すべてがテキスト拡大時も初期表示に収まる」という強い主張までは
  していない（元々の受け入れ条件・既存テスト設計もデフォルトscale 1.0を対象と
  しており、本フェーズもそれを踏襲）。

## PR / merge readiness

- ブランチ `claude/home-compact-1b4-visual-polish-qrn9ki` は `origin/main`
  (`eb275ae`) から分岐し、コミット `04e9d92`（初回実装）→ `288d43a`／`2d68ee4`
  （レポート・スクリーンショット）→ `1390fdc`（FIX1: 実資金不足時の社員概要
  初期可視化）をプッシュ済み。最終HEAD: `1390fdcf81cce6762203fb53f06735f5c4fb3e2f`。
- PR: https://github.com/perusonao/smile_enjoy_story/pull/160（オープンのまま。
  マージは実施していない）
- **merge readiness**: 受け入れ条件1〜5すべて、通常・予防的資金注意・実資金不足の
  全3状態×360px/390pxの全6パターンで達成済み。`flutter analyze`問題なし、
  対象テストディレクトリ合計928件すべてグリーン、既存SkillSheetフロー・
  資金不足優先導線・CTA重複防止の既存契約は無変更で確認済み。マージ判断は
  リポジトリオーナーに委ねる。
