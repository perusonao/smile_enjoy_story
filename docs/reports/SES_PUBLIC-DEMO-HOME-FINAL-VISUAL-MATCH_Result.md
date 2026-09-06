# SES Public Demo HOME「Final Visual Match」実装結果

## STATUS

**部分完了 — remaining differences あり（下記参照）。「HOME COMPLETE」ではない。**

Visual SSOT（ユーザー提示の360×800 HOME画面レイアウト仕様画像）と現行Public Demo実機
（IMG_2926）を実装前に比較し、差分をすべて列挙したうえで対応した。3項目のうち2項目
（ひよりカードの構成、今月の重要タスクの2列化）は完全に一致させた。残り1項目（社員の
様子の「3名視認可能」）は、既存の意図的なテスト契約（`test/ui/public_demo/
public_demo_01_home_office_stage_test.dart`）と「fake employee/status禁止」の両方を
同時に満たせないため、既存契約を優先し、truthfulな範囲で最大限対応した — 詳細は
「[2] 社員の様子」節と「remaining HOME visual differences」節を参照。

**追記（PR #182 Codex P2レビュー対応）**: PR #182への3件のP2レビュー指摘（今月の重要
タスクのfinance factが2列化で読めなくなる、社員名幅拡大がsummary chipと重なりうる、
E2Eスクリプト/レポートの「real-browser no-scroll confirmed」という主張が実際には
検証になっていない）にすべて対応した。詳細は「PR #182 Codex P2 レビュー対応」節。

## BASE / HEAD

- **BASE SHA**: `a5d7025daddc9dd0719dfa4573672a8dfe4b2ce6`（`origin/main`、
  "Merge pull request #181 from perusonao/claude/ses-home-one-screen-fit-9w0app"）
  — GitHub上で`origin/main`の最新であることを確認済み（`mcp__github__pull_request_read`
  でPR #181が`merged: true`であることも確認済み）。
- **作業ブランチ**: `claude/ses-home-final-visual-lfizhq`（既存PR #182のブランチ。
  新規ブランチ・新規PRは作成していない）。
- **PR #182 初回実装 HEAD SHA**: `f7eb55e70fafc5bffdaf55c015262769e1642753`
- **PR #182 初回レポートコミット SHA**: `db332276d6c6295e63d09084b64f9e0ccfbb6d64`
  （Codex P2レビュー対応前の直前HEAD。fetchで最新であることを確認済み）
- **本レビュー対応 HEAD SHA**: `13816b0ccf82ea126d6b8dcf5c395a8ec26cb38d`
  （P2-1/P2-2/P2-3対応の実装コミット"PR #182 Codex P2 fixes: finance-fact
  wrap, caption-only widen, drop bogus scroll check"。本レポート自身は
  このコミットの直後に追加する）。

## changed files

### PR #182 初回実装分

- `lib/presentation/home/widgets/home_navigator_section.dart`
  （ひよりポートレートサイズ）
- `lib/presentation/home/widgets/home_office_stage_section.dart`
  （社員名ラベル幅）
- `lib/ui/public_demo/public_demo_home_presentation_components.dart`
  （今月の重要タスクの2列グリッド化）
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  （2列レイアウトの検証テストへ更新）
- `e2e/scripts/ses-home-final-visual-match-screenshot.mjs`（新規、検証用
  Playwrightスクリーンショットスクリプト）
- `docs/reports/screenshots/ses-home-final-visual-match-360x800.png` /
  `-390x844.png`（新規、実ブラウザキャプチャ、Visual Acceptance証跡）
- `docs/reports/SES_PUBLIC-DEMO-HOME-FINAL-VISUAL-MATCH_Result.md`（本レポート）

### PR #182 Codex P2レビュー対応分（本追記）

- `lib/ui/public_demo/public_demo_home_presentation_components.dart`
  （P2-1: financeファクトの2行wrap許可、単一項目時のfull-width化、
  `_HomeSectionCard`/`_ImportantTaskCell`の縦paddingを追加トリム）
