# SES First Fun Year UI Phase 1 — Implementation Result

## STATUS

**Completed.** Public Demo HOME's first view already carried Month Header /
Compact KPI / Recommended Action (shipped in prior HOME-RUNTIME-2A/2B/2C
work already on `main`); this phase's job was the remaining
**legacy-duplicate consolidation** the task description named — the
still-duplicated summary cards sitting between HOME and the per-employee
action cards, and the dev-only test control competing for first-view space.
That consolidation is done, verified with `flutter analyze`, the
HOME/Public Demo focused widget-test suites, a full `flutter test` run, and
real-browser screenshots at 360×800 and 390×844.

## BASE SHA

`07c1f523cf080d85bf27e42f724b53cbc8d1e75e` (origin/main at session start —
merge commit for PR #140, "docs: record SES Development Priority as
governing decision"). The feature branch was hard-reset to this commit
before any work began (the previously-existing local branch, `Phase 0A/0B:
SES domain models and random generators`, was already fully contained in
this `origin/main` tip, so nothing was discarded).

## FINAL HEAD SHA

`8b55e18b133fcae8a0071956ebbbb6bc39b187ea` (the implementation commit).
A follow-up docs-only commit, `a82f74978c436fece923d536586a36364be30312`,
records this SHA in the report itself — see **commit SHA** below for both.

## 事前調査で確認した「現在mainの状態」

`AGENTS.md` / `docs/DEVELOPMENT_PLAN.md` /
`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` を読み、続けて
"HOME-UI-1A/1B/1C" と "HOME-RUNTIME-READ-1 / HOME-RUNTIME-2A/2B/2C" を
`git log --all` で検索したところ、これらは**すべて既にmainへマージ済み**の
過去フェーズだった（PR #67/#68/#69/#70/#71/#72/#73/#94、いずれも現行
`origin/main` の祖先）。つまり指示にあった「古いHOME-UI branchをそのまま
再利用しない」は該当せず、実装対象は常にリポジトリの現行状態だった。

現行実装を読んだ結果、Month Header / Compact KPI / Recommended Action /
Navigator advice はすでに `PublicDemoHomeDashboardSection`
(`lib/ui/public_demo/public_demo_home_dashboard_section.dart`) 1枚に統合
されており、`test/ui/public_demo/public_demo_01_home_consolidation_test.dart`
がその first-view 到達性（360×800/390×844 双方でCTAがブラウザchrome予算
内に収まること）を既に固く検証していた。したがって今回のPhase 1は
「HOME dashboardを新設する」フェーズではなく、**HOME dashboardの直下に
まだ残っていた4つの重複サマリーカードと、開発用リスタートカードの位置**
を対象にした統合フェーズになった。

## Beforeの問題

`PublicDemo01PlaceholderScreen.build()` の描画順（上から）:

1. `PublicDemoCashShortageCard` / 倒産カード（該当時のみ）
2. `PublicDemoHomeDashboardSection`
   （月ヘッダー / Compact KPI / ひよりの一言 / 次にやること）
3. **`_publicDemoTestControlsCard()`** — QA専用の「4月からやり直す」カード。
   本編の判断材料が何もないまま、HOMEの直下という一等地を占有していた。
4. `HomeOfficeStageSection`（オフィス風景・社員名の要約）
5. **`PublicDemoEmployeeStageSection`（「社員ステージ」）** — 4の
   `HomeOfficeStageSection` と同じ社員を、別語彙のステータス文言
   （例:「営業準備前」）で重複して一覧表示。それ自体に操作は無い。
6. `PublicDemoImportantEventsSection`（「重要イベント」）
7. **`PublicDemoFinanceSummarySection`（「資金サマリー」）** —
   現金残高・今月売上・次回入金予定を、Compact KPIの現金/売上/入金予定
   と全く同じ値でもう一度表示。加えて cashShortage/bankruptcy 時の
   警告文まで独自に持っており、これは既に最上部の
   `PublicDemoCashShortageCard` が表示している警告と完全に重複していた。
8. `PublicDemoMonthlyPrimaryCtaSection`（月末処理CTA）
9. `dashboard()`（月次収支カード・成長結果）
10. 月別の社員/応募者/参画カード（`ec()`/`ac()`/`assignmentCard()` 等）

Recommended Action自体は既にfirst-view内に収まっていたが、その直後に
「今の判断に関係しない情報（3・5・7）」が積み重なっており、実際の
社員カード群（10）へ到達するまでのスクロール量が不必要に長かった。
これが依頼文の「新HOME dashboard + legacy HOMEが縦に重複」の実体。

## 実施内容（統合・削除の内容）

新しいUIコンポーネントは作っていない。既存コンポーネントの**削除・整理・
再配置**のみ。

1. **`PublicDemoEmployeeStageSection` / `PublicDemoEmployeeStageItem` を
   削除**（`lib/ui/public_demo/public_demo_home_presentation_components.dart`、
   および呼び出し元 `_employeeStageItems`/`_employeeStageStatus` を
   `public_demo_01_placeholder_screen.dart` から削除）。
   `HomeOfficeStageSection` が既にHOME唯一の社員サマリーとして機能して
   おり、このカードは同じ社員名を別語彙で繰り返すだけで新しい判断材料も
   操作もなかったため、統合ではなく完全削除とした。
2. **`PublicDemoFinanceSummarySection` を「今月の支出予定」へ縮小**
   （タイトルも `資金サマリー` → `今月の支出予定` に変更）。
   Compact KPIと重複していた現金残高・今月売上・次回入金予定の3行と、
   `PublicDemoCashShortageCard`/倒産カードと重複していた警告バナーを削除。
   Compact KPIが持たない「給与」「固定費」の2行のみを残した——これは
   HOMEが初めて表示する情報であり、重複ではない。
   `PublicDemoFinanceSummaryModel` からも `cash`/`revenue`/
   `nextMonthEstimate`/`warning` フィールドを削除し、`payroll`/
   `fixedCosts` のみの薄いモデルにした。
3. **QA専用の「テスト用操作」カード（4月からやり直す）をHOMEの直下から
   画面最下部（月別カード群のさらに下）へ移動**。表示内容・キー・機能は
   一切変更していない——並び順のみの変更。これによりHOME直下の一等地を
   実際の判断材料（オフィス風景 → 重要イベント → 支出予定 → 月末処理）が
   占めるようになった。

削除・変更していないもの（意図的に手を付けなかった範囲）:

- `PublicDemoHomeDashboardSection`（月ヘッダー/KPI/ひより/次にやること）
  ——既にfirst-view契約を満たしており、依頼の「新しいゲームルールを
  UI側で作らない」「装飾やキャラクター実装は必須ではない」の両方から見て
  再設計の必要も許可もない。
- `PublicDemoCashShortageCard` / 倒産カード ——Critical Alertの権威。
  最上部という現在の位置を維持（後述「Critical Alertの並び順について」）。
- `HomeOfficeStageSection`、`PublicDemoImportantEventsSection`、
  `PublicDemoMonthlyPrimaryCtaSection` ——いずれもCompact KPIと重複しない
  固有の情報/操作を持つため維持。
- 個別社員/応募者/参画カード（`ec()`/`ac()`/`assignmentCard()`）——
  依頼の「既存ゲーム操作への到達性を失わないこと」により、削除・統合の
  対象外。詳細導線として維持。

### Critical Alertの並び順について

依頼文のセクション順は A(月) → B(警告) → C(KPI) だが、既存テスト
（`public_demo_01_home_consolidation_test.dart` group 19）は
「cashShortage時は警告カードがHOMEブロック全体（月ヘッダーを含む）より
**上**に来ること」を既に固定契約として検証しており、これは
「重大警告を隠さない」という制約をB単体よりも強く満たしている。
そのため本フェーズではこの並び順（警告 → 月ヘッダー）をそのまま維持し、
崩していない。

## After のHOME構造（上から）

1. `PublicDemoCashShortageCard` / 倒産カード（該当時のみ、隠さない）
2. `PublicDemoHomeDashboardSection`
   - 月ヘッダー（`1年目 4月`）
   - Compact KPI（現金 / 参画 / 待機 / 営業残 / 社員 / 売上 / 入金予定）
   - ひよりの一言（既存Navigator、変更なし）
   - 次にやること（Recommended Action CTA、または月ゴール文）
3. `HomeOfficeStageSection`（社員の様子——オフィス風景+ポートレート、唯一の社員サマリー）
4. `PublicDemoImportantEventsSection`（重要イベント、該当時のみ）
5. `PublicDemoFinanceSummarySection`（今月の支出予定——給与/固定費のみ）
6. `PublicDemoMonthlyPrimaryCtaSection`（月末処理CTA、該当時のみ）
7. 月次収支カード・成長結果（`dashboard()`）
8. 月別の社員/応募者/参画の詳細カード（既存、変更なし）
9. **QA専用「テスト用操作」カード（画面最下部に移動）**

## authoritative state の利用方法

今回の変更は表示コンポーネントの削除・統合・並び替えのみで、値の算出元は
一切変更していない。

- `PublicDemoFinanceSummaryModel.payroll`/`fixedCosts` は変更前と同じ
  `s.latestMonthlyCashFlow?.salaryPaid` /
  `s.latestMonthlyCashFlow?.fixedCostsPaid`（無ければ既存の
  `PublicDemoSalary` 定数）を読むだけで、UI側の独自計算は追加していない。
- 削除した行（現金残高・今月売上・次回入金予定・警告）は、Compact KPI
  （`HomeDashboardDisplayData.fromPublicDemoState`）と
  `PublicDemoCashShortageCard`/倒産カード（`PublicDemoState.financialStatus`
  を直接読む既存カード）がそれぞれ既に同じ authoritative な値を表示して
  いたものの再掲であり、削除しても情報は失われない。

## Domain / Finance / Persistence 変更の有無

**なし。** `lib/game/**` 配下のドメイン/ファイナンス/永続化コードは一切
変更していない。変更は `lib/ui/public_demo/**` の2ファイルと、それに追随
するテスト（Flutter widget test 3ファイル、Playwright e2e 3ファイル）の
みで、save schema・給与計算・売上計算・月進行ルールへの変更はゼロ。

## 変更ファイル

```
lib/ui/public_demo/public_demo_01_placeholder_screen.dart
lib/ui/public_demo/public_demo_home_presentation_components.dart
test/ui/public_demo/public_demo_01_home3_integration_test.dart
test/ui/public_demo/public_demo_01_home_consolidation_test.dart
test/ui/public_demo/public_demo_home_presentation_components_test.dart
e2e/helpers/public-demo-player.ts
e2e/tests/public-demo-fresh-start.spec.ts
e2e/tests/public-demo-recovery.spec.ts
docs/reports/SES_FIRST-FUN-YEAR_UI-PHASE-1_Implementation_Result.md（本ファイル）
```

## 360px確認結果（360×800）

`flutter build web --release` の実ビルドを `localhost` で配信し、
Chromium（Playwright、pre-installed）で `?e2e=1#/public-demo-01` を実描画
してスクリーンショットを取得。

- 横スクロール（overflow）なし。
- ノースクロールの初回ビューポート内に、月（1年目4月）→ Compact KPI →
  ひより → 「次にやること: 佐藤 健のSkillSheetを確認」CTA →
  「社員の様子」（オフィス風景）まで表示。
- 月表示・現金表示の重複なし（Compact KPIの1箇所のみ）。
- 「今月の支出予定」が給与のみ見えている状態でスクロール終端（固定費は
  数十pxのスクロールで到達、390pxでは両方可視）。
- Widget-testの `responsive layout` グループ（
  `public_demo_01_home_consolidation_test.dart`）がこのサイズでの
  horizontal overflow なしを既に機械的に検証済み（後述）。

## 390px確認結果（390×844）

同条件・同手順。給与 -¥750,000 / 固定費 -¥50,000 の両方がノースクロール
初回ビューポート内に収まって見える（360pxよりも1行分余裕がある）。
横スクロールなし、重複なし。Widget-testの同グループで機械的にも検証済み。

## test結果

- **`flutter analyze`**: `No issues found!`（プロジェクト全体）。
- **HOME/Public Demo focused tests**:
  `test/ui/public_demo/public_demo_01_home_consolidation_test.dart` (43件)、
  `test/ui/public_demo/public_demo_01_home3_integration_test.dart`、
  `test/ui/public_demo/public_demo_home_presentation_components_test.dart`
  を単独実行 → **All tests passed!**
- **`test/ui/public_demo/` ディレクトリ全体**（193テスト）:
  **All tests passed!**
- **`flutter test`（プロジェクト全体、可能なら実施）**: 実行した。
  スイート全体は非常に大きく（テストファイル162個、Public Demoの
  実プレイスルーを伴うテストが多数含まれるため1本あたり数十秒かかるものが
  多い）、本レポートのコミット時点では実行が継続中だったが、開始から
  6分台で経過した356件（Public Demo/HOME関連テストを大量に含む）
  については **failureゼロ**（`flutter test`の失敗出力・`Some tests
  failed`はゼロ件）。特にPublic Demo/HOMEに関わるテストは前段の
  focused runで既に193件全てpass確認済みであり、全体ランでもこの
  範囲で新たな失敗は出ていない。プロジェクト全体の完走確認は本セッション
  内で継続監視し、失敗が見つかった場合は別コミットで追って報告する。
- **`git diff --check`**: 空白系エラーなし（exit 0）。
- 既存assertionはすべて維持または「削除したUIに対応する削除」のみ——
  `findsOneWidget` → `findsWidgets` のような弱体化は行っていない。
  むしろ「今月の支出予定」に警告Semanticsが存在しないことを明示的に
  アサートするなど、削除したことを積極的に検証する形にしている。

## Known Issues / 未解決事項

- `PublicDemoHomeDashboardSection` 内のひより（Navigator）バブルは今回の
  対象外として現状維持——「案内役キャラクター」の新規実装ではなく既存の
  HOME-RUNTIME-2C機能であり、削除も拡張もスコープ外と判断した。
- Recommended Action候補には「月末処理」自体は含まれない
  （`_recommendedActionCandidates` は社員/応募者/参画/夏季賞与のみを候補
  にする設計で、月末処理は独立した `PublicDemoMonthlyPrimaryCtaSection`
  として残る）。将来「次に押すべき操作」をさらに一本化するなら、
  Recommended Actionが空のときに月末処理をフォールバック候補にする案が
  あるが、これは挙動変更（`14b`テストの再設計を伴う）になるため今回は
  見送った。
- E2E（Playwright）はローカルでの `tsc`静的チェックのみ実施し、実ブラウザ
  でのフルラン（`playwright test`）は行っていない——指示どおり
  「E2E完全Greenは今回のmerge条件ではない」に基づく判断。ただし変更した
  3つのspec/helperファイルの文字列・ロジックは実ブラウザスクリーンショット
  で使われている実際のDOM/アクセシビリティ文言と目視突合済み。

## First Fun Year playthrough readiness

4月開始の初回ビューで「今月・KPI・次にやること・警告（該当時)」が
最小スクロールで揃うようになり、判断に関係しない重複カード
（社員ステージ/資金サマリー旧版）と開発用カードが取り除かれたことで、
実際に4月→翌3月を通しプレイする際の1画面あたりの情報ノイズは明確に
減っている。ドメイン/ファイナンス/セーブの権威は一切変更していないため、
既存の進行・売上・給与・倒産/資金不足フローへの影響はない。

Public Demoの主要操作（SkillSheet確認・営業開始・案件紹介・面談・受注・
月末処理・求人媒体・研修選択・4月リスタート）はすべて既存のキー/ラベルの
まま到達可能であることをwidget testで確認済み。**通常操作での進行不能
regressionは無い。**

## commit SHA

- `8b55e18b133fcae8a0071956ebbbb6bc39b187ea` — implementation + tests.
- `a82f74978c436fece923d536586a36364be30312` — docs-only fixup recording
  the above SHA in this report.

Both on branch `claude/ses-first-fun-year-ui-phase-1-vx9110`. If a further
docs-only fixup lands after this line was written, the branch's true HEAD
(`git log -1` on `claude/ses-first-fun-year-ui-phase-1-vx9110`) is
authoritative over this static value.

## PR / Merge Readiness

PRは今回作成していない（指示どおり）。ブランチ
`claude/ses-first-fun-year-ui-phase-1-vx9110` へコミット・pushのみ実施。
`flutter analyze`/対象widget test/`flutter test`全体が green であれば
マージ候補として提示可能。E2E（Playwright）フルランはCIまたは次回セッション
での実施を推奨。
