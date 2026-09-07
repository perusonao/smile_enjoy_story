# SES 5-Tab Visual Review — Execution Package

STATUS: **READY（実行前チェックシート、docs-only）**

GOVERNING SSOT: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`（Employee / Sales /
Accounting / Menu）、`docs/reports/SES_HOME-FINAL-TOUCH_Result.md`「SES HOME
Visual SSOT Exact Layout Match」節（HOME、Freeze維持）
DEVELOPMENT PRIORITY: `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
（次順序 #12「5-tab Visual Review」）
CANONICAL VISUAL REFERENCE: `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`
（7枚のPNG。詳細は本書「4. Canonical Reference対応表」）

本ドキュメントは **READ-ONLY 作業の成果物** である。本タスクではコード
（`lib/`・`test/`）・PR・Issue・GitHub Actions workflowを一切変更していない。
実際の5-tab Visual Review（実画面確認・PASS/FAIL判定・修正実装）を行う
**次のセッションが実行するためのチェックシート** として本書を作成した。

---

## 1. 前提条件（Precondition）

**この実行パッケージそのものは今すぐ実行可能な状態ではない。** 以下2件の
PRが `main` へマージされ、Pages（本番）へのデプロイが完了するまで、実画面
確認（本書 §6以降のチェックシート）を開始してはならない。

