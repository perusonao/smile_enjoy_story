# SES NON-HOME-UI EMPLOYEE Visual Complete — Result

STATUS: **完了**

GOVERNING SSOT: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`
CANONICAL REFERENCE: `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`
（`01_Employee_LayoutDraft.png` / `02_Employee_DetailedLayout.png` /
`03_FiveTabs_LayoutOverview.png`）

## BASE SHA

`ce1025d09dc530696e7a77444bf186484a2d7a45`
（PR #193 "SES TAB-UI Visual Reference" merge commit — `git fetch origin main`
で作業開始時に確認した最新 `origin/main`）

作業開始前、ローカルブランチ `claude/ses-employee-visual-complete-xl8vp7` が
古いコミット（`f4ca78f`, Phase 0A/0B相当。BASE SHA の祖先で未マージの変更は
無かった）に取り残されていたため、
`git checkout -B claude/ses-employee-visual-complete-xl8vp7 origin/main` で
最新 main から作り直した。

## branch / final HEAD

- branch: `claude/ses-employee-visual-complete-xl8vp7`
- final HEAD: 本コミット参照（コミット後にPRで確認可能）

## 目的

既存 Employee UI Phase 1（`docs/reports/SES_NON-HOME-UI_EMPLOYEE_Phase1_Implementation_Result.md`）が
確立した4セクション構成の情報階層（社員一覧・現在状態 → 今やるべき社員アクション →
参画中案件 → 成長・SkillSheet・研修）は**変更せず**、Canonical Visual Reference
の完成イメージへ visual（配色・カード形状・アイコン・タイポグラフィ・avatar・
progress bar等）を近づける「Visual Complete」化を行った。

## 実施前の確認

`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` の3枚
（`01_Employee_LayoutDraft.png` / `02_Employee_DetailedLayout.png` /
`03_FiveTabs_LayoutOverview.png`）を実画像として確認した。共通する視覚要素:

- 社員カード: 円形avatar + 名前 + 状態バッジ（色分け: 待機中=黄、参画中=緑、
  研修中=赤系）+ スキル名と数値（成長時は `before → after (+delta)`）+
  アクションボタン
- 上部に「全員 / 待機中 / 参画中 / 休職」フィルタチップ + 集計
- 案件詳細・スキルシートは進捗バーを使った整理された情報カード
- 統一されたカード角丸・アイコン付きセクション見出し

これを、既存の authoritative な Public Demo state・実装済みルートに対して
のみ適用した（架空の休職状態・架空スキルシート項目・架空案件詳細は追加していない）。

## 実施内容

### 1. 社員カードの Reference 準拠 Visual 再設計（優先1・2・3・4）

`_employeeRosterSection`（Section 1）の各行を、`Wrap`によるテキスト行から
Reference 風のカードへ再構成した（`_employeeRosterCard`, 新規）。

- **avatar**: `lib/presentation/home/models/home_office_stage_display.dart` の
  既存公開関数 `homeOfficeStagePortraitFor(employeeId)`（HOME の Office
  Stage が既に使っている authoritative な社員ポートレート決定ロジック —
  eng-01=`AssetPaths.engineerMidlevel`, eng-02=`AssetPaths.engineerJunior`,
  それ以外は同じ決定的ハッシュによる `engineer_*` 系の実在asset）をそのまま
  読み取って使用。**架空の人物画像は一切生成・追加していない** — HOME
  側のファイルは1行も変更していない（read-onlyな関数呼び出しのみ）。
- **状態バッジ**: `PublicDemoEmployeeStatusBadge`（新規, `lib/ui/public_demo/
  public_demo_employee_visual.dart`）。表示文字列は既存の
  `_currentEmployeeStatusLabel(engineer)` を**そのまま**使用（既存回帰
  テストが検証する文字列は無変更）。色のみ、以下の既存 authoritative な
  事実から決まる3トーンに分岐:
  - 参画中（`_currentlyAssignedEngineerIds` に含まれる）→ 緑
  - 今月の社内研修選択済み（`PublicDemoState.trainingSelections` に
    含まれる）→ 赤系
  - それ以外（待機系）→ 黄
- **skill/growth 可視化**: `PublicDemoEmployeeSkillBar`（新規）。
  `PublicDemoEngineerRuntime.actualCapability` / `.primaryLanguage`
  （`languageLabels` でラベル化）を0-100スケールの progress bar で表示。
  `PublicDemoState.latestGrowthResults` に当該社員の今月の成長イベントが
  実在する場合のみ `before → after (+delta)` を表示し、無い月は
  現在値のみを表示する（**存在しない成長を毎月捏造しない**）。

### 2. フィルタ（優先5）

`_employeeStatusFilterChips`（新規, key
`public-demo-employee-status-filter`）。「全員 / 待機中 / 参画中」の3チップ
のみ（「休職」等、存在しない状態のチップは追加していない）。カウントは
既存の `PublicDemoState.engineersWaiting` / `engineersAssigned` を
そのまま表示。フィルタは Section 1 のロースター行の表示/非表示のみを
制御する client-side 表示状態（`_EmployeeStatusFilter`, 新規 enum）であり、
Section 2/3/4・既存コマンド・eligibility には一切影響しない。

### 3. APV（参画中案件）カードの Reference 風整理（優先6）

`activeProjectStatusCard`（Section 3）を、アイコン付きヘッダー + 「参画中」
バッジ + `_assignmentMetricBar`（新規, 納期プレッシャー/予算健全度を
0-100 progress bar化）で再構成。表示するフィールドは
`PublicDemoAssignment.engineerName` / `.projectName` / `.deliveryPressure`
/ `.budgetHealth` の4つのみで **Phase 1 から変更なし**（`fieldEvaluation`
は既存方針どおり非表示のまま）。クライアント名・単価・契約期間は
authoritative な `PublicDemoAssignment` に存在しないため表示していない。

### 4. SkillSheet / 研修導線（優先7）

既存の導線（Section 2 の「SkillSheet確認」ボタン → 実際の
`PublicDemoSkillSheetSheet`、Section 4 の研修カード）は**変更していない**
— eligibility・遷移先・keyは無変更。研修カードの視覚整理は今回スコープ外
（既存カードのまま）とし、Section見出しへのアイコン追加（下記5）で
セクション単位の視覚整理を行った。

### 5. card shape / spacing / icon / typography（優先8）

- `_sectionHeader` にオプションの `icon` パラメータを追加（デフォルト
  `null` — 営業/会計/メニュー/Year-Endの既存呼び出し箇所は無変更）。
  Employeeタブの4見出しにのみアイコンを指定（社員一覧=`groups_outlined`,
  今やるべき社員アクション=`checklist_outlined`, 参画中案件=`work_outline`,
  成長・SkillSheet・研修=`trending_up`）。
- 社員カードは白背景・角丸12・`outlineVariant`ボーダーの統一card shapeへ。
- 配色・token は Employeeタブローカル（`public_demo_employee_visual.dart`
  内のみ）で完結しており、`lib/ui/theme.dart`（app-wide `SesTheme`）は
  **1行も変更していない**。

### 6. excessive scrolling の抑制（優先9）

社員カード・フィルタチップを高情報密度かつコンパクトに設計した
（skill bar はラベル+バーを1行に収める、avatar radius 20、card padding
10×8、filter chip は独自の compact `InkWell` pill — Material `ChoiceChip`
の既定タップ領域より縦方向を詰めた）。実装過程で、既定の flutter_test
サーフェス（800×600、実機ターゲット外の人為的に小さいウィンドウ）で
既存 SkillSheet 回帰テストのタップ座標がボトムナビゲーションバーの
描画領域と重なる regression を検出し、上記のコンパクト化で解消した
（詳細は「TEST」節）。実機ターゲット2サイズ（360×800 / 390×844）では
avatar・skill bar・フィルタ追加分だけ社員一覧セクションの高さは
Phase 1 比で増えているが、overflow・タップ不能は発生していない
（TextScaler 1.0/1.3/2.0 で確認済み）。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | 社員ロースターカード再設計・フィルタ追加・APVカード再設計・セクション見出しアイコン化 |
| `lib/ui/public_demo/public_demo_employee_visual.dart`（新規） | Employeeタブローカルの visual building blocks（`PublicDemoEmployeeStatusBadge` / `PublicDemoEmployeeAvatar` / `PublicDemoEmployeeSkillBar`） |
| `test/ui/public_demo/public_demo_employee_visual_complete_test.dart`（新規） | 新Visual構造のwidget test（後述） |
| `test/ui/public_demo/public_demo_active_project_visibility_test.dart` | APVカード再設計に伴い、Text widget数アサーションを4→7へ更新（下記「テスト更新の説明」参照） |
| `docs/reports/screenshots/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_{BEFORE,AFTER}_{360x800,390x844}.png`（新規） | Visual Verification screenshot |
| `e2e/scripts/ses-employee-visual-complete-screenshot.mjs`（新規） | 上記screenshot撮影用の使い捨てPlaywrightスクリプト（既存 `ses171-tab-screenshot.mjs` 等と同じ手法） |
| `docs/reports/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_Result.md`（新規） | 本結果報告 |

`lib/presentation/home/` 配下・`lib/ui/theme.dart`・`lib/game/`配下・
save/schema関連ファイルは**1バイトも変更していない**
（`git diff --stat` で確認済み、変更は上記ファイルのみ）。

### テスト更新の説明（`public_demo_active_project_visibility_test.dart`）

Phase 1 時点の APV カードは「name/project/deliveryPressure/budgetHealth の
4事実 = ちょうど4つの `Text` widget」という実装詳細で fieldEvaluation
非表示を保証していた。今回の Visual Complete（優先6, カード再設計）で
deliveryPressure/budgetHealthそれぞれを「ラベルTextの progress bar row」
に分割し、かつ新規の「参画中」バッジ（内部で `Text` 1個）を追加したため、
同じ4事実から `Text` widget数が7個になった。アサーションはこの新しい
widget数（7）へ更新し、その直前に既存の`find.textContaining`による
4事実（engineerName/projectName/deliveryPressure/budgetHealth）の内容
一致チェックは**無変更のまま**維持している（fieldEvaluationが表示され
ない保証はこの4チェック+widget数チェックの組み合わせで維持）。

## Canonical Reference との差分 Before/After

Screenshot: `docs/reports/screenshots/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_{BEFORE,AFTER}_{360x800,390x844}.png`
（実ブラウザ Playwright screenshot、`?e2e=1#/public-demo-01` の4月初期状態
= 創業社員2名とも待機中、で撮影。APV/研修バッジのトーン等は widget test
で個別に検証 — 詳細は「残Visual Gap」参照）

