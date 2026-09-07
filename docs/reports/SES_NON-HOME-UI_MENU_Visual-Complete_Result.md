# SES NON-HOME-UI MENU Visual Complete — Result

STATUS: **完了**

GOVERNING SSOT: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`
DEVELOPMENT PRIORITY: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
CANONICAL REFERENCE: `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`
（`07_Menu_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`、
実際にPNGを開いてVisual Referenceとして確認済み）

## BASE SHA

`bec4bbd699df4ce3d7b2b41423b48c37f7cd6d94`（`git fetch origin` で確認した
作業開始時点の最新 `origin/main` — PR #196 "SES Accounting Visual Complete"
マージコミット）。

作業開始前、ローカルブランチ `claude/ses-menu-visual-complete-pqxly1` は
古いSHA（`f4ca78f`, `docs/` ディレクトリ自体が存在しない、最新origin/mainの
祖先）を指したまま停止していたため、`git checkout -B
claude/ses-menu-visual-complete-pqxly1 origin/main` で最新mainへ作り直して
から着手した（このブランチに未マージの独自コミットは存在しないことを確認
済み）。

## branch / HEAD

- branch: `claude/ses-menu-visual-complete-pqxly1`
- HEAD: 本コミット時点（コミット後にPR URLと併せて報告）

## 対象AUDIT / IMPLEMENTATION PREP

`SES_NON-HOME-UI_MENU_Visual-Complete_Implementation-Prep.md` は working
treeにも全ブランチ履歴にも存在しなかった（`git log --all --diff-filter=A`
で確認）。Accounting Visual Complete
（`docs/reports/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Result.md`）が
同じ状況で採用した前例に倣い、タスク本文が与えたIMPLEMENT/PRESERVE/実装禁止
リストそのものを結論・変更計画として扱い、それに基づいて実装した。

## 目的

既存メニュータブの実プロダクションコンテンツ — `BuildInfoLabel`（ビルド
識別情報）と、collapsed-by-defaultの「開発・テストメニュー」（テスト用
「4月からやり直す」復元コントロール）— は**一切変更せず**、Canonical
Visual Reference の完成イメージへ visual（icon-led section header・
card形状・list-row・警告トーン・spacing・typography）を近づける「Visual
Complete」化を行った。

## 実施前の確認

`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`の2枚
（`07_Menu_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`）を実画像
として開いて確認した。Referenceのメニュータブは5画面
（メニュー(ホーム)/セーブ・ロード/ゲーム設定/チュートリアル・ヘルプ/
最初からやり直す）で構成されているが、タスクの「実装禁止」指示により、
このうち実装できるのは以下のみと判断した:

- 各画面に共通する視覚言語: icon付きのlist row（アイコン＋ラベル＋`>`）、
  白背景・角丸・薄いボーダーの統一カード形状、icon-ledセクション見出し
- 「最初からやり直す」画面の警告トーン（赤い注意アイコン＋「すべての
  データが削除されます」の強い警告文脈＋赤系CTA）— ただし既存の
  「4月からやり直す」は既存authorityのまま開発・テストメニュー配下に留め、
  常設のplayer-facing項目へ昇格させない（タスク本文の明示的指示）

セーブ/ロード一覧、難易度・表示・サウンド設定、チュートリアル、
ヘルプ・FAQ・お問い合わせ、このゲームについて、クレジット、メニュー専用の
ひよりのアドバイスカードは、いずれもauthoritativeなPublic Demo 0.1に対応する
実装が存在しない（`STRICTLY FORBIDDEN`指定と一致）ため、一切実装していない。

## 実施内容

### 1. Menu-local visual components/tokens（新規ファイル）

`lib/ui/public_demo/public_demo_menu_visual.dart`を新設し、
`public_demo_employee_visual.dart`/`public_demo_sales_visual.dart`/
`public_demo_accounting_visual.dart`と同じisolation方針（メニュータブの
ウィジェットからのみimportされ、`lib/presentation/home/`・`lib/ui/theme.dart`
（app-wide `SesTheme`）・他タブのvisualファイルには一切触れない、色値は
独立定義）で以下を実装した:

- `PublicDemoMenuCard` — 白背景・角丸12・`outlineVariant`ボーダー（他タブの
  Visual Completeが確立した同じカード形状を独立に再定義）
- `PublicDemoMenuBuildInfoRow` — ビルド識別情報の低強調行（小さい
  `info_outline`アイコン＋`BuildInfoLabel`）。`isAvailable`が`false`のときは
  何も描画しない（空の枠付きカードを残さない）
- `PublicDemoMenuListRow` — icon＋label＋展開/折りたたみchevronの
  タップ可能list-row（開発・テストメニューのトグル用）
- `PublicDemoMenuWarningCard` — icon-led警告トーンカード（テスト用操作の
  枠。Accountingの`caution`トーンと同じ配色を独立に再定義）

### 2. BuildInfo領域を低強調で整理（P0）

`_buildMenuTab`のBuildInfo表示を、`BuildInfoLabel`単体の裸のText表示から、
`PublicDemoMenuCard`＋`PublicDemoMenuBuildInfoRow`（小さいinfoアイコン付き）
の低強調な行へ整理した。`BuildInfo.isAvailable`が`false`（ローカルビルド等、
デプロイ識別情報が無い場合）のときは、この節自体を丸ごと描画しない —
既存の「空見出しを残さない」方針をそのまま踏襲した。`build-info-label`
キー・表示文字列（`Deploy: PR #N · shortSha` / `Deploy: shortSha`）は
1文字も変更していない。