- `lib/presentation/home/widgets/home_office_stage_section.dart`
  （P2-2: 名前captionだけを`OverflowBox`+`IntrinsicHeight`で幅拡張し、figure
  slot自体の幅は`portraitSize`に戻す）
- `e2e/scripts/ses-home-final-visual-match-screenshot.mjs`
  （P2-3: `document.scrollingElement`の`scrollHeight`/`clientHeight`比較と
  その主張を削除。スクリーンショット撮影のみに縮小）
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  （P2-1の検証テストを追加・既存の単一項目テストを更新）
- `test/presentation/home/home_office_stage_section_test.dart`
  （P2-2の検証テスト — 4名以上でsummary chipと重ならないことを新規追加）
- `docs/reports/screenshots/ses-home-final-visual-match-360x800.png` /
  `-390x844.png`（P2対応後の状態で再撮影・差し替え）
- `docs/reports/SES_PUBLIC-DEMO-HOME-FINAL-VISUAL-MATCH_Result.md`（本追記）

## 実施内容の前提: Before / After 差分一覧（実装開始前に作成）

添付2枚（①現在のPublic Demo実機スクリーンショット IMG_2926 / ②360×800 HOME画面
レイアウト仕様=Visual SSOT）を比較し、実装前に列挙した差分一覧:

| # | セクション | 現状（Before） | Visual SSOT（完成仕様） | 対応方針 |
|---|---|---|---|---|
| 1 | ひよりカード・ひより画像 | 小さい円形ポートレート（60/68pt） | 大きなひより画像（88×88pt目安） | ポートレートを80/88ptへ拡大 |
| 2 | ひよりカード・全体構成 | 既に「ポートレート＋名前/役職＋次にやること＋説明＋primary CTA 1個＋アドバイス」の構成 | 同一構成 | 構成は既に一致（変更不要） |
| 3 | ひよりカード・アドバイス | 長い説明文が2行で切れ「続きを読む」が表示される | 説明文がその場で読める（切れていないように見える） | 調査の結果、既存の「続きを読む」は"サイレントな切り捨て"ではなく、明示的な一方向reveal（HOME-COMPACT-1B.4 FIX2で追加された既存の意図的UX）であり、かつ`test/presentation/home/home_navigator_section_test.dart`がこの挙動（この文字列は2行で溢れ、続きを読むが出ること）を直接pinしている。「不自然な途中切れ」の定義に照らし、これは既に満たされていると判断し、変更なし（下記「検討して見送った変更」参照） |
| 4 | 社員の様子・名前表示 | 名前ラベルの幅がポートレート幅(28/32pt)に固定され、実名「佐藤 健」「鈴木 葵」が1文字+省略記号（「佐…」「鈴…」）に切り詰められる | 各社員のフルネームが読める | 名前ラベルの幅をポートレート幅から分離（`_labelWidthFactor = 2.0`）し、フルネームが省略されずに表示されるよう修正 |
| 5 | 社員の様子・表示人数 | 実在する社員（技術者2名: 佐藤健・鈴木葵）のみ表示 | 3名（架空の氏名: 鈴木翔・高橋美咲を含む、全員「待機中」） | **既存の氏名は実在データと一致しないfake dataであり、追加できない。** 実在の総人数3名（技術者2名＋総務ひより1名）を鵜呑みにひよりを社員の様子へ追加することも検討したが、`public_demo_01_home_office_stage_test.dart`の複数テスト（`display.members.length == workflow.engineers.length`をApril/May/Juneの全実プレイ軌跡で直接assert）が明示的にこれを禁止している。既存の意図的な設計判断（`home_office_stage_display.dart`冒頭のコメント: 3つの権威が月内で食い違うため、社員の様子は集計値のみを扱い個別の参画/待機主張をしない）を尊重し、変更しなかった。真実の「社員数/待機数」は既存の集計チップ「社員3名・待機2名」で既に表現されている（詳細は「[2] 社員の様子」節） |
| 6 | 今月の重要タスク・レイアウト | 縦1列（Divider区切り） | 横2列グリッド | `PublicDemoImportantTasksSection`を2列グリッドへ書き換え（既存の`items`・`onPressed`・`ctaLabel`・カテゴリ表記は完全に再利用、並び順も変更なし） |
| 7 | KPI 4+3 / 現金・参画・待機・営業残・社員・売上・入金予定 | 実装済み | 同一 | 変更なし（維持） |
| 8 | 月次処理 | 実装済み | 同一 | 変更なし（維持） |
| 9 | Bottom Navigation | 実装済み | 同一 | 変更なし（維持） |

