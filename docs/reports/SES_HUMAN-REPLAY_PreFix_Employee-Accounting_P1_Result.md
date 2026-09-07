# SES Human-Replay Pre-Fix — Employee/Accounting P1 — Result

STATUS: **完了**

GOVERNING SSOT: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`

## BASE SHA

`bec4bbd699df4ce3d7b2b41423b48c37f7cd6d94`（`git fetch origin` で確認した
作業開始時点の最新 `origin/main` — PR #196 "SES Accounting Visual Complete"
マージコミット。PR #197 "SES Menu Visual Complete" は未マージのopen PRで
あり、本ブランチのbaseには含まれない）。

作業開始前、ローカルブランチ `claude/ses-human-replay-pre-fix-c3ficx` は
無関係の古いコミット（`f4ca78f` "Phase 0A/0B: SES domain models and random
generators"）を指したまま停止していた。このコミットは
`git merge-base HEAD origin/main` で確認した通り最新 `origin/main` の
祖先そのものであり、このブランチ固有の未マージコミットは存在しなかったため、
`git reset --hard origin/main` で最新mainへ作り直してから着手した。

## branch / final HEAD

- branch: `claude/ses-human-replay-pre-fix-c3ficx`
- final HEAD: `101b08bad9fd5de9348eb77640dafb2751fa63b2`（この報告書自体を
  含むコミット。この後PR作成のみ行うため、PR自体はこのコミットへの追加
  変更を含まない）

## 対象AUDIT（参照ドキュメントの不在について）

指示で参照された以下のドキュメントは、`origin/main` にも、PR #197
（`claude/ses-menu-visual-complete-pqxly1`）を含む全リポジトリブランチにも
**存在しなかった**（`git ls-tree -r` で全ブランチを走査して確認済み）:

- `docs/reports/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_Fresh-Audit-v2.md`
- `docs/reports/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Fresh-Audit-v2.md`
- Employee Canonical Reference 01/02、Accounting Canonical Reference 06
  （`docs/design/references/` 配下に "Canonical Reference" と明示された
  該当ファイルは存在せず、既存の `SES_TAB-UI_REFERENCE_2026-09-05/` 一式のみ
  確認できた）

`SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Result.md`
（PR #196、直前タスク）が同様の状況で確立した前例
（"Fresh-Audit.md was not present... 指示に従い、タスク本文が与えたP0/P1
ゴール自体をAuditの結論として扱い、それに基づいて実装した"）に倣い、
本タスクでもタスク本文に列挙されたP1項目自体を確定済み監査結論として扱い、
実装した。

## 目的

Human Replay（実プレイヤーによる手動プレイテスト）着手前に、タスク本文で
確定したP1項目のみを最小修正する。Section 1/2の全面IA再設計、既存
action/eligibility/keys/command wiring、Finance/Balance計算、Domain/Save/
schema、Month transition、HOME、Menu（PR #197）には一切触れない。

## Employee P1

### P1-1 / P1-3: 「今やるべき社員アクション」の大型・重複カード圧縮

対象: `ec(i)`（Section 2の主要アクションカード）、
`employeeConditionCard(a)`（昇給フロー）、`founderFollowUpCard(e)`
（Issue #167フォローアップ）— いずれもSection 2に描画される3種のカード。

問題: 3枚とも冒頭で社員名を `fontSize: 16, FontWeight.bold` の大きな
見出しとして再掲していた。この同じ社員名は、直前のSection 1
（社員一覧・現在状態）のroster行に、ポートレート・ステータスバッジ付きで
既に表示されている（`_employeeRosterCard`）。1人プレイの間は視覚的に
気にならないが、採用が進んで社員が増えるほど、Section 2の各カードの
先頭で同じ名前が繰り返し大きく表示され、"current state → next action"
の把握までのスクロール量が増える。

修正: 3カードとも、社員名Textを `fontSize: 16 bold` から
`fontSize: 12, FontWeight.w600, color: onSurfaceVariant`（キャプション
相当）へ縮小し、名前直後のスペーシングも詰めた（Card paddingを
`EdgeInsets.all(12)` → `EdgeInsets.symmetric(horizontal: 12, vertical:
10)`、名前後のSizedBoxを4/8px→2/6pxへ）。**名前自体は削除していない**
— 複数社員状態ではSection 2の各カードが単一の直近roster行と隣接すると
限らないため、識別情報としての名前は残しつつ、視覚的な優先度をアクション
本体（stepper・ボタン・研修カード）より下げた。

変更していないもの: `readyForFieldSales`・stage分岐・
`FilledButton.onPressed`ハンドラ・全キー（`public-demo-field-sales-lock-*`
等）・field-sales lock bannerの文言（Issue #168 Finding Bで確定した
truthfulness copyであり、3本のスナップショットテスト
`public_demo_01_suzuki_sales_lock_test.dart` /
`_reentry_test.dart` / `_yearend_boundary_test.dart` が exact 3-line
配列で厳密pinしているため、リスクに対して得るものが小さいと判断し
非対象とした）・`internalTrainingCard`の説明文（同様に
`public_demo_01_internal_training_explanation_test.dart` がpinしている）
・`PublicDemoSalesProgress`（営業stepper — Employee/Salesタブ共有ウィジェット
であり、変更するとSales Visual Complete領域まで影響範囲が広がるため
非対象とした）。

### P1-6: filter chipの実hit target

対象: `_employeeStatusFilterChips`（社員一覧セクションの全員/待機中/参画中
フィルタ）。

実測: 新規widget test
（`public_demo_employee_visual_complete_test.dart`
「every filter chip's real hit-test box... is at least 48x48dp」）で
修正前の実サイズを計測したところ、`tester.getRect` の高さは約26-28dp
（vertical padding 6+6 + 12pxフォントの行高）で、SSOTの実務上のタップ
ターゲット48dp基準を下回っていた（既存のVisual Complete報告書自身も
"filter chip は独自の compact InkWell pill — Material ChoiceChip の
既定タップ領域より縦方向を詰めた" と明記しており、既知のトレードオフ
だった）。

修正: `InkWell`の子を`ConstrainedBox(minHeight: 48, minWidth: 48)`で
包み、`BoxConstraints`の最小値をタップ領域に強制した。最初の実装では
中央寄せに`Center`を使ったが、`Wrap`内で`Center`（widthFactor/
heightFactorを指定しない`Align`のデフォルト挙動）は「利用可能な最大幅
まで拡張する」動作になり、3つのchipが横一列の compact pill ではなく
縦積みの全幅バーになってしまうリグレッションを実機screenshotで発見した
（下記screenshotsのAFTER画像は修正後の最終版）。`Align(widthFactor: 1,
heightFactor: 1)`に変更することで、パディング込みのテキストサイズへ
shrink-wrapしたうえで48dp未満だけを引き上げる正しい挙動に修正した。
タップハンドラ・キー・フィルタロジックは無変更。

## Employee: 採用後の複数社員状態での検証

`test/game/public_demo/public_demo_aggregate_test.dart`のP1-4テストと
同じ実コマンド連鎖（`completeInterview` → `acceptOffer` →
`closeApril`/`closeMay`）で、pool applicant 2名を実際に採用・入社させ、
創業社員2名と合わせて **4名の社員が同時に存在する状態**
（`workflow.engineers.length == 4`）を作るfixtureを新規追加した
（`fourEmployeesAtMonth6`）。この状態で:

- Section 1のroster行が4名分すべて表示される
- Section 2の圧縮後カードが4名分連続しても例外・overflowが発生しない
- 360×800/390×844 × TextScaler 1.0/1.3/2.0の全組み合わせでhorizontal
  overflow 0

を新規widget test群で確認した（全件green — 詳細は下記テスト結果）。

## Accounting P1

### P1（前月比の意味論修正）

問題: `_accountingFundStatusSection()`が「前月比
±¥X」という文言で表示していた値は、実際には
`PublicDemoState.latestMonthlyCashFlow!.netCashMovement`
（`closingCash - openingCash`、直近に確定した決算月**単体**の収支）
であり、「今月と前月の値を比較した差分」ではない。「前月比」という
文言は「2つの月の値を比較している」という誤読を誘発する
（例: 決算後に研修/採用媒体費を使って`s.cash`が変動しても、この値
自体は直近決算月の確定値のまま変わらないため、"前月比較" という
フレーミングは特に誤解を招きやすい）。

修正: 表示文言を「前月比」から「前回決算の収支」へ変更した
（`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`の
`_accountingFundStatusSection()`、1箇所のみ）。この語は既にこの画面の
別箇所（`最終決算月: ${publicDemoMonthLabel(...)}`）で確立済みの
「決算」という語彙と一貫しており、"直近の決算で確定した収支の実額"
という意味を、比較であるかのような誤読なしに伝える。

**Finance/Balance計算は一切変更していない** — `netCashMovement`
getter自体（`lib/game/public_demo/public_demo_monthly_cash_flow.dart:67`,
domain層）や、`flow.netCashMovement`を読む箇所（表示層1箇所のみ）の
計算ロジックはtouchしていない。変更は表示文言の1つの文字列リテラル
のみ。

### 決算後に研修/採用媒体支出を行ったケースのテスト

新規widget test（`public_demo_accounting_visual_complete_test.dart`
「前回決算の収支 stays pinned to the prior close」）:

1. 4月決算済み（5月）状態を作る（`publicDemoAggregateAtMonth(5)`）。
2. `aggregate.selectInternalTraining(engineerId)` で社内研修を選択
   （`PublicDemoInternalTrainingTransaction`が即座に`s.cash -= 30000`
   することをfixture sanityとして確認）。
3. さらに `aggregate.recruit(PublicDemoRecruitmentMedium.engineer)`
   で採用媒体（¥100,000）を購入（同様に即座に`s.cash`が減ることを確認）。
4. この2つの支出は`latestMonthlyCashFlow`（4月決算の記録）の
   `month`/`netCashMovement`を一切変えないことを確認。
5. 会計タブを描画し、「前回決算の収支」の文言＋金額が**4月決算時点の
   確定値のまま**表示され、`現在の現預金`だけが支出後の値に変わって
   いることを確認。

この結果は、新しい文言「前回決算の収支」が指す意味（直近決算月**単体**
の確定収支であり、その後のリアルタイム支出とは独立）を実際のコマンド
連鎖で裏付けている。

## 禁止事項の遵守確認

- HOME変更: 0（`git diff --stat -- lib/presentation/home/` 差分なし。
  `git diff --stat -- lib/` は
  `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` と
  `lib/ui/public_demo/public_demo_accounting_visual.dart` の2ファイルのみ）
- Menu / PR #197変更: 0（PR #197のbranch
  `claude/ses-menu-visual-complete-pqxly1`には一切触れていない。本ブランチ
  は最新`origin/main`からの新規branchであり、PR #197のheadを含まない
  ため競合しない）
- Domain/Save/schema/Finance/Balance/Month transition変更: 0
  （`git diff --stat -- lib/game/` 差分なし。`lib/ui/`配下2ファイルの
  みが変更対象で、いずれも表示文言・padding・spacing・tap-target
  constraintのみ）
- 新機能/fake data追加: 0（新規UIウィジェット・新規状態・架空データは
  一切追加していない。既存authoritative値の表示スタイルと文言のみ変更）
- グローバルTheme変更: 0（`lib/ui/theme.dart`は無変更。色は既存の
  `Theme.of(context).colorScheme.onSurfaceVariant`を再利用したのみ）

## テスト結果

（Flutter 3.44.9 / Dart 3.12.2 — `flutter --version`
出力を確認。本リポジトリCIワークフロー（`.github/workflows/e2e.yml`等）
と同一メジャーバージョン系列）

### flutter analyze

```
$ flutter analyze
No issues found!
```

### 新規/修正テスト（Employee + Accounting、対象ファイル14本）

```
$ flutter test \
  test/ui/public_demo/public_demo_employee_ui_phase1_test.dart \
  test/ui/public_demo/public_demo_employee_visual_complete_test.dart \
  test/ui/public_demo/public_demo_active_project_visibility_test.dart \
  test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart \
  test/ui/public_demo/public_demo_founder_follow_up_dialog_test.dart \
  test/ui/public_demo/public_demo_raise_dialog_test.dart \
  test/ui/public_demo/public_demo_growth_result_card_test.dart \
  test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart \
  test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart \
  test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart \
  test/ui/public_demo/public_demo_accounting_visual_complete_test.dart \
  test/ui/public_demo/public_demo_accounting_ui_phase1_test.dart \
  test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart \
  test/ui/public_demo/public_demo_monthly_cash_flow_card_test.dart