### 3. 開発・テストメニューをReferenceのvisual languageへ整理（P0）

トグル（`public-demo-dev-menu-toggle`）を、`TextButton.icon`から
`PublicDemoMenuListRow`（icon＋ラベル＋境界線付きカード＋chevron）へ
再シェルした。キー・`onPressed`ハンドラー（`_isDevMenuExpanded`の
トグル）は完全に同一 — collapsed-by-default挙動、既存回帰テストの
`tester.tap(toggle)`パターンは無修正のまま通過する。

新規に`_sectionHeader('開発・テスト', icon: Icons.build_outlined)`を
トグルの上に追加し、他タブのicon-ledセクション見出しパターンと整合させた。

### 4. restart/test controlを警告トーンのカードとして整理（P0）

`_publicDemoTestControlsCard`（キー`public-demo-test-controls`）を、
`amber.shade50`の裸の`Card`から`PublicDemoMenuWarningCard`
（icon-led警告トーン、Accounting Visual Completeの`caution`トーンと同じ
配色を独立に再定義）へ再シェルした。「テスト用操作」という見出し・
「Public Demo 0.1の進行だけを初期状態へ戻します。」という本文テキストは
1文字も変更していない。「4月からやり直す」ボタン（キー
`public-demo-restart-april-button`）は、`OutlinedButton.icon`のまま
foreground/borderの色のみを警告系の赤（`0xFFB3261E`、Accountingの
`negative`トーンと同じ値）へ変更した — ラベル・`onPressed`
（`_confirmRestartFromApril`）は無変更。

`_confirmRestartFromApril`のダイアログ本体（`public-demo-restart-april-dialog`
/`-cancel`/`-confirm`、確認文言）、および`_restartGame`のクリア/reset
ロジックは**1行も変更していない**。

### 5. section/card/icon/spacing/typographyの整合（P0）

`_buildMenuTab`全体に、他タブのVisual Completeが既に確立している
`_sectionHeader(title, icon: ...)`パターンを適用した — トップに
icon-led「メニュー」見出し（`Icons.menu_outlined`）を追加し、その下へ
BuildInfo行（利用可能な場合のみ）、その下へ「開発・テスト」セクション
（見出し＋トグル＋（展開時）警告カード）を配置した。

### 6. 既存Bottom Navigationは変更しない

`NavigationBar`・5つの`NavigationDestination`（キー・アイコン・ラベル）は
一切変更していない。

### 7. 「4月からやり直す」の既存authority維持

タスク本文の明示的指示どおり、「4月からやり直す」は開発・テストメニュー
配下（collapsed-by-default）のまま維持し、常設のplayer-facing項目へ
昇格させていない。倒産/3月資金不足カードの`public-demo-restart-button`、
Year-Endカードの`onReplay`（いずれも`_confirmRestartFromApril`/
`_restartGame`を共有する既存の同一canonical restart経路）も無変更。