### 検討して見送った変更（記録）

- **ひよりのアドバイス説明文のmaxLinesを2→3へ広げる案**: 実装前に検討したが、
  `home_navigator_section_test.dart`の
  `'a long explanation that would overflow two lines shows 続きを読む, ...'`
  テストが、April実際の説明文字列（`スキルシートは、経験やスキルを案件へ伝えるための
  資料です。内容を確認して次の手続きに備えます。`）についてまさに「2行で溢れて続きを
  読むが出ること」を意図した挙動としてpinしている。この「続きを読む」は
  HOME-COMPACT-1B.4 FIX2で追加された、サイレント切り捨てを防ぐための明示的な
  一方向revealであり、タスクの禁止する「不自然な途中切れ」（読む手段がない切り捨て）
  には該当しないと判断し、変更しなかった。
- **社員の様子へ佐倉ひより（総務）を3人目として追加する案**: 上記差分表#5のとおり、
  既存テストの明示的な禁止により見送った。

## PR #182 Codex P2 レビュー対応

初回実装（HEAD `f7eb55e`）に対して`chatgpt-codex-connector`から3件のP2指摘があり、
すべてに対応した。

### P2-1: 今月の重要タスク — financeファクトの金額が2列化で読めなくなる

**指摘**: 2列グリッド化で各タイルの幅が半分になり、`資金計画を確認する`タイルの
`今月の固定費: ¥50,000`が`maxLines: 1`のellipsisで金額まで切り詰められる。資金
タスクが1件だけ残る月（営業/採用が両方尽きた月）でも、空の右カラムが半分を予約し
続けて同じ問題が起きる。

**対応**:
- `item.fact`の`Text`を`maxLines: 1`→`maxLines: 2`へ変更。2行のwrapで実際の
  April本番文字列（`今月の固定費: ¥50,000`）が360px/390pxの両方で完全に収まる
  ことを新規テストで確認した（`overflow: ellipsis`は、万一将来もっと長いfactが
  来た場合の保険として残すのみで、現在の実文言では発火しない）。
- 項目が奇数個（1件のみ、または3件）になる場合、最後の1件を空の`Expanded`で
  半分に押し込めていたのをやめ、`SizedBox(width: double.infinity)`で行全体を
  使うよう変更した。
- factが2行になった分の高さを、`_ImportantTaskCell`の縦padding（6→4）と
  `_HomeSectionCard`の縦padding（6→4）・タイトル下のgap（4→2）をそれぞれ
  トリムして相殺し、360×800の`maxScrollExtent == 0`を維持した（下記実測参照）。
- `item.title`・`category`・`ctaLabel`・`onPressed`は無変更。

### P2-2: 社員の様子 — 名前幅拡大がsummary chipと重なりうる

**指摘**: 初回実装は名前captionを表示するために**figure slot全体**を
`portraitSize * 2.0`へ広げていた。これにより社員が4名以上（3 figures + `+N`
インジケータ）になったとき、Row全体の必要幅が実質2倍になり、右上の集計chip
（`home-office-stage-headcount-summary`）の描画領域と重なりうることが判明した
（既存テストは「カード内に収まっているか」のみを検証しており、この重なりを検出
できていなかった）。