→ 148/148 tests passed
```

内訳の主な新規テスト:
- filter chip 48dp hit-target測定（Employee visual complete）
- 4名同時在籍状態でのSection 1/2描画・overflow 0（Employee visual
  complete、360×800/390×844 × TextScaler 1.0/1.3/2.0）
- 「前回決算の収支」が決算後支出の影響を受けないことの確認（Accounting
  visual complete）
- `public_demo_employee_ui_phase1_test.dart`の既存テスト1件
  （SkillSheet確認ボタンのtap）を、filter chip高さ変更でボタンが
  デフォルトテストviewportの折り返し外に出たため、`ensureVisible`を
  追加して修正（ロジック・アサーション自体は無変更）。

既存のfield-sales lock banner exact-string pinning
（`public_demo_01_suzuki_sales_lock_test.dart` /
`_reentry_test.dart` / `_yearend_boundary_test.dart`）は無修正のまま
全緑（本タスクではlock bannerの文言・構造に触れていない）。

### 必須回帰: `test/ui/public_demo` フル

```
$ flutter test test/ui/public_demo
→ 454/454 tests passed
```

（既存447件 + 本タスクの新規7件（filter chip 48dp測定1件 + 4名同時在籍
状態でのoverflow確認6件）。既存テストは、`public_demo_employee_ui_phase1_
test.dart`の1件へのensureVisible追加を除き、無修正のまま全緑）

### 必須回帰: `test/game/public_demo` フル

```
$ flutter test test/game/public_demo
→ 520/520 tests passed
```

（Domain層は無変更のため、この結果は変更前と同一。念のため実行し確認済み）

### full `flutter test`

```
$ flutter test
→ 1762/1762 tests passed
```

（リポジトリ全体 — `test/ui/public_demo`/`test/game/public_demo`に加え、
`test/presentation/`・`test/domain/`・`test/widget_test.dart`等、本タスクが
一切変更していない領域を含む全テスト。時間内に実行完了した）

### git diff --check

```
$ git diff --check
（差分なし、exit 0 — whitespace error なし）
```

## screenshots

- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_EMPLOYEE_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_EMPLOYEE_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_EMPLOYEE_AFTER_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_EMPLOYEE_AFTER_390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_ACCOUNTING_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_ACCOUNTING_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_ACCOUNTING_AFTER_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_ACCOUNTING_AFTER_390x844.png`