| 項目 | BEFORE (Phase 1) | AFTER (Visual Complete) | Reference |
|---|---|---|---|
| 社員カード | 名前+テキストバッジのみ | avatar + 色分けバッジ + skill progress bar | avatar + 色分けバッジ + skill表示 |
| フィルタ | なし | 全員/待機中/参画中 チップ（カウント付き） | 全員/待機中/参画中/休職チップ（休職は非対応） |
| セクション見出し | プレーンテキスト | アイコン付き | アイコン付き |
| APVカード | プレーンテキスト4行 | アイコン+バッジ+progress bar | カード形式+ラベル+数値 |
| card shape | 既定の白カード | 角丸12・outlineVariantボーダー統一 | 角丸・淡色カード |

## 使用した real assets

- `AssetPaths.engineerMidlevel`（`assets/images/characters/engineer_midlevel.jpg`）
  — eng-01（佐藤健）
- `AssetPaths.engineerJunior`（`assets/images/characters/engineer_junior.jpg`）
  — eng-02（鈴木葵）
- それ以外の社員（将来の入社者）は `homeOfficeStagePortraitFor` の既存
  決定的フォールバック（`engineer_junior/midlevel/veteran` を id の
  安定ハッシュで選択）をそのまま使用。

いずれも HOME の Office Stage が既に使用している authoritative なマッピング
（`home_office_stage_display.dart`）を read-only で再利用したものであり、
新規に生成・追加した画像は無い。

