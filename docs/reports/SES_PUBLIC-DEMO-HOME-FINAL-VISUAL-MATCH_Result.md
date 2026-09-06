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

**追記2（SES HOME Final Visual Match - Structural Layout Fix）**: 上記2ラウンドの
padding/サイズ微調整だけではVisual SSOTとの目視比較でFAILだったため、構造レベルの
再設計を行った — ひよりを円形サムネイルから縦長の等身大クロップへ、社員の様子を
「小さな写真+バナー背景」から「大きな社員カード（写真・フルネーム・truthful status）
中心」へ、今月の重要タスクを「カテゴリchip+アイコンなし」から「icon→title→fact」の
視覚階層へ、それぞれ作り直した。詳細は「SES HOME Final Visual Match - Structural
Layout Fix」節。**社員3-person presentationは依然FAILのまま**（既存data/testの制約は
変わっていないため — 詳細は同節と「remaining HOME visual differences」参照）。

## BASE / HEAD

- **BASE SHA**: `a5d7025daddc9dd0719dfa4573672a8dfe4b2ce6`（`origin/main`、
  "Merge pull request #181 from perusonao/claude/ses-home-one-screen-fit-9w0app"）
  — GitHub上で`origin/main`の最新であることを確認済み（`mcp__github__pull_request_read`
  でPR #181が`merged: true`であることも確認済み）。origin/mainはこのラウンド開始時点
  でも再fetchし、変化なしを確認済み。
- **作業ブランチ**: `claude/ses-home-final-visual-lfizhq`（既存PR #182のブランチ。
  新規ブランチ・新規PRは作成していない）。
- **PR #182 初回実装 HEAD SHA**: `f7eb55e70fafc5bffdaf55c015262769e1642753`
- **PR #182 初回レポートコミット SHA**: `db332276d6c6295e63d09084b64f9e0ccfbb6d64`
- **Codex P2レビュー対応 実装コミット SHA**: `13816b0ccf82ea126d6b8dcf5c395a8ec26cb38d`
- **Codex P2レビュー対応 レポートコミット SHA**: `dc5eb30f5a0329c2e5c78e34637c1dcf7438f1c8`
  （本ラウンド開始時点の直前HEAD。fetchで最新であることを確認済み）
- **本ラウンド（Structural Layout Fix）実装コミット SHA**: `2637495` (フル: `26374954e221c729c307d3e7fc80a9ed8bd3ce49`)
  （本レポート自身はこのコミットの直後に追加する）。

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

### SES HOME Final Visual Match - Structural Layout Fix分（本追記2）

- `lib/presentation/home/widgets/home_navigator_section.dart`
  （ひよりポートレートを円形→縦長角丸矩形へ構造変更。`portraitSize`を
  `portraitWidth`/`portraitHeight`へ分離）
- `lib/presentation/home/models/home_office_stage_display.dart`
  （`HomeOfficeStageMember`に truthful な`status`フィールドを追加）
- `lib/presentation/home/widgets/home_office_stage_section.dart`
  （社員の様子を全面書き直し — 横長オフィス背景+小さい重なりportraitから、
  社員写真を主役にした大きな個別カード（写真・フルネーム・truthful status）
  へ。オフィス写真は小さな装飾アイコンへ縮小)
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
  （`_officeStageDisplay`が各engineerの`status`に既存の`engineerStatus(engineer)`
  を渡すよう変更。HOMEタブのセクション間gapを1px追加トリム）
- `lib/ui/public_demo/public_demo_home_presentation_components.dart`
  （今月の重要タスクのタイル構成を「カテゴリchip」から「カテゴリicon→
  title→fact」の視覚階層へ再設計。`_StatusChip`を`_CategoryIcon`へ置換）
- `e2e/scripts/ses-home-final-visual-match-screenshot.mjs`
  （出力ファイル名をタスク指定の
  `SES_HOME-FINAL-VISUAL-MATCH_AFTER_<viewport>.png`へ変更）
- `test/presentation/home/home_navigator_section_test.dart`
  （`portraitSize`→`portraitWidth`/`portraitHeight`参照を更新。テキスト
  スケールに応じたカード高さ増加を検証するテストの前提を、ポートレートが
  固定高さの矩形になったことに合わせて更新）
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  （カテゴリ表記がテキストからiconへ変わったことに合わせ、`find.text`を
  `find.bySemanticsLabel`へ更新）
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
  （同上のカテゴリicon対応、および「待機」が社員の様子の truthful
  per-employee statusとしてもHOME内に現れるようになったことへテストの
  前提を更新）
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
  （同上のカテゴリicon対応）