**対応**:
- `_MemberFigure`のfigure slot幅を`layout.portraitSize`（元の値）に戻した —
  Row/Flexibleがこのfigureに割り当てる幅は初回実装前と完全に同じになり、4名以上
  でも集計chipとの位置関係は変化しない。
- 名前captionだけを`OverflowBox`（`maxWidth: portraitSize * 2.0`）でラップし、
  「レイアウト上の予約幅は変えず、描画だけ広く許可する」方式にした。
  - **副作用と修正**: `OverflowBox`はheight方向の指定を省略すると、Columnの
    非flex子に与えられる無制限（0〜∞）の高さ制約をそのまま自分の報告サイズに
    してしまい、`Alignment.topCenter`のオフセット計算で`NaN`が発生して
    描画例外になることが実際のテスト実行で判明した。`OverflowBox`を
    `IntrinsicHeight`でラップし、captionの実際の（テキストスケール込みの）
    高さを先に確定させてから渡すことでこれを解消した。
- `maxLines: 1` + `overflow: ellipsis`は維持（非常に長い名前は引き続き省略）。
- 4名以上（3 figures + `+N`）でも実名フルネームが読め、かつsummary chipと重なら
  ないことを新規widget test（360×800・390×844の両方）で確認した。

### P2-3: E2Eスクリプト/レポートの「real-browser no-scroll confirmed」主張

**指摘**: `document.scrollingElement`の`scrollHeight`/`clientHeight`比較では、
Flutter Web内部の`ListView`スクロールを検出できない。Flutter Webは固定サイズの
ホストDOM要素にcanvas/HTML描画するため、Flutter側の`ListView`が実際に
overflowしていても、ブラウザのdocument自体は常にviewportサイズのまま
（`scrollHeight == clientHeight`）になる。したがってこの比較は「検証」として
機能しておらず、レポートの主張は過大だった。

**対応（指示のオプションB — 複雑なE2Eを新設しない）**:
- `e2e/scripts/ses-home-final-visual-match-screenshot.mjs`から
  `document.scrollingElement`の`scrollHeight`/`clientHeight`比較コードを削除し、
  スクリーンショット撮影のみのスクリプトへ縮小した。ファイル冒頭に、なぜこの
  比較が無効だったかをコメントで明記した。
- 本レポートの「real-browser no-scroll confirmed」という趣旨の記述をすべて削除・
  訂正し、`test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`
  の`ScrollableState.position.maxScrollExtent == 0`（実際のFlutter
  `ScrollPosition`を読む数値テスト）を唯一の正式なno-scroll numeric evidenceとして
  扱うよう明記した（下記「360×800 / 390×844 実測」節を参照）。
- スクリーンショット自体は削除せず、Visual comparison用の証跡として維持・
  P2対応後の状態で再撮影した。

## [1] ひよりカード

- **変更ファイル**: `lib/presentation/home/widgets/home_navigator_section.dart`
- **変更内容**: `HomeNavigatorMetrics.compact/normal`の`portraitSize`を60/68pt→
  80/88ptへ拡大。Visual SSOTの「大きなひより画像」（88×88pt目安）に合わせた。
- **高さへの影響**: なし。ひよりカードの高さはポートレートではなくテキスト列（名前/
  役職・次にやること・説明・CTA・アドバイス）が決めており、テキスト列は既に
  ポートレートの新サイズより高い（実測171pt @360×800、174pt @390×844 — 変更前後で
  完全に同一）。
- 構成（左に大きな画像／右に佐倉ひより・総務／次にやること／推奨行動／説明／
  primary CTA 1個／ひよりからのアドバイス）は元から一致しており、追加の構造変更は
  不要だった。primary CTAは引き続き1個のみ（`home-recommended-action-cta`）。

