# SES NON-HOME-UI SALES Visual Complete — Result

STATUS: **完了**

GOVERNING SSOT: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`
CANONICAL REFERENCE: `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`
（`03_FiveTabs_LayoutOverview.png` / `04_Sales_DetailedLayout.png` /
`05_Sales_ScreenFlow.png`）

## BASE SHA

`11e6898e6c705558cc9bd352ef101c053dd4b76f`
（PR #194 "SES Employee Visual Complete" merge commit — `git fetch origin`
で作業開始時に確認した最新 `origin/main`）

## branch / final HEAD

- branch: `claude/ses-sales-visual-complete-9co508`
- final HEAD: 本コミット時点（PR作成後にHEADを追記）

## 目的

既存 Sales UI Phase 1（`docs/reports/SES_NON-HOME-UI_SALES_Phase1_Implementation_Result.md`）
が確立した4セクションの情報階層（現在の営業・採用状況 → 今やるべき営業アクション →
採用・候補者進捗 → 案件・参画/継続状況）は**変更せず**、Canonical Visual
Reference の完成イメージへ visual（カード階層・配色・アイコン・avatar・
情報密度）を近づける「Visual Complete」化を行った。

## 実施前の確認

`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` の3枚
（`03_FiveTabs_LayoutOverview.png` / `04_Sales_DetailedLayout.png` /
`05_Sales_ScreenFlow.png`）を実画像として確認した。共通する視覚要素:

- 上部に「すべて/新着/提案中/内定」等のフィルタチップ＋件数、または
  「ひよりのアドバイス」のような常時サマリー領域
- 案件/候補者/営業状況カード: 円形avatarまたはアイコン + タイトル +
  色分けされたstatusバッジ（新着=赤、提案中=青、内定=緑、見送り=グレー等）
  + 詳細情報 + アクションボタン
- アイコン付きセクション見出し
- 統一されたカード角丸・spacing・タイポグラフィ

これを、既存の authoritative な Public Demo state・実装済みルートに対して
のみ適用した（架空のクライアント名・案件名・単価・マッチ度・スキル要件は
一切追加していない）。

## 実施内容

### 1. Sales overview の Reference 準拠 Visual 化（GOAL 1・8）

`_salesOverviewSection`（Section 1）を、2行のプレーンテキスト
（`営業残 N回（上限N回）` / `候補者 N名・案件 N件（うち検討中 N件）`）から、
アイコン付きの3つのstat tile（`PublicDemoSalesStatTile`, 新規）へ再構成した。

- 各タイルは「営業残」「候補者」「案件」を、アイコン + 太字の主要数値 +
  補助テキスト（上限/検討中件数）で表示する。
- 既存テキストの語句・数値表現は**1文字も変えていない** — 主要数値行
  （`primaryText`）は旧実装のTextと完全に同じ文字列（`'営業残 $N回'` /
  `'候補者 $N名'` / `'案件 $N件'`）をそのまま`Text`1個として描画するため、
  既存回帰テスト（`public_demo_sales_ui_phase1_test.dart`）の
  `find.textContaining('営業残 N回')` 等のアサーションは**無修正のまま**
  全て通過する。
- 「うち検討中 N件」がある場合のみ、案件タイルを強調色（`emphasize`）で
  表示する — 新しい閾値・新しい警告ルールではなく、既存の
  `pendingAssignmentCount > 0` 判定をそのまま視覚化しただけ。
- セクション見出しにアイコン（`Icons.insights_outlined`）を追加。

### 2. 各カードの Reference 準拠 Visual 再設計（GOAL 2・4・5）

`PublicDemoSalesStatusBadge`（新規, 4トーン: positive/inProgress/caution/
negative）と `PublicDemoSalesAvatar`（新規）を導入し、以下のカードへ適用:

- **`ac(i)`（採用・候補者進捗カード）**: `PublicDemoSalesAvatar`
  （`homeOfficeStagePortraitFor(a.id)`）+ 名前 + `PublicDemoSalesStatusBadge`
  （`applicantStatus(a)`の**既存文字列をそのまま**、色のみ`a.stage`から
  新規の`_applicantStatusTone`で決定 — 不採用/内定辞退/各面談不合格は
  negative、内定承諾/各面談通過/入社・参画予定はpositive、それ以外は
  inProgress）。
- **`assignmentCard(i)`（案件・参画/継続状況カード）**: 同様に avatar
  （`homeOfficeStagePortraitFor(a.engineerId)`）+ `PublicDemoSalesStatusBadge`
  （'継続予定'/'参画中'、常にpositive）+ 案件名の前にアイコン
  （`Icons.business_center_outlined`）。
- **7月の結果ナラティブ**（`_salesProjectStatusCards`内）: プレーンな
  `ListTile`を、他カードと同じavatar + `PublicDemoSalesStatusBadge`
  （`julyResult(a)`の**既存文字列をそのまま**、色は新規`_julyResultTone`—
  現案件継続/新案件切替はpositive、'待機（営業が必要）'はcaution）付きの
  カード（`PublicDemoSalesCard`）へ再構成。
- **`_RecruitmentMediaCard`（求人媒体カード）**: 見出しにアイコン
  （`Icons.campaign_outlined`）を追加し、共通カード形状
  （`PublicDemoSalesCard`）へ統一。

いずれのカードも、authoritative なテキスト・ボタン・eligibility・keyは
**1つも変更していない** — 変更したのは avatar・バッジの色分け・アイコン・
spacing・カード形状のみ。

badgeの色は全て以下の**既存の事実**からのみ決まる（新しいドメイン判定は
一切追加していない）:

- `PublicDemoApplicant.stage`（`_applicantStatusTone`）
- `PublicDemoAssignment.nextOrderStatus`/`replacementStage`
  （`assignmentCard`のbadge、`_julyResultTone`）

### 3. card shape / spacing / icon / typography（GOAL 2）

`PublicDemoSalesCard`（新規, 共通カード形状 — 白背景・角丸12・
`outlineVariant`ボーダー）を導入し、`ac(i)` / `assignmentCard(i)` /
7月ナラティブ / `_RecruitmentMediaCard` の4種のカードすべてに統一適用した。
Employee Visual Complete（PR #194）が確立したのと同じカード形状（値は
独立定義 — 本ファイルの「isolation」方針どおり、Employeeの実装からは
import していない）。

セクション見出し（既存 `_sectionHeader`, Employee Visual Complete で
追加済みの`icon`パラメータをそのまま利用）に、営業タブの3見出し
（今やるべき営業アクション=`campaign_outlined`, 採用・候補者進捗=
`groups_outlined`, 案件・参画/継続状況=`handshake_outlined`）へアイコンを
追加した。

### 4. real assets の再利用（GOAL 3）

候補者・社員のavatarは、HOME の Office Stage が既に使用している
authoritative な決定的マッピング関数 `homeOfficeStagePortraitFor(id)`
（`lib/presentation/home/models/home_office_stage_display.dart`, 既存の
公開関数を read-only で呼び出すのみ）をそのまま使用した。**新規の画像・
架空の人物画像は一切生成・追加していない**。`lib/presentation/home/`
配下のファイルは1行も変更していない。

### 5. Reference の5-screen flow について（GOAL 6, STRICTLY FORBIDDEN 遵守）

`05_Sales_ScreenFlow.png`が描く「案件一覧 → 案件詳細 → 提案する社員の選択 →
提案内容の確認 → 営業の進捗」という5画面遷移のうち、現行 authoritative
workflow に実際に存在する遷移は「営業タブ内の既存4セクション」のみである
（案件詳細モーダル・複数社員選択・提案確認画面などは既存実装に存在しない）。
本タスクはこれらの新規画面・新規機能を一切実装していない — 既存の
`_buildSalesTab`が持つ4セクション構成・遷移先（社員タブへのCTA等）は
無変更のまま、その中のカード/見出しのみをVisual再設計した。

### 6. authoritative fields のみ表示（GOAL 7）

client/project/rate/match score/skill requirement等、Reference画像内に
描かれているがauthoritative実装に存在しないフィールド（クライアント名・
単価・契約期間・マッチ度・スキル要件等）は、**一切新規表示していない**。
既存カードが元々表示していたフィールド（`engineerName`, `projectName`,
`resumeSummary`, `interviewScore`, `requestedMonthlySalary`等）のみを、
レイアウトを変えて表示している。

### 7. excessive scrolling の抑制（GOAL 8）

Overviewをstat tile化したことで、Section 1が「読む」情報から「一目で
把握できる」情報へ変わり、画面上部での状態認識が速くなった。カード自体は
avatar追加分だけわずかに縦方向が増えているが、Employee Visual Complete
と同様に「増加を最小化する」形での対応とした（後述「残Visual Gap」参照）。

### 8. Sales ローカル style/token（GOAL 9）

新設した `lib/ui/public_demo/public_demo_sales_visual.dart` は、Employee
Visual Complete（`public_demo_employee_visual.dart`）と同じ isolation
方針を踏襲した独立ファイルであり、`lib/ui/theme.dart`（app-wide
`SesTheme`）・`lib/presentation/home/`配下・Employeeタブ自身のファイルは
**1行も変更していない**。Employeeのvisual実装からのimportもしていない
（配色の値は独立に再定義 — 意図的な重複、他タブへの波及を避けるため）。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | Sales overviewをstat tile化、`ac(i)`/`assignmentCard(i)`/7月ナラティブ/`_RecruitmentMediaCard`をカード+avatar+バッジへ再設計、セクション見出しへアイコン追加、tone判定ヘルパー（`_applicantStatusTone`/`_julyResultTone`）新規追加、未使用化した旧`badge()`ヘルパーを削除 |
| `lib/ui/public_demo/public_demo_sales_visual.dart`（新規） | 営業タブローカルの visual building blocks（`PublicDemoSalesStatusBadge` / `PublicDemoSalesStatusTone` / `PublicDemoSalesAvatar` / `PublicDemoSalesStatTile` / `PublicDemoSalesCard`） |
| `test/ui/public_demo/public_demo_sales_visual_complete_test.dart`（新規） | 新Visual構造のwidget test（後述） |
| `e2e/scripts/ses-sales-visual-complete-screenshot.mjs`（新規） | Visual Verification screenshot撮影用の使い捨てPlaywrightスクリプト（既存`ses-employee-visual-complete-screenshot.mjs`と同じ手法） |
| `docs/reports/screenshots/SES_NON-HOME-UI_SALES_Visual-Complete_{BEFORE,AFTER}_{360x800,390x844}.png`（新規） | Visual Verification screenshot |
| `docs/reports/SES_NON-HOME-UI_SALES_Visual-Complete_Result.md`（新規） | 本結果報告 |

`lib/presentation/home/`配下・`lib/ui/theme.dart`・`lib/game/`配下・
save/schema関連ファイル・Employeeタブの実装ファイル
（`public_demo_employee_visual.dart`）は**1バイトも変更していない**
（`git diff --stat 11e6898..HEAD -- lib/presentation/home/ lib/ui/theme.dart
lib/game/`で確認済み、差分なし）。

## Canonical Reference との差分 Before/After

Screenshot: `docs/reports/screenshots/SES_NON-HOME-UI_SALES_Visual-Complete_{BEFORE,AFTER}_{360x800,390x844}.png`
（実ブラウザPlaywright screenshot、`?e2e=1#/public-demo-01`の4月初期状態
= 営業・採用のアクションがまだ何もない状態で撮影。5月/6月/7月の
populatedなカード状態はwidget testで個別に検証 — 詳細は「残Visual Gap」参照）