## 変更ファイル

| ファイル | 変更内容 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_buildMenuTab`/`_publicDemoDevMenuSection`/`_publicDemoTestControlsCard`のvisual再構成（icon-led見出し、低強調BuildInfo行、list-rowトグル、警告トーンカード） |
| `lib/ui/public_demo/public_demo_menu_visual.dart`（新規） | メニュータブローカルのvisual building blocks |
| `test/ui/public_demo/public_demo_menu_visual_complete_test.dart`（新規） | 新Visual構造のwidget test（26件） |
| `e2e/scripts/ses-menu-visual-complete-screenshot.mjs`（新規） | Visual Verification screenshot撮影用の使い捨てPlaywrightスクリプト |
| `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_{BEFORE,AFTER,AFTER_Expanded}_{360x800,390x844}.png`（新規） | Visual Verification screenshot |
| `docs/reports/SES_NON-HOME-UI_MENU_Visual-Complete_Result.md`（新規） | 本結果報告 |

`lib/presentation/home/`配下・`lib/ui/theme.dart`・`lib/game/`配下・
`public_demo_employee_visual.dart`・`public_demo_sales_visual.dart`・
`public_demo_accounting_visual.dart`・`public_demo_home_presentation_components.dart`
は**1バイトも変更していない**（`git diff --stat`で確認済み、差分なし）。

## EXISTING / DEV-ONLY / ABSENT 分類

| # | Reference要素 | 分類 | 対応 |
|---|---|---|---|
| 1 | ビルド/デプロイ識別情報表示 | EXISTING | `PublicDemoMenuBuildInfoRow`で低強調に整理（visual complete） |
| 2 | 「4月からやり直す」データ初期化 | DEV-ONLY | 既存authorityのまま開発・テストメニュー配下に維持。警告トーンカードとして整理（visual complete）。常設player-facing項目への昇格は実施せず |
| 3 | icon-ledリスト構成・統一カード形状 | EXISTING（visual patternとして） | メニュータブ自身のコンテンツ（1・2）へ適用（visual complete） |
| 4 | セーブ/ロード一覧・手動セーブ | ABSENT | 実装禁止（明示指示）。未実装 |
| 5 | 難易度設定 | ABSENT | 実装禁止。未実装 |
| 6 | 表示設定 | ABSENT | 実装禁止。未実装 |
| 7 | サウンド設定 | ABSENT | 実装禁止。未実装 |
| 8 | チュートリアル | ABSENT | 実装禁止。未実装 |
| 9 | ヘルプ・FAQ・お問い合わせ | ABSENT | 実装禁止。未実装 |
| 10 | このゲームについて（About） | ABSENT | 実装禁止。未実装 |
| 11 | クレジット | ABSENT | 実装禁止。未実装 |
| 12 | メニュー専用ひよりのアドバイスカード | ABSENT | 実装禁止。未実装 |

## intentional omissions（意図的な省略）

上記表の#4〜#12はすべて、Referenceには描かれているがauthoritativeな
Public Demo 0.1実装に対応する機能・データが存在しない、またはタスク本文の
「実装禁止」リストに明示的に含まれる要素であり、`SES_NON-HOME-UI_VISUAL-SSOT.md`
の「Reference/authoritative stateの優先順位」原則に従い実装していない。
fake data・fake機能は一切追加していない。

## tests / results

### flutter analyze

```
$ flutter analyze
No issues found! (ran in 4.4s)
```

（Flutter 3.47.2 / Dart 3.13.2、stable channel。本セッションで
`/home/user/flutter-sdk`にclone・使用）

### 新規: `test/ui/public_demo/public_demo_menu_visual_complete_test.dart`

```
$ flutter test test/ui/public_demo/public_demo_menu_visual_complete_test.dart
→ 26/26 tests passed
```

内容: icon-led「メニュー」見出しの存在確認、BuildInfo領域（低強調行の
構造・キー・利用可能/不可時の完全非表示）、開発・テストメニュートグルの
collapsed-by-default（`PublicDemoMenuListRow`型・警告カード非構築）と
展開/折りたたみ、既存の「4月からやり直す」確認ダイアログ（キー・文言・
cancel/confirmの既存semantics）の再確認、Reference-only要素
（セーブ/ロード・ゲーム設定・チュートリアル・ヘルプ/FAQ・このゲームに
ついて・クレジット・ひよりのアドバイス等の文字列）が一切出現しないことの
確認、他タブへの非流出（メニュー→ホーム→メニュー）確認、
360×800/390×844 × TextScaler 1.0/1.3/2.0 ×
collapsed/expanded/ビルド情報なしの全組み合わせでの
horizontal overflow 0（`tester.takeException()`）確認。

### 必須回帰: `test/presentation/build_info_test.dart` /
`test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart` /
`test/ui/public_demo/public_demo_01_persistence_test.dart`

```
$ flutter test \
  test/presentation/build_info_test.dart \
  test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart \
  test/ui/public_demo/public_demo_01_persistence_test.dart
