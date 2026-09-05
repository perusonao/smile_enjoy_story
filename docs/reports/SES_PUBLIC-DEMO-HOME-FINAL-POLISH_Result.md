# SES Public Demo HOME「Final Polish」— Result

STATUS: **Done — implemented, focused-tested, full `flutter test` green (except 2 pre-existing unrelated failures), not merged**

BASE: `origin/main` @ `321641da7710b960a7873b154579d776cd2ab3c3` (PR #179, SES HOME Final Density, merged)
HEAD: `09602d8` (branch `claude/ses-home-final-polish-3odl0v`)

## Changed files

```
docs/reports/SES_PUBLIC-DEMO-HOME-FINAL-POLISH_Result.md          | new
lib/game/public_demo/public_demo_month_guard.dart                 | doc comment only
lib/presentation/home/models/home_navigator_display.dart          | SkillSheet→スキルシート (C)
lib/presentation/home/models/home_recommended_action.dart         | SkillSheet→スキルシート (C)
lib/presentation/home/widgets/kpi_section.dart                    | KPI padding/gap (A)
lib/ui/public_demo/public_demo_01_placeholder_screen.dart          | 他の行動を確認する削除(B), Quick Access削除(D), SkillSheet→スキルシート(C), gap復元(I)
lib/ui/public_demo/public_demo_home_dashboard_section.dart         | 他の行動を確認する削除 (B)
lib/ui/public_demo/public_demo_home_presentation_components.dart   | Quick Access削除(D), 重要タスク/月次処理padding復元(E,G,I)
test/presentation/home/home_navigator_advice_adapter_test.dart     | スキルシート表記更新
test/presentation/home/home_navigator_section_test.dart            | スキルシート表記更新(fixture)
test/presentation/home/home_recommended_action_test.dart           | スキルシート表記更新
test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart        | Quick Access/secondary CTAテスト削除
test/ui/public_demo/public_demo_01_home3_integration_test.dart      | Quick Access関連削除
test/ui/public_demo/public_demo_01_home_consolidation_test.dart     | secondary CTA削除に伴うボタン数更新
test/ui/public_demo/public_demo_01_home_final_density_test.dart     | Final Polish受入基準へ全面更新
test/ui/public_demo/public_demo_01_home_navigator_test.dart         | スキルシート表記更新
test/ui/public_demo/public_demo_01_home_office_stage_test.dart      | Quick Access参照差替、ボタン数/表記更新
test/ui/public_demo/public_demo_01_home_recommended_action_test.dart| スキルシート表記更新
test/ui/public_demo/public_demo_01_home_runtime_read_test.dart      | secondary CTA削除に伴うボタン数更新
test/ui/public_demo/public_demo_01_month_guard_april_may_june_test.dart | スキルシート表記更新
test/ui/public_demo/public_demo_01_persistence_test.dart            | スキルシート表記更新
test/ui/public_demo/public_demo_home_presentation_components_test.dart | Quick Accessテスト削除
```

## 目的

完成イメージ（`S.E.S. Public Demo 0.1` HOME、佐倉ひよりナビゲーター付き）を
UIターゲットとして、既存のPublic Demo実装（データ・状態・操作・レスポンシブ
要件）を維持したまま、HOMEの情報階層・配置・視認性を仕上げる。

## 変更概要

| # | 内容 | 主なファイル |
|---|---|---|
| A | KPIレイアウトの padding/gap 統一・可読性復元 | `lib/presentation/home/widgets/kpi_section.dart` |
| B | ひよりカードの「他の行動を確認する」削除 | `lib/ui/public_demo/public_demo_home_dashboard_section.dart`, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` |
| C | プレイヤー向け「SkillSheet」→「スキルシート」表記統一（HOMEの実際の文言のみ） | `lib/presentation/home/models/home_recommended_action.dart`, `lib/presentation/home/models/home_navigator_display.dart`, `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` |
| D | Quick Access セクション削除 | `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`, `lib/ui/public_demo/public_demo_home_presentation_components.dart` |
| E | 月次処理CTAは維持・padding復元 | `lib/ui/public_demo/public_demo_home_presentation_components.dart` |
| F | 社員の様子は既存のまま維持（変更なし） | — |
| G | 今月の重要タスクのpadding復元、行間の実余白を復元 | `lib/ui/public_demo/public_demo_home_presentation_components.dart` |
| I | Quick Access / 他の行動を確認する 削除で空いた高さを可読性へ再配分 | 上記複数ファイル |

Domain / Save / Balance / Finance / Month transition / Recovery / Sales /
Employee / SkillSheet domain logic / Active Project Visibility / Employee UI
Phase A / #167 Late Game / Year-End仕様 / workflow は **一切変更していない**。

## A. KPI

`KpiSection.compact`（`lib/presentation/home/widgets/kpi_section.dart`）は
既存のまま「1段目4等分（現金/参画/待機/営業残）・2段目3等分（社員/売上/
入金予定）」の`Row`+`Expanded`構造だった。Final Density フェーズで
padding/gapを極限まで詰めていたため（カード全体`padding: 1`、行間`1`、
タイル内`vertical: 1`）文字が窮屈に見えていた。今回は構造・情報を変えず、
以下の余白のみ復元した：

- カード全体 padding: `1` → `8`
- 行間 (現金〜営業残 / 社員〜入金予定): `1` → `6`
- タイル内 vertical padding: `1` → `5`
- アイコンバッジ: `size 10/padding 2.5` → `size 11/padding 3`（視認性）
- アイコン-ラベル間 gap: `4` → `5`
- ラベル-値間 gap: `1` → `3`

情報（フィールド・ラベル・値・並び順）はすべて既存のまま。左右端・
カード間gap・radius・アイコン位置・ラベル位置・数値baselineは、
1段目/2段目とも共通の`_CompactKpiTile`が担っており、変更していない
（統一済みのまま）。360×800でも横overflowなし（既存の
`public_demo_01_home_ui_3c_density_test.dart` の overflow 回帰＋新規
Final Polish 回帰で確認）。

## B. ひよりカード

既存の情報階層（ひより → 役割 → 次にやること → 推奨行動 → Primary CTA →
ひよりからのアドバイス）はそのまま。今回削除したのは「他の行動を確認する」
の secondary CTA のみ：

- `PublicDemoHomeDashboardSection.onShowOtherActions`（フィールド自体）を削除
- `_effectiveAdvice` は `cashAdvice ?? _baseAdvice` を返すだけになり、
  secondary route を合成しなくなった
- `PublicDemo01PlaceholderScreen` の呼び出し側から
  `onShowOtherActions: _switchToEligibleSalesDestination` の引数を削除

`HomeNavigatorSection`（`lib/presentation/home/widgets/home_navigator_section.dart`）
自体の secondary-CTA描画コードは、他の呼び出し元（コンポーネントテスト）
が引き続き使う一般的な仕組みとして温存した（Public Demo からは二度と
`secondaryLabel`が渡されないので、実際には常に非表示になる）。

Primary CTAの遷移・操作（`_recommendedActionSlot`経由の既存bound
callback）は完全に維持。

## C. SkillSheet → スキルシート

**スコープ**: 「HOME Final Polish」のPRに限定するため、HOMEのひよりカード
自身が生成する文言（`home_recommended_action.dart`のctaLabel/headline、
`home_navigator_display.dart`のmessage/explanation、および
`public_demo_01_placeholder_screen.dart`の資金不足時アドバイス
`_cashForecastAdvice`のctaLabel/headline）だけを対象にした。

| 変更前 | 変更後 | 出現箇所 |
|---|---|---|
| `SkillSheetを確認` | `スキルシートを確認` | `HomeRecommendedActionKind.employeeSkillSheetReview.ctaLabel`, `_cashForecastAdvice`のctaLabel |
| `{name}のSkillSheetを確認` | `{name}のスキルシートを確認` | 同上 headline |
| `入社前SkillSheetへ` | `入社前スキルシートへ` | `HomeRecommendedActionKind.applicantBeginPreEntrySkillSheet.ctaLabel` |
| `{name}の入社前SkillSheetを確認` | `{name}の入社前スキルシートを確認` | 同上 headline |
| `SkillSheetの内容を確認しましょう。` | `スキルシートの内容を確認しましょう。` | `navigatorAdviceFor`のmessage |
| `SkillSheetは、経験やスキルを案件へ伝える…` | `スキルシートは、経験やスキルを案件へ伝える…` | 同上 explanation |

**意図的に変更しなかったもの**（class名/Widget名/enum/test identifier/
Domain・API内部名/ファイル名は変更禁止のルール、および他タブ（社員/営業）
の既存ボタン文言は今回のHOME限定スコープ外）:

- `HomeRecommendedActionKind.employeeSkillSheetReview` などのenum値名
- `PublicDemoSkillSheetSheet`, `PublicDemoSkillSheetBody`,
  `SkillSheetMetricRow`, `SkillSheetEmptyState` などのWidget/クラス名
- `SkillSheet`, `SkillSheetRisk` などのDomainモデル/API内部名
- 社員タブの既存ボタン「SkillSheet確認」「入社前SkillSheet」
  （`_buildEmployeesTab`内、HOMEには存在しない）
- 営業進捗ステッパー（`public_demo_sales_progress.dart`）のchip文言
- ファイル名（`public_demo_skill_sheet_*.dart`等）

既存テストのうち、上記の**HOME側の実文言**を英字表記のまま前提にしていた
ものは新しいプレイヤー向け表記へ更新した（詳細は「テスト」節）。社員/営業
タブの既存ボタン文言をアサートするテスト（多数）は今回無変更のため、
そのままで良い。

## D. Quick Access 削除

`PublicDemoQuickAccessSection` / `PublicDemoQuickAccessItem` /
`_QuickAccessButton`（`lib/ui/public_demo/public_demo_home_presentation_components.dart`）
と、HOME側の呼び出し（`_quickAccessItems`ゲッター、
`PublicDemoQuickAccessSection(items: _quickAccessItems)`の描画）を削除した。

Quick Access が持っていた4つの遷移先は、削除後も以下から到達可能：

| Quick Access 項目 | 削除後の到達経路 |
|---|---|
| 社員の様子 → 社員タブ | Bottom Navigation「社員」 |
| 収支・会計 → 会計タブ | Bottom Navigation「会計」、および「今月の重要タスク」の資金計画行 |
| 案件・営業 → 営業/社員タブ | Bottom Navigation「営業」、および「今月の重要タスク」の営業活動行 |
| 開発・テスト → 開発メニュー | AppBar左のハンバーガーメニュー（`public-demo-app-bar-menu`、既存・無変更） |

Bottom Navigation（ホーム/社員/営業/会計/メニュー）自体は一切変更していない。

## E. 月次処理

`PublicDemoMonthlyPrimaryCtaSection`は構造・ロジックとも既存のまま
（月表示・ボタン文言は`_monthlyPrimaryAction`から動的生成、既存の
Month Guard / Finance Guard / Recovery / 賞与 / 年末ロジックは無変更）。
Quick Access 削除で空いた高さの一部をカードのpaddingへ戻した：

- カードのvertical padding: `0` → `8`
- 「月次処理」ラベルと説明文の間: gapなし → `2`
- 説明文とボタンの間: `2` → `6`

## F. 社員の様子

`HomeOfficeStageSection` / `HomeOfficeStageMetrics`（`lib/presentation/home/widgets/home_office_stage_section.dart`）
は完全に無変更。既存の「社員N名・待機N名」ヘッドカウントサマリー
（`hasHeadcountSummary`）と最大4名までのポートレート表示をそのまま維持。
Employee UI Phase A や Active Project Visibility の内容は先取りしていない。

## G. 今月の重要タスク

`PublicDemoImportantTasksSection` / `_ImportantTaskRow`は構造・ロジックとも
既存のまま（`_importantTasks`が生成する最大3件、各行の遷移先は既存の
`homeImportantTaskHasEligibleAction` / `_switchToEligibleSalesDestination` /
`_switchTab`をそのまま使用— 推測で新しい遷移先は作っていない）。

可読性のために以下のpaddingを復元：

- 行の上下padding: なし → `vertical: 6`
- タイトル/カテゴリチップとfactの間: `1` → `3`
- カード全体のpadding: `3` → `12`
- タイトルと本文の間: `2` → `8`

各行のCTAは既存のまま `IconButton`（`minWidth/minHeight: 48`）+
`Semantics(label: item.ctaLabel)` — タップ領域48px以上、意味のわかる
labelを維持。

## H. 1画面要件（結果）

- **390×844**: 月ヘッダー / KPI / ひより（Primary CTA・アドバイス含む）/
  月次処理 / 社員の様子 / 今月の重要タスク が unscrolled `ListView`の
  viewport内で開始することを`public_demo_01_home_final_density_test.dart`
  で確認（「今月の重要タスク」というタイトル文字列自体が完全にviewport内、
  という厳しめの基準も維持）。
- **360×800**: 同じセクション順序を維持。KPI〜今月の重要タスクまで
  unscrolled viewport内で開始することを同テストで確認。
- Quick Access はHOMEに存在しない（新規テストで
  `find.text('クイックアクセス')`が`findsNothing`であることを確認）。
- 横スクロール: 0（360/390 × textScale 1.0/1.3/2.0 で`rect.left>=0` /
  `rect.right<=width`を確認、既存＋新規回帰）。
- critical text clipping: 0（`tester.takeException()`が`isNull`である
  ことを既存＋新規回帰で確認。テキストの省略は既存のFittedBox/ellipsis
  ルールのまま、今回の変更で新たな省略は追加していない）。
- Bottom Navigationとの重複: 0（`Scaffold.bottomNavigationBar`は
  スクロール本体の外にあり、既存のSafeArea/ListViewパディングのまま）。
- TextScaler: 1.3, 2.0 で既存＋新規回帰確認済み（詳細は「テスト」節）。

## I. Density の巻き戻し

Final Densityフェーズが圧縮していたpadding/gapのうち、Quick Access削除
（§D）とひよりカードの secondary CTA 削除（§B）で空いた高さを、以下へ
再配分した（機械的な巻き戻しではなく、可読性が最も効くカード内 padding /
セクション間gap を選んで戻した）:

- KPI（§A）
- 今月の重要タスク（§G）
- 月次処理（§E）
- HOME本体のセクション間gap（ひより→月次処理→社員の様子→重要タスク、
  各`SizedBox`高さ `1`→`6`、`2`→`6`）

ひよりカード自体の内部padding（`HomeNavigatorMetrics`）と社員の様子
（`HomeOfficeStageMetrics`）は、既存の厳密な安全マージンテスト
（`compactCeiling`/`safetyCeiling`）が根拠を示すfloorであり、今回は
意図的に変更していない — Final Densityと同じ理由でスコープ外とした。

再びHOMEが長いスクロール画面になっていないことは、Hの1画面要件テストで
確認済み。

## 変更禁止事項の遵守

- Domain changes: **NONE**
- Save schema changes: **NONE**
- Balance changes: **NONE**
- Finance calculation changes: **NONE**
- Month transition / Recovery / Sales / Employee logic: **NONE**
- SkillSheet domain logic (`SkillSheet`, `SkillSheetRisk`, etc.): **NONE**
- Active Project Visibility / Employee UI Phase A: **NONE**（先取りなし）
- #167 Late Game / Year-End仕様 / workflow: **NONE**
- 新しい架空データ・架空社員・架空状態: **追加していない**

## テスト

### flutter analyze

`flutter analyze --no-fatal-infos` → **No issues found!**

### 変更した/新規のテスト

- `test/presentation/home/home_navigator_advice_adapter_test.dart` —
  headline/message/explanationの期待値をスキルシート表記へ更新
- `test/presentation/home/home_recommended_action_test.dart` —
  headline/ctaLabelの期待値をスキルシート表記へ更新（"legacy"文言セット
  との重複禁止テストは無変更で通過）
- `test/presentation/home/home_navigator_section_test.dart` — 実際の
  プロダクション文言を模した fixture 文字列（44文字のexplanation、
  headline）をスキルシート表記へ更新。secondary route自体の一般テスト
  （widget-level, 引数で明示的に渡した場合の描画確認）は今回のPublic Demo
  側の削除と無関係なため無変更
- `test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart` —
  Quick Access専用テストと「他の行動を確認する」secondary CTA専用テストを削除
  （機能自体が削除されたため）
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart` —
  reading-order検証からQuick Access項目を削除、Quick Access専用テストを削除、
  増大テキストスケール回帰から「クイックアクセス」の文字列チェックを削除
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` —
  「HOMEのボタンはCTA1つ+secondary1つ」→「CTA1つのみ」へ更新
- `test/ui/public_demo/public_demo_01_home_final_density_test.dart` —
  Quick Access関連の全アサーションを削除し、「SES HOME Final Polish」の
  新しい受入基準（Quick Access非存在、5セクションのunscrolled可視性、
  overflow/touch-target/Semantics回帰）へ全面更新
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart` — HOME上の
  実際のヘッドライン/メッセージ/説明文の期待値をスキルシート表記へ更新
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` — Quick
  Access参照をimportant-tasksキーへ差し替え、HOMEのボタン数（CTA1つのみ）
  を更新、CTA実文言の期待値をスキルシート表記へ更新
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` —
  HOME上の実際のheadline期待値をスキルシート表記へ更新
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart` —
  「HOMEのボタンはCTA1つ+secondary1つ」→「CTA1つのみ」へ更新
- `test/ui/public_demo/public_demo_01_month_guard_april_may_june_test.dart` —
  Month Guardダイアログ内の実際のheadline期待値をスキルシート表記へ更新
- `test/ui/public_demo/public_demo_01_persistence_test.dart` — 再起動後の
  HOME CTA期待値をスキルシート表記へ更新
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart` —
  Quick Access専用テストと、増大テキストスケール回帰内のQuick Access利用を削除

### 実行結果

`flutter analyze --no-fatal-infos` → **No issues found!**

HOME関連 focused widget tests（15ファイル、個別実行、全て green）:

| ファイル | 結果 |
|---|---|
| `public_demo_01_bottom_nav_tabs_test.dart` | All tests passed! (+6) |
| `public_demo_01_home3_integration_test.dart` | All tests passed! (+10) |
| `public_demo_01_home_cash_forecast_advice_test.dart` | All tests passed! (+5) |
| `public_demo_01_home_consolidation_test.dart` | All tests passed! (+32) |
| `public_demo_01_home_final_density_test.dart` | All tests passed! (+8) |
| `public_demo_01_home_navigator_test.dart` | All tests passed! (+29) |
| `public_demo_01_home_office_stage_test.dart` | All tests passed! (+16) |
| `public_demo_01_home_recommended_action_test.dart` | All tests passed! (+27) |
| `public_demo_01_home_runtime_read_test.dart` | All tests passed! (+12) |
| `public_demo_01_home_ui_3c_density_test.dart` | All tests passed! (+8) |
| `public_demo_01_issue_124_screen_verification_test.dart` | All tests passed! (+7) |
| `public_demo_01_month_guard_april_may_june_test.dart` | All tests passed! (+6) |
| `public_demo_01_month_guard_recommended_test.dart` | All tests passed! (+4) |
| `public_demo_01_persistence_test.dart` | All tests passed! (+13) |
| `public_demo_home_presentation_components_test.dart` | All tests passed! (+9) |
| **合計** | **192 passed, 0 failed** |

`test/presentation/home/` 一式（`home_navigator_advice_adapter_test.dart`,
`home_navigator_section_test.dart`, `home_recommended_action_test.dart` 含む）
も実行し、SkillSheet表記更新箇所を含めてgreen。

既存HOME regression suite（上記15ファイル）も同一実行に含まれている。

全`flutter test`（PR前に1回）:

```
1542 tests: 1540 passed, 2 failed
```

失敗した2件は、いずれも本ブランチの変更と**無関係**（詳細は「残課題」節）:

- `test/presentation/home/home_shell_page_test.dart`: `Month-end CTA is disabled`
- `test/presentation/home/home_dashboard_data_wiring_test.dart`: `HomeShellPage the month-end CTA stays disabled even with real dashboard data`

`origin/main`（`321641d`）で`git stash`して同じ2件が既に失敗することを確認済み
（`HomeShellPage`はアプリの実際のナビゲーション経路から到達不能な孤立コードで、
Public Demoの一部ではない）。

## PR

<!-- PR_URL_PLACEHOLDER -->

## 残課題

- `test/presentation/home/home_shell_page_test.dart` の "Month-end CTA is
  disabled" と `test/presentation/home/home_dashboard_data_wiring_test.dart`
  の同名テストは、**このブランチの変更と無関係に origin/main で既に
  失敗している**（`HomeShellPage`はアプリの実際のナビゲーションから
  到達不能な孤立コードで、Public Demoの一部ではない）。今回スコープ外の
  ため未修正。origin/mainで`git stash`して再現確認済み。
- 社員/営業タブの既存「SkillSheet確認」「入社前SkillSheet」ボタンおよび
  営業進捗ステッパーの表記統一は、今回のHOME限定スコープの都合上、
  意図的に見送った（PRをHOME Final Polishのみに限定するため）。将来
  「社員/営業タブのスキルシート表記統一」として別issueで対応可能。
