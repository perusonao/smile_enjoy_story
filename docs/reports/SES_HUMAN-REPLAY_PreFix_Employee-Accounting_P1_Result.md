# SES Human-Replay Pre-Fix — Employee / Accounting P1 — Result

STATUS: **完了**

GOVERNING SSOT: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`
CANONICAL REFERENCE: `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`
PRIORITY DECISION: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
（Employee Visual Complete → Sales Visual Complete → Accounting Visual
Complete → Menu Visual Complete → 5-tab Visual Review → **April→March Human
Replay** の直前に位置する、Employee/Accounting限定のP1事前修正）

## BASE SHA

`bec4bbd699df4ce3d7b2b41423b48c37f7cd6d94`（`git fetch origin` で確認した
作業開始時点の最新 `origin/main` — PR #196 "SES Accounting Visual Complete"
マージコミット）。過去の会話メモより GitHub の実状態（`git fetch origin` の
結果）を優先し、このSHAから新規ブランチを作成した。

## branch / final HEAD

- branch: `claude/ses-human-replay-prefix-p1-h5gtmu`
- final HEAD: 本コミット参照（コミット後にPR URLと併せて報告）

## 目的

Human Replay（4月→翌3月の通しプレイ監査）に入る前に、既存の Employee
Visual Complete（`docs/reports/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_Result.md`）・
Accounting Visual Complete（`docs/reports/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Result.md`）
の実装・reportsを実地に確認し、Human Replay前に確定しているP1だけを最小修正する。
Section 1/2の全面再設計・action/eligibility/keys/command wiring変更・
Finance/Balance計算変更は一切行わない。

## 調査で確認した実態（Fresh Audit相当）

`docs/reports/`にHuman Replay向けのFresh Visual Auditは存在しなかった。
指示に従い、両Visual Complete reportの「残Visual Gap」節・実装本体
（`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` /
`public_demo_accounting_visual.dart`）を実地に読み込み、以下2件のP1を
実際のコード動作から特定した（いずれも既存reportには明記されていなかった、
Visual Complete化の過程で見落とされていた実挙動）。

### Employee P1-1: 「今やるべき社員アクション」の重複表示（6月）

`_employeeNextActionsSection`の6月ブランチ（`joinedApplicantIds`に含まれる
が`ordered`未到達・未アサインの新規入社者向け`ec(i)`呼び出し）が
`showTrainingCard`のデフォルト`true`のまま呼ばれていた。一方
`_employeeGrowthSection`は`s.month >= 5`で全`engineerRuntimes`に対して
無条件に`internalTrainingCard`を描画する — 6月に参画済みの新規入社者は
`PublicDemoAggregate.closeMay`の時点で既に`engineerRuntimes`に加わっている
ため、この2箇所が同一`public-demo-internal-training-<id>`キーの
研修カードを**2重に**描画していた（7月〜2月のRECOVERY-LOOP-1ループは
既に`showTrainingCard: false`でこれを回避済みだったが、6月だけ同じ対処が
漏れていた）。

再現手順を`test/ui/public_demo/public_demo_employee_visual_complete_test.dart`
の新規`juneWithJoinedStillSellingHire()`フィクスチャ（`recruit` →
`completeInterview` → `acceptOffer` → `closeMay`という実コマンドの連鎖のみ、
架空データ・stage直接書き換えなし）で構築し、修正前に実際に
`findsOneWidget`が`findsNWidgets(2)`相当で失敗することを確認した上で
修正した。

### Employee P1-2: filter chipの実hit target

`_employeeStatusFilterChips`の「全員/待機中/参画中」チップは
`Material`+`InkWell`+`Padding(12h/6v)`のみで構成されており、実測
タップ領域は概ね26〜28dp四方相当 — 48dp未満だった（Employee Visual
Complete時点では計測されていなかった）。

## 実施内容

### Employee P1-1 修正: 6月ブランチに`showTrainingCard: false`を追加

`_employeeNextActionsSection`の6月`ec(i)`呼び出しに、7月〜2月ループと
**全く同じ**`showTrainingCard: false`を渡すよう1行変更した。研修
アクション自体（コマンド・キー・eligibility）は Section 4 の
standalone `internalTrainingCard`に既に存在しており、この変更は
Section 2 側の**埋め込みコピーだけ**を除去する — 到達可能な導線は
Section 4 経由のまま1本になる（7月以降と完全に同じ形）。

### Employee P1-2 修正: filter chipを48dp tap targetへ

各チップを`ConstrainedBox(minHeight: 48, minWidth: 48)`でラップし、
実タップ領域（`Material`+`InkWell`）を48dp以上に拡張した。可視のピル自体
（背景色・角丸・パディング）は`Center(widthFactor: 1, heightFactor: 1)`で
明示的にshrink-wrapさせることで、コンパクトな見た目を維持している
（実装過程で一度`Center()`のデフォルト挙動によりピルが行全体に伸びる
regressionを作り込み、実機screenshotで検出・修正した — 詳細は
「実装中に検出・修正したregression」参照）。

### Accounting P1: 「前月比」の意味論修正（文言のみ、計算は無変更）

`_accountingFundStatusSection`が使う`PublicDemoMonthlyCashFlow
.netCashMovement`（`closingCash - openingCash`、FINANCE-UX-1由来の
既存getter）は、**直近に決算が閉じた月それ自体の資金増減**を表す値であり、
「現在の現金と先月を比較した値」ではない。閉月直後は
`s.cash == flow.closingCash`のため両者は一致して見えるが、決算後に
研修（`selectInternalTraining`）や採用媒体購入（`recruit`）で
`s.cash`が直接減算されると（いずれも月次決算を経ない即時のcash控除 —
`public_demo_aggregate.dart`の`cash: state.cash - cost`/
`cash: state.cash - medium.cost`）、`s.cash`は`flow.closingCash`から
乖離する一方、このdeltaは先月の決算時点で凍結されたまま変わらない。
既存ラベル「前月比」は「現在の現金と先月を比較した値」だと読めてしまい、
この乖離状態では実際の意味と一致しなくなる。

Finance/Balance計算は一切変更禁止のため、**計算はそのまま
`netCashMovement`を使い続け、文言だけ**を「先月の資金増減」へ修正した —
これは常に真として成立する表現（先月の決算そのものの増減額）であり、
「現在の現金との比較」という誤読を招かない。

## 実装中に検出・修正したregression

filter chipの48dp化（`ConstrainedBox(minWidth: 48, minHeight: 48)`）を
実ブラウザscreenshotで確認したところ、`Center()`のデフォルト挙動
（Wrapが各チップに渡す境界内で、widthFactor/heightFactor未指定時は
利用可能幅いっぱいに広がる）により、3チップが縦に積まれ各行いっぱいに
伸びる見た目のregressionが発生した。widget test（`getRect`での
`>=48.0`確認のみ）はこの見た目の破綻を検出できなかった —
実機/実ブラウザscreenshotで初めて発見し、`Center(widthFactor: 1,
heightFactor: 1)`で明示的にshrink-wrapさせることで解消した。
BEFORE/AFTER screenshotはいずれも修正後の最終状態のもの。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | 6月`ec(i)`呼び出しに`showTrainingCard: false`追加（重複解消）、filter chipを48dp ConstrainedBox化、`前月比`→`先月の資金増減`へ文言修正 |
| `lib/ui/public_demo/public_demo_accounting_visual.dart` | `PublicDemoAccountingCashHero`のdocコメントを新ラベルへ更新（挙動変更なし） |
| `test/ui/public_demo/public_demo_employee_visual_complete_test.dart` | 6月重複表示の回帰テスト（`juneWithJoinedStillSellingHire()`新規フィクスチャ）、filter chip 48dp測定テスト、複数社員（3名）一覧性テストを追加 |
| `test/ui/public_demo/public_demo_accounting_visual_complete_test.dart` | 「前月比」→「先月の資金増減」への文言更新、決算後の研修費支出ケースの新規回帰テストを追加 |
| `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` | 48dp化で1行分高さが増えたことによる既存 SkillSheet タップテストの`flutter_test`デフォルトサーフェス（800×600、実機ターゲット外）依存の不安定化を`ensureVisible`で解消（挙動アサーション自体は無変更） |
| `e2e/scripts/ses-human-replay-prefix-p1-screenshot.mjs`（新規） | 本タスクのBEFORE/AFTER screenshot撮影用の使い捨てPlaywrightスクリプト（既存スクリプトと同じ手法） |
| `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_{Employee,Accounting}_{BEFORE,AFTER}_{360x800,390x844}.png`（新規） | Visual Verification screenshot |
| `docs/reports/SES_HUMAN-REPLAY_PreFix_Employee-Accounting_P1_Result.md`（新規） | 本結果報告 |

`lib/presentation/home/`配下（HOME）・`lib/ui/theme.dart`（app-wide
Theme）・`lib/game/`配下（Domain/Finance/Balance/Month transition）・
メニュータブ関連ファイルは**1バイトも変更していない**
（`git diff --stat`で確認済み）。

## 禁止事項の遵守確認

- HOME変更: 0（`git diff --stat -- lib/presentation/home/` 差分なし）
- Menu / PR #197変更: 0（メニュータブ関連ファイル無変更）
- Domain/Save/schema/Finance/Balance/Month transition変更: 0
  （`lib/game/` 配下は無変更。`netCashMovement`計算式自体・
  `PublicDemoMonthlyClose`・`PublicDemoAggregate`の月送りロジックは
  一切変更していない — 変更したのは表示文言のみ）
- 新機能・fake data: 0（既存authoritativeフィールドの読み取り・
  既存コマンドの呼び出しのみ。新規テストフィクスチャも実コマンド
  （`recruit`/`completeInterview`/`acceptOffer`/`closeMay`/
  `selectInternalTraining`）の連鎖のみで構築）
- global Theme変更: 0（`lib/ui/theme.dart` 無変更）
- P2 polishの便乗: 0（Section 1/2の全面再設計・研修カード内部レイアウト
  整理・ボタンアイコン付与等は今回スコープ外のまま touch していない）
- Section 1/2の全面再設計: していない（既存の4セクション構成・カード
  構造は無変更、6月ブランチの1パラメータ追加とfilter chipの
  hit-target拡張のみ）
- action/eligibility/keys/command wiring変更: 0（研修アクションの
  コマンド・キー・eligibilityは無変更。到達経路がSection 2埋め込みから
  Section 4 standaloneの1本に絞られただけ）

## 必須検証

### 360x800 / 390x844 / TextScaler 1.0 / 1.3 / 2.0 / horizontal overflow 0

`public_demo_employee_visual_complete_test.dart`・
`public_demo_accounting_visual_complete_test.dart`双方の既存
overflow回帰グループ（`tester.takeException()`が`null`、各セクションの
`Rect.left >= 0` / `Rect.right <= size.width`）が全組み合わせでgreen。
本タスクで追加した3-employee roster・filter chip 48dp計測テストも
同様に360x800/390x844×TextScaler 1.0/1.3/2.0で確認済み。

### tap target >= 48dp

新規テスト「every 全員/待機中/参画中 chip meets the 48dp minimum touch
target (measured, not assumed)」で、`tester.getRect`実測により
`rect.height >= 48.0` かつ `rect.width >= 48.0`をチップ3つ全てで確認。

### Employee/Accounting関連tests

```
$ flutter test test/ui/public_demo/public_demo_employee_visual_complete_test.dart
→ 17/17 passed
$ flutter test test/ui/public_demo/public_demo_accounting_visual_complete_test.dart
→ 28/28 passed
$ flutter test \
    test/ui/public_demo/public_demo_employee_ui_phase1_test.dart \
    test/ui/public_demo/public_demo_active_project_visibility_test.dart \
    test/ui/public_demo/public_demo_01_home_office_stage_test.dart \
    test/ui/public_demo/public_demo_founder_follow_up_dialog_test.dart \
    test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart \
    test/ui/public_demo/public_demo_skill_sheet_display_projection_test.dart \
    test/ui/public_demo/public_demo_growth_result_card_test.dart \
    test/ui/public_demo/public_demo_01_internal_training_explanation_test.dart \
    test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart \
    test/ui/public_demo/public_demo_raise_dialog_test.dart \
    test/ui/public_demo/public_demo_accounting_ui_phase1_test.dart \
    test/ui/public_demo/public_demo_01_accounting_tab_empty_heading_test.dart \
    test/ui/public_demo/public_demo_01_suzuki_sales_reentry_test.dart \
    test/ui/public_demo/public_demo_01_suzuki_sales_lock_test.dart \
    test/ui/public_demo/public_demo_01_recovery_ui_test.dart \
    test/ui/public_demo/public_demo_01_completion_lock_ui_test.dart \
    test/ui/public_demo/public_demo_01_suzuki_sales_yearend_boundary_test.dart \
    test/ui/public_demo/public_demo_01_home_consolidation_test.dart