- `docs/reports/screenshots/SES_HOME-FINAL-VISUAL-MATCH_AFTER_360x800.png` /
  `_390x844.png`（新規、実ブラウザキャプチャ — 必須成果物）
- `docs/reports/screenshots/ses-home-final-visual-match-360x800.png` /
  `-390x844.png`（削除 — 旧ラウンドの実装状態を映した画像で、現状と一致
  しなくなったため、指定の新ファイル名のスクリーンショットに置き換え）
- `docs/reports/SES_PUBLIC-DEMO-HOME-FINAL-VISUAL-MATCH_Result.md`（本追記2）

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

## SES HOME Final Visual Match - Structural Layout Fix

前2ラウンド（初回実装・Codex P2対応）はpaddingやサイズの微調整に留まり、実際に
Visual SSOTと目視比較するとまだFAILだった。本ラウンドは「既存コードの構造を維持する
ことをVisual SSOTへの一致より優先しない」という明示指示のもと、3箇所を構造レベルで
作り直した。

### BEFORE（Codex P2対応後）vs Visual SSOT 差分一覧（実装前に作成）

| # | セクション | BEFORE（Codex P2対応後） | Visual SSOT | 問題の本質 | 対応方針 |
|---|---|---|---|---|---|
| 1 | ひよりカード | `ClipOval`の円形ポートレート（80/88pt、`navigator_home_compact.webp`を正方形にクロップ） | 縦長の等身大に近い写真が案内役として存在感を持つ | 円形にクロップすると顔しか見えず、サイズを上げても「小さいアイコン」の印象が変わらない | 円形→縦長角丸矩形（`portraitWidth`×`portraitHeight`）へ構造変更。同じ既存アセット（`navigator_home_compact.webp`、512×768）を`BoxFit.cover`で使うが、クロップ形状を変える |
| 2 | 社員の様子 | 横長オフィス背景写真が主役で、社員は写真上に重なる小さい円形サムネイル（28/32pt）＋名前ラベル | 社員本人の写真が主役。名前・状態が人物のすぐ近くに大きく表示 | オフィス背景が視覚的な主役になっており、社員個人の存在感が乏しい | オフィス背景を廃止（小さな装飾iconへ縮小）し、社員ごとに独立した大きめカード（48/54ptポートレート・フルネーム・truthful status）を横に並べる構成へ全面書き直し |
| 3 | 今月の重要タスク | カテゴリ名を文字chipで表示（icon要素なし） | icon → title → fact の明確な視覚階層。カテゴリ名の文字chipは存在しない | 視覚階層がVisual SSOTと異なる。文字chip1行分の高さも無駄 | `_StatusChip`（文字）を`_CategoryIcon`（小さい丸アイコン、`Semantics`でカテゴリ名を保持）へ置換。icon→title→factの順で1つの行にまとめる |

### 検討して見送った変更

- **社員の様子に3人目（架空社員）を追加してVisual SSOTの「3名」に一致させる案**:
  今回の指示でも明示的に禁止（"fake employeeは禁止"、"実データ上表示可能な社員が
  2名なら、2名を大きく表示する構図に変更する"）。実在する2名（佐藤健・鈴木葵）を
  大きく表示し、真実の集計チップ「社員3名・待機2名」で総数を示す方針を維持した。

### [A] ひよりカード — 構造変更

- **変更ファイル**: `lib/presentation/home/widgets/home_navigator_section.dart`
- **変更内容**: `HomeNavigatorLayout`の`portraitSize`（単一の正方形サイズ）を
  `portraitWidth`/`portraitHeight`（独立した幅・高さ）へ分離。`_NavigatorPortrait`
  の`ClipOval`＋`BoxShape.circle`を`ClipRRect`（角丸16pt）＋矩形の
  `BoxDecoration`へ変更。**新しい画像アセットは追加していない** —
  既存の`AssetPaths.navigatorHomeCompact`（512×768、既に縦長の等身大クロップ）を
  そのまま`BoxFit.cover`で使用し、円形ではなく縦長矩形の枠に収めることで、
  彼女の上半身がより大きく見えるようにした。
  - compact（360×800）: 幅80pt × 高さ150pt（旧: 80×80circle）
  - normal（390×844）: 幅94pt × 高さ158pt（旧: 88×88circle）
  - 幅は文字列の折り返し崩れ（後述）を避けるため元の80/88付近を維持しつつ、
    **高さを150/158ptへ大幅に増やした**ことで、円形時代よりはるかに大きな
    存在感を実現した（高さは面積で見ると旧80×80=6,400pt²に対し
    80×150=12,000pt²、約1.9倍）。
