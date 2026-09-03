# SES HOME-COMPACT-1B.4 — Public Demo HOME Visual Polish — Result Report

## 概要

Issue #148 Phase 1B.3 で月・KPI・ひよりの主行動・月次CTAは初期表示へ移ったが、実画面
（360×800 / 390×844）は「経営ダッシュボード＋ゲームの案内役」という完成イメージと
まだ差があった。本フェーズは **Public Demo 専用 HOME の視覚表現のみ** を対象に、
`PublicDemo01PlaceholderScreen` と既存 HOME presentation/widget 層を最小変更して
その差を解消した。

- **Base SHA**: `eb275aeb0ca6156d29d171b70f33ef19d0740c16` (`origin/main`。作業開始前に
  `git fetch origin` で確認済み。指定 SHA と一致)
- **Head SHA**: `04e9d92e7433ba3d4c41c8ec05a656f5ef74df53`
- **Branch**: `claude/home-compact-1b4-visual-polish-qrn9ki`
- **PR**: (このレポート内で後述のPR URLを参照)

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

1. （資金不足/倒産時のみ）`PublicDemoCashShortageCard` / 倒産カード — 既存のまま、最優先で表示
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
| D. 社員の様子が初期表示で見える | オフィス写真＋集計チップを圧縮済みレイアウトの中で初期ビューポート内に収めた（通常・予防的caution状態で確認済み。下記「未達成事項」参照） |
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
| 実資金不足 (2月決算直後、`financialStatus == cashShortage`、`isCloseBlocked == false`) | ⚠️ 下記参照 | ⚠️ 下記参照 |

### 未達成事項（実資金不足状態）

実際の資金不足状態では、既存の `PublicDemoCashShortageCard`（本フェーズの変更対象
外・維持指示のある既存の大型カード）が画面最上部に表示され、月・KPI・ひよりの
主CTA・月次CTAまでは初期表示内に収まるが、**社員概要はスクロールしないと見えない**。
これは以下の理由により本フェーズでは意図的に対応していない:

- `PublicDemoCashShortageCard` はタスク指示で明示的に保護されたクラスではないが、
  実装方針セクションに「既存の資金注意は、ひより領域の優先表示として維持する。
  新しい大型資金警告カードは追加しない」とあり、これは *予防的* caution（ひより
  領域内のアドバイス）についての指示であって、*実資金不足* 時の独立した既存
  警告カードを圧縮・再配置する指示ではない。
- このカードを圧縮するには、その独自の警告コピー・レイアウトへ踏み込む必要が
  あり、「無関係なリファクタリングをしない」「最小変更」という方針と、
  実資金不足という緊急事態でこそ警告を画面の大部分に優先表示するという既存の
  意図的な設計（`PublicDemoCashShortageCard`, `PLAYTEST-BLOCKER-1A` 由来）に反する。
- 受け入れ条件3（「通常・予防的資金注意・実資金不足の各状態で、既存の優先導線と
  CTA重複防止が維持される」）は実資金不足状態でも確認済み（下記スクリーン
  ショット参照。ひよりのCTAは「資金不足を確認」一本のみ、月次CTAも1つのみ）。
  受け入れ条件1（5要素すべての初期可視性）は実資金不足状態では部分的（4/5、
  社員概要のみ未達）。

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

- `dart format`（変更対象ファイルのみ）: 適用済み（4ファイルに整形差分）
- `flutter analyze`: No issues found
- `flutter test test/ui/public_demo/`: 226 tests, all pass
- `flutter test test/presentation/`: 200 tests, all pass
- `flutter test test/game/public_demo/`: 500 tests, all pass
- 既存 SkillSheet flow test (`test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`): 2 tests, all pass（開く→戻る→確認→営業開始のフローは無変更）
- 上記3ディレクトリ合計: **926 tests, all pass**

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
  (`eb275ae`) から分岐し、コミット `04e9d92` を1件プッシュ済み。
- PR: (作成後にURLを追記)
- **merge readiness**: 上記テストはすべてグリーン。実資金不足状態での「社員概要も
  初期表示」は未達（前述の理由により本フェーズでは意図的に対象外）。マージ判断は
  リポジトリオーナーに委ねる。マージは実施していない。