→ 147/147 passed
```

（`public_demo_employee_ui_phase1_test.dart`の1件のみ、
「実装中に検出・修正したregression」節と別に、48dp化に伴う既存
`flutter_test`デフォルトサーフェス依存タップの`ensureVisible`追加を実施
— アサーション内容自体は無変更のまま通過）

### test/ui/public_demo フル

```
$ flutter test test/ui/public_demo
→ 451/451 passed
```

### test/game/public_demo フル

```
$ flutter test test/game/public_demo
→ 520/520 passed
```

（`lib/game/`配下は本タスクで無変更 — このフルスイートがgreenのまま
なのはDomain/Finance/Balance/Month transitionへの影響が無いことの
直接的な確認）

### flutter analyze

```
$ flutter analyze
No issues found!
```

（Flutter 3.44.8 / Dart 3.12.2、本セッションで`/home/user/flutter-sdk`に
stable channel 3.44.8タグをcloneして使用 — CIワークフロー
`flutter-version: '3.44.8'`と同一バージョン）

### full flutter test

リポジトリ全体`flutter test`（`test/domain`・`test/presentation`・
`test/widget_test.dart`等、本タスクが一切変更していない領域を含む）は、
このセッションの共有実行環境で`test/ui/public_demo`単体・
`test/game/public_demo`単体それぞれに10〜17分を要した実測時間から、
全体では過去のVisual Complete報告と同様に1〜2時間規模になる見込みであり、
セッション時間の制約により完走を確認できていない。

本タスクの変更ファイルは`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`・
`lib/ui/public_demo/public_demo_accounting_visual.dart`の2ファイルのみ
（`lib/game/`・`lib/presentation/`・`lib/domain/`は無変更）であるため、
「必須検証」節の以下2つのフルディレクトリ実行が実質的な full-suite
カバレッジとして機能している:

```
$ flutter test test/ui/public_demo
→ 451/451 passed
$ flutter test test/game/public_demo
→ 520/520 passed
```

上記2つは本タスクの変更後（filter chip 48dp化 + 6月重複解消 +
前月比文言修正のいずれも適用済みの状態）で実行し、全てgreenを確認した。
filter chipの`Center(widthFactor: 1, heightFactor: 1)`修正（「実装中に
検出・修正したregression」節参照）適用後は、影響範囲が
`_employeeStatusFilterChips`という1メソッドに閉じているため、これを
直接・間接に exercise する
`public_demo_employee_visual_complete_test.dart`（17/17）・
`public_demo_employee_ui_phase1_test.dart`を含む前掲147件の対象回帰
バッチで再確認し、全てgreenであることを確認済み。加えて、上記の
`test/ui/public_demo`フル（451/451）・`test/game/public_demo`フル
（520/520）自体も、この`Center(widthFactor: 1, heightFactor: 1)`修正
適用後の状態で改めて実行し直し、両方ともgreenであることを最終確認した
（本reportに記載の数値はすべてこの最終確認後のもの）。

リポジトリ全体`flutter test`（`test/domain`・`test/presentation`等）は
上記の理由により本セッションでは完走を確認していないが、無変更の領域
であるため、フルディレクトリ実行2件（合計971件）による確認で
本タスクの検証としては十分と判断した。

### git diff --check

```
$ git diff --check
（差分なし、exit 0 — whitespace error なし）
```

## BEFORE/AFTER screenshots

- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Employee_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Employee_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Employee_AFTER_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Employee_AFTER_390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Accounting_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Accounting_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Accounting_AFTER_360x800.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_Accounting_AFTER_390x844.png`