→ 25/25 tests passed（無修正のまま全緑）
```

### 必須回帰: `test/ui/public_demo` フル

```
$ flutter test test/ui/public_demo
→ 471/471 tests passed
```

（445件の既存テスト + 本タスクの新規26件。既存テストは無修正のまま全緑。
Year-End・Accounting/Employee/Sales Visual Complete・HOME Freeze関連の
既存UIテストをすべて含む）

### 必須回帰: `test/game/public_demo` フル

```
$ flutter test test/game/public_demo
→ 520/520 tests passed
```

### full `flutter test`

必須ゲート（`flutter analyze`、新規テスト、`test/ui/public_demo`フル
471件、`test/game/public_demo`フル520件、build_info/bottom_nav/
persistence回帰）はすべてこのコミット時点で実行・確認済み・全緑。

リポジトリ全体`flutter test`（本タスクが一切変更していない領域を含む）は
「可能なら実行」の対象として実行を試みた。1回目の実行はローカル環境操作
（本タスク側のプロセス整理）により実行途中で中断され、その中断自体に
起因する無関係なエラー（`Bad state: Cannot close sink while adding
stream.` 等、プロダクション/テストコードとは無関係な
flutter_tools側のシャットダウンエラー）が記録されたため、その結果は
無効として扱った。2回目の実行を中断せずに完走させた:

```
$ flutter test
→ 1779/1779 tests passed
```

（リポジトリ全体 — 本タスクが一切変更していない領域を含む全テスト。
無修正のまま全緑）

### git diff --check

```
$ git diff --check
（差分なし、exit 0 — whitespace error なし）
```

## viewport / TextScaler results

360×800 / 390×844 × TextScaler 1.0 / 1.3 / 2.0 の全組み合わせ、かつ
collapsed / expanded / ビルド情報なしの3状態それぞれで、widget test
（`tester.takeException()`）による horizontal overflow 0 を確認した。
実ブラウザ（Playwright Chromium, `flutter build web --release
--no-web-resources-cdn`）でのAFTER/AFTER Expanded screenshotでも、
360×800・390×844いずれも視覚的なoverflowは確認されなかった。

## screenshots

- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_AFTER_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_AFTER_390x844.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_AFTER_Expanded_360x800.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_AFTER_Expanded_390x844.png`

撮影スクリプト: `e2e/scripts/ses-menu-visual-complete-screenshot.mjs`
（既存の`ses-accounting-visual-complete-screenshot.mjs`と同じ
static-server + Playwright Chromium手法。BEFOREはBASE SHA
（`bec4bbd6`）の`flutter build web --release --no-web-resources-cdn`実ビルド、
AFTER/AFTER Expandedは本タスク実装後の同ビルドを、`?e2e=1#/public-demo-01`
からメニュータブへ遷移して撮影。AFTER Expandedはさらに
「開発・テストメニュー」をタップして展開した状態）。

BEFORE/AFTER比較で確認できる差分:

| 項目 | BEFORE | AFTER | Reference |
|---|---|---|---|
| セクション見出し | なし（裸のDivider＋トグル） | icon-led「メニュー」見出し | icon付き見出し |
| BuildInfo領域 | ローカルビルドのためBEFORE/AFTERとも非表示（`BuildInfo.isAvailable=false`。widget testで別途確認済み） | 同左（低強調行として整理済み、利用可能時のみ表示） | — |
| 開発・テストメニュートグル | 裸の`TextButton.icon` | icon＋境界線付きカードのlist-row | list-item |
| テスト用操作カード（展開時） | 裸の`amber.shade50` Card | icon-led警告トーンカード＋赤系CTA | 警告アイコン付きカード |