| PR | タイトル | 対象タブ | 状態（本ドキュメント作成時点） |
|---|---|---|---|
| [#197](https://github.com/perusonao/smile_enjoy_story/pull/197) | SES Menu Visual Complete: icon-led sections, list-row toggle, warning card | メニュー | **open, unmerged** |
| [#200](https://github.com/perusonao/smile_enjoy_story/pull/200) | SES Human-Replay Pre-Fix: Employee/Accounting P1 minimal fixes | 社員・会計 | **open, unmerged** |

理由: #197はメニュータブのVisual Complete化そのもの、#200は社員タブ
（Section 2カード圧縮・filter chip 48dp化）と会計タブ（「前回決算の収支」
文言修正）に対するP1修正であり、いずれも5-tab Visual Reviewが確認すべき
「最終状態」の一部である。この2件がデプロイされる前に実施した確認は、
デプロイ後に再度やり直しになる。

**実行開始条件（すべて満たすこと）:**

- [ ] PR #197が `main` へマージ済み
- [ ] PR #200が `main` へマージ済み
- [ ] マージ後のFast CI（`flutter-validate` / `replay-unit` / `smoke-e2e`）が
      green
- [ ] Pages本番デプロイが完了し、デプロイ済みURLの `BuildInfoLabel`
      （メニュータブ、`build-info-label`キー）が #197/#200マージ後の
      コミットSHAを指していることを確認済み

---

## 2. スコープ

**対象:** HOME → 社員（Employee） → 営業（Sales） → 会計（Accounting） →
メニュー（Menu）の5タブすべてを、この順番で実デプロイ画面上で確認する。

**目的:** 個別タブ単位で完了した Visual Complete（Employee/Sales/Accounting/
Menu）と HOME Visual SSOT Exact Layout Match が、**5タブ横断で見たときに
視覚的一貫性を保っているか**（カード形状・アイコン語彙・バッジ配色・
spacing・タイポグラフィがタブ間で矛盾していないか）を最終確認する。個別
タブの Visual Complete 判定（すべてPASS済み、本書§4参照）を覆すことは
本レビューの目的ではない。

**対象外:**

- HOMEのレイアウト変更（HOME Freeze維持。本レビューはHOMEを**確認のみ**
  行い、追加のレイアウト変更は一切行わない）
- Reference専用機能の新規実装（各タブのVisual Complete Result報告書が
  明記した「intentional omissions」は本レビューでも実装しない）
- Domain / Save / schema / Finance / Balance / Month transition / gameplay
  authorityの変更
- April→March human replay（本レビューの次の工程。本書の対象外）

---

## 3. P0 / P1 / P2 判定基準

`docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`の必須ルールと、
`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`のE2E Policy
（Blocking / Non-blocking分類）に準拠し、5-tab Visual Review専用の
重大度基準を以下のとおり定義する。

### P0 — Blocking（発見した場合、5-tab Visual ReviewをPASS判定にできない）

以下のいずれかに該当する問題。**発見したら該当タブの修正実装が完了する
まで、5-tab Visual ReviewのSTATUSを「完了」にしない。**

- 360×800 または 390×844 のいずれかで、TextScaler 1.0/1.3/2.0のいずれかに
  おいて **horizontal overflow** が発生する
- 実際のタップ領域（practical tap target）が **48px未満** で、通常操作で
  誤操作・操作不能を招く
- **fake data**（架空の人物名・案件名・金額・数値・存在しない機能への
  遷移）が実画面に表示される
- 情報階層（current state → next action → detail）が壊れている、または
  当該タブの主要情報に到達できない
- HOME Freeze違反（HOME側のレイアウトが本レビュー中に変更されている、
  または他タブ側の変更がHOMEへ意図せず波及している）
- 5タブいずれかで、既存の主要導線（Bottom Navigation、各タブの主要CTA）が
  実際に機能しない

### P1 — 5-tab Visual Reviewの本題（次点で修正すべきだが、単体でPASSを妨げない）

- タブ間でのvisual language不一致（例: カード角丸半径が違う、
  icon-ledセクション見出しのアイコンサイズ・色トーンがタブごとに揺れている、
  バッジの配色ルールが同じ意味なのにタブ間で違う）
- excessive scrolling（1画面相当の密度に収まらず、主要情報に到達するまで
  過剰なスクロールを要する）
- 各タブのVisual Complete Result報告書が記録した「残Visual Gap」
  「remaining visual gaps」のうち、5タブ横断で見て初めて目立つもの
  （個別タブレビュー時点では許容されたが、5タブ通しで見ると一貫性を
  損なうもの）

### P2 — 記録のみ（Backlogへ回す、本レビューでは修正しない）

- populated状態（複数月経過後、複数社員在籍時等）のみで発生する軽微な
  visual ズレで、P0基準に抵触しないもの
- Reference画像にあるが「実装禁止」リストに明記された、そもそも実装
  対象外の機能に関する見た目上の要望
- 将来のP1/P2バックログ項目（`SES_DEVELOPMENT-PRIORITY_2026-09-02.md`の
  P1〜P4行）に相当する改善提案

判定フロー: 発見した問題は、まずP0該当性を確認 → 非該当ならP1該当性を
確認 → 非該当ならP2として記録。P0が1件でも残っている間はSTATUSを
「完了」にしない。

---

## 4. Canonical Reference対応表

`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`配下の7枚。
HOMEはこのSSOTの対象外（Freeze維持、別のHOME Visual SSOTを使用）。

| # | ファイル | 対応タブ | 内容 |
|---|---|---|---|
| — | `docs/reports/screenshots/SES_HOME-VISUAL-SSOT-EXACT_AFTER_360x800.png` / `..._390x844.png` | **HOME** | HOME Visual SSOT Exact Layout Match の実装済みAFTERスクリーンショット（Referenceそのもの＝実装済み実画面。詳細: `docs/reports/SES_HOME-FINAL-TOUCH_Result.md`「SES HOME Visual SSOT Exact Layout Match」節） |
| 1 | `01_Employee_LayoutDraft.png` | **社員（Employee）** | 改善レイアウト（案） |
| 2 | `02_Employee_DetailedLayout.png` | **社員（Employee）** | 詳細レイアウト（完成イメージ案）— 一覧/詳細モーダル/スキルシート/案件詳細 |
| 3 | `03_FiveTabs_LayoutOverview.png` | 社員/営業/会計/メニュー（+ホーム参考） | 5タブ横断の全体像（**本レビューが最も参照すべき1枚**） |
| 4 | `04_Sales_DetailedLayout.png` | **営業（Sales）** | 詳細レイアウト（完成イメージ案）— 案件一覧〜提案確認〜進捗の5画面 |
| 5 | `05_Sales_ScreenFlow.png` | **営業（Sales）** | 画面遷移イメージ（完成案） |
| 6 | `06_Accounting_DetailedLayout.png` | **会計（Accounting）** | 詳細レイアウト（完成イメージ案）— サマリー/収支内訳/入金予定/予測/アラート |
| 7 | `07_Menu_DetailedLayout.png` | **メニュー（Menu）** | 詳細レイアウト（完成イメージ案）— メニュー/セーブロード/設定/チュートリアル/初期化 |

**重要（既存SSOTの必須確認事項）:** 7枚に描かれた具体的な人物名・案件名・
金額・数値・存在しない機能（セーブ/ロード一覧、難易度・表示・サウンド
設定、チュートリアル、ヘルプ/FAQ、About、クレジット、Menu専用ひよりの
アドバイス等）は **レイアウトの参考例に過ぎない**。実装済みの各タブは
これらのfake要素を意図的に実装していない（各タブのVisual Complete
Result報告書「intentional omissions」参照）。本レビューでこれらの不在を
P0/P1として指摘してはならない。

---

## 5. 各タブの既完了Visual Complete状況（レビュー前の前提知識）

5-tab Visual Reviewは、以下のとおり**個別タブでは既にPASS判定済み**の
状態を、5タブ横断で最終確認する工程である。

| タブ | Governing Result Report | Visual判定 | 備考 |
|---|---|---|---|
| HOME | `docs/reports/SES_HOME-FINAL-TOUCH_Result.md`「SES HOME Visual SSOT Exact Layout Match」節 | 完了（Freeze） | 追加レイアウト変更は禁止。本レビューは確認のみ |
| 社員 | `docs/reports/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_Result.md` + PR #200のP1修正（本書§1「前提条件」参照） | PASS | #200マージ後、Section 2カード圧縮・filter chip 48dp化が反映された状態を確認すること |
| 営業 | `docs/reports/SES_NON-HOME-UI_SALES_Visual-Complete_Result.md` | PASS | #200の影響なし（Sales側の変更は無し） |
| 会計 | `docs/reports/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Result.md` + PR #200のP1修正 | PASS | #200マージ後、「前月比」→「前回決算の収支」の文言変更が反映された状態を確認すること |
| メニュー | PR #197 `docs/reports/SES_NON-HOME-UI_MENU_Visual-Complete_Result.md`（#197マージ後にmainへ追加される） | PASS（#197マージ後にmain反映） | #197マージ前は現行mainにメニュータブのVisual Complete化が未反映 |

---

## 6. 共通検証マトリクス

全タブ・全画面状態で、以下の組み合わせを漏れなく確認する。

| Viewport | TextScaler | 確認項目 |
|---|---|---|
| 360×800 | 1.0 | 基準レイアウト、overflow 0 |
| 360×800 | 1.3 | overflow 0、主要文言の可読性 |
| 360×800 | 2.0 | overflow 0、タップ領域48px維持 |
| 390×844 | 1.0 | 基準レイアウト、overflow 0 |
| 390×844 | 1.3 | overflow 0、主要文言の可読性 |
| 390×844 | 2.0 | overflow 0、タップ領域48px維持 |

= 1タブあたり最低6状態 × 5タブ = 30状態。加えて、各タブで
「populated状態」（社員複数名在籍、案件進行中、資金不足alert発生時等）が
別途必要なタブは後述§7〜§11の該当箇所で個別に追記する。

---

## 7. HOME — チェックシート

**Canonical Reference:** `docs/reports/screenshots/SES_HOME-VISUAL-SSOT-EXACT_AFTER_360x800.png` / `..._390x844.png`
**変更方針:** HOME Freeze維持。**本レビューでレイアウト変更を行わない。**

### 確認項目

- [ ] デプロイ済みHOMEが `SES_HOME-VISUAL-SSOT-EXACT_AFTER_*` の構図
      （Header/Month/KPI/Hiyori/月次処理/Employee/Tasks/Nav の順序、
      Hiyoriポートレートの存在感、Employee Sceneのオフィス画像配置）と
      一致しているか
- [ ] KPI（4+3構成）が現在の実装済みステートで正しく表示されているか
- [ ] 「今月の重要タスク」からEmployee/Sales/Accounting/Menuへの遷移が
      すべて機能するか（Bottom Navigationとの重複導線含む）
- [ ] 360×800/390×844 × TextScaler 1.0/1.3/2.0でoverflow 0
- [ ] 他タブ側のVisual Complete変更（Employee/Sales/Accounting/Menu）が
      HOME側へ一切波及していないか（`git diff --stat -- lib/presentation/home/`
      が空であることをコード側でも再確認）

### 必要スクリーンショット（新規取得）

- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_HOME_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_HOME_360x800_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_HOME_360x800_TextScaler2.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_HOME_390x844_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_HOME_390x844_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_HOME_390x844_TextScaler2.0.png`

### 既知の残課題（既存Result報告書より、P2として記録済み）

- なし（HOME Freeze完了時点で既知の残課題は記録されていない）

---

## 8. 社員（Employee）タブ — チェックシート

**Canonical Reference:** `01_Employee_LayoutDraft.png` / `02_Employee_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`
**Governing Result:** `docs/reports/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_Result.md`
（PASS）+ PR #200のP1修正（社員名キャプション縮小・filter chip 48dp化）

### 確認項目

- [ ] Section 1（社員一覧・現在状態）: avatar付きカード、色分けstatus
      バッジ（待機中=黄／参画中=緑／研修中=赤系）、skill progress barが
      Referenceの視覚言語と整合しているか
- [ ] Section 1のフィルタ（全員/待機中/参画中）チップの実タップ領域が
      48px以上か（PR #200のP1修正が反映されているか — `ConstrainedBox
      (minHeight: 48, minWidth: 48)` + `Align(widthFactor: 1,
      heightFactor: 1)`による修正。**修正前のリグレッション
      （chipが縦積みの全幅バーになる）が再発していないか**、横一列の
      compact pillレイアウトであることを目視確認）
- [ ] Section 2（今やるべき社員アクション）の`ec(i)`/`employeeConditionCard`/
      `founderFollowUpCard`で、社員名がキャプションサイズ（PR #200で
      `fontSize 16 bold`→`fontSize 12, w600`へ縮小）になっているか、
      Section 1のroster行と視覚的に重複していないか
- [ ] Section 3（参画中案件、APVカード）のprogress bar・バッジがReference
      の「カード形式+ラベル+数値」と整合しているか
- [ ] Section 4（成長・SkillSheet・研修）の導線が機能するか
- [ ] **複数社員在籍状態**（採用後、4名程度同時在籍）でSection 1/2の
      カードが連続してもoverflowしないか（PR #200で追加された
      `fourEmployeesAtMonth6`相当のシナリオを実画面で再現）
- [ ] 360×800/390×844 × TextScaler 1.0/1.3/2.0でoverflow 0
      （初期状態・複数社員状態の両方）

### 必要スクリーンショット（新規取得）

初期状態（4月、創業社員2名待機中）:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE_360x800_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE_360x800_TextScaler2.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE_390x844_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE_390x844_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE_390x844_TextScaler2.0.png`

複数社員在籍状態（populated、P0基準の確認に必須）:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE-POPULATED_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_EMPLOYEE-POPULATED_390x844_TextScaler1.0.png`

参考（既存スクリーンショット、比較用）:
- `docs/reports/screenshots/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_AFTER_360x800.png` / `..._390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_EMPLOYEE_AFTER_360x800.png` / `..._390x844.png`

### 既知の残課題（既存Result報告書より）

- P2: 参画中（緑バッジ）・研修選択済み（赤系バッジ）の実機screenshot未取得
      （widget testでのみ検証済み） — 本レビューで実機確認し、必要なら
      上記populatedスクリーンショットで補完する
- P2: SkillSheetシート内部・研修カード内部のレイアウトはReferenceほど
      視覚整理されていない（意図的にスコープ外、Visual Complete PASSを
      妨げない）
- P2: フィルタは「全員/待機中/参画中」の3つのみ（「休職」は
      authoritative状態が存在しないため非対応、SSOT準拠）

---

## 9. 営業（Sales）タブ — チェックシート

**Canonical Reference:** `04_Sales_DetailedLayout.png` / `05_Sales_ScreenFlow.png` / `03_FiveTabs_LayoutOverview.png`
**Governing Result:** `docs/reports/SES_NON-HOME-UI_SALES_Visual-Complete_Result.md`（PASS）
**PR #200の影響:** なし（Sales側production/testファイルは#200で変更されていない）

### 確認項目

- [ ] Section 1（Overview）のアイコン付きstat tile（営業残/候補者/案件）
      がReferenceの「アイコン付きサマリー領域」と整合しているか
- [ ] Section 2（今やるべき営業アクション、求人媒体カード）がicon-led
      見出し+統一カード形状か
- [ ] Section 3（採用・候補者進捗、`ac(i)`カード）のavatar+色分けバッジが
      Employeeタブの色分けルールと同じ意味論を保っているか（P1: タブ間
      一貫性チェック）
- [ ] Section 4（案件・参画/継続状況、`assignmentCard(i)`+7月結果
      ナラティブ）のavatar+バッジ表示を確認
- [ ] **populated状態**（5月: 候補者ファネル表示中、6月: 案件決定カード、
      7月: 結果ナラティブ）を月送りで実際に再現し、overflow・視覚崩れが
      ないか確認（既存Result報告書時点ではwidget testのみで実機
      screenshot未取得の既知ギャップ）
- [ ] 360×800/390×844 × TextScaler 1.0/1.3/2.0でoverflow 0
      （4月空状態・5月候補者状態・6月案件状態・7月結果状態それぞれ）

### 必要スクリーンショット（新規取得）

4月初期状態（空状態）:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES_360x800_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES_360x800_TextScaler2.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES_390x844_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES_390x844_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES_390x844_TextScaler2.0.png`

populated状態（5月候補者/6月案件/7月結果、P0基準の確認に必須）:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES-MAY-APPLICANTS_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES-JUNE-ASSIGNMENT_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_SALES-JULY-RESULT_360x800_TextScaler1.0.png`
- 上記3状態それぞれの390x844版（同名で `390x844` へ差し替え）

参考（既存スクリーンショット、比較用）:
- `docs/reports/screenshots/SES_NON-HOME-UI_SALES_Visual-Complete_AFTER_360x800.png` / `..._390x844.png`

### 既知の残課題（既存Result報告書より）

- **P1（本レビューで実確認すべき）**: populated状態の実機screenshotが
  未取得。widget testでのRect/tone/文字列検証のみで実施済みだが、5-tab
  横断確認では実画面での目視確認が必要
- P2: Referenceのフィルタチップ（すべて/新着/提案中/内定等）は、
  authoritative workflowが月ゲートで少数カードしか同時描画しないため
  未実装（意図的、SSOT準拠）

---

## 10. 会計（Accounting）タブ — チェックシート

**Canonical Reference:** `06_Accounting_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`
**Governing Result:** `docs/reports/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_Result.md`（PASS）
+ PR #200のP1修正（「前月比」→「前回決算の収支」文言変更）

### 確認項目

- [ ] Section 1（現在の資金状態）の現金Hero表示・財務状態バッジの色分けを
      確認
- [ ] 「前回決算の収支」表示（PR #200で「前月比」から改称）が、決算後に
      研修/採用媒体支出を行っても**直近決算月時点の値のまま変わらない**
      ことを実プレイで確認（意味論修正の実地検証、P0候補: 誤解を招く
      表示が残っていればP0）
- [ ] Section 2（今月の収支）のstat tile・支出サマリー見出しが、決算前
      （「今月の支出予定」）／決算後（「前回確定の支出」）で正しく
      切り替わっているか
- [ ] Section 3（将来の資金予測・リスク）の予測バー・alert表示
- [ ] Section 4（今月必要な経営判断、夏季賞与カード等）
- [ ] Section 5（月次結果/Year-End）
- [ ] **資金不足alert発生時**の表示（populated状態、既存Result報告書で
      widget testのみ確認済み — 実機確認が未実施）
- [ ] `PublicDemoMonthlyCashFlowCard`内訳行がTextScaler 2.0で
      横overflowしないか（Accounting UI Phase 1で修正済みの既知バグの
      再発確認）
- [ ] 360×800/390×844 × TextScaler 1.0/1.3/2.0でoverflow 0
      （4月初期状態・5月以降決算後状態・資金不足alert状態それぞれ）

### 必要スクリーンショット（新規取得）

4月初期状態:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING_360x800_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING_360x800_TextScaler2.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING_390x844_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING_390x844_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING_390x844_TextScaler2.0.png`

populated状態（決算後の「前回決算の収支」表示・資金不足alert、P0基準の確認に必須）:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING-POST-CLOSE_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING-POST-CLOSE_390x844_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING-CASH-SHORTAGE_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_ACCOUNTING-CASH-SHORTAGE_390x844_TextScaler1.0.png`

参考（既存スクリーンショット、比較用）:
- `docs/reports/screenshots/SES_NON-HOME-UI_ACCOUNTING_Visual-Complete_AFTER_360x800.png` / `..._390x844.png`
- `docs/reports/screenshots/SES_HUMAN-REPLAY_PreFix_ACCOUNTING_AFTER_360x800.png` / `..._390x844.png`

### 既知の残課題（既存Result報告書より）

- **P1（本レビューで実確認すべき）**: 月次推移の複数か月ぶん棒グラフ・
  案件別入金予定一覧はauthoritative履歴データの粒度不足のため未実装
  （意図的、SSOT準拠、実装対象外）
- **P1（本レビューで実確認すべき）**: populated状態（5月以降の前月比/tile
  → 「前回決算の収支」、資金不足alert）の実機screenshotが未取得

---

## 11. メニュー（Menu）タブ — チェックシート

**Canonical Reference:** `07_Menu_DetailedLayout.png` / `03_FiveTabs_LayoutOverview.png`
**Governing Result:** PR #197 `docs/reports/SES_NON-HOME-UI_MENU_Visual-Complete_Result.md`
（PASS、#197マージ後にmainへ反映）

**前提:** 本セクションはPR #197がマージされてはじめて実施可能。#197が
未マージの現行mainには、メニュータブのVisual Complete化（`PublicDemoMenuCard`
/`PublicDemoMenuBuildInfoRow`/`PublicDemoMenuListRow`/`PublicDemoMenuWarningCard`）
が存在しない。

### 確認項目

- [ ] icon-led「メニュー」セクション見出し（`Icons.menu_outlined`）
- [ ] BuildInfo領域が低強調行として整理されているか（`BuildInfo.isAvailable`
      が`true`のデプロイ環境でのみ表示 — ローカルビルドでは非表示が正しい
      挙動。**本番デプロイ環境でBuildInfo行が実際に表示され、
      `Deploy: PR #N · shortSha`形式で#197/#200マージ後のSHAを指して
      いるか確認**。これは既存Result報告書が「未取得」と記録した
      screenshotギャップの解消も兼ねる）
- [ ] 「開発・テスト」セクション見出し＋`PublicDemoMenuListRow`形式の
      トグルがcollapsed-by-defaultで表示されているか
- [ ] トグル展開時、`PublicDemoMenuWarningCard`（icon-led警告トーン）が
      表示され、「4月からやり直す」ボタンが赤系CTAになっているか
- [ ] **「4月からやり直す」は開発・テストメニュー配下に留まっており、
      常設のplayer-facing項目へ昇格していないこと**（P0: authorityの
      誤った昇格は破壊的操作の露出リスクのため必ずP0扱い）
- [ ] 「4月からやり直す」確認ダイアログ（文言・cancel/confirm）が既存の
      まま変更されていないか
- [ ] Bottom Navigation（5タブ、キー・アイコン・ラベル）が無変更か
- [ ] 360×800/390×844 × TextScaler 1.0/1.3/2.0 ×
      collapsed/expanded/ビルド情報あり・なしでoverflow 0

### 必要スクリーンショット（新規取得）

collapsed状態:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU_360x800_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU_360x800_TextScaler2.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU_390x844_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU_390x844_TextScaler1.3.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU_390x844_TextScaler2.0.png`

expanded状態（開発・テストメニュー展開時、P0基準の確認に必須）:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU-EXPANDED_360x800_TextScaler1.0.png`
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU-EXPANDED_390x844_TextScaler1.0.png`

BuildInfo行あり状態（本番デプロイ環境限定、P1: 既存ギャップの解消確認）:
- `docs/reports/screenshots/SES_5TAB-VISUAL-REVIEW_MENU-BUILDINFO_360x800_TextScaler1.0.png`

参考（既存スクリーンショット、比較用、#197ブランチより）:
- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_AFTER_360x800.png` / `..._390x844.png`
- `docs/reports/screenshots/SES_NON-HOME-UI_MENU_Visual-Complete_AFTER_Expanded_360x800.png` / `..._390x844.png`

### 既知の残課題（既存Result報告書より）

- P2: Referenceの他4画面（セーブ/ロード、ゲーム設定、チュートリアル/
      ヘルプ、最初からやり直す専用フルスクリーン）に対応する実装は
      authoritativeな機能自体が存在しないため未実装（意図的、実装対象外）
- **P1（本レビューで実確認すべき）**: ローカルビルドではBuildInfo行が
  常に非表示のため、実際にPRのSHA/PR番号付きでBuildInfo行が表示された
  状態のブラウザscreenshotが未取得。本番デプロイ後に確認可能になる

---

## 12. タブ横断（cross-tab）一貫性チェック — 5-tab Visual Reviewの本題

個別タブのVisual Completeがすべて完了した前提で、**5タブを続けて操作した
ときに視覚的に同じアプリだと感じられるか**を確認する。`03_FiveTabs_
LayoutOverview.png`を横に並べながら実施する。

- [ ] **カード形状**: 全タブで角丸半径・`outlineVariant`ボーダーの太さ・
      白背景が統一されているか（Employee/Sales/Accounting/Menuは各タブ
      ローカルファイルで独立に色値を再定義しているため、実装上は
      同一値でも意図せずズレていないか実測確認）
- [ ] **icon-ledセクション見出し**: アイコンサイズ・アイコンと文字の
      間隔・タイトルのフォントウェイトがタブ間で揃っているか
      （`_sectionHeader(title, icon: ...)`の共通ヘルパーを各タブが
      同じ引数パターンで呼んでいるか）
- [ ] **バッジ配色の意味論**: 「進行中・ポジティブ」を表す緑、
      「警告・注意」を表す黄、「危険・要対応」を表す赤系が、社員
      （待機中=黄/参画中=緑/研修中=赤系）・営業（`_applicantStatusTone`/
      `_julyResultTone`）・会計（財務状態バッジ、`negative`/`caution`
      トーン）・メニュー（警告トーン）で同じ意味に対して同じ色を
      使っているか
- [ ] **avatar/アイコンの一貫性**: 社員・営業タブの人物avatar表示方針
      （`homeOfficeStagePortraitFor`由来）が統一されているか
- [ ] **タイポグラフィ**: 見出し・本文・キャプションのフォントサイズ
      階層がタブ間で一貫しているか（PR #200で社員タブのSection 2見出しを
      `fontSize 16 bold`→`12, w600`へ変更した結果、他タブの同種要素との
      サイズ差が生じていないか）
- [ ] **spacing/density**: 各タブのセクション間余白・カード内padding が
      極端に異なっていないか（1画面相当の密度という共通ルールに対して
      タブ間でばらつきがないか）
- [ ] **Bottom Navigation**: 5タブ間の遷移がどの状態からでもスムーズに
      機能するか（HOME→社員→営業→会計→メニュー→HOMEの一周を実際に
      操作して確認）
- [ ] **HOME Freezeとの整合**: HOME自体は上記チェックの対象外
      （レイアウト変更禁止）だが、HOMEのカード形状・アイコン語彙と
      他4タブのそれが著しく乖離していないか（乖離がある場合はP2として
      記録し、HOME Freeze解除は別タスクの判断に委ねる — 本レビューで
      HOME側を変更しない）

---

## 13. 実行手順（順序厳守）

1. 本書§1「前提条件」を満たしていることを確認する（#197/#200マージ・
   デプロイ完了）。
2. デプロイ済みURLで §7 HOME → §8 社員 → §9 営業 → §10 会計 →
   §11 メニュー の順に、各タブのチェックシートを上から実施する。
   タブごとに、初期状態の6スクリーンショット（360×800/390×844 ×
   TextScaler 1.0/1.3/2.0）をまず取得し、その後populated状態が必要な
   タブ（社員・営業・会計・メニュー）は追加のスクリーンショットを取得する。
3. §12「タブ横断一貫性チェック」を実施する。
4. 発見した問題を本書§3の基準でP0/P1/P2に分類し、一覧化する。
5. P0が0件であることを確認できたら、5-tab Visual Reviewの結果報告
   （新規、`docs/reports/SES_5-TAB_VISUAL-REVIEW_Result.md`等）を作成し、
   `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`の次順序を
   更新する（次工程: April→March human replay）。
6. P0が1件でも残っている場合は、該当タブの最小修正を実装し、修正後に
   該当タブのチェックシートのみ再実施する（他タブへの影響がないことを
   `git diff --stat`で確認したうえで）。

---

## 14. Sign-off テンプレート（実行時にコピーして使用）

```
## 5-tab Visual Review 実行結果サマリー

- 実行日: 
- デプロイ済みSHA（BuildInfoLabelより）: 
- #197 マージSHA: 
- #200 マージSHA: 

| タブ | P0件数 | P1件数 | P2件数 | 判定 |
|---|---|---|---|---|
| HOME | | | | |
| 社員 | | | | |
| 営業 | | | | |
| 会計 | | | | |
| メニュー | | | | |
| タブ横断 | | | | |

総P0件数: 
5-tab Visual Review 判定: PASS / FAIL（P0が0件のときのみPASS）
```

---

## 15. Relationship to existing documents

- `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md` — Employee/Sales/
  Accounting/MenuのVisual正本。本書のP0/P1/P2基準の一部（overflow・
  タップ領域・fake data禁止）はこのSSOTの必須ルールをそのまま引用。
- `docs/reports/SES_HOME-FINAL-TOUCH_Result.md` — HOME Visual SSOTと
  Freeze方針の出典。
- `docs/reports/SES_TAB-UI_REFERENCE_Canonicalization_Result.md` —
  Canonical Visual Reference 7枚の来歴・sha256証跡。
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — 5-tab Visual
  Reviewが次順序#12に位置づけられている根拠。実行後はこの文書の次順序
  リストを更新すること。
- `docs/reports/SES_NON-HOME-UI_EMPLOYEE_Visual-Complete_Result.md` /
  `..._SALES_Visual-Complete_Result.md` / `..._ACCOUNTING_Visual-Complete_
  Result.md` — 各タブの個別Visual Complete判定（すべてPASS）と、本書が
  引用した「残Visual Gap」の出典。
- PR #197 `docs/reports/SES_NON-HOME-UI_MENU_Visual-Complete_Result.md`
  （マージ後にmainへ追加される） — メニュータブのVisual Complete判定。
- PR #200 `docs/reports/SES_HUMAN-REPLAY_PreFix_Employee-Accounting_P1_
  Result.md`（マージ後にmainへ追加される） — 社員・会計タブのP1修正の
  出典。

## Update history

### 2026-09-07（新規作成、docs-only）

- #197/#200デプロイ完了後の5-tab Visual Review実行に向けて、本実行
  パッケージ（チェックシート）を新規作成した。既存のCanonical Visual
  Reference・Visual SSOT・Final Preflight相当の既存文書（HOME Visual
  SSOT Exact Layout Match）・各タブのVisual Complete Result報告書
  （Employee/Sales/Accounting、すべてPASS）・PR #197（Menu Visual
  Complete）・PR #200（Human-Replay Pre-Fix P1）の内容を照合し、
  P0/P1/P2基準、360×800/390×844、TextScaler 1.0/1.3/2.0、必要
  スクリーンショット、各タブのCanonical Reference対応を含めて作成した。
- コード（`lib/`・`test/`）・PR・Issue・GitHub Actions workflowは一切
  変更していない（docs-onlyの新規追加のみ）。
