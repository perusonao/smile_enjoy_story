# SES HOME Final Touch — 実装結果

## STATUS

完了。実機スクリーンショットで確認された3点（ひよりカード / 社員の様子 /
今月の重要タスク）のみを修正。新機能追加・別画面改修・domain/finance/
workflow/CI 変更はなし。

## BASE / HEAD

- **BASE SHA**: `123ec61` (`origin/main`, PR #182 マージ後の最新)
- **FINAL HEAD SHA**: `d1c85c3`
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
- CTA の高さを 48pt → 40pt（`minimumSize` + `tapTargetSize:
  MaterialTapTargetSize.shrinkWrap` — Material のデフォルト48pt下駄を明
  示的に外している）、vertical padding を 12 → 8 に縮小。
- CTA の幅を `FractionallySizedBox(widthFactor: 0.86)` + 左寄せで、カー
  ド幅の86%に縮小（フル幅ベタ塗りを回避）。
- アドバイスバブルの折返し上限を2行→3行に拡大（`_collapsedMaxLines`）。
  「続きを読む」は3行に収まらない場合のみ表示される一方通行の展開ボタン
  のまま。
- action/遷移先（`advice.onCtaPressed`）は完全に不変。
- ひより画像サイズ（`portraitWidth`/`portraitHeight`）は不変 — 存在感を
  維持。

結果、CTA は主要導線として十分な40pt・カード幅86%のタップ領域を保ちなが
ら、アドバイス本文の実質表示行数が増え、実機で見切れていた文が全文表示さ
れるようになった（スクリーンショットで確認、後述）。

### 2. 社員の様子（`home_office_stage_section.dart`）

**Before**: オフィス画像アイコンが 20pt(360)/22pt(390) と小さく、枠線も
なく、実機ではオフィス写真であることがほぼ判別できなかった。

**After**:
- 既存の同一アセット（`display.backgroundAssetPath` /
  `AssetPaths.locationOfficeDayHomeBanner`）はそのまま、サイズのみ
  20→30pt（360x800）、22→32pt（390x844）に拡大。
- 社員ポートレートと同様の薄い枠線（`Border.all(outlineVariant)`）と角丸
  を追加し、単なるアイコングリフではなく「小さな写真」として認識できる
  枠組みに変更。
- レイアウト定数 `_titleRowHeight` を実際に描画される最大アイコンサイズ
  （32）に合わせて更新（`compactComponentHeight`/`safetyCeiling` の予測
  値が実測値を下回らないようにするため）。
- 社員2名（佐藤健・鈴木葵）の顔写真・氏名・ステータス（「待機」）表示は
  変更なし。
- 実在しない3人目の追加、ひよりの社員追加、fake data の追加は一切なし
  （`HomeOfficeStageDisplay.members` は `workflow.engineers` のみを引き
  続き参照）。

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

参考: 実装中に取得した内訳（`flutter test`、TextScaler 1.0）:

- 360x800: `home-navigator` 167px / `home-office-stage` 122px /
  `public-demo-important-tasks` 108px。ビューポート下端720pxに対し
  `public-demo-important-tasks` 下端は717px（マージン3px）。
- 390x844: 同様に `maxScrollExtent = 0`、360x800よりマージンが大きいこと
  を確認済み。

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

いずれも `flutter test`（本セッションでインストールした Flutter
3.44.9 stable、CI の `.github/workflows/*.yml` が指定するバージョンに合
わせた）で実行。

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

PR作成後にこのセクションを更新する（本レポートのコミット後、GitHub上で
PRを1本作成し、番号とURLをここに追記する）。**自動mergeはしない**。

## remaining visual differences

- ひよりカードのCTA幅（86%）は、ユーザー提示の設計仕様シート（2枚目の画
  像、フル幅ボタン想定）と比べるとわずかに狭い。これは「幅と高さを適度
  に縮小」という今回の指示に沿った意図的な変更であり、タップ領域
  （40pt高 × カード幅86%）は主要CTAとして引き続き十分な大きさを維持し
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

## HOME Freeze readiness: PASS