## [2] 社員の様子

- **変更ファイル**: `lib/presentation/home/widgets/home_office_stage_section.dart`
- **変更内容（P2-2対応後の最終形）**: `_MemberFigure`のfigure slot自体の幅は
  `layout.portraitSize`（元の値）のまま変更していない。名前captionだけを
  `IntrinsicHeight` + `OverflowBox`（`maxWidth: portraitSize * 2.0`）で包み、
  「レイアウト上の予約幅は広げず、描画だけ広く許可する」方式にした。これにより
  実在の社員名「佐藤 健」「鈴木 葵」が1文字+省略記号へ切り詰められる不具合
  （「佐…」「鈴…」— 意味のない省略表示）を解消しつつ、4名以上（3 figures + `+N`）
  でもRowの実効幅は初回実装前と変わらず、右上の集計chipと重ならない。
  `maxLines: 1` + `overflow: ellipsis`は維持しているため、既存の「非常に長い名前は
  省略される」保護（`home_office_stage_section_test.dart`）はそのまま有効。
- **「3名視認可能」について**: 上記差分表#5のとおり、実在データ（技術者2名）のみを
  表示し、社員数/待機数の真実は既存の集計チップ「社員3名・待機2名」
  （`home-office-stage-headcount-summary`、Issue #122以来の既存実装、無変更）が担う。
  個別の第3の人物（架空の氏名、または総務ひよりの二重表示）は追加していない。
- 高さへの影響: なし（幅のみの変更）。`HomeOfficeStageMetrics`の`compactSceneHeight`
  / `normalSceneHeight` / `chromeHeight`は無変更。

## [3] 今月の重要タスク

- **変更ファイル**: `lib/ui/public_demo/public_demo_home_presentation_components.dart`
- **変更内容**: `PublicDemoImportantTasksSection`を縦1列（`Divider`区切り）から
  横2列グリッドへ書き換え。`items`を2件ずつ`Row`にまとめ、各タイル
  （`_ImportantTaskCell`、旧`_ImportantTaskRow`を置換）にカテゴリチップ・タイトル・
  factテキスト・既存のicon-only CTA（`important-task-cta-${item.title}`キー、
  `Semantics(label: item.ctaLabel)`、48×48pt以上）をそのまま再配置した。
  - 項目が奇数個（1件または3件）の場合、最後の項目は左カラムに残し、右カラムは
    空のまま予約せず、**行全体（full width）を使う**（P2-1対応、下記参照）。
  - `onPressed`・`ctaLabel`・`category`・`fact`の文言は一切変更していない
    （既存action/handlerをそのまま使用）。
- **P2-1対応（financeファクトの可読性）**: `item.fact`を`maxLines: 1`→`2`へ変更し、
  金額を含む長いfact文字列（`今月の固定費: ¥50,000`）が2行にwrapして完全に読める
  ようにした。単一項目のケースも上記のとおりfull-widthへ変更済み。