| 項目 | BEFORE (Phase 1) | AFTER (Visual Complete) | Reference |
|---|---|---|---|
| Overview (Section 1) | 2行のプレーンテキスト | アイコン付き3 stat tile（営業残/候補者/案件） | アイコン付きサマリー領域 |
| セクション見出し | プレーンテキスト | アイコン付き（campaign/groups/handshake） | アイコン付き |
| 候補者カード (`ac`) | 名前+テキストバッジのみ | avatar + 色分けバッジ + アイコン | avatar + 色分けバッジ |
| 案件カード (`assignmentCard`) | 名前+テキストバッジのみ | avatar + 色分けバッジ + 案件名アイコン | avatar + 色分けバッジ |
| 7月結果 | プレーンListTile | avatar + 色分けバッジ付きカード | カード形式 |
| card shape | 既定の白カード | 角丸12・outlineVariantボーダー統一（`PublicDemoSalesCard`） | 角丸・淡色カード |
| 求人媒体カード | プレーンテキスト | アイコン付き見出し + 統一カード形状 | アイコン付きカード |

実画像（AFTER, 390x844、4月初期状態）: Overview
セクションが3つのアイコン付きタイルへ変わり、「現在の営業・採用状況」を
一目で把握できる構成になったことを確認した（他の populated 状態は
widget testで個別に確認 — 下記「tests」節参照）。

