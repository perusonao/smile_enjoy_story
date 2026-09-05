# SES Public Demo HOME「One-Screen Final Fit」実装結果

## 概要

Public Demo HOME の初期4月画面を、360×800 / 390×844 の両方で「縦スクロール不要の1画面」に完全に収めた。HOME Final Polish で確定した情報階層・機能・文言（KPI 4+3、ひより primary CTA 1個、Quick Access なし、「他の行動を確認する」なし、「スキルシート」表記、月次処理、社員の様子、今月の重要タスク、Bottom Navigation、既存画像アセット、既存の遷移/操作/状態）は一切変更していない。変更したのは各セクション間の余白・カード内パディングのみ（純粋なレイアウト調整）。

## BASE

- **BASE SHA**: `e0172ee7bf0e39cfa9d297c1f56452ca4b18cbee`（`origin/main`、"Merge pull request #180 from perusonao/claude/ses-home-final-polish-3odl0v"）
- 作業ブランチ: `claude/ses-home-one-screen-fit-9w0app`（origin/main から作り直し。既存ブランチには未マージの独自コミットがなかったため `git checkout -B` でリセットして開始）

## Phase 1: READ-ONLY 実測（修正前 / Before）

Flutter widget test（`tester.view.physicalSize` で実サイズを設定し、`tester.getRect` / `ScrollableState.position` で実測）で、`PublicDemo01PlaceholderScreen` の初期状態（4月開始直後、セーブなし）を測定した。TextScaler 1.0。

### 360×800

| 項目 | 実測値 |
|---|---|
| Scaffold全体 | 800px |
| AppBar | 56px（top 0–56） |
| SafeArea（widget test既定、実機の状態バー/ホームインジケータ相当は含まず。既存の全レイアウト予算テスト（`public_demo_01_home_consolidation_test.dart` 等）と同じ前提） | 0px（widget test既定） |
| Bottom Navigation（`NavigationBar`） | 80px（top 720–800） |
| ListView（実効viewport） | top 56 / bottom 720 → **664px** |
| 月表示（`MonthHeaderBar`、定数） | 36px |
| KPI（`home-kpi-compact`） | top 98 / bottom 222 → 124px |
| ひよりカード（`home-navigator`） | top 224 / bottom 399 → 175px |
| 月次処理（`public-demo-monthly-primary-cta-card`） | top 405 / bottom 509 → 104px |
| 社員の様子（`home-office-stage`） | top 515 / bottom 600 → 85px |
| 今月の重要タスク（`public-demo-important-tasks`） | top 606 / bottom 779 → 173px |
| section間gap/padding合計（ListView top padding 4 + 月表示-KPI 2 + KPI-ひより 2 + ひより-月次処理 6 + 月次処理-社員 6 + 社員-タスク 6 + ListView bottom padding 16） | 42px |
| HOME content 実効高さ（ListView content extent） | 739px（= viewport 664 + `maxScrollExtent` 75） |
| **overflow（`maxScrollExtent`）** | **+75px（要スクロール）** |

### 390×844

| 項目 | 実測値 |
|---|---|
| AppBar | 56px |
| Bottom Navigation | 80px |
| ListView（実効viewport） | top 56 / bottom 764 → **708px** |
| 月表示 | 36px |
| KPI | 124px |
| ひよりカード | 178px |
| 月次処理 | 104px |
| 社員の様子（compactWidthThreshold=375のため normal レイアウト） | 95px |
| 今月の重要タスク | 173px |
| HOME content 実効高さ | 752px（708 + 44） |
| **overflow（`maxScrollExtent`）** | **+44px（要スクロール）** |

いずれも `PublicDemoCashShortageCard`（初期状態では `SizedBox.shrink()`）と `_bankruptcyTerminalCard`（初期状態では非表示）は高さ0。

## Phase 2: 高さ予算