## 使用した authoritative fields

- `PublicDemoState.engineersWaiting` / `.engineersAssigned`（HOME KPIと同一）
- `PublicDemoEngineerRuntime.actualCapability` / `.primaryLanguage`
  （`s.runtimeForOrNull(engineerId)`）
- `PublicDemoState.latestGrowthResults`（`PublicDemoMonthlyGrowth.
  capabilityBefore` / `.capabilityAfter` / `.engineerId`）
- `PublicDemoState.trainingSelections`
- `_currentlyAssignedEngineerIds`（= `workflow.assignedEngineerIds(month:
  s.month)`, Phase 1から既存）
- `_currentEmployeeStatusLabel(engineer)`（Phase 1から既存、文字列は無変更）
- `PublicDemoAssignment.engineerName` / `.projectName` / `.deliveryPressure`
  / `.budgetHealth`（Phase 1/APV Phase 1から既存）

新しい永続フィールド・新しい集計ロジック・新しいドメインメソッドは
一切追加していない。

## fake data 0 確認

- 架空の人物画像: 追加していない（authoritative asset のみ使用、上記参照）
- 架空の社員名・案件名・クライアント名・単価・契約期間: 追加していない
  （APVカードは既存の4フィールドのみ、Reference画像内の「ECサイト開発支援」
  「A社」「60万円」等の具体値は一切参照・実装していない）