## 使用した authoritative fields

- Overview: `PublicDemoState.salesRemaining`/`salesCapacity`（Phase 1から
  既存）、`workflow.applicants`（`hasJoined`フィルタ）、
  `workflow.assignments`（`nextOrderStatus`フィルタ） — いずれもPhase 1の
  `_salesOverviewSection`が既に読んでいたものと完全に同一
- 候補者カード: `PublicDemoApplicant.id`/`.name`/`.resumeSummary`/`.stage`/
  `.interviewScore`/`.requestedMonthlySalary`（Phase 1/既存実装から無変更）
- 案件カード: `PublicDemoAssignment.engineerId`/`.engineerName`/
  `.projectName`/`.nextOrderStatus`/`.replacementStage`（Phase 1/既存実装
  から無変更）
- avatar: `homeOfficeStagePortraitFor(id)`（HOME Office Stageが既に使用
  している既存公開関数、read-only呼び出しのみ）

新しい永続フィールド・新しい集計ロジック・新しい営業/採用ルールは
一切追加していない。

## 使用した real assets

- `homeOfficeStagePortraitFor(id)`の既存決定的フォールバック
  （`engineer_junior`/`midlevel`/`veteran`をidの安定ハッシュで選択、または
  `eng-01`/`eng-02`の明示的ポートレート）をそのまま使用。候補者
  （`PublicDemoApplicant.id`）にも同じ関数を適用しているが、これは
  Employee Visual Complete が「将来の入社者」に対して既に確立した
  フォールバック方針と同一の使い方であり、新規に画像を生成・追加しては
  いない。