- **テスト更新**: `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  の「dividerが2本あることをpinするテスト」を、新しい2列レイアウトを検証するテスト
  （1行目に営業/採用が並ぶこと、2行目に資金が単独で来ることを`tester.getRect`の
  位置関係で確認）へ置き換えた。単一項目がfull widthになること、financeファクトが
  360px/390pxの両方でellipsisされず完全に読めることを確認する新規テストを追加した。

## 360×800 / 390×844 実測（本番テーマ・実ブラウザの両方で確認）

### Widget test（`flutter test`、`SesTheme.build()`適用、TextScaler 1.0）

**PR #182 Codex P2対応後の最終実測**（P2-1のfinance fact 2行wrap許可により
今月の重要タスクの高さが増えた分は、`_ImportantTaskCell`/`_HomeSectionCard`の
非コンテンツ縦paddingを追加でトリムして相殺し、`maxScrollExtent == 0`と実用的な
余裕の両方を維持した）:

| 項目 | 360×800 | 390×844 |
|---|---|---|
| `maxScrollExtent` | **0** | **0** |
| KPI高さ | 124pt（変更なし） | 124pt（変更なし） |
| ひよりカード高さ | 171pt（変更なし） | 174pt（変更なし） |
| 月次処理高さ | 93pt（変更なし） | 93pt（変更なし） |
| 社員の様子高さ | 82pt（変更なし） | 92pt（変更なし） |
| 今月の重要タスク高さ | **133pt**（P2-1前127pt、+6pt — factの2行化を追加paddingトリムで一部相殺） | **133pt** |
| 今月の重要タスク bottom と viewport bottom の差（余裕） | **12pt** | **43pt** |

参考（変遷）: 旧実装（Divider区切りの1列、P181時点）137pt/余裕8pt・39pt →
初回2列化（P182最初のコミット）127pt/余裕18pt・49pt →
P2-1でfactを2行許可した直後（padding未調整）143pt/余裕2pt・33pt →
**P2-1のpadding相殺後（最終）133pt/余裕12pt・43pt**。
ひよりカードのポートレート拡大・社員の様子の名前幅拡大は、いずれも高さへの影響
ゼロ（幅のみの変更）であることを実測で確認済み（P2-2後も変化なし）。

### 実ブラウザ（`flutter build web --release` + Playwright Chromium、本番フォント/画像）

**PR #182 Codex P2対応（P2-3）**: 当初の実装は`document.scrollingElement`の
`scrollHeight`/`clientHeight`比較を「real-browser no-scroll confirmed」の根拠として
記載していたが、これは誤りだった。Flutter Webは固定サイズのホストDOM要素へ
canvas/HTML描画するため、Flutter内部の`ListView`が実際にoverflowしていても
ブラウザのdocument自体は常にviewportサイズのまま（`scrollHeight == clientHeight`）
になり、この比較は「証拠」として機能していなかった。この比較コードと、それに基づく
主張はすべて削除した。

**正式なno-scroll numeric evidenceは、Widget testの`ScrollableState.position
.maxScrollExtent == 0`（実際のFlutter `ScrollPosition`を読む値）のみとする**
（上記の表を参照）。

`e2e/scripts/ses-home-final-visual-match-screenshot.mjs`は、`build/web`をローカル
配信し実Chromiumで360×800・390×844のHOME初期表示（4月・セーブなし）を
スクリーンショットする**視覚比較用**のスクリプトとして維持している（no-scrollの
数値証拠としては使用しない）。P2対応後の状態で再撮影したスクリーンショットは
`docs/reports/screenshots/ses-home-final-visual-match-360x800.png` /
`-390x844.png`。目視で、名前「佐藤 健」「鈴木 葵」がフル表示されていること、
financeファクト「今月の固定費: ¥50,000」が2行で完全に読めることを確認できる。

### TextScaler 1.3 / 2.0（360×800・390×844）

`test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`（既存の
One-Screen Final Fitスイート、変更なし・そのまま実行）で確認:

- `tester.takeException()`が`null`（RenderFlex/RenderBoxのoverflow例外なし）。
- 全セクションが画面幅内（横overflow 0）。
- 今月の重要タスクの各CTAアイコンボタンは48×48pt以上を維持。
- 月次処理ボタンは44pt以上、ひよりのprimary CTAは48pt以上を維持。
- このスケールではスクロールが発生してよい（既存仕様どおり、情報の切り捨てをしない）。

## テスト

すべてP2対応後（最終コード）に対して実行し直した結果。数値は本追記で実測し直した
正確な値であり、初回レポートが「Focused HOMEスイート: 122/122」としていたのは
`test/presentation/home/`ディレクトリ全体ではなく一部のみを指した不正確な内訳
だった（テスト自体は当時も現在も全PASSで、regressionはない）。本節はその内訳を
修正し、実行したコマンドと実測件数をそのまま記載する。

- **`flutter analyze`**: **No issues found!**
- **One-Screen Final Fit numeric suite**（`public_demo_01_home_one_screen_final_fit_test.dart`、
  無変更のまま実行）: **9/9 PASS**（`maxScrollExtent == 0` @360×800/390×844、
  TextScaler 1.3/2.0でoverflow例外なし）。
- **`test/presentation/home/`（widget-levelコンポーネントスイート全体）**:
  **189/189 PASS**。
- **`public_demo_01_home_office_stage_test.dart`（実画面統合、P2-2新規2件含む）**:
  **16/16 PASS**。
- **`public_demo_home_presentation_components_test.dart`（P2-1新規2件含む）**:
  **11/11 PASS**。
- **既存HOME regression family**（`public_demo_01_home_consolidation_test.dart` +
  `public_demo_01_home_final_density_test.dart` +
  `public_demo_01_home_ui_3c_density_test.dart` +
  `public_demo_01_home_navigator_test.dart` +
  `public_demo_01_home_recommended_action_test.dart` +
  `public_demo_01_issue_124_screen_verification_test.dart` +
  `public_demo_01_home3_integration_test.dart` + 上記office-stage統合 +
  presentation-components）: **148/148 PASS**。
- **上記すべてを1回のコマンドで実行した合算**（one-screen-final-fit +
  `test/presentation/home/` + presentation-components + office-stage統合 +
  regression family）: **346/346 PASS**。
- **new 4+ employee overlap regression**（P2-2、`home_office_stage_section_test.dart`
  新規group、上記189件の内数）: **2/2 PASS**（360×800・390×844の両方で、3
  figures + `+N` + 実名フルネームがsummary chipと重ならないことを確認）。
- **finance fact readable regression**（P2-1、
  `public_demo_home_presentation_components_test.dart`新規テスト、上記11件の
  内数）: **2/2 PASS**（360px/390pxの両方で`今月の固定費: ¥50,000`が
  ellipsisされず完全に見つかる）。
- **PR前の`flutter test`フル実行**: **実行済み・全PASS**。プロジェクト全体で
  **1557 tests, All tests passed!**（exit code 0）。既存の全ドメイン/セーブ/収支/
  月次処理/週次進行等のテストを含め、失敗0件（初回実装時の1554件から、本追記の
  新規テスト4件分と既存テスト1件の置き換えで+3、合計1557件）。

（開発中に発見・修正した回帰: P2-2の`OverflowBox`初版が`Alignment.topCenter`の
オフセット計算で`NaN`を生じさせ描画例外になる問題を、`IntrinsicHeight`でラップして
解消した。修正後は上記のとおり全スイートPASS。）

## Forbidden scope（変更禁止項目）= none

以下は一切変更していない（累積diffは「changed files」節に記載の presentation
layer 2ファイル（初回実装3ファイル中2ファイルへ再度手を入れた）+ テスト3ファイル
+ 検証用スクリーンショット2枚（差し替え）+ 検証用Playwrightスクリプト1本のみ）:

- Domain（`lib/game/**`のロジック・モデル）
- Save/Persistence（`public_demo_save_service.dart` / `public_demo_save_codec.dart`）
- Balance（賃金・固定費・売上・現金計算式など）
- Finance logic（`public_demo_financial_status.dart`等の判定ロジック）
- Month transition logic（`public_demo_monthly_close.dart`等）
- Sales logic / Employee domain logic（`task_engine.dart`、`public_demo_sales.dart`等）
- workflow authority（`public_demo_workflow_state.dart`等）
- game balance / fake data（新規架空データは追加していない）
- workflow files
- Employee UI Phase A（社員タブ側の実装には触れていない）
- Active Project Visibility

`_officeStageDisplay`（`public_demo_01_placeholder_screen.dart`）自体も無変更 —
このファイルへの変更は一切なし。

**P2レビュー対応分についても同様**: 変更はすべて`lib/ui/public_demo/
public_demo_home_presentation_components.dart`と`lib/presentation/home/widgets/
home_office_stage_section.dart`（いずれもpresentation layer）、
`e2e/scripts/ses-home-final-visual-match-screenshot.mjs`（検証スクリプト）、
および対応するテストファイルのみ。Domain/Save/Balance/Finance/Month
transition/Sales/Employee domain logic/workflow authority/Employee UI Phase
A/Active Project Visibility/GitHub workflow filesへの変更は一切なし。
Employee UI Phase Aへは進んでいない。

## Visual Acceptance PASS/FAIL

| チェック項目 | 結果 | 備考 |
|---|---|---|
| section order | **PASS** | ヘッダー→月表示→KPI 4+3→ひよりカード→月次処理→社員の様子→今月の重要タスク→Bottom Navigationの順で無変更 |
| Hiyori composition | **PASS** | 大きなポートレート(80/88pt)＋名前/役職＋次にやること＋説明＋primary CTA 1個＋アドバイスの構成一致 |
| employee 3-person presentation | **FAIL（意図的・justified）** | 実在データは技術者2名のみ。3人目（架空氏名 or ひより二重表示）は「fake data禁止」と既存テスト契約（`display.members.length == workflow.engineers.length`）の両方に反するため追加していない。真実の総数「社員3名・待機2名」は既存の集計チップで表現済み — 詳細は「remaining HOME visual differences」参照 |
| important tasks 2-column layout | **PASS** | 営業活動を進める（左）／資金計画を確認する（右）が横並び。項目が3件になる月は3件目が2行目左に単独表示 |
| KPI 4+3 | **PASS** | 無変更 |
| monthly CTA | **PASS** | 無変更 |
| bottom navigation | **PASS** | 無変更 |
| no-scroll (360×800 / 390×844) | **PASS** | `ScrollableState.position.maxScrollExtent == 0`（widget test、実際のFlutter `ScrollPosition`）で確認。実ブラウザの`document.scrollingElement`比較はFlutter Web内部のスクロールを検出できないと判明したため証拠として採用していない（P2-3、詳細は該当節） |

## remaining HOME visual differences

**あり。よって「HOME COMPLETE」とは報告しない。**

- **社員の様子の表示人数**: Visual SSOTは3名（架空の氏名、全員「待機中」）を示すが、
  実装は実在データに基づき技術者2名（佐藤 健・鈴木 葵）のフルネーム表示 + 真実の
  集計チップ「社員3名・待機2名」とした。理由は上記の通り: (a)
  Visual SSOTの3名の氏名は実在データと一致しないfake dataであり追加できない、
  (b) 実在の3人目（総務・佐倉ひより）を社員の様子へ追加することは
  `test/ui/public_demo/public_demo_01_home_office_stage_test.dart`の複数の既存
  regressionテストが明示的に禁止している。この差分を解消するには、次のいずれかが
  必要で、いずれも本タスクの権限（HOME presentation layerのみ、Employee domain
  logic/Employee UI Phase A禁止）を超える: (i) 4月の初期社員数を実際に3名の技術者へ
  増やす（Domain/Balance変更、禁止）、(ii) 総務ひよりを社員の様子へ表示する設計を
  正式に変更し、上記の既存テスト契約自体を意図的に更新する（Employee UI/Domain側の
  設計判断が必要で、本タスクの一存では決定できない）。
- **ひよりのアドバイス説明文**: 4月のデフォルト説明文は引き続き2行で「続きを読む」を
  経由してフル表示される（サイレントな切り捨てではなく明示的な一方向reveal）。Visual
  SSOTの静止画は説明文が短く収まって見えるが、これは既存のHOME-COMPACT-1B.4 FIX2の
  意図的な挙動であり、変更しないことにした（詳細は「検討して見送った変更」参照）。