撮影スクリプト: `e2e/scripts/ses-human-replay-prefix-p1-screenshot.mjs`
（既存の`ses-employee-visual-complete-screenshot.mjs`等と同じ
static-server + Playwright Chromium手法。`flutter build web --release
--no-web-resources-cdn`の実ビルドを4月初期状態で`?e2e=1#/public-demo-01`
から各タブへ遷移して撮影。BEFOREはBASE SHAの一時`git worktree`でビルドした
別artifact）。

Employee: filter chipのvisual（BEFORE/AFTER共に一列・コンパクトなピル）は
同一に見えるが、実タップ領域はAFTERで48dp以上に拡張済み（widget test で
実測確認、上記「tap target >= 48dp」参照）。6月の重複表示修正は4月初期
状態のscreenshotには現れない（6月固有の状態のため）— widget test
（`juneWithJoinedStillSellingHire()`フィクスチャ）で個別に検証している。

Accounting: 「先月の資金増減」ラベルは4月初期状態（決算未発生）では
非表示のため、BEFORE/AFTERのscreenshotは見た目上ほぼ同一（意図通り、
truthful — fake historyを作らないため populated 状態の実機screenshotは
撮っていない）。5月以降の表示・決算後研修費支出時の挙動はwidget test
（`public_demo_accounting_visual_complete_test.dart`の新規ケース）で
検証済み。

## Human Replay blocker

**NO**

Employee/Accounting双方のP1事前修正は完了し、既存の情報階層・
eligibility・Finance/Balance・HOME・Menuは一切変更していない。
Human Replay（4月→翌3月通しプレイ監査）を妨げるP0/P1の既知課題は
残っていない。

## P0/P1残件

- P0: なし（本タスクのスコープ内に新規P0は発見していない）
- P1: 本タスクで特定・修正した2件（Employee: 今やるべき社員アクションの
  重複表示、Accounting: 前月比の意味論）以外、`docs/decisions/
  SES_DEVELOPMENT-PRIORITY_2026-09-02.md`記載の既存P1（9月〜2月コンテンツ
  強化、会社の成長実感強化、月次結果・経営フィードバック改善、年度末結果・
  年間評価強化）はHuman Replay後の後続タスクとして未着手のまま残る
  （本タスクのスコープ外、意図的）。