## fake data 0 確認

- 架空の人物画像・企業画像: 追加していない（authoritative asset のみ
  使用、上記参照）
- 架空のクライアント名・案件名・単価・契約期間・マッチ度・スキル要件:
  追加していない（Reference画像内の「B社」「ECサイト開発支援」
  「70万円/月」「マッチ度 高」等の具体値は一切参照・実装していない）
- 架空のstatus・badge文言: 追加していない（badgeの表示テキストは全て
  既存の`applicantStatus`/`julyResult`/'継続予定'/'参画中'の**既存文字列を
  そのまま**使用、色分けのみ新規）
- Referenceだけに存在する画面（案件詳細モーダル・複数社員選択・提案確認
  画面等）: 新設していない

## HOME 変更 0 確認

```
$ git diff --stat 11e6898..HEAD -- lib/presentation/home/ lib/ui/theme.dart
（差分なし）
```

`lib/presentation/home/`配下ファイル・`lib/ui/theme.dart`（app-wide
`SesTheme`）は本タスクで1行も変更していない。

## gameplay authority 変更 0 確認

```
$ git diff --stat 11e6898..HEAD -- lib/game/
（差分なし）
```

`lib/game/`配下のドメインファイルは1つも変更していない。全てのボタン・
コマンド呼び出し・eligibility判定式（`s.salesRemaining > 0`、
`a.interviewScore >= 60`、`PublicDemoNextOrderStatus`/
`PublicDemoReplacementStage`/`PublicDemoApplicantStage`の各分岐等）は
既存のものを1文字も変更せず、視覚コンポーネントで包んだだけである。
Save/schema・Finance/Balance計算・Month transitionロジックへの変更もゼロ。

