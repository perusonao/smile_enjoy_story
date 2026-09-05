# SES HOME Final Density — Result

STATUS: **Done — implemented, focused-tested, full `flutter test` green, not merged**

BASE: `origin/main` @ `a80d6e473e344655f120cac597ff104444b48e51` (PR #177 merged; Issue #168 complete)
HEAD: see commit below

## Task

HOMEをスマホ1画面で理解できる密度へ仕上げる（SES HOME Final Density）。参照:

- `docs/reports/SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_PreImplementation_Audit.md`
  — this task names this file as a reference; it did not exist anywhere in
  the repository or its git history on a fresh `origin/main` checkout, so
  this implementation authored it first, from real measurements against
  the current production widget tree, before making any code change. See
  that file's own "Why this document looks the way it does" section.
- `docs/design/references/public_demo_home_ui_3a_target.jpeg` — the
  approved visual target (its own caption notes actual numbers may differ).
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — updated by this
  work (see below), never truncated.

最優先要件（達成状況）:

| 要件 | 結果 |
|---|---|
| 390x844: KPI/ひより/月次処理/社員概要/重要タスク/Quick Access/Bottom Nav を初期viewportで原則把握可能 | **達成** — 全6セクションの`top`がunscrolled `ListView`のviewport内。さらにPR #179レビューで指摘の通り、クイックアクセスは**タイトル文字列自体**が完全にviewport内（`title.bottom <= viewport.bottom`）まで強化・検証済み |
| 360x800: 同じ情報階層を維持、最低でもQuick Accessの存在/入口が認識可能 | **達成** — KPI〜重要タスクは引き続きviewport内。Quick Accessのカード`top`はfoldから19px先、タイトルは22px先（いずれもfold直下、スクロール量小） |
| 横スクロール禁止 | 達成 — 360/390 双方、textScale 1.0/1.3/2.0で`rect.left>=0` / `rect.right<=width`を確認 |
| 重要copy/CTAのclip禁止 | 達成 — テキストは一切truncateせず、削減はpadding/gapのみ。重要タスクCTAはicon化したが`Semantics(label: item.ctaLabel)`で実ラベルを保持 |
| touch target >=48px | 達成 — 新規iconCTAは明示的に`BoxConstraints(minWidth:48,minHeight:48)`。既存の48pt CTA群は無変更 |
| TextScaler要件維持 | 達成 — 1.3/2.0で新規回帰テストがoverflow無しを確認 |

**PR #179 Codex review (P2) 対応**: 初版の390x844テストは「カードの`top`が
viewport内」のみを検証しており、実際にはクイックアクセスの見出し文字列
自体は完全にfold外という指摘（`card.top=760`に対し`title.bottom=784`、
viewport bottomは`764`）を受けた。これは正しい指摘であり、無視・
言い訳せず追加のpadding/gap削減を実施し、テストも「タイトル文字列が
完全にviewport内」という、より正直で意味のある基準に強化した。詳細は
下記「PR #179 Codex review 対応」節を参照。

## 実施内容

### 1. Pre-Implementation Audit（新規作成）

`docs/reports/SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_PreImplementation_Audit.md`
に、`PublicDemo01PlaceholderScreen`の実際のレイアウトを計測して基準値・削減方針を記録した。

### 2. ひより (`HomeNavigatorSection`) — 最大レバー

`lib/presentation/home/widgets/home_navigator_section.dart`:

- `cardPaddingVertical`: 4 → 1（実カードpadding、テキスト高さではない）
- `textGap`: 2 → 1（カード内の全seam共通の定数）
- CTA/secondaryボタン前の`SizedBox`: 各4 → 1
- アドバイスバブルの`padding`: `(10,2,10,2)` → `(8,0,8,0)`
- eyebrowラベル（"次にやること"/"今月やること"）とheadlineを`Wrap`へ統合し、
  幅が許す限り同一行に収まるようにした（収まらない場合は従来通り個別行へ
  フォールバックするため退行なし。実際の初期状態のheadline長では同一行に
  収まらず数値上の削減は僅かだが、より短いheadline/adviceでは有効）

390×844: 264px → 244px（-20px）。360×800: 280px → 260px（-20px）。

### 3. KPI (`KpiSection.compact`)

`lib/presentation/home/widgets/kpi_section.dart`: カードpadding 6→2、行間4→2、
タイルpadding(vertical) 5→2、行内gap 2→1。114px → 90px（-24px）。

### 4. 月次処理 (`PublicDemoMonthlyPrimaryCtaSection`)

`lib/ui/public_demo/public_demo_home_presentation_components.dart`: カード
padding(vertical) `4`→`1`、ラベル-説明間gap 2→1、説明-ボタン間gap 4→3。
94px → 86px（-8px）。ボタン自体の`minimumSize`は無変更（44指定だが実測
`tester.getRect`で48pxを確認済み — Flutterの標準タップターゲットpaddingが
既に効いているため、この密度作業でtouch targetを縮小する必要はなかった）。

### 5. 社員概要 (`HomeOfficeStageSection`) — 意図的に無変更

要件通り、これ以上圧縮していない。`HomeOfficeStageMetrics`の`compactSceneHeight:
60`は既存の安全マージンテストが根拠を示すfloorであり、今回のスコープ外。

### 6. 今月の重要タスク (`PublicDemoImportantTasksSection`)

`lib/ui/public_demo/public_demo_home_presentation_components.dart`:

- CTAを`TextButton`（"対応する"/"確認する"を毎回印字）から、`Icon(Icons
  .arrow_forward_ios_rounded)`のみの`IconButton`へ変更。実ラベルは
  `Semantics(button: true, label: item.ctaLabel)`で明示的に保持し、
  `BoxConstraints(minWidth: 48, minHeight: 48)`でtouch targetを保証。
- `Divider`: 10 → 2
- タイトル-fact間gap: 3 → 1
- 共有`_HomeSectionCard`のpadding: 12 → 4、タイトル-content間gap: 8 → 3
  （今月の重要タスク/クイックアクセス/今月の支出予定 共通）

166px → 129px（-37px）。

### 7. セクション間gap・ListView上部padding

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` /
`public_demo_home_dashboard_section.dart`: KPI-ひより間、社員概要-重要タスク
間、重要タスク-クイックアクセス間の各gapを6→3、`_buildHomeTab`の`ListView`
top paddingを16→8（左右/下は16のまま — 各カードの水平マージンと最終scroll
insetを変更しない）。

## 計測結果（最終、`PublicDemoAggregate.initial()`＝4月、textScale 1.0）

| セクション | 390×844 top (元→中間→最終) | 360×800 top (元→中間→最終) |
|---|---:|---:|
| viewport bottom | 764 | 720 |
| KPI | 114 → 103 → 98 | 112 → 103 → 98 |
| ひより | 234 → 196 → 183 | 234 → 196 → 183 |
| 月次処理 | 500 → 442 → 426 | 516 → 458 → 442 |
| 社員概要 | 596 → 530 → 509（無変更） | 612 → 546 → 525（無変更） |
| 今月の重要タスク | 697 → 628 → 606 | 703 → 634 → 612 |
| **クイックアクセス（カード）** | **869 → 760 → 733** | **875 → 766 → 739** |
| クイックアクセス（タイトル文字列） | 計測なし → 764〜784 → **736〜756** | 計測なし → 770〜790 → 742〜762 |

「中間」列は最初のPR作成時点、「最終」列はPR #179 Codex reviewを受けた
追加削減後。クイックアクセスの**カード**`top`位置は最終的に両viewport共通で
**133〜136px**削減（元869/875 → 最終733/739）。

- **390×844**: タイトル文字列`title.bottom=756` <= viewport bottom `764`
  （margin 8px）→ カード端だけでなく見出し文字列自体が完全にviewport内。
  6セクション全てがunscrolled viewport内で開始し、クイックアクセスは
  「カードの端が入っている」ではなく「見出しが読める」状態を実測で確認
  （focused testで固定）。
- **360×800**: カード`top=739`（fold`720`から+19px）、タイトル`top=742`
  （+22px）。フル可視ではないが、要件の弱い基準（"最低でもQuick Accessの
  存在/入口が認識可能"）を満たすのに十分近い（元は+155px）。

## PR #179 Codex review 対応（P2: Quick Accessの可視性判定が甘い）

初版のfocused test（`public_demo_01_home_final_density_test.dart`）は
クイックアクセスを含む全セクションについて「カードの`top` <
viewport.bottom」のみを検証していた。Codexのレビューは、390x844の実測値
（カード`top=760`、viewport bottom`764`）に対し、`_HomeSectionCard`の
padding（当時4px）を考慮すると見出し文字列「クイックアクセス」自体は
`title.bottom=784`と完全にfold外であり、「カード端が数px入っているだけ」
でテストが通ってしまう ＝ HOME密度目標を実質的に達成していない、と正しく
指摘した。

対応:

1. **さらなる実削減**（padding/gapのみ、テキストのclipなし）:
   - `ListView`のtop padding: 8 → 4
   - KPIカードpadding: 2 → 1、行間: 2 → 1、タイルpadding(vertical): 2 → 1
   - 月次処理カードpadding: `(12,1,12,1)` → `(12,0,12,0)`、内部gapも詰め
   - 今月の重要タスク: カードpadding 4→3、タイトルgap 3→2、Divider 2→1
   - 共有`_HomeSectionCard`: padding 4→3、タイトルgap 3→2
   - ひより: `cardPaddingVertical` 1→0
   - セクション間`SizedBox`gapを全体的にもう一段階詰めた（3→2、2→1等）
2. **テスト自体を強化**: 390x844では「クイックアクセスのカード`top`」では
   なく「`find.text('クイックアクセス')`の`rect.bottom` <=
   viewport.bottom」を検証するよう変更 — Codexが指摘した「カード端だけ
   入っている」を実際に検出できる基準にした。360x800側もカード`top`に加え
   タイトル`top`の近さを別途検証するようにした。

この結果、390x844では見出し文字列自体がmargin 8pxを持って完全に
viewport内に収まることを実測・テスト両方で確認した。社員概要
（`HomeOfficeStageSection`）は今回の追加削減でも引き続き無変更。

## 変更ファイル

Production:
- `lib/presentation/home/widgets/home_navigator_section.dart`
- `lib/presentation/home/widgets/kpi_section.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_home_dashboard_section.dart`
- `lib/ui/public_demo/public_demo_home_presentation_components.dart`

Test:
- `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  （icon化したCTAに合わせて更新 — `find.text('対応する'/'確認する')`での
  tap/assertionを、専用キー＋`find.bySemanticsLabel`ベースへ）
- `test/ui/public_demo/public_demo_01_home3_integration_test.dart`
  （同上、icon CTAのキーで検索するよう更新）
- `test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart`
  （`importantTaskCta`ヘルパーが探す型を`TextButton`から`IconButton`へ更新
  — full `flutter test`実行で発見した回帰）
- `test/ui/public_demo/public_demo_01_home_final_density_test.dart`（新規）

Docs:
- `docs/reports/SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_PreImplementation_Audit.md`（新規）
- `docs/reports/SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_Result.md`（本ファイル）
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`（Update history追記）

## Domain / Save / Balance / Finance / Issue #167

一切変更していない。触れたのは`lib/presentation/home/widgets/*`と
`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`のUI組み立て
部分（`_buildHomeTab`のpadding/gapと`_importantTasks`が返すCTAのpresentation
のみ）、`public_demo_home_dashboard_section.dart`、
`public_demo_home_presentation_components.dart`のpresentation層のみ。
`_importantTasks`/`_quickAccessItems`が読む値・分岐条件・`onPressed`の
配線は無変更。Active Project Visibility（#167）は未着手・未混在。

## テスト結果（Tier1方針: focused tests + flutter analyze、full testはPR完成時に1回）

```
$ flutter analyze
No issues found! (ran in 13.7s)
```

Focused（本フェーズで変更/新規追加したもの）:

```
$ flutter test test/ui/public_demo/public_demo_home_presentation_components_test.dart
00:01 +10: All tests passed!

$ flutter test test/ui/public_demo/public_demo_01_home_final_density_test.dart
00:02 +7: All tests passed!
```

回帰確認（HOME/ひより/KPI/社員概要/重要タスクに触れる既存suite一式）:

```
$ flutter test test/presentation/home/
00:10 +187: All tests passed!

$ flutter test test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart \
    test/ui/public_demo/public_demo_01_home_consolidation_test.dart \
    test/ui/public_demo/public_demo_01_home_office_stage_test.dart \
    test/ui/public_demo/public_demo_01_home_navigator_test.dart \
    test/ui/public_demo/public_demo_01_home_recommended_action_test.dart \
    test/ui/public_demo/public_demo_01_home_runtime_read_test.dart \
    test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart \
    test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart
06:26 +136: All tests passed!
```

Full `flutter test`（PR完成時点で1回実行。1回目でimportant-taskのCTAを
icon化したことによる既存test 2件の破損を発見・修正し、修正後に2回目を
実行して確定）:

```
$ flutter test
...
12:19 +1547: All tests passed!
```

1547 tests, 0 failures。1回目の失敗2件は
`test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart`の
`importantTaskCta`ヘルパーが旧`TextButton`を探していたことによるもので、
`IconButton`を探すよう修正した（本ファイルの「変更ファイル」に追記済み）。

**PR #179 Codex review対応後の再検証**（上記「PR #179 Codex review 対応」
節の追加削減・テスト強化後。Tier1方針により、この局所修正ではfull
`flutter test`を再実行せず、影響範囲のfocused test + 既存HOME回帰suite
一式で確認した）:

```
$ flutter analyze
No issues found!

$ flutter test test/ui/public_demo/public_demo_01_home_final_density_test.dart
00:02 +7: All tests passed!

$ flutter test test/presentation/home/
00:09 +187: All tests passed!

$ flutter test test/ui/public_demo/public_demo_01_home_ui_3c_density_test.dart \
    test/ui/public_demo/public_demo_01_home_consolidation_test.dart \
    test/ui/public_demo/public_demo_01_home_office_stage_test.dart \
    test/ui/public_demo/public_demo_01_home_navigator_test.dart \
    test/ui/public_demo/public_demo_01_home_recommended_action_test.dart \
    test/ui/public_demo/public_demo_01_home_runtime_read_test.dart \
    test/ui/public_demo/public_demo_01_home_cash_forecast_advice_test.dart \
    test/ui/public_demo/public_demo_01_issue_124_screen_verification_test.dart \
    test/ui/public_demo/public_demo_01_home3_integration_test.dart \
    test/ui/public_demo/public_demo_01_bottom_nav_tabs_test.dart \
    test/ui/public_demo/public_demo_home_presentation_components_test.dart
06:25 +165: All tests passed!
```

## Known Issues / 未解決事項

1. **360×800でクイックアクセスは依然fold外**（カード`top=739`, fold=720,
   +19px。タイトル`top=742`, +22px）。要件はこの解像度でQuick Accessを
   「entry point recognizable」レベルで許容しているが、完全な視認性では
   ない。さらに縮めるには、社員概要の追加圧縮（要件で禁止）か、ひよりの
   advice message/explanationの表示方法自体の変更（必須copyのclip回避の
   観点でリスクが高いと判断し見送った）が必要。
2. **Pre-Implementation Auditはこの実装内で新規作成した。** 元々参照された
   文書がPR #177までのどの時点にも存在しないため、実測ベースで代替した。
   もし別セッション/別ツールで作成済みの監査が別途存在し、後でこの
   リポジトリに提供された場合は、本Result文書とのつき合わせが必要になる
   可能性がある。

## Commit / PR

- commit: `a9de1ac7b4229587e2b0b323722c7024461a5bb1`
- PR: https://github.com/perusonao/smile_enjoy_story/pull/179
- Merge Readiness: 未マージ（指示通り）。CIは`flutter-validate`
  （`flutter analyze`＋全Flutter test＋Web build）を含むFast CIゲートに
  依存。