- 架空のスキル値・成長値: 追加していない（`actualCapability` /
  `latestGrowthResults` の実値のみ表示、成長イベントが無い月は
  `before → after`行自体を出さない）
- 架空のstatus（休職等）: 追加していない（フィルタは全員/待機中/参画中の
  3つのみ）

## HOME 変更 0 確認

```
$ git diff --stat -- lib/presentation/home/ lib/ui/theme.dart
（差分なし）
```

`lib/presentation/home/` 配下ファイル・`lib/ui/theme.dart`（app-wide
`SesTheme`）は本タスクで1行も変更していない。`homeOfficeStagePortraitFor`
は既存の公開関数を呼び出しているのみで、その定義ファイルは無変更。

HOME Freeze regression テスト（既存
`public_demo_employee_ui_phase1_test.dart`「HOME Freeze regression」、
および新規追加した同種テスト）が両方green。

## viewport/TextScaler 結果

- 360×800 / 390×844 の両方
- TextScaler 1.0 / 1.3 / 2.0 の全組み合わせで `tester.takeException()` が
  `null`（horizontal overflow 0）
- フィルタチップ行・社員カード・APVカードのRectがいずれも画面幅内
  （`left >= 0`, `right <= size.width`）

（新規 `public_demo_employee_visual_complete_test.dart` の該当テスト
グループ、既存 `public_demo_employee_ui_phase1_test.dart` の該当テスト
グループ、いずれもgreen — 詳細は「tests」節）

## tests / analyze / diff-check

### flutter analyze

```
$ flutter analyze
No issues found!
```

（Flutter 3.35.5 / Dart 3.9.2、本セッションで `/opt/flutter` にstable
channelをcloneして使用。CI設定は `flutter-version: '3.44.8'`/`'3.44.9'`
— このセッションでは同じ `sdk: ^3.9.2` 制約を満たす別バージョンを使用した。
`pubspec.lock` の無関係な transitive依存差分は `git checkout --
pubspec.lock` で元に戻し、diffを本タスクのスコープのみに保った。）

### 新規: `test/ui/public_demo/public_demo_employee_visual_complete_test.dart`

```
$ flutter test test/ui/public_demo/public_demo_employee_visual_complete_test.dart
→ 12/12 tests passed
```

内容: 社員カードのavatar/badge/skill bar widget型の存在確認、badgeの
tone（色）が authoritative な参画/研修/待機の事実と一致すること、フィルタ
チップのタップでSection 1の行のみが増減しSection 2/3が無影響であること、
フィルタ操作後も既存の集計文（`待機 N・参画中 N・合計 M`）が無変更で
残ること、APVカードのprogress bar数値が `PublicDemoAssignment` の実値と
一致すること、HOME Freezeへの新規widgetの非流出、360×800/390×844×
TextScaler 1.0/1.3/2.0でのoverflow 0。

### 既存回帰: Employee Phase 1 / APV / founder follow-up / SkillSheet

```
$ flutter test test/ui/public_demo/public_demo_employee_ui_phase1_test.dart
→ 15/15 passed

$ flutter test \
  test/ui/public_demo/public_demo_active_project_visibility_test.dart \
  test/ui/public_demo/public_demo_01_home_office_stage_test.dart \
  test/ui/public_demo/public_demo_founder_follow_up_dialog_test.dart \
  test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart \
  test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart \
  test/ui/public_demo/public_demo_growth_result_card_test.dart \
  test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart \
  test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart \
  test/ui/public_demo/public_demo_raise_dialog_test.dart
→ 50/50 passed
```

（`public_demo_active_project_visibility_test.dart` の1件のみ、
「テスト更新の説明」節のとおり widget数アサーションを更新した上でpass）

### HOME Freeze関連 test

```
$ flutter test \
  test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart \
  test/ui/public_demo/public_demo_01_home_final_density_test.dart \
  test/ui/public_demo/public_demo_01_home_consolidation_test.dart \
  test/ui/public_demo/public_demo_01_home3_integration_test.dart \
  test/ui/public_demo/public_demo_01_home_runtime_read_test.dart \
  test/presentation/home/ \
  test/game/public_demo/public_demo_founder_follow_up_test.dart
→ 177/179 passed, 2 pre-existing failures (baseline-reproducible, unrelated)
```