## viewport/TextScaler 結果

- 360×800 / 390×844 の両方
- TextScaler 1.0 / 1.3 / 2.0 の全組み合わせで `tester.takeException()` が
  `null`（horizontal overflow 0）
- Overview stat tile・全statusバッジ（最長の'待機（営業が必要）'ラベルを
  含む）のRectがいずれも画面幅内（`left >= 0`, `right <= size.width`）
- 既存`public_demo_sales_ui_phase1_test.dart`のTextScaler回帰スイートも
  無修正のまま全緑（Overview/次アクション/候補者進捗/空状態の4セクション）

（新規 `public_demo_sales_visual_complete_test.dart` の該当テストグループ、
既存 `public_demo_sales_ui_phase1_test.dart` の該当テストグループ、
いずれもgreen — 詳細は「tests」節）

## tests / analyze / diff-check

### flutter analyze

```
$ flutter analyze
No issues found!
```

（Flutter 3.44.8 / Dart 3.12.2、本セッションで`/home/user/flutter-sdk`に
stable channel 3.44.8タグをcloneして使用 — 本リポジトリのCIワークフロー
`public-demo-validation.yml`/`public-demo-preview.yml`と同一バージョン）

### 新規: `test/ui/public_demo/public_demo_sales_visual_complete_test.dart`

```
$ flutter test test/ui/public_demo/public_demo_sales_visual_complete_test.dart
→ 22/22 tests passed
```

内容: Overview stat tile（3枚、既存文字列と完全一致）の存在確認、案件
tileの強調表示（`emphasize`）と検討中件数の一致確認、求人媒体カードの
アイコン確認、候補者カードのavatar/badge存在確認とtoneの一致確認
（`応募`→inProgress、経歴書確認後の`書類確認済`→inProgress維持）、案件
カードのbadge tone確認（`参画中`/`継続予定`→positive）、7月結果の
positive/cautionそれぞれのbadge tone確認（最長ラベル`待機（営業が必要）`
のoverflow非発生を含む）、`PublicDemoSalesStatusBadge`の4トーンが
互いに異なる色を持つことの確認、HOME Freezeへの新規widgetの非流出、
360×800/390×844×TextScaler 1.0/1.3/2.0でのoverflow 0（May/July caution
の両方）。

### 既存回帰: Sales UI Phase 1

```
$ flutter test test/ui/public_demo/public_demo_sales_ui_phase1_test.dart
→ 26/26 tests passed
```

（Overview文言・4月〜3月の各月ゲート・空状態・HOME Freeze regressionを
含む既存26テストが無修正のまま全緑 — Overviewのstat tile化がテキスト
アサーションを壊していないことを直接確認）

### 既存回帰: Employee Visual Complete / HOME Freeze / bottom nav

```
$ flutter test \
  test/ui/public_demo/public_demo_employee_visual_complete_test.dart \
  test/ui/public_demo/public_demo_employee_ui_phase1_test.dart \
  test/ui/public_demo/public_demo_active_project_visibility_test.dart \
  test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart \
  test/ui/public_demo/public_demo_01_home_final_density_test.dart \
  test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart
→ 58/58 tests passed
```

### 既存回帰: 求人媒体/CTA/月次進行

```
$ flutter test \
  test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart \
  test/ui/public_demo/public_demo_01_home_recommended_action_test.dart \
  test/ui/public_demo/public_demo_01_fiscal_year_progression_test.dart
→ 36/36 tests passed
```

### Public Demo フルスイート

```
$ flutter test test/ui/public_demo
→ 418/418 tests passed

$ flutter test test/game/public_demo
→ 520/520 tests passed
```