撮影スクリプト: 既存の `e2e/scripts/ses-employee-visual-complete-screenshot.mjs`
/ `ses-accounting-visual-complete-screenshot.mjs`（static-server +
Playwright Chromium、`flutter build web --release`の実ビルドを
`?e2e=1#/public-demo-01`から各タブへ遷移して撮影）。BEFORE画像は
`git stash`でbase SHA（PR #196マージコミット）へ一時的に戻して同じ
スクリプトでビルド・撮影し、直後に`git stash pop`で作業内容を復元して
取得した。

Employee AFTER画像で確認できる変化: Section 2の社員名が大きな太字見出し
から小さなキャプションへ縮小され、フィルタchip（全員/待機中/参画中）が
48dp相当の高さへ拡大（横一列のcompact pillレイアウトは維持）。

Accounting画面はスクリプトの制約上4月初期状態（月次決算未発生）のみ
撮影しており、「前回決算の収支」行はそもそも非表示のため
BEFORE/AFTERの画像上の差分はない（PR #196の前例と同じスコープ判断 —
月送り操作を伴う5月以降の状態再現はE2Eスクリプトでは複雑になるため、
文言変更の検証は上記widget test（exact string assertion）で実施した）。

## Visual判定

**PASS**

判定根拠: Employee/Accounting両タブとも、既存の情報階層・
eligibility・save/schema・HOME・Domain・Finance/Balance計算・Menu
(PR #197)を一切変更せずに、タスク本文が確定したP1項目（Section 2の
大型・重複カード圧縮、filter chip 48dp化、前月比の意味論修正）を
反映した。fake data 0 / HOME変更 0 / Menu変更 0 / Domain・Finance・
Balance・Month transition変更 0 / 新機能追加 0 / グローバルTheme変更 0
/ horizontal overflow 0（360×800・390×844 × TextScaler 1.0/1.3/2.0、
複数社員状態を含む）を確認済み。既存Employee/Accounting Visual
Completeテスト（148件、うち1件は同一アサーションのままensureVisible
追加のみ）と`test/ui/public_demo`/`test/game/public_demo`フル回帰は
全緑。

## Human Replay blocker残存

**NO**

本タスクでスコープに含めたP1項目（Section 2カード圧縮・filter chip
tap target・前月比表示の誤解防止）はすべて修正・検証済み。ただし、
これは「タスク本文が列挙したP1項目」に対する完了であり、`Fresh-Audit-v2`
文書自体が存在しなかった（上記「対象AUDIT」参照）ため、その文書が
仮に存在していた場合に追加で列挙されていたはずのP1項目の有無は
本タスクの範囲では検証できていない。Human Replayを開始した後、
その文書に相当する監査が別途行われる場合は、本報告書の内容と
突き合わせて差分を確認することを推奨する。