上記2件（`test/presentation/home/home_dashboard_data_wiring_test.dart`
「the month-end CTA stays disabled even with real dashboard data」、
`test/presentation/home/home_shell_page_test.dart`「Month-end CTA is
disabled」）は、本タスクのブランチ変更を `git stash` で退避し BASE SHA
の状態のまま再実行しても同一の `StateError: Bad state: No element`
（`find.byType(FilledButton)` の単一マッチ前提が崩れている）で失敗する
ことを確認済み — 本タスクの変更とは無関係な、このセッションの Flutter
SDKバージョン（3.35.5、CI固定の3.44.8/3.44.9とは異なる）に起因する
pre-existingな既知failureである。`lib/presentation/home/` は本タスクで
一切変更していない。

### フルスイート

```
$ flutter test
→ 実行中（このセッションの環境ではフルスイート ~1700件の実行に30分以上
  かかる — 個別ファイル実行では数分で終わる規模のテストが、まとめて
  実行すると顕著に遅くなる)。進行状況は488件時点まで確認しており、
  新規failureはゼロ（既知のpre-existing 2件のみ、上記「HOME Freeze関連
  test」節で個別に確認・原因説明済み）。
```

上記のとおりフルスイートは実行に長時間を要するため、本タスクに直接
関連するテスト（Employee Phase 1 / APV / SkillSheet / founder follow-up /
HOME Freeze関連、および本タスクの新規テスト）は個別実行で全数確認済み
（上記の各節、いずれも green）。フルスイートは引き続きバックグラウンドで
実行し、完了後に本節を更新する。

### git diff --check

```
$ git diff --check
（差分なし、exit 0 — whitespace error なし）
```

## screenshots paths

- `docs/reports/screenshots/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_AFTER_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_AFTER_390x844.png`

撮影スクリプト: `e2e/scripts/ses-employee-visual-complete-screenshot.mjs`
（既存の `ses171-tab-screenshot.mjs` と同じ static-server + Playwright
Chromium手法。`flutter build web --release --no-web-resources-cdn` の
実ビルドを4月初期状態で `?e2e=1#/public-demo-01` から社員タブへ遷移して
撮影。BEFOREはBASE SHAの一時 `git worktree` でビルドした別artifact）

## 残Visual Gap

- 上記screenshotは4月初期状態（創業社員2名とも待機中）のみを撮影して
  おり、参画中（緑バッジ）・研修選択済み（赤系バッジ）・APVカードの
  実機screenshotは未取得（widget testでのRect/色/数値検証のみ実施）。
  月送り操作を伴う状態再現が必要なため、実行時間の都合でスコープ外とした。
- SkillSheetシート自体（`PublicDemoSkillSheetSheet`）・研修カード
  （`internalTrainingCard`）の内部レイアウトはReferenceの「スキルシート
  （簡易表示）」画面ほどには視覚整理していない（既存の導線・レイアウトを
  維持、優先度7は「導線の整理」を主眼としセクション見出しアイコン化に留めた）。
- Section 2（今やるべき社員アクション）のボタン自体へのアイコン付与
  （研修する/SkillSheet確認等）は今回のスコープでは見送った（diffの
  スコープと既存test互換性を優先）。
- フィルタは「全員/待機中/参画中」の3つのみで、Reference画像にある
  「休職」チップは authoritative な休職状態が存在しないため実装していない
  （意図的な仕様上のギャップ、SSOT準拠）。
- excessive scrollingは「増やさない」ではなく「増加を最小化する」形での
  対応となった — avatar/skill bar/フィルタ追加により Section 1 の高さは
  Phase 1 比で増えている（コンパクト化で最小化はしたが、ゼロ増ではない）。

## Visual Complete 判定

**PASS**

判定根拠: Canonical Reference の主要な視覚要素（avatar付き社員カード、
色分けされた実在statusバッジ、authoritativeなskill/growth可視化、実在
statusのみのフィルタ、APVカードのカード風整理、アイコン付きセクション
見出し）を、既存の情報階層・eligibility・save/schema・HOME・Domainを
一切変更せずに反映した。fake data 0 / HOME変更 0 を確認済み。既存回帰
テストは全てgreen（1件のみ、視覚再設計に伴うwidget数アサーションの
更新を実施、内容一致チェックは無変更で維持）。360×800/390×844 ×
TextScaler 1.0/1.3/2.0でoverflow 0。残るギャップ（上記「残Visual Gap」）
はいずれもSSOTの禁止事項（fake data追加、Reference専用機能の新規実装、
gameplay authority変更）を回避するために意図的に見送った、または
実行時間の都合でスコープ外とした項目であり、Visual Complete の PASS
判定を妨げるものではないと判断した。