上記2ディレクトリは、本タスクが変更したファイル
（`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）に関連する
UI/domainテストの全量であり、いずれも無変更のまま全緑（既存の失敗は
0件）。リポジトリ全体のフルスイート（`flutter test`）は実行時間の都合で
今回はスコープ外としたが、変更ファイルに直接関連する上記2ディレクトリ
（合計938件）は全て確認済みであり、Employee Visual Complete（PR #194）の
Result Reportが記録した「本ブランチ変更とは無関係な2件のpre-existing
failure」（`test/presentation/home/`配下、`lib/presentation/home/`は本
タスクで無変更）は今回のdiffに影響を受けない。

### git diff --check

```
$ git diff --check 11e6898..HEAD
（差分なし、exit 0 — whitespace error なし）
```

## screenshots paths

- `docs/reports/screenshots/SES_NON-HOME-UI_SALES_Visual-Complete_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_SALES_Visual-Complete_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_SALES_Visual-Complete_AFTER_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_SALES_Visual-Complete_AFTER_390x844.png`

撮影スクリプト: `e2e/scripts/ses-sales-visual-complete-screenshot.mjs`
（既存の`ses-employee-visual-complete-screenshot.mjs`と同じ
static-server + Playwright Chromium手法。`flutter build web --release
--no-web-resources-cdn`の実ビルドを4月初期状態で`?e2e=1#/public-demo-01`
から営業タブへ遷移して撮影。BEFOREはBASE SHAの一時`git worktree`で
ビルドした別artifact）

## 残Visual Gap

- 上記screenshotは4月初期状態（営業・採用のアクションがまだ何もない
  空状態）のみを撮影しており、Overview stat tileの視覚変化は確認できるが、
  populatedな候補者カード（avatar+色分けバッジ）・案件カード・7月結果
  ナラティブの実機screenshotは未取得（月送り操作を伴う状態再現が
  E2Eスクリプトでは複雑になるため、widget testでのRect/tone/文字列検証
  のみ実施 — Employee Visual Complete Result Reportが記録した同種の
  スコープ制約と同じ判断）。
- Reference画像が示すフィルタチップ（すべて/新着/提案中/内定等）は、
  Employee Visual Complete が社員一覧に導入した「全員/待機中/参画中」
  フィルタに相当する機能を、Salesの各セクション（候補者進捗・案件状況）
  には導入していない — 各セクションは月ゲートにより同時に描画される
  カード数が少なく（Phase 1の設計どおり、5月は候補者、6月は案件、
  7月は結果、と月単位で分離済み）、フィルタが解決する「多数カードからの
  絞り込み」というユースケース自体が現状のauthoritative workflowには
  存在しないため、意図的に見送った。
- Reference の5-screen flow（案件詳細モーダル・複数社員選択・提案確認
  画面）は、GOAL 6/STRICTLY FORBIDDENの指示どおり実装していない
  （「Referenceの5-screen flowについて」節参照）。
- excessive scrollingは「増やさない」ではなく「増加を最小化する」形での
  対応となった — avatar追加分だけ各カードの縦方向がわずかに増えている
  （Employee Visual Complete と同じトレードオフ）。

## Visual Complete 判定

**PASS**

判定根拠: Canonical Reference の主要な視覚要素（アイコン付きOverview
stat tile、avatar付きパイプラインカード、色分けされた実在statusバッジ、
統一カード形状、アイコン付きセクション見出し）を、既存の情報階層
（現在の営業・採用状況 → 今やるべき営業アクション → 採用・候補者進捗 →
案件・参画/継続状況）・eligibility・save/schema・HOME・Domainを一切
変更せずに反映した。fake data 0 / HOME変更 0 / gameplay authority変更 0
を確認済み。既存回帰テスト（Sales UI Phase 1: 26件、Employee Visual
Complete/HOME Freeze: 58件、求人媒体/CTA/月次進行: 36件、
`test/ui/public_demo`フル: 418件、`test/game/public_demo`フル: 520件）
は全てgreen、無修正のまま通過。新規visual構造のwidget test（22件）も
green。360×800/390×844 × TextScaler 1.0/1.3/2.0でoverflow 0。残る
ギャップ（上記「残Visual Gap」）はいずれもSSOTの禁止事項（fake data
追加、Reference専用機能の新規実装、gameplay authority変更）を回避する
ために意図的に見送った、または実行時間の都合でスコープ外とした項目で
あり、Visual Complete の PASS 判定を妨げるものではないと判断した。