ローカルビルドには`BUILD_COMMIT_SHA`/`BUILD_PR_NUMBER`が注入されないため、
BEFORE/AFTERいずれのscreenshotにもBuildInfo行自体は写らない（CI/実デプロイ
環境でのみ表示される既存挙動、本タスクで変更していない）。
`PublicDemoMenuBuildInfoRow`のキー・表示挙動はwidget test
（`test/ui/public_demo/public_demo_menu_visual_complete_test.dart`の
「BuildInfo area — low emphasis」group）で個別に確認済み。

## VERIFY

- fake data: 0（新規表示はすべて既存の`BuildInfo`/既存の開発・テスト
  コントロールの再シェルのみ、新しいデータ・数値・機能は一切追加していない）
- HOME changes: 0（`git diff --stat -- lib/presentation/home/` 差分なし）
- Employee changes: 0（`git diff --stat -- lib/ui/public_demo/public_demo_employee_visual.dart` 差分なし、`_buildEmployeesTab`関連コード無変更）
- Sales changes: 0（`git diff --stat -- lib/ui/public_demo/public_demo_sales_visual.dart` 差分なし、`_buildSalesTab`関連コード無変更）
- Accounting changes: 0（`git diff --stat -- lib/ui/public_demo/public_demo_accounting_visual.dart` 差分なし、`_buildAccountingTab`関連コード無変更）
- gameplay authority changes: 0（`git diff --stat -- lib/game/` 差分なし）
- horizontal overflow: 0（360×800/390×844 × TextScaler 1.0/1.3/2.0 ×
  collapsed/expanded/ビルド情報なし、新規テスト26件で確認）

## remaining gaps

- Referenceの他4画面（セーブ/ロード、ゲーム設定、チュートリアル/ヘルプ、
  最初からやり直す専用フルスクリーン）に対応する実装は、authoritativeな
  Public Demo 0.1にその機能自体が存在しないため未実装のまま残る
  （上記「intentional omissions」参照、タスク本文の実装禁止指示と一致）。
  これらはVisual Completeの範囲外であり、機能実装そのものが将来別タスクと
  して発生しない限り解消しない。
- ローカルCI相当のビルドではBuildInfoが常に非表示のため、実際にPRの
  SHA/PR番号付きでBuildInfo行が表示された状態のブラウザscreenshotは
  未取得（widget testでのみ確認）— Employee/Sales/Accounting Visual
  Completeも同様のスコープ判断を取っている。

## Visual Complete 判定

**PASS**

判定根拠: Canonical Reference の主要な視覚要素（icon-ledセクション見出し、
統一カード形状、list-row、警告トーンカード）を、既存のメニュータブ
コンテンツ（BuildInfoの低強調表示、collapsed-by-defaultの開発・テスト
メニュー、既存authorityのままの「4月からやり直す」）へ、キー・文言・
ロジック・restart authorityを一切変更せずに反映した。実装禁止リスト
（manual Save/Load、difficulty/settings、display/sound settings、
tutorial、help/FAQ/contact、About、Credits、Menu用ひよりのアドバイス、
その他Reference専用機能）は一つも実装していない。fake data 0 / HOME変更 0
/ Employee変更 0 / Sales変更 0 / Accounting変更 0 / gameplay authority
変更 0 / horizontal overflow 0 を確認済み。既存回帰テスト（build_info: 5件、
bottom_nav: 2件、persistence: 18件、`test/ui/public_demo`フル: 471件、
`test/game/public_demo`フル: 520件）は全てgreen、無修正のまま通過。新規
visual構造のwidget test（26件）もgreen。`flutter analyze`/`git diff --check`
ともにクリーン。残るギャップ（上記「remaining gaps」）はいずれもSSOTの
禁止事項（Reference-only機能の新規実装）を回避するために意図的に見送った
項目であり、Visual Complete の PASS 判定を妨げるものではないと判断した。
