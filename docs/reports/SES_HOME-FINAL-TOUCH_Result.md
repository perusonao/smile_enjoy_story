# SES HOME Final Touch — 実装結果

## STATUS

完了。実機スクリーンショットで確認された3点（ひよりカード / 社員の様子 /
今月の重要タスク）のみを修正。新機能追加・別画面改修・domain/finance/
workflow/CI 変更はなし。

**追記（SES HOME Visual SSOT Exact Layout Match フェーズ）**: 上記の
Final Touch 完了後、添付の「360×800 HOME画面レイアウト仕様画像」を
Visual SSOT として、レイアウト構造・寸法・情報階層・人物サイズをより忠実
に再現する追加フェーズを同じ PR #184 上で実施した。詳細は本ファイル末尾
の「SES HOME Visual SSOT Exact Layout Match — 追加フェーズ」を参照。

## BASE / HEAD

- **BASE SHA**: `123ec61` (`origin/main`, PR #182 マージ後の最新)
- **FINAL HEAD SHA**: `5fc678d`
- ブランチ: `claude/ses-home-final-touch-cbu8lw`

作業前提: セッション開始時のローカル `claude/ses-home-final-touch-cbu8lw`
は origin に存在せず、かつ無関係な過去フェーズ（Phase 0A/0B ドメインモデ
ル）の上に作られていたため、タスク冒頭の指示（「過去情報より最新mainを優
先」）に従い、`origin/main`（`123ec61`）からブランチを再作成した。

## changed files

```
docs/reports/screenshots/SES_HOME-FINAL-TOUCH_AFTER_360x800.png   (new)
docs/reports/screenshots/SES_HOME-FINAL-TOUCH_AFTER_390x844.png   (new)
docs/reports/screenshots/SES_HOME-FINAL-TOUCH_BEFORE_360x800.png  (new)
docs/reports/screenshots/SES_HOME-FINAL-TOUCH_BEFORE_390x844.png  (new)
e2e/scripts/ses-home-final-touch-screenshot.mjs                   (new)
lib/presentation/home/widgets/home_navigator_section.dart         (modified)
lib/presentation/home/widgets/home_office_stage_section.dart      (modified)
lib/ui/public_demo/public_demo_home_presentation_components.dart  (modified)
test/presentation/home/home_navigator_section_test.dart           (modified)
test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart       (modified)
test/ui/public_demo/public_demo_01_home_final_density_test.dart   (modified)
test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart (modified)
test/ui/public_demo/public_demo_home_presentation_components_test.dart (modified)
docs/reports/SES_HOME-FINAL-TOUCH_Result.md                       (new, this file)
```

lib 側の変更は3ファイルのみ。いずれも既存の該当セクション自身の内部レイ
アウト・タップ処理の調整であり、action/遷移先/データモデル/domain ロジッ
クには一切触れていない。

## 3点それぞれの before/after

### 1. ひよりカード（`home_navigator_section.dart`）

**Before**: 「スキルシートを確認」CTA が全幅・高さ48pt・vertical padding
12 で大きく、直下の「ひよりからのアドバイス」バブルが2行キャップのため、
実機（実フォント）では April 実データの説明文
（「スキルシートは、経験やスキルを案件へ伝えるための資料です。内容を確認
して次の手続きに備えます。」）が2行に収まらず「続きを読む」の途中で見切
れて表示されていた。

**After**:
- CTA の高さを 48pt → 44pt（`minimumSize` + `tapTargetSize:
  MaterialTapTargetSize.shrinkWrap` — Material のデフォルト48pt下駄を明
  示的に外している）、vertical padding を 12 → 10 に縮小。
- CTA の幅を `FractionallySizedBox(widthFactor: 0.86)` + 左寄せで、カー
  ド幅の86%に縮小（フル幅ベタ塗りを回避）。
- アドバイスバブルの折返し上限を2行→3行に拡大（`_collapsedMaxLines`）。
  「続きを読む」は3行に収まらない場合のみ表示される一方通行の展開ボタン
  のまま。
- action/遷移先（`advice.onCtaPressed`）は完全に不変。
- ひより画像サイズ（`portraitWidth`/`portraitHeight`）は不変 — 存在感を
  維持。

結果、CTA は主要導線として十分な44pt・カード幅86%のタップ領域を保ちなが
ら、アドバイス本文の実質表示行数が増え、実機で見切れていた文が全文表示さ
れるようになった（スクリーンショットで確認、後述）。

**PRレビュー指摘の発見と修正（Codex P2）**: 当初 CTA の高さは 40pt にし
ていたが、GitHub上の自動レビュー（Codex）から「`研修する`のような短いラ
ベルの場合、内容が40ptの高さに収まってしまい、`shrinkWrap`によって
Materialの48ptタップ領域下駄も外れているため、実タップ領域が真に40ptま
で縮んでしまう。このアプリの他のCTAが守っている既存の48pt基準を下回る」
という正当な指摘があった。48ptに戻すと360x800のno-scroll予算（本フェー
ズの他2点の修正と合わせて）を壊すため、Apple HIGのアクセシブル最小値で
もある44ptを採用し、実機同等の`flutter test`で360x800/390x844の両方（通
常のApril状態・より予算の厳しい実資金不足状態の両方）で no-scroll を維
持できることを確認した。短いラベルでも44pt以上のタップ領域になることを
明示的に検証する新規テスト
（`home_navigator_section_test.dart`の`the CTA stays a real >=44pt tap
target even for a short label`）を追加した。

### 2. 社員の様子（`home_office_stage_section.dart`）

**Before**: オフィス画像アイコンが 20pt(360)/22pt(390) と小さく、枠線も
なく、実機ではオフィス写真であることがほぼ判別できなかった。

**After**:
- 既存の同一アセット（`display.backgroundAssetPath` /
  `AssetPaths.locationOfficeDayHomeBanner`）はそのまま、サイズのみ
  20→26pt（360x800）、22→28pt（390x844）に拡大。
- 社員ポートレートと同様の薄い枠線（`Border.all(outlineVariant)`）と角丸
  を追加し、単なるアイコングリフではなく「小さな写真」として認識できる
  枠組みに変更。
- レイアウト定数 `_titleRowHeight` を実際に描画される最大アイコンサイズ
  （28）に合わせて更新（`compactComponentHeight`/`safetyCeiling` の予測
  値が実測値を下回らないようにするため）。
- 社員2名（佐藤健・鈴木葵）の顔写真・氏名・ステータス（「待機」）表示は
  変更なし。
- 実在しない3人目の追加、ひよりの社員追加、fake data の追加は一切なし
  （`HomeOfficeStageDisplay.members` は `workflow.engineers` のみを引き
  続き参照）。

**回帰の発見と修正（実装中）**: 当初は 20→30pt / 22→32pt で実装したが、
その後 `flutter test` フル実行で
`public_demo_01_issue_124_screen_verification_test.dart`
（HOME-COMPACT-1B.4 FIX1: 実際の資金不足状態で360x800が unscrolled に収
まることを検証する既存テスト）が 1.07px の overflow で failing になるこ
とを発見した。資金不足カードがHOME本体の上に追加で表示される、より予算
の厳しい既存シナリオで、オフィス画像拡大分がその余白を超えていたため。
アイコンサイズを 26/28pt に抑えることで、このシナリオも含めた全ての既存
360x800/390x844 no-scroll テストが green になることを確認した上で最終
版とした（詳細は後述の「今回追加/更新した test」および tests 節を参照）。

### 3. 今月の重要タスク（`public_demo_home_presentation_components.dart`）

**Before**:
- タップ可能領域は右端の48x48 `IconButton`（矢印アイコン）のみで、タイ
  トル・補足・余白をタップしても何も起きなかった。
- 左右セルは `Row(crossAxisAlignment: start)` で各セルが自身の内容量だ
  け（タイトル/fact の折返し行数依存）の高さになり、片方が2行、もう片方
  が3行に折り返すと左右の高さが揃わなかった。

**After**:
- セル全体（`Semantics` → `Material` → `InkWell` → 装飾 → `Row`）を1つ
  の `InkWell` でラップし、アイコン・タイトル・fact・余白・矢印のどこを
  タップしても同一の `item.onPressed` が発火するようにした。ジェスチャ
  ー認識器はこの `InkWell` 一つだけなので、二重発火は構造的に発生しない
  （旧 `IconButton` は装飾用の `Icon` に置き換え、独自の `onPressed` は
  持たない）。
- タップ領域には `ConstrainedBox(minHeight: 48)` を追加し、短い1行タイト
  ル/factでも48ptのタップ領域を維持。
- 行を `IntrinsicHeight` + `Row(crossAxisAlignment: stretch)` でラップ
  し、左右セルの高さ（背景の枠含む）を常に同じ（= その行の中で最も高い
  セルの高さ）に揃えた。
- タイトル・fact のテキスト自体・`maxLines`・省略ルールは変更なし（省略
  していない）。
- `item.ctaLabel` はアイコン単体の `Semantics` から、セル全体を包む
  `Semantics(container: true, button: true, label: item.ctaLabel)` に移
  動。タイトル/fact の `Text` は同じ木の子ノードとして引き続きアクセシ
  ビリティツリーに個別に現れる（実測: 結合ラベルは
  `"対応する\n営業活動を進める\n営業残: 4回"` のような順で1つの
  button ノードに現れ、カテゴリアイコンは別ノードのまま — 詳細はテスト
  参照）。

## 360x800 / 390x844 maxScrollExtent

`test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`
（`SesTheme.build()` 適用、TextScaler 1.0、`flutter test`）で実測:

| viewport | maxScrollExtent |
|---|---|
| 360x800 | **0.0** |
| 390x844 | **0.0**（360x800 より実質的な余白があることも同スイートの別テストで確認） |

参考: 最終版での内訳（`flutter test`、`SesTheme.build()`適用、
TextScaler 1.0）:

- 360x800（viewport: y=56〜720）: `home-navigator` 167px /
  `home-office-stage` 118px / `public-demo-important-tasks` 108px。
  `public-demo-important-tasks` 下端は713px（ビューポート下端720pxまで
  マージン7px）。
- 390x844（viewport: y=56〜764）: `home-navigator` 170px /
  `home-office-stage` 127px / `public-demo-important-tasks` 108px。
  `public-demo-important-tasks` 下端は725px（マージン39px、360x800より
  余裕があることを既存テストでも確認済み）。

## tests

### 実行した既存 HOME focused tests（すべて green）

- `test/presentation/home/home_navigator_section_test.dart` — 60/60
- `test/presentation/home/home_office_stage_section_test.dart` — 40/40
- `test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`
- `test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart`
- `test/ui/public_demo/public_demo_01_home_final_density_test.dart`
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  — 12/12
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart` — 10/10
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart` — 16/16
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
  — 27/27
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
  （フル実行、既存分すべて green）
- `test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart` — 6/6
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
  — 全green（資金不足シナリオでの360x800/390x844 no-scroll検証を含む）
- `test/presentation/home/home_recommended_action_test.dart`
- `test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart`
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart`
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart`
- `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`
- プロジェクト全体の `flutter test`（フル実行、約1560テスト）を1回実行
  し、影響範囲の洗い出しに使った。本流のHOME以外を含む全テストの中から、
  今回の変更が直接原因の既存テスト2件（後述）を発見・修正した。

いずれも `flutter test`（本セッションでインストールした Flutter
3.44.9 stable、CI の `.github/workflows/*.yml` が指定するバージョンに合
わせた）で実行。

### フル実行で見つけた既存テストへの影響と修正

`git diff --check` / `flutter analyze` の前に、影響範囲を狭く見積もらな
いためプロジェクト全体の `flutter test` を実行した。以下の2件が、今回の
widget内部実装変更（旧 `IconButton` の廃止・オフィス画像サイズ変更）が
原因で実際に落ちていたので修正した（それ以外の既存の失敗は、作業用に一
時的に追加していた `test/ui/public_demo/zz_debug_*.dart` を実行中に削除
したことによる読み込みエラーのみで、最終コミットには含まれていない）。

1. **`public_demo_01_bottom_nav_tabs_test.dart`**: 共有ヘルパー
   `importantTaskCta()` が `find.byType(IconButton)` で重要タスクのCTAを
   探していたため、`IconButton` を装飾用 `Icon` に置き換えた今回の変更で
   見つからなくなっていた。`important-task-cta-<title>` キーで直接
   `InkWell`（＝タイル全体のタップ領域）を探すように更新。
2. **`public_demo_01_issue_124_screen_verification_test.dart`**
   （HOME-COMPACT-1B.4 FIX1: 実際の資金不足状態での360x800 no-scroll検
   証）: オフィス画像アイコンを当初 30/32pt にしたところ、資金不足カー
   ドがHOME本体の上に追加されるこのシナリオの既存予算を 1.07px だけ超え
   た。アイコンサイズを 26/28pt に抑えることで解消（本レポート冒頭の
   「社員の様子」節の「回帰の発見と修正」を参照）。

### 今回追加/更新した test（タスク必須の6項目に対応）

1. **360x800 no-scroll**: 既存
   `public_demo_01_home_one_screen_final_fit_test.dart` の
   `maxScrollExtent == 0` アサーションで確認（新規のオフィス画像拡大・
   CTA縮小の後も 0 のまま — 既存テスト、回帰なしを確認）。
2. **390x844 no-scroll**: 同上。
3. **重要タスク左右カード同高**:
   `public_demo_home_presentation_components_test.dart` に新規テスト
   `important tasks: the left and right tiles in a row always share the
   same height, even when one wraps to more lines than the other` を追
   加。片方だけ大幅に長いタイトル/factを与え、左右セルの `top` と
   `height` が一致することを検証。
4. **重要タスクのカード領域tapで既存actionが発火**:
   `public_demo_home_presentation_components_test.dart` の既存テスト
   `important tasks always renders all items ...` に、タイトルテキスト
   /factテキストを直接タップして同じ `onPressed` が発火することを追加
   検証（二重発火がないこと = 各タップでカウンタが1ずつしか増えないこと
   を確認）。
5. **Hiyori CTA/action維持**: `home_navigator_section_test.dart` の既存
   CTA発火テスト・secondary CTA テストがすべて green（action/キー不変を
   再確認）。アドバイス3行キャップの新しい期待値に既存テストを更新し、
   April実データの説明文がもう「続きを読む」を必要としないことを明示的
   に検証するテストを追加。
6. **社員データtruth維持**: `home_office_stage_section_test.dart`
   （40テストすべて既存のまま green）— 3人目の追加なし、ひよりの追加な
   し、headcount summary の一致（`employeeCount`/`waitingCount` はKPIと
   同一authority）を引き続き検証。

### 実ブラウザでの screenshot 比較

`flutter build web --release` + Playwright Chromium
（`/opt/pw-browsers/chromium-1194`、本番相当のフォント/画像）で
360x800 / 390x844 の Before/After を撮影し、目視確認した。Before は
`git stash` で `origin/main`（`123ec61`）に一時的に戻した状態でビルド。

## forbidden scope = none の確認

- Domain / Save-Persistence / Balance / Finance logic / Month transition
  / Sales・Employee domain logic / workflow authority / Employee UI
  Phase A / Active Project Visibility / fake data: **変更なし**（lib側
  差分はプレゼンテーション層3ファイルのみ、いずれもレイアウト・タップ処
  理のみで、状態・ロジックは無変更）。
- GitHub Actions / workflow: **変更なし**（`.github/` 配下は未変更）。
- Issue #183 の CI 変更: **変更なし**。
- unrelated refactor: **なし**（触れたのは3セクションの該当箇所のみ）。
- Quick Access 復活: **なし**（該当widgetは今回のdiffに含まれない）。
- 「他の行動を確認する」復活: **なし**（production側のsecondaryLabelは
  今回も未設定のまま。テストfixtureとして既存のまま存在するのみ）。
- 「スキルシート」表記: **維持**（`スキルシートを確認`
  / `home-navigator-advice-title` 等、文言は無変更）。

## screenshot paths

- `docs/reports/screenshots/SES_HOME-FINAL-TOUCH_BEFORE_360x800.png`
- `docs/reports/screenshots/SES_HOME-FINAL-TOUCH_BEFORE_390x844.png`
- `docs/reports/screenshots/SES_HOME-FINAL-TOUCH_AFTER_360x800.png`
- `docs/reports/screenshots/SES_HOME-FINAL-TOUCH_AFTER_390x844.png`

撮影スクリプト: `e2e/scripts/ses-home-final-touch-screenshot.mjs`
（既存の `ses-home-final-visual-match-screenshot.mjs` と同じ
サーバー/ブラウザ起動方式を踏襲した使い捨てスクリプト）。

## PR番号/URL

- **PR #184**: https://github.com/perusonao/smile_enjoy_story/pull/184

**自動mergeはしていない。**

## remaining visual differences

- ひよりカードのCTA幅（86%）は、ユーザー提示の設計仕様シート（2枚目の画
  像、フル幅ボタン想定）と比べるとわずかに狭い。これは「幅と高さを適度
  に縮小」という今回の指示に沿った意図的な変更であり、タップ領域
  （44pt高 × カード幅86%）は主要CTAとして引き続き十分な大きさを維持し
  ている。
- 実機スクリーンショット（ユーザー提示の1枚目）にあった「一歩ずつ、会社
  を大きくしていきましょう!」という吹き出しや3人目の社員写真は、設計仕
  様シート（2枚目）側のみに存在するモックであり、実際の runtime state
  （2名の engineer のみ）と矛盾するため、今回のFinal Touchでは意図的に
  実装していない（fake data 禁止のため）。
- `flutter test` は Flutter SDK の既知の制約により実フォント
  （NotoSansJP）ではなくテスト用フォントでレイアウトを測定するため、本
  レポートの実ブラウザスクリーンショットが実際の折返し・見切れの最終的
  な目視根拠であり、widget testの数値（maxLines等）はそれを補強する形。

## HOME Freeze readiness (Final Touch フェーズ時点): PASS

（このあと Visual SSOT Exact Layout Match フェーズを実施。最終的な
HOME Freeze readiness は本ファイル末尾を参照）

---

# SES HOME Visual SSOT Exact Layout Match — 追加フェーズ

## STATUS

完了。添付「360×800 HOME画面レイアウト仕様画像」を Visual SSOT として、
既存 PR #184（`claude/ses-home-final-touch-cbu8lw`）ブランチ上で追加実装。
新しい PR は作成していない。自動mergeはしていない。

## BASE / PR #184 final HEAD SHA

- **origin/main SHA**: `123ec613fb7bd39484f01c6994c6b4b23ca5309e`
  （このフェーズ開始時点でも main は動いていないことを `git fetch` で確
  認済み）
- **このフェーズ開始時点の PR #184 HEAD**: `0ac6df4377a475c1b6d4d8a9f9f8db5d7fd8a0b2`
  （Final Touch フェーズの最終コミット。前セクション参照）
- **このフェーズの PR #184 final HEAD SHA**: `5f38889`
  （`git log --oneline`: `5f38889` ← `bfdd943` ← `861557a` ← `0ac6df4`）
- ブランチ: `claude/ses-home-final-touch-cbu8lw`（変更なし、同一PR上で継続）

作業前提として、開始時に `git fetch origin` → 既存ローカルブランチが
PR #184 の最新 HEAD (`0ac6df4`) と一致していることを確認し、
`origin/main` が動いていないことも確認した。

## Visual SSOT used

ユーザーが本タスクで添付した2枚の画像のうち、

- **画像A（完成イメージ / レイアウト仕様）= Visual SSOT**
- **画像B（現在のHOMEスクリーンショット）= BEFORE**

を、指示された解釈のとおりに使用した（逆に解釈していない）。

## 実装前の差分列挙（画像A vs 画像B、実装前に作成）

| 項目 | 画像A（Visual SSOT） | 画像B（BEFORE = Final Touch完了時点） |
|---|---|---|
| section順序 | Header/Month/KPI/Hiyori/月次処理/Employee/Tasks/Nav | 同じ（差分なし） |
| KPI | 4+3構成 | 同じ（差分なし） |
| Hiyoriポートレート | 画面上かなりの存在感、縦に大きい | 縦150/158pt、Visual SSOTと比べ控えめ |
| Hiyori CTA | 適度な幅、フル幅ではない | 幅86%・高さ44pt（既にFinal Touchで対応済み、SSOTと大きくは違わない） |
| Employee Scene | 社員ポートレート＋**オフィス写真が独立したパネルとして右側に大きく表示** | オフィス画像はタイトル行の20〜28pt程度の小さいアイコンのみ。独立パネルなし |
| Employee Scene 社員人数 | 画像上は3名（社員2名は実データと矛盾するfake、無視） | 実データ通り2名（佐藤健・鈴木葵）— 変更しない |
| Important Tasks | icon→title→supporting text、2列、矢印 | 既にFinal TouchでPR #184の全面タップ・同高が実装済み。ほぼ差分なし |
| Bottom Nav | ホーム/社員/営業/会計/メニュー | 同じ（差分なし） |

→ 最大の構造的差分は **Employee Scene のオフィス写真の扱い**（小アイコン
vs 独立パネル）と **Hiyoriポートレートの存在感**（小さめ vs 大きめ）の
2点であり、この2点を中心に実装した。

## changed files（このフェーズ分）

```
lib/presentation/home/widgets/home_navigator_section.dart          (modified)
lib/presentation/home/widgets/home_office_stage_section.dart       (modified)
docs/reports/screenshots/SES_HOME-VISUAL-SSOT-EXACT_AFTER_360x800.png (new)
docs/reports/screenshots/SES_HOME-VISUAL-SSOT-EXACT_AFTER_390x844.png (new)
e2e/scripts/ses-home-visual-ssot-exact-screenshot.mjs               (new)
docs/reports/SES_HOME-FINAL-TOUCH_Result.md                        (modified, this file)
```

`test/` 配下は今回変更なし — 既存テストが新構造でもすべてそのまま green
だったため、テストの新規追加・改修は不要だった（後述）。

## section geometry（実測、`flutter test` + `SesTheme.build()`、TextScaler 1.0）

| section | 360x800 top-bottom (height) | 390x844 top-bottom (height) |
|---|---|---|
| home-kpi-compact | 95–219 (124px) | 95–219 (124px) |
| home-navigator | 220–391 (171px) | 220–394 (174px) |
| home-navigator-portrait | 220–380 (160×80px) | 220–383 (163×94px) |
| home-recommended-action-cta | 288–332 (44px) | 291–335 (44px) |
| public-demo-monthly-primary-cta-card | 394–487 (93px) | 397–490 (93px) |
| home-office-stage | 489–599 (110px) | 492–611 (119px) |
| home-office-stage-background（写真パネル） | 512–598 (86×97px) | 515–610 (95×106px) |
| public-demo-important-tasks | 601–709 (108px) | 613–721 (108px) |

viewport: 360x800 は y=56–720、390x844 は y=56–764。

## Hiyori before/after

**Before（Final Touch完了時点）**: `portraitWidth`/`portraitHeight` =
80/150（360x800）、94/158（390x844）。Row内で幅80×高さ150〜158の縦長
ポートレート。

**After**: `portraitHeight` を 150→160（360x800）、158→163（390x844）に
拡大（実測 +6.7%/+3.2%）。`portraitWidth` は80/94のまま据え置き。

**据え置きにした理由（重要・意図的な判断）**: 当初 `portraitHeight` を
170/173（このカードのテキスト列自身の高さ171/174ptぎりぎりまで）、
`portraitWidth` も92/106や84/98まで拡大する案を試したが、

1. `portraitWidth` を80から84pt（+4pt）にするだけで、テキスト列の幅が
   狭まり `HomeNavigatorAdvice.message`（`maxLines`制限なし、仕様上省略
   禁止）が2行に折り返り、カード高さが+18px増加した。
2. `portraitHeight` を170/173にすると、通常のApril状態では
   360x800/390x844とも `maxScrollExtent == 0` を維持できたが、より予算
   の厳しい既存シナリオ
   （`public_demo_01_issue_124_screen_verification_test.dart` の
   HOME-COMPACT-1B.4 FIX1: 実際の資金不足状態）で360x800が約9px
   overflowすることを`flutter test`フル実行で発見した。

タスク自身が定める優先順位（1. Visual SSOTレイアウト、2. 360×800の
no-scroll、…）に従い、**no-scroll制約を優先**し、`portraitHeight` を
両シナリオとも余裕を持ってno-scrollを維持できる160/163に、
`portraitWidth` は80/94（変更なし）に確定した。これは「幅を変えないこと
で高さの伸びしろが自由になる」という現行実装の物理的な制約に基づく、意
図的なトレードオフである。

## Employee Scene before/after

**Before（Final Touch完了時点）**: 「社員の様子」タイトル行の左に
20〜28ptの小さいオフィス写真アイコン（角丸・枠線あり）。その下に社員
ポートレート（48/54pt円形）が2列。オフィス写真は独立したパネルではな
かった。

**After**:
- オフィス写真をタイトル行から完全に除去し、社員カードの横に**3列目の
  独立した写真パネル**として配置（`_OfficePhotoPanel`）。
- 実装は `IntrinsicHeight` + `Row(crossAxisAlignment: stretch)`
  （`PublicDemoImportantTasksSection` が既に使っている左右同高の手法と
  同じ）で、写真パネルは常に社員カードの実際の高さ（ポートレート+氏名+
  状態バッジの合計）に自動的に揃う。
- 実データ通り、佐藤健・鈴木葵の2名の社員カード + 写真パネルで
  ちょうど3列（Visual SSOTの「Column1/Column2/Column3=オフィス写真」
  という構造そのもの）。
- 写真パネルが表示されるのは「表示中の社員/overflow chip の合計が
  `visibleSlotCount`（3）未満のとき」のみ — 実在の社員が3名以上いる場
  合は社員が優先され、写真パネルは表示されない（既存の
  `HomeOfficeStageDisplay`の3名上限・`+N`ロジックと完全に両立し、
  既存テスト40件すべて変更なしでgreenのまま）。
- タイトル行の高さ（`_titleRowHeight`）はアイコンが行から消えたため
  28pt→20ptに縮小 — ここで浮いた分がHiyoriポートレートの拡大に充てら
  れた。
- 社員ポートレートサイズ・氏名・ステータス表示（`_MemberCard`）は無変
  更。3人目の追加、ひよりの社員追加、fake dataの追加は一切なし。

## Important Tasks before/after

Final Touch フェーズで既に icon→title→supporting text の階層・2列・
同高・全面タップ・単一発火を実装済みで、Visual SSOTの構造と一致してい
たため、このフェーズでは**変更なし**。

## 360x800 / 390x844 maxScrollExtent（このフェーズの最終確認）

`flutter test`、`SesTheme.build()`、TextScaler 1.0:

| viewport | maxScrollExtent |
|---|---|
| 360x800（通常April状態） | **0.0** |
| 390x844（通常April状態） | **0.0** |
| 360x800（実資金不足状態、HOME-COMPACT-1B.4 FIX1シナリオ） | 該当セクションがすべてviewport内（`public_demo_01_issue_124_screen_verification_test.dart`で確認） |
| 390x844（実資金不足状態） | 同上 |

## TextScaler 1.3 / 2.0 の確認

`public_demo_01_home_one_screen_final_fit_test.dart` /
`public_demo_01_home_final_density_test.dart` の既存テスト
（360x800・390x844 × textScale 1.3/2.0）で:

- horizontal overflowなし（`tester.takeException()` が null であること
  を確認）
- 今月の重要タスクの各タップ領域が引き続き実質48px以上
- Hiyori CTAが見つかる場合は44px以上

を確認済み。縦scrollは許容される仕様のため、縦方向のoverflow例外が出な
いことのみを確認している。

## tests

### 実行した既存 HOME focused tests（このフェーズ後、すべて green）

- `test/presentation/home/home_navigator_section_test.dart` — 101/101
- `test/presentation/home/home_office_stage_section_test.dart` — 40/40
- `test/presentation/home/home_recommended_action_test.dart`
- `test/ui/public_demo/public_demo_01_home_one_screen_final_fit_test.dart`
- `test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart`
- `test/ui/public_demo/public_demo_01_home_final_density_test.dart`
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`
- `test/ui/public_demo/public_demo_01_home_office_stage_test.dart`
- `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart`
- `test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
- `test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart`
- `test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart`
  （資金不足シナリオを含む）
- `test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart`
- `test/ui/public_demo/public_demo_01_home_navigator_test.dart`
- `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart`
- `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart`

合計303テストを1回にまとめて実行し、すべてgreen（`flutter test ... 2>&1`
の最終行 `All tests passed!`、exit code 0）。**既存テストの改修は不要**
だった — Employee Sceneの構造変更（写真パネルの追加）は
`IntrinsicHeight`+`stretch`という非破壊的な追加方式にしたため、既存の
`home_office_stage_section_test.dart` 40件が無改修でそのまま通った。

### 実装中に発見・修正した回帰（このフェーズ中）

1. **Hiyoriポートレート幅+4ptでメッセージが2行折返し**: 上記「Hiyori
   before/after」参照。`portraitWidth`を80/94に据え置くことで解消。
2. **Hiyoriポートレート高さ170/173で実資金不足シナリオが約9pxオーバー
   フロー**: `public_demo_01_issue_124_screen_verification_test.dart`
   のフル実行で発見。`portraitHeight`を160/163に抑えることで解消（両
   シナリオ・両サイズで再確認済み）。

## flutter analyze

`flutter analyze` — **No issues found!**（このフェーズの変更後、実行済
み）

## git diff --check

`git diff --check` — 出力なし（trailing whitespace等の問題なし）。

## Visual comparison table（Visual SSOT vs AFTER 360×800 screenshot）

| 項目 | 判定 | 備考 |
|---|---|---|
| Header | MATCH | ハンバーガー/タイトル/通知ベルの配置・高さとも一致 |
| Month | MATCH | 「1年目 4月」中央表示、一致 |
| KPI | MATCH | 4+3構成、既存stateのみ使用、一致 |
| Hiyori | ACCEPTABLE DIFFERENCE | ポートレート高さを150→160/158→163に拡大し明確に存在感が増したが、Visual SSOTほどの幅の広さ・全身感には達していない（メッセージ折返しコストのため意図的に据え置き — 上記「Hiyori before/after」参照）。asset自体の服装/ポーズの違いも許容差。 |
| Monthly Processing | MATCH | 赤系カード・アイコン・説明・ボタンとも一致 |
| Employee Scene | MATCH | 社員2名（実データ通り）+ オフィス写真パネルの3列構造を実現。写真は独立パネルとして十分な大きさで表示され、単なるアイコンでも全面背景でもない。3人目社員は実データに存在しないため意図的に不在（許容差） |
| Important Tasks | MATCH | icon→title→supporting text、2列同高、全面タップ、Final Touchフェーズで実装済み |
| Bottom Navigation | MATCH | 5タブ構成、固定表示、変更なし |

## 許容差として扱った項目（記録）

- Hiyoriポートレートの幅（80/94のまま） — no-scroll制約優先による意図
  的な判断（MISMATCHではなくACCEPTABLE DIFFERENCEと判断した理由は上表
  の通り）。
- Hiyori asset自体の服装・ポーズ — 既存bundled assetをそのまま使用。
- 実フォント差 — `flutter test`はテスト用フォントを使うため実ブラウザ
  との数px差はあり得るが、実ブラウザスクリーンショットで目視確認済み。
- Employee Sceneの3人目社員 — 実データに存在しないため意図的に不在。

## forbidden scope = none の確認（このフェーズ）

- Domain / Save-Persistence / Balance / Finance logic / Month transition
  / Sales・Employee domain logic / workflow authority / Issue #148 /
  Issue #167 / Year-End / Employee UI Phase A / Active Project
  Visibility / Issue #183のCI変更 / unrelated refactor: **変更なし**。
  lib側の差分は `home_navigator_section.dart`（定数値のみ）と
  `home_office_stage_section.dart`（プレゼンテーション層の構造変更の
  み、`HomeOfficeStageDisplay`モデル自体は無変更）の2ファイルのみ。
- `HomeOfficeStageDisplay.members` は引き続き `workflow.engineers` の
  みを参照 — fake employee/fake data 追加なし。
- Hiyoriのaction/遷移先（`advice.onCtaPressed`）は無変更。
- GitHub Actions / `.github/` 配下: 変更なし。
- 新しいPRは作成していない（既存PR #184上で継続）。
- 自動mergeはしていない。

## screenshot paths

- `docs/reports/screenshots/SES_HOME-VISUAL-SSOT-EXACT_AFTER_360x800.png`
- `docs/reports/screenshots/SES_HOME-VISUAL-SSOT-EXACT_AFTER_390x844.png`
- （BEFORE個別スクリーンショットは撮影していない。Final Touchフェーズの
  `SES_HOME-FINAL-TOUCH_BEFORE_*.png` がこのフェーズの実質的なBEFOREに
  相当し、上記「実装前の差分列挙」で画像Bとして比較・記録済み）

撮影スクリプト: `e2e/scripts/ses-home-visual-ssot-exact-screenshot.mjs`
（既存スクリプトと同じサーバー/ブラウザ起動方式を踏襲）。

## PR番号/URL

- **PR #184**: https://github.com/perusonao/smile_enjoy_story/pull/184
  （同一PR、新規PRなし）

**自動mergeはしていない。**

## remaining visual differences（このフェーズ後）

- Hiyoriポートレートの幅がVisual SSOTほど広くない（意図的、上表参照）。
- Employee SceneのVisual SSOTは3名の社員（うち1名はfake）+ 独立した
  巨大な写真パネルという構成だが、実装は実データの2名+写真パネルの3列
  という、指示された「データはstate優先」ルールに従った構成。
- それ以外の主要構造（section順序、KPI、Monthly Processing、
  Important Tasks、Bottom Navigation）はVisual SSOTと一致。

## VISUAL SSOT MATCH: PASS

## HOME FREEZE READY: YES