360×800 で Bottom Navigation（80px）を除いた利用可能領域は AppBar 下 **664px**。この中に月表示～今月の重要タスクの5セクション＋区切り余白を収める必要がある。削減優先順位（不要な外側余白 → section間gap → 装飾余白 → 補助説明 → 画像サイズ → 主要コンテンツ）に従い、**主要コンテンツ（KPI数値・社員状態・月次処理ボタン・ひよりCTA本文）と48px以上のタップ領域には一切手を付けず**、以下の非コンテンツ要素のみを削減した。

## Phase 3: 実装（変更内容）

| 対象 | Before | After | 削減 | 分類 |
|---|---|---|---|---|
| HOMEタブ ListView padding (top/bottom) | `4 / 16` | `2 / 0` | -18px | ①外側余白 |
| ひより→月次処理 gap | `6` | `3` | -3px | ②section間gap |
| 月次処理→社員の様子 gap | `6` | `3` | -3px | ②section間gap |
| 社員の様子→重要タスク gap | `6` | `3` | -3px | ②section間gap |
| 月表示→KPI gap | `2` | `1` | -1px | ②section間gap |
| KPI→ひよりカード gap | `2` | `1` | -1px | ②section間gap |
| 月次処理カード 内側パディング(縦) | `8/8` | `4/4` | -8px | ③装飾余白 |
| 月次処理カード 説明文→ボタン gap | `6` | `3` | -3px | ③装飾余白 |
| 今月の重要タスクカード 外側パディング | `12` | `6` | -12px | ③装飾余白 |
| 今月の重要タスクカード タイトル→本文 gap | `8` | `4` | -4px | ③装飾余白 |
| 重要タスク各行 縦パディング | `6` | `1` | -20px（2行×上下） | ③装飾余白 |
| ひよりカード内 textGap（3箇所） | `1` | `0` | -3px | ③装飾余白 |
| 社員の様子カード 内側パディング(縦)/タイトルgap | `2/2/1` | `1/1/0` | -3px | ③装飾余白 |

**KPI数値・社員名/状態・月次処理ボタン・ひよりCTA本文・重要タスクの文言・各タップ領域（48px以上）は変更なし。** 画像サイズ（ひより肖像・社員の様子シーン）・主要コンテンツ（KPI 4+3構成、ひよりカードの文言/CTA、月次処理文言、社員の様子の情報、重要タスクの項目）は一切削減していない（Phase 2の優先順位どおり、①〜③の非コンテンツ要素のみで目標を達成できたため④⑤⑥には手を付けていない）。

## Phase 3: 実測（修正後 / After）

TextScaler 1.0。

### 360×800

| 項目 | 実測値 |
|---|---|
| KPI | 124px（変更なし） |
| ひよりカード | 171px |
| 月次処理 | 93px |
| 社員の様子 | 82px |
| 今月の重要タスク | 137px |
| ListView（実効viewport） | 664px（変更なし） |
| HOME content 実効高さ | 664px |
| **overflow（`maxScrollExtent`）** | **0px** |
| 今月の重要タスク bottom と viewport bottom の差（余裕） | **8px（余裕あり、はみ出し0）** |

### 390×844

| 項目 | 実測値 |
|---|---|
| ひよりカード | 174px |
| 月次処理 | 93px |
| 社員の様子 | 92px |
| 今月の重要タスク | 137px |
| ListView（実効viewport） | 708px（変更なし） |
| HOME content 実効高さ | 669px |
| **overflow（`maxScrollExtent`）** | **0px** |
| 余裕 | **39px** |

## 検証結果