- **高さへの影響**: 実測で変化なし（171pt/174pt、旧ラウンドと同一）。テキスト列が
  引き続きこの値を決めており、ポートレートの新しい高さ（150/158pt）はまだそれを
  下回っているため、Rowの高さはテキスト列に支配されたまま。
  - 幅を100/106ptまで広げる案も試したが、テキスト列の折返し行数が1行増え
    Hiyoriカードが185/189ptへ拡大し、360×800でoverflowが再発した（実測で確認）。
    幅は80/94ptに戻し、高さだけを伸ばす方針で決着した。
- 構成（左に大きな画像／右に佐倉ひより・総務／次にやること／推奨行動／説明／
  primary CTA 1個／ひよりからのアドバイス）は変更していない。primary CTAは
  引き続き1個のみ（`home-recommended-action-cta`）。

### [B] 社員の様子 — 構造変更

- **変更ファイル**: `lib/presentation/home/widgets/home_office_stage_section.dart`、
  `lib/presentation/home/models/home_office_stage_display.dart`、
  `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- **変更内容**:
  - **オフィス背景写真を廃止**し、`_OfficeIcon`という小さな装飾アイコン
    （compact 20pt / normal 22pt角丸正方形）へ縮小。既存アセット
    （`AssetPaths.locationOfficeDayHomeBanner`）は引き続き使用・
    customizable（`backgroundAssetPath`）だが、もはや視覚的主役ではない。
  - 社員ごとに独立した`_MemberCard`（縦積み: ポートレート48/54pt円形 →
    フルネーム(bold, 12/13pt) → truthful statusピル(10/10.5pt)）を
    `Row`で横並びに。旧実装の「写真の上に重なる小さいサムネイル」から
    「対等な大きさの独立カードが横に並ぶ」構成へ変わった。
  - **truthful status**: `HomeOfficeStageMember`に新しい`status`フィールド
    （nullable String）を追加。実装は`_officeStageDisplay`
    （`public_demo_01_placeholder_screen.dart`）が各engineerについて
    **既存の`engineerStatus(engineer)`関数の戻り値をそのまま渡す** —
    社員タブが既に表示している値と完全に同じ、単一の権威（
    `PublicDemoEngineerSales.stage`）から読む、新規のドメインロジックは
    一切追加していない値。April初期状態では両エンジニアとも`waiting`ステージ
    のため、表示される値は truthfulに「待機」となる。
  - **なぜ以前のラウンドでこれを避けていたか、そしてなぜ今回は追加したか**:
    `home_office_stage_display.dart`冒頭のコメント（HOME-RUNTIME-2B）は
    「参画/待機」という**集計的な二値判定**を個別社員に持たせることを禁止
    している — 月内のタイミングによって3つの権威（KPIの集計、
    `workflow.assignments`、`engineer.stage==ordered`）が食い違いうるため。
    今回追加した`status`は、この集計的な二値判定ではなく、**社員タブが
    既に表示している当人のセールスステージ文字列をそのまま複製表示する
    だけ**であり、新たな集計・突合ロジックを一切含まない。それでも
    「HOME内で"待機"という文字列が複数回現れる」という結果は生じるため、
    既存テストの前提（"待機はKPIタイルにのみ現れる"）と直接衝突した —
    `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`の
    「4: the legacy KPI row is gone, not duplicated」テストで実際に検出され、
    「KPIタイル(1) + April の2エンジニア自身の社員の様子ステータスカード(2)
    = HOME内で計3件」という新しい truthful な状態を反映するようテストを
    更新した（テストの意図＝一つの事実は一箇所、という原則自体は維持し、
    「KPIの集計」と「個々の社員自身の状態」が別の事実であることを明記）。
  - **「3名視認可能」について**: 実在データ（技術者2名）のみを大きく表示。
    3人目（架空氏名、または総務ひよりの追加）は指示で明示的に禁止・
    既存テストでも禁止されているため追加していない。真実の総数は
    引き続き集計チップ「社員3名・待機2名」（タイトル行に統合、写真上の
    オーバーレイではなくなった）で表現。
- **高さへの影響**: 110pt/121pt（旧82pt/92ptから+28/+29pt）。employee visual
  prominenceのための意図的な増加。予算超過分は[C]の削減と各所のchrome
  トリムで相殺した（詳細は実測節）。

### [C] 今月の重要タスク — 視覚階層の変更

- **変更ファイル**: `lib/ui/public_demo/public_demo_home_presentation_components.dart`
- **変更内容**: 各タイルの構成を「カテゴリ文字chip（1行）→title→fact」から
  「カテゴリicon（title/factと同じ行の左側）→ title → fact」へ変更。
  `_StatusChip`（文字chip）を削除し、`_CategoryIcon`（`営業`→
  `Icons.campaign_outlined`、`採用`→`Icons.person_search_outlined`、
  `資金`→`Icons.savings_outlined`、未知の値→中立的なフォールバック
  アイコン）を新設。`item.category`自体は削除しておらず、
  `Semantics(label: category, container: true)`で引き続き
  支援技術に伝わる。
- **実ブラウザで発見・修正した回帰（重要）**: `flutter test`のテストフォント
  代替では「今月の固定費: ¥50,000」が2行に収まると測定されたが、
  カテゴリiconを追加した直後の**実Chromiumスクリーンショット**では、
  実NotoSansJPフォント（テストフォントより実測で幅広）のもとで
  タイトル・factの両方が2行を超えて省略記号（…）で切れることを発見した。
  これはドキュメント化済みのFlutter SDKの制約（`flutter test`は常に
  決定論的なテスト専用グリフに置き換える — 詳細はOne-Screen Final Fit
  スイートの既存コメント参照）そのものであり、widget testだけでは
  検出できない実UI回帰だった。対応:
  - カテゴリiconのサイズを16pt/padding6pt→14pt/padding4ptへ縮小し、
    title/fact列に実際の幅を返した。
  - タイトルに明示的な`fontSize: 13`（旧: テーマ既定サイズ、実測で
    大きすぎた）を設定。
  - 対応後、実Chromiumスクリーンショットで
    「営業活動を進める」「資金計画を確認する」の両タイトルが2行で
    完全に表示され、「今月の固定費: ¥50,000」も省略されずに表示される
    ことを目視で確認した（下記スクリーンショット参照）。
  - **この経験から得た教訓**: widget testの`maxLines`/幅の検証は
    `flutter test`のテストフォント下でのみ有効というFlutter SDKの
    制約があるため、今回のような密なグリッドレイアウトでは
    **実ブラウザスクリーンショットによる目視確認が数値テストの
    代わりにならない、必須の検証手段**であることを再確認した。
- **高さへの影響**: 108pt/108pt（旧133pt/133ptから-25pt）。カテゴリ文字chip行
  の削除が主な要因。

## [1] ひよりカード（初回実装分・現在は[A]で置き換え済み。履歴として残す）

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

## [2] 社員の様子（初回実装分・現在は[B]で置き換え済み。履歴として残す）

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

## [3] 今月の重要タスク（初回実装分・現在は[C]で置き換え済み。履歴として残す）

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

## 360×800 / 390×844 実測（Structural Layout Fix後の最終値）

### Widget test（`flutter test`、`SesTheme.build()`適用、TextScaler 1.0）

| 項目 | 360×800 | 390×844 |
|---|---|---|
| `maxScrollExtent` | **0** | **0** |
| KPI高さ | 124pt（変更なし） | 124pt（変更なし） |
| ひよりカード高さ | 171pt（変更なし） | 174pt（変更なし） |
| 月次処理高さ | 93pt（変更なし） | 93pt（変更なし） |
| 社員の様子高さ | **110pt**（旧82pt、+28pt — [B]の意図的な拡大） | **121pt**（旧92pt、+29pt） |
| 今月の重要タスク高さ | **108pt**（旧133pt、-25pt — [C]のicon化で削減） | **108pt**（旧133pt、-25pt） |
| 今月の重要タスク bottom と viewport bottom の差（余裕） | **11pt** | **41pt** |

参考（本ラウンド内の変遷、360×800）: Codex P2対応後133pt/余裕12pt →
社員の様子[B]適用直後（他は据え置き）185pt/余裕-26pt（overflow）→
office-stageのchrome/portraitトリムで113pt→110pt、ひよりportrait幅を
100pt→80ptへ戻して171pt（overflowなし）に復帰、important-tasksの
icon化で110pt、ImportantTaskCellのpaddingを4→3へトリットして
**最終108pt/余裕11pt**に到達。KPI/月次処理は本ラウンドで無変更。

### 実ブラウザ（`flutter build web --release` + Playwright Chromium、本番フォント/画像）— 必須成果物

**PR #182 Codex P2対応（P2-3）で明確化した方針のとおり**、no-scrollの正式な
numeric evidenceは実ブラウザのDOM測定ではなく、Widget testの
`ScrollableState.position.maxScrollExtent == 0`（実際のFlutter `ScrollPosition`
を読む値、上表）のみとする。実ブラウザキャプチャは**Visual比較専用の証拠**として
別に取得した。

**実ブラウザでのみ検出できた回帰（widget testでは検出不可）**: [C]の実装直後、
実Chromiumスクリーンショットで「今月の固定費: ¥50,000」と各タイトルが
省略記号で切れているのを目視で発見した — `flutter test`のテストフォント
代替では2行に収まると測定されていたが、実NotoSansJPフォント（テスト
フォントより幅広）では3行目が必要だった。カテゴリiconのサイズ縮小
（16pt/pad6→14pt/pad4）とタイトルの明示的`fontSize: 13`で解消し、
再撮影で目視確認した。**これはタスクが要求した「実ブラウザからの
AFTER screenshot」という検証手段が実際に必要だったことの直接的な証拠**
であり、widget testの数値PASSだけでは「Visual PASS」と判定できないことを
実例で裏付けた。

スクリーンショット（P2対応時点の旧ファイル`ses-home-final-visual-match-*.png`は
現状と一致しなくなったため削除し、以下のタスク指定ファイル名に置き換えた）:

- `docs/reports/screenshots/SES_HOME-FINAL-VISUAL-MATCH_AFTER_360x800.png`
- `docs/reports/screenshots/SES_HOME-FINAL-VISUAL-MATCH_AFTER_390x844.png`

目視確認した内容:
- ひよりが縦長の等身大クロップで案内役として存在感を持つ（円形サムネイルではない）。
- 佐藤健・鈴木葵の写真が大きく、フルネームと「待機」ステータスが人物の直下に表示。
  集計チップ「社員3名・待機2名」がタイトル行に統合されている。
- 今月の重要タスクが icon → title → fact の階層で表示され、
  「営業活動を進める」「資金計画を確認する」の両タイトルと
  「今月の固定費: ¥50,000」の金額がいずれも省略されず完全に読める。
- 360×800・390×844のどちらもスクロールなしで全セクション
  （ヘッダー〜今月の重要タスク〜下部ナビ）が収まっている。

### TextScaler 1.3 / 2.0（360×800・390×844）

`test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`（既存の
One-Screen Final Fitスイート、変更なし・そのまま実行）で確認:

- `tester.takeException()`が`null`（RenderFlex/RenderBoxのoverflow例外なし）。
- 全セクションが画面幅内（横overflow 0）。
- 今月の重要タスクの各CTAアイコンボタンは48×48pt以上を維持。
- 月次処理ボタンは44pt以上、ひよりのprimary CTAは48pt以上を維持。
- このスケールではスクロールが発生してよい（既存仕様どおり、情報の切り捨てをしない）。

## テスト

Structural Layout Fix適用後（最終コード）に対して実行し直した結果。

- **`flutter analyze`**: **No issues found!**
- **One-Screen Final Fit numeric suite**（`public_demo_01_home_one_screen_final_fit_test.dart`、
  無変更のまま実行）: **9/9 PASS**（`maxScrollExtent == 0` @360×800/390×844、
  TextScaler 1.3/2.0でoverflow例外なし）。
- **`test/presentation/home/`（widget-levelコンポーネントスイート全体）**:
  **189/189 PASS**（`portraitSize`→`portraitWidth`/`portraitHeight`分離、
  テキストスケール成長アサーションの前提更新を反映）。
- **`public_demo_01_home_office_stage_test.dart`（実画面統合）**: **16/16 PASS**
  （社員の様子の構造変更後も、ロスター＝`workflow.engineers`、集計チップの
  一意性、mutation権限なし、の各アサーションはすべて無変更のまま成立）。
- **`public_demo_home_presentation_components_test.dart`**: **11/11 PASS**
  （カテゴリicon化・financeファクト可読性を反映）。
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
- **finance fact readable regression**（`public_demo_home_presentation_components_test.dart`
  既存テスト）: PASS（360px/390pxの両方で`今月の固定費: ¥50,000`が
  ellipsisされず完全に見つかる — widget test上の数値としては。ただし上記
  「実ブラウザ」節のとおり、これだけでは実フォントでの可読性を保証しない
  ことを実地で確認したため、実ブラウザスクリーンショットで別途目視確認済み）。
- **4+ employee overlap regression**（P2-2で追加、`home_office_stage_section_test.dart`）:
  PASS（構造変更後も維持 — 360×800・390×844の両方で、summary chipとの
  重なりがないことを確認）。
- **PR前の`flutter test`フル実行**: **実行済み・全PASS**。プロジェクト全体で
  **1557 tests, All tests passed!**（exit code 0）。既存の全ドメイン/セーブ/収支/
  月次処理/週次進行等のテストを含め、失敗0件。件数はCodex P2対応時点と同じ
  1557件（本ラウンドはテストケース数を増減させず、既存テストのアサーションを
  更新したのみ）。

（開発中に発見・修正した回帰: (1) `home_office_stage_section.dart`書き直しの際、
`_MemberCard`のColumnで新規に導入したコードには影響しなかったが、以前の
`OverflowBox`関連の`IntrinsicHeight`修正はそのまま維持。(2) 社員の様子の構造
変更で「待機」がHOME内に複数回現れるようになり、
`public_demo_01_home_consolidation_test.dart`の「4: legacy KPI row」テストが
検出 → truthfulな新しい期待値へ更新。(3) 実Chromiumスクリーンショットで
today→タイトル/factの省略記号切れを発見 → icon縮小+タイトルfontSize指定で解消
（widget testでは検出できなかった実フォント依存の回帰 — 詳細は上記「実ブラウザ」
節）。修正後は上記のとおり全スイートPASS。）

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

**Structural Layout Fixラウンドについても同様**: 変更はすべて
`lib/presentation/home/widgets/home_navigator_section.dart`、
`lib/presentation/home/models/home_office_stage_display.dart`、
`lib/presentation/home/widgets/home_office_stage_section.dart`、
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
（`_officeStageDisplay`ゲッターとHOMEタブのgap定数のみ）、
`lib/ui/public_demo/public_demo_home_presentation_components.dart`
（いずれもpresentation layer）、`e2e/scripts/ses-home-final-visual-match-screenshot.mjs`
（検証スクリプト）、および対応するテストファイルのみ。追加した唯一の「新しい値」は
`HomeOfficeStageMember.status`だが、これは新規ドメインロジックではなく、既存の
`engineerStatus()`（社員タブが既に使用している既存の純関数）の戻り値をそのまま
presentation層へ運んでいるだけである。Domain/Save/Balance/Finance/Month
transition/Sales/Employee domain logic/workflow authority/Employee UI Phase
A/Active Project Visibility/GitHub workflow filesへの変更は一切なし。
Employee UI Phase Aへは進んでいない。

## Visual Acceptance PASS/FAIL

| チェック項目 | 結果 | 備考 |
|---|---|---|
| section order | **PASS** | ヘッダー→月表示→KPI 4+3→ひよりカード→月次処理→社員の様子→今月の重要タスク→Bottom Navigationの順で無変更 |
| KPI 4+3 | **PASS** | 無変更 |
| Hiyori visual prominence | **PASS** | 円形サムネイル(80/88pt)から縦長角丸矩形(80×150pt/94×158pt)へ構造変更。同じ既存アセットを異なるcrop形状で使い、案内役として明確な存在感を持つ |
| Hiyori composition | **PASS** | 大きな縦長ポートレート＋名前/役職＋次にやること＋説明＋primary CTA 1個＋アドバイスの構成 |
| Hiyori primary CTA | **PASS** | `home-recommended-action-cta`のまま、1個のみ、無変更 |
| employee visual prominence | **PASS** | オフィス背景写真を主役から装飾icon(20/22pt)へ縮小し、社員写真(48/54pt)を中心にした個別カードへ構造変更 |
| employee full names | **PASS** | 「佐藤 健」「鈴木 葵」がフルネームで表示（省略なし） |
| truthful employee presentation | **PASS（社員数は下記参照）** | 名前・写真は実在データ。各人のstatusは既存`engineerStatus()`をそのまま表示（fake dataではない）。3名視認は不可 — 下記参照 |
| employee 3-person presentation | **FAIL（意図的・justified）** | 実在データは技術者2名のみ。3人目（架空氏名 or ひより追加）は「fake data禁止」と既存テスト契約（`display.members.length == workflow.engineers.length`）の両方に反するため追加していない。真実の総数「社員3名・待機2名」は集計チップで表現済み — 詳細は「remaining HOME visual differences」参照 |
| important tasks 2-column layout | **PASS** | 営業活動を進める（左）／資金計画を確認する（右）が横並び。項目が3件になる月は3件目が2行目左に単独表示 |
| finance fact readability | **PASS** | 「今月の固定費: ¥50,000」が省略されず表示。実ブラウザで発見した回帰（icon追加直後に3行目が必要になっていた）をicon縮小+タイトルfontSize調整で解消し、実スクリーンショットで再確認済み |
| monthly processing | **PASS** | 無変更 |
| bottom navigation | **PASS** | 無変更 |
| 360×800 no-scroll | **PASS** | `ScrollableState.position.maxScrollExtent == 0`（widget test、実際のFlutter `ScrollPosition`）で確認。余裕11pt |
| 390×844 no-scroll | **PASS** | 同上、余裕41pt |

## remaining HOME visual differences

**あり。よって「HOME COMPLETE」とは報告しない。**

- **社員の様子の表示人数**: Visual SSOTは3名（架空の氏名、全員「待機中」）を示すが、
  実装は実在データに基づき技術者2名（佐藤 健・鈴木 葵）を大きく表示 + 真実の
  集計チップ「社員3名・待機2名」とした。理由は上記の通り: (a)
  Visual SSOTの3名の氏名は実在データと一致しないfake dataであり追加できない
  （今回の指示でも明示的に禁止）、(b) 実在の3人目（総務・佐倉ひより）を
  社員の様子へ追加することは`test/ui/public_demo/public_demo_01_home_office_stage_test.dart`
  の複数の既存regressionテストが明示的に禁止している（`display.members.length
  == workflow.engineers.length`をApril→June全軌跡でassert）。この差分を
  解消するには、次のいずれかが必要で、いずれも本タスクの権限（HOME
  presentation layerのみ、Employee domain logic/Employee UI Phase A禁止）を
  超える: (i) 4月の初期社員数を実際に3名の技術者へ増やす（Domain/Balance変更、
  禁止）、(ii) 総務ひよりを社員の様子へ表示する設計を正式に変更し、上記の
  既存テスト契約自体を意図的に更新する（Employee UI/Domain側の設計判断が
  必要で、本タスクの一存では決定できない）。
- **ひよりのアドバイス説明文**: 4月のデフォルト説明文は引き続き2行で「続きを読む」を
  経由してフル表示される（サイレントな切り捨てではなく明示的な一方向reveal）。Visual
  SSOTの静止画は説明文が短く収まって見えるが、これは既存のHOME-COMPACT-1B.4 FIX2の
  意図的な挙動であり、変更しないことにした（詳細は「検討して見送った変更」参照）。

## SCREENSHOT DOWNLOAD

PR #182のbranch (`claude/ses-home-final-visual-lfizhq`)、コミット
`466e134bb268804cfcfe7964400400d65eb7a7ce`へpush後、GitHub API
（`get_file_contents`）でファイルの存在を確認し、続けて各raw URLに対して
`curl`でHTTP 200が返ることを実際に確認した（推測URLではない）。

- 360×800: https://raw.githubusercontent.com/perusonao/smile_enjoy_story/466e134bb268804cfcfe7964400400d65eb7a7ce/docs/reports/screenshots/SES_HOME-FINAL-VISUAL-MATCH_AFTER_360x800.png
- 390×844: https://raw.githubusercontent.com/perusonao/smile_enjoy_story/466e134bb268804cfcfe7964400400d65eb7a7ce/docs/reports/screenshots/SES_HOME-FINAL-VISUAL-MATCH_AFTER_390x844.png