- **360×800 / TextScaler 1.0**: `maxScrollExtent == 0`。今月の重要タスクの最下部（タイトル含む）まで全セクションが viewport 内に収まり、Bottom Navigation との重なりなし。初期4月HOMEは**縦スクロール不要**。
- **390×844 / TextScaler 1.0**: 同上、`maxScrollExtent == 0`、余裕39px（360×800より広い余白を維持）。
- **TextScaler 1.3 / 2.0**（360×800・390×844の両方）: `tester.takeException()` が `null`（RenderFlex/RenderBoxのoverflow例外なし）。全セクションが画面幅内（横overflow 0）。今月の重要タスクの各CTAアイコンボタンは 48×48px 以上を維持。月次処理ボタンは44px以上（既存の `minimumSize` 契約どおり）を維持。このスケールでは仕様どおりスクロールが発生してよい（情報の切り捨てをしない設計を維持）。
- 横overflow: 0（全ターゲット・全TextScalerで確認）。
- Bottom Navigation との重複: 0（`今月の重要タスク bottom <= Bottom Nav top` を明示的にassert）。
- tappable control: 全て48px以上を維持（重要タスクCTA、月次処理ボタン、ひよりCTAボタン）。

## テスト

- `flutter analyze`: **No issues found!**
- HOME focused widget tests: 新規 `test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`（9 tests, 全PASS）で「スクロール不要」を数値検証（`ScrollableState.position.maxScrollExtent == 0` を360×800/390×844それぞれでassert）。
- 既存HOME関連スイート（regressionチェック）: `test/presentation/home/`、`public_demo_01_home_consolidation_test.dart`、`public_demo_01_home_final_density_test.dart`、`public_demo_01_home_ui_3c_density_test.dart`、`public_demo_01_home_office_stage_test.dart`、`public_demo_01_home_navigator_test.dart`、`public_demo_01_home_recommended_action_test.dart`、`public_demo_01_issue_124_screen_verification_test.dart`、`public_demo_home_presentation_components_test.dart`、`public_demo_01_home3_integration_test.dart` — **全333 tests PASS**（既存の情報階層・機能・文言のassertionに影響なし）。
- E2E: 本フェーズはFlutterレイアウト（padding/gap）のみの変更で、DOM構造・遷移・状態管理には触れていないため、widget testでの数値検証（上記）で十分と判断し、フルE2E（Flutter web build + Playwright）は実行していない。
- PR前の `flutter test` フル実行: 実行済み（結果は本レポート末尾/PRに記載）。

## 変更ファイル（changed files）

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`（ListView padding、section間gap）
- `lib/ui/public_demo/public_demo_home_dashboard_section.dart`（月表示/KPI/ひより間の内部gap）
- `lib/ui/public_demo/public_demo_home_presentation_components.dart`（月次処理カード・重要タスクカードの内側パディング/gap）
- `lib/presentation/home/widgets/home_navigator_section.dart`（`HomeNavigatorMetrics.textGap`）
- `lib/presentation/home/widgets/home_office_stage_section.dart`（`HomeOfficeStageMetrics` カードパディング/タイトルgap）
- `test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`（新規、数値検証テスト）

## Production / Domain / Save / Balance 変更有無

**なし。** 今回の変更は上記5ファイルのうち4ファイルがすべて `lib/ui` / `lib/presentation/home/widgets` 配下の**プレゼンテーション層のパディング・SizedBoxの数値のみ**の変更であり、以下は一切変更していない：

- Domain（`lib/game/**` のロジック・モデル）
- Save（`public_demo_save_service.dart` / `public_demo_save_codec.dart`）
- Balance（賃金・固定費・売上・現金計算式など）
- Finance（`public_demo_financial_status.dart` 等の判定ロジック）
- Month transition（`public_demo_monthly_close.dart` 等）
- Sales/Employeeロジック（`task_engine.dart` 等）
- Employee UI Phase A
- Active Project Visibility
- ワークフロー状態遷移
- 新規架空データの追加

すべてのKey・文言・ボタンの `onPressed` 束縛・情報階層はHOME Final Polish時点から変更していない。

## 結果

| 項目 | Before | After |
|---|---|---|
| 360×800 overflow | +75px | **0px**（余裕+8px） |
| 390×844 overflow | +44px | **0px**（余裕+39px） |

初期4月のPublic Demo HOMEは、360×800・390×844の両方で縦スクロール不要の1画面に収まることを、目視ではなくwidget testの数値（`maxScrollExtent`・各セクションの`Rect`）で確認した。
