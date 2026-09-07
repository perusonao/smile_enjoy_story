# SES Development Priority (2026-09-02)

Status: **Accepted — current governing decision / living source of truth**

This document is the current single source of truth for **how development is prioritized and run** on S.E.S. It is a living plan: when task status, priority, estimate, product direction, or persistent execution policy changes, update this document rather than leaving the change only in chat or a result report.

`docs/DEVELOPMENT_PLAN.md` remains the source of truth for detailed phase/feature design. Read this document first for current priority, then `DEVELOPMENT_PLAN.md` for phase detail.

---

## Primary Goal — First Fun Year

現在の最優先目標は100人テストではない。

まず開発者本人がPublic Demoを **4月 → 翌年3月** まで1年度通して実際にプレイし、

- 「面白かった」
- 「もう1年遊びたい」
- 「別の経営戦略を試したい」

と思える状態 = **First Fun Year** を作る。

機能追加・UX改善・バランス調整・テスト改善の優先順位は、この目標への寄与で判断する。

### First Fun Year completion criteria

1. 4月から翌3月まで通常プレイで完走できる。
2. 進行不能、月送り不能、セーブ破壊、重大な二重処理がない。
3. 毎月、判断・変化・結果のいずれかを感じられる。
4. 9月〜2月が単なる週送り期間にならない。
5. 会社が成長している実感がある。
6. 月次結果から「なぜ良くなった／悪くなったか」を理解できる。
7. 年度末に一年間の成果を振り返れる。
8. 終了時に別の戦略でもう1年遊びたいと思える。

---

## Current execution order

**HOME Freeze → #167 Late Game Phase 1 → Year-End Phase 1 → Active Project Visibility Phase 1 → Employee UI Phase 1 → Sales UI Phase 1 → Accounting UI Phase 1 → NON-HOME Visual Fresh Audit → Employee Visual Complete → Sales Visual Complete → Accounting Visual Complete → Menu Visual Complete → 5-tab Visual Review → April→March human replay → 後半強化 → 成長実感 → 月次結果 → 戦略性 → バランス → Public Demo仕上げ**

**Employee UI Phase 1 / Sales UI Phase 1は「information architecture complete」（4段階の情報階層への再設計が完了した状態）であり、「Visual Complete」（配色・カード形状・アイコン・タイポグラフィ等が
`docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`のCanonical Visual Referenceに整合した状態）ではない。** Visual Complete化は下記Employee Visual Complete / Sales Visual Completeで別途行う。

Issue番号順に機械的に実装しない。実プレイ結果を根拠に、First Fun Yearを最も改善するものを選ぶ。

### HOME Freeze（2026-09-06）

**HOME One-Screen Final Fit が PR #184のマージ・main CI・実機確認まで完了し、HOMEをFreezeする。** HOMEの追加レイアウト変更は禁止。HOME完成を前提としていたP0「進行中HOME UI改修を完成」系列のタスクは、HOME自体の変更としては完全終了。Employee UI Phase 1（Active Project Visibility Phase 1を前提コンポーネントとして統合済み）、Sales UI Phase 1、Accounting UI Phase 1は、HOMEへの先取りを禁止したまま、それぞれ社員タブ・営業タブ・会計タブ側の独立実装として引き続き有効（下記の次順序を参照）。

### Prioritized backlog and AI processing-time budget

処理時間は調査・実装・関連テスト・結果報告作成を含む概算。CI待ち時間は含めない。

次順序（2026-09-07時点、詳細はUpdate history）:

1. ~~**#167 Late Game Phase 1**~~ — 完了。8月〜2月の「創業エンジニアのフォロー判断」実装。
2. ~~**Year-End Phase 1**~~ — 完了。年度末の振り返り演出。
3. ~~**Active Project Visibility Phase 1**~~ — 完了。参画中社員の案件状態を社員タブから可視化。
4. ~~**Employee UI Phase 1**~~ — 完了（information architecture complete、Visual Completeではない）。社員タブを「社員一覧・現在状態 → 今やるべき社員アクション → 参画中案件（Active Project Visibility Phase 1を統合） → 成長・SkillSheet・研修」の4段階へ再設計。stale「翌月参画予定」の社員タブ側の残差も解消（会計側の「空の○月開始結果」はPOST-HOME-FREEZE Small-UX-Fixで既に解消済み）。
5. ~~**Sales UI Phase 1**~~ — 完了（information architecture complete、Visual Completeではない）。営業タブを「現在の営業・採用状況 → 今やるべき営業アクション → 採用・候補者進捗 → 案件・参画/継続状況」の4段階へ再設計。
6. ~~**Accounting UI Phase 1**~~ — 完了。会計タブを「現在の資金状態 → 今月の収支 → 将来の資金予測・リスク → 今月必要な経営判断 → 月次結果/Year-End」の5段階へ再設計。支出サマリー見出しの真実性修正（Fresh Audit相当）も実施。
7. **NON-HOME Visual Fresh Audit** — `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`のCanonical Visual Reference（7枚）を基準に、Employee/Sales/Accounting/Menuの現行実装とのギャップを棚卸しする監査。
8. **Employee Visual Complete** — Employee UI Phase 1のIAを維持したまま、Visual SSOTに配色・カード形状・アイコン・タイポグラフィを整合させる。
9. **Sales Visual Complete** — Sales UI Phase 1のIAを維持したまま、Visual SSOTに整合させる。
10. **Accounting Visual Complete** — Accounting UI Phase 1のIAを維持したまま、Visual SSOTに整合させる。
11. **Menu Visual Complete** — メニュータブをVisual SSOTに整合させる。
12. **5-tab Visual Review** — HOME Freezeを維持したまま、5タブ全体で視覚的一貫性を最終確認する。
13. **April→March human replay** — 上記反映後の年間通しプレイ監査。

**#148の追加production実装は次P0として扱わない。** #183（CI高速化）はdev-efficiency用の別ラインとして記録し、gameplayより前へ出さない。

| Priority | Task | Claude Code / Codex目安 | Outcome |
|---|---|---:|---|
| P0 | ~~進行中HOME UI改修を完成~~ — **完了・HOME Freeze**（HOME Final Density + Final Polish + One-Screen Final Fit, PR #180/#184。詳細はUpdate history） | 実績: 完了 | HOMEで会社状況・推奨行動・KPI・次の行動を理解できる — 達成済み。HOMEへの追加レイアウト変更は禁止 |
| P0 | #167 Late Game Phase 1 | 実績: 完了 | 8月〜2月の「創業エンジニアのフォロー判断」— 詳細はUpdate history |
| P0 | Year-End Phase 1 | 実績: 完了（本エントリ） | 年度末の振り返り演出（会計タブ「第1期終了」強化） — 詳細はUpdate history |
| P0 | ~~Active Project Visibility Phase 1~~ | 実績: 完了 | 参画中社員の案件状態（engineerName/projectName/deliveryPressure/budgetHealth）を社員タブから可視化 — 詳細はUpdate history |
| P0 | ~~Employee UI Phase 1~~ | 実績: 完了 | 社員タブを4段階の情報階層へ再設計、stale「翌月参画予定」の社員タブ側を解消 — **information architecture complete、Visual Completeではない**。詳細はUpdate history |
| P0 | ~~Sales UI Phase 1~~ | 実績: 完了 | 営業タブを「現在の営業・採用状況 → 今やるべき営業アクション → 採用・候補者進捗 → 案件・参画/継続状況」の4段階へ再設計 — **information architecture complete、Visual Completeではない**。詳細はUpdate history |
| P0 | ~~Accounting UI Phase 1~~ | 実績: 完了 | 会計タブを「現在の資金状態 → 今月の収支 → 将来の資金予測・リスク → 今月必要な経営判断 → 月次結果/Year-End」の5段階へ再設計、支出サマリー見出しの真実性修正 — 詳細はUpdate history |
| P0 | NON-HOME Visual Fresh Audit | 1〜2h | `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`のCanonical Visual Reference（7枚）と現行実装のギャップを棚卸し |
| P0 | Employee Visual Complete | 目安未確定 / 分割検討 | Employee UI Phase 1のIAを維持しVisual SSOTへ整合（HOMEへの先取り禁止） |
| P0 | Sales Visual Complete | 目安未確定 / 分割検討 | Sales UI Phase 1のIAを維持しVisual SSOTへ整合（HOMEへの先取り禁止） |
| P0 | Accounting Visual Complete | 目安未確定 / 分割検討 | Accounting UI Phase 1のIAを維持しVisual SSOTへ整合（HOMEへの先取り禁止） |
| P0 | Menu Visual Complete | 目安未確定 / 分割検討 | メニュータブをVisual SSOTへ整合 |
| P0 | 5-tab Visual Review | 1〜2h | HOME Freezeを維持したまま5タブ全体の視覚的一貫性を最終確認 |
| P0 | 4月→翌3月 First Fun Year通しプレイ（human replay） | 1〜2h | 上記反映後、年間完走可否・退屈な期間・重大問題を実プレイで再特定 |
| P0 | 年間進行Blocker修正 | 1件0.5〜3h | 月送り不能、二重処理、セーブ破壊等を除去 |
| P1 | 9月〜2月コンテンツ強化（#167 Phase 1以降の追加分） | 4〜8h / 分割必須 | 年度後半にも判断・イベント・変化がさらに発生 |
| P1 | 会社の成長実感強化 | 3〜6h | 社員・売上・資金・オフィス等から成長を実感 |
| P1 | 月次結果・経営フィードバック改善 | 2〜4h | 前月比・収支理由・危険要因が次の判断につながる |
| P1 | 年度末結果・年間評価強化 | 2〜4h | 一年間の成果を振り返り、年度完走に意味が生まれる |
| P2 | 経営判断のリスク/リターン強化 | 5〜10h / 分割必須 | 安全策・成長策など経営方針によるプレイ差が生まれる |
| P2 | 採用・社員マネジメント強化 | 5〜10h / 分割必須 | 採用・給与・昇給・定着が一連の経営判断になる |
| P2 | 営業・案件選択の戦略性強化 | 4〜8h | 適性・成功率・Trust等を考えて案件を選べる |
| P2 | 資金繰り表示改善 | 2〜4h | 将来入金・支出・資金ショートを予測しやすくなる |
| P2 | ナビゲーター支援強化 | 2〜5h | 状況別の危険・チャンス・推奨行動を案内 |
| P3 | 年間バランス調整 | 4〜10h / 反復 | 難易度と戦略ごとの生存・成長バランスを改善 |
| P3 | 重要イベント演出強化 | 2〜5h | 初契約・黒字化・社員増加等に達成感が生まれる |
| P3 | Public Demo UX仕上げ | 3〜6h | 初見でも基本ループを理解できる |
| P3 | 重大経路E2E整備 | 3〜8h | First Fun Yearを壊す重大Regressionを自動検出 |
| P4 | リファラル採用 | 4〜8h | 社員紹介という採用ルートを追加 |
| P4 | 雇用形態拡張 | 8〜16h | 正社員・契約社員・個人事業主等を使い分ける |
| P4 | 部署・役職システム | 8〜16h | 成長に応じて組織・役職を構築 |
| P4 | 労務・制度コンテンツ | 10〜20h+ | 社保・36協定・休職・退職代行・士業等を経営要素化 |
| P4 | SNS/HP/ISMS/Pマーク等 | 5〜10h | ブランド・認証投資を営業・採用へ接続 |

P4の拡張仕様はFirst Fun Yearの基本ループが成立するまで原則着手しない。

---

## AI task sizing / usage-window policy

5時間制限で実装途中のまま停止することを避けるため、AI作業量そのものを計画単位として扱う。

- **〜2h:** 1タスクで実行可能。
- **2〜3h:** 推奨サイズ。Claude Code / Codexの標準実装単位。
- **3〜5h:** 原則2タスクへ分割を検討。
- **5h超:** 必ずPhase分割する。設計・Domain・UI・テスト等に分ける。
- **10h超:** 独立Issue/PR単位まで分割する。

利用枠が少ない時は新規大型実装を開始せず、監査・設計・レビュー・タスク分割を優先する。

---

## Development AI

当面のメイン実装AIは **Claude Code** とする。

ChatGPTは主に開発優先順位判断、Claude Code用プロンプト作成、Issue/PR整理、独立レビュー、実装結果評価に使用する。

Codexは独立監査、難しい原因調査、重要設計判断、必要に応じた実装に使う。同じproductionファイルをClaude CodeとCodexで同時変更しない。

## Model Selection

Claude Code / Codexへ作業を依頼するときは、その作業を安全に完遂できる**必要最低限のモデル**を選ぶ。高性能モデルを常用しない。

## Result Report

実装・調査・設計を依頼する際は、原則として結果報告Markdownを `docs/reports/` に出力する。

最低限記録するもの:

- STATUS
- BASE / HEAD
- 実施内容
- 変更ファイル
- テスト結果
- 未解決事項 / Known Issues
- commit SHA（commitした場合）
- PR / Merge Readiness（該当する場合）

---

## E2E Policy

E2E完全Greenを、すべてのゲーム開発を開始する条件にはしない。

### Blocking — 開発を止めて優先修正

- アプリが起動できない
- 通常操作で進行不能になる
- セーブデータを破壊する
- 4月→翌3月の年度完走を妨げる
- 主要ゲームフローそのものが成立しない
- productionの重大なregression

### Non-blocking — 記録してFirst Fun Year開発を継続

- 特定viewportだけのE2E不安定
- browser / CI環境固有の問題
- accessibility tree等、テスト環境由来と根拠を持って判断できる問題
- 特殊条件だけのテスト失敗で通常プレイを阻害しないもの
- flaky test

テスト削除・skip・retry増加・timeout増加だけでGreenへ見せかけない。

---


### Routine delivery gate

通常のPRからPagesデプロイまでを待たせないため、Fast CIは次の独立した必須ゲートを並列実行する。

- `flutter-validate`: `flutter analyze`、全Flutter test、Pagesと同一条件のWeb build
- `replay-unit`: lockfileを使うReplay ViewerのNode unit test
- `smoke-e2e`: 上記2ゲート後のChromium主要導線確認

Node依存はlockfileを維持したままnpmキャッシュ優先で取得する。失敗をskip/retry/timeout延長で隠さず、各ゲートは引き続きPages deployを止める。WebKit・年間通し・Recovery・多viewportはHeavy E2Eに分離する。

## Plan maintenance rule

この文書は会話時点のメモではなく、継続更新する正本である。

以下が起きたら更新する:

- タスク完了・中止・Block
- 優先順位変更
- AI処理時間見積りが大きく変化
- 新しいBlockerや実プレイ上の問題を発見
- First Fun Yearの完成条件・方向性を変更
- AI使い分け、モデル選択、E2E方針などの永続ルールを変更

Result Reportは履歴・証拠であり、この文書の代わりにはしない。変更後に複数の「current」文書を作らず、この正本を更新するか、明示的にsupersedeする。

---

## Relationship to existing documents

- `AGENTS.md` — この文書と `docs/DEVELOPMENT_PLAN.md` を作業前必読として直接参照する。
- `docs/DEVELOPMENT_PLAN.md` — phase/feature詳細の正本。この文書の優先方針で実行順を判断する。
- `docs/ai-knowledge/INDEX.md` — 技術的incident/pattern/decisionの索引。現在の開発優先順位の正本ではない。
- `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md` — Employee/Sales/Accounting/MenuのVisual（layout/情報階層/visual treatment/navigation target）正本。Canonical Visual Reference（7枚のPNG）の所在と、Reference/authoritative game stateの優先順位を定義する。HOMEはこのSSOTの対象外（Freeze維持）。
- `docs/reports/` — 実施結果と証拠。計画変更が必要なら結果報告だけで終わらせず、この文書も更新する。

## Update history

### 2026-09-07（SES TAB UI Visual Reference Canonicalization — Accounting UI Phase 1完了とのreintegration）

- PR #193（本ブランチ）に、PR #192でmainへマージされた「Accounting UI Phase 1完了」（直下のUpdate historyエントリ参照）を`git merge origin/main`で取り込んだ。取り込みは`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`の「Current execution order」「次順序」「Prioritized backlog table」で発生したconflictのみで、`docs/design/`配下（Visual SSOT・Canonical Reference・README）はconflictなし・無変更。
- 「Current execution order」「次順序」「Prioritized backlog table」を、Accounting UI Phase 1完了（origin/main側の記述をそのまま採用）とVisual Complete計画（本ブランチ側の記述）の両方を反映するよう再構成した: 1. Accounting UI Phase 1（完了）→ 2. NON-HOME Visual Fresh Audit → 3. Employee Visual Complete → 4. Sales Visual Complete → 5. Accounting Visual Complete → 6. Menu Visual Complete → 7. 5-tab Visual Review → 8. April→March Human Replay。
- Canonical 7 PNG（`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`）のpixel内容・sha256、修正済みの`02_Employee_DetailedLayout.png`/`03_FiveTabs_LayoutOverview.png`名称、`docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`の内容はこのreintegrationで一切変更していない。Accounting production code、HOME、gameplay/domain/save/finance/balance/month authorityも無変更。

### 2026-09-07（Accounting UI Phase 1完了 / governing plan sync）

- **Accounting UI Phase 1を実装。** 会計タブ（`_buildAccountingTab`、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）を、単一`Column`にフラットに並んでいた月次収支カード・支出サマリー・（月により）夏季賞与カード/8月開始結果・（完了時）Year-Endカードから、5段階の情報階層を持つセクション構成へ再設計した: 1) 現在の資金状態（`_accountingFundStatusSection`、新規 — `PublicDemoState.cash`/`financialStatus`の常時表示スナップショット）、2) 今月の収支（`_accountingMonthlyBalanceSection` — 既存の月次収支カード＋支出サマリーをそのまま移動）、3) 将来の資金予測・リスク（`_accountingForecastSection`、新規 — 既存の`PublicDemoCashForecast`/`PublicDemoCashStatusPresentation`をHOMEの`_cashForecastAdvice`と並ぶ第二の呼び出し元として直接読み取り表示）、4) 今月必要な経営判断（`_accountingDecisionSection` — 7月の夏季賞与決定カードをそのまま移動）、5) 月次結果/Year-End（`_accountingMonthlyResultSection` — 8月開始結果ナラティブ＋`PublicDemoYearEndResultCard`をそのまま移動・統合）。
  - Section 2/4/5は既存のカード・key・月ゲート・eligibility判定を1つも変更せず、そのままセクションメソッドへ移動しただけ。Section 1/3は新規セクションだが、いずれも既存authoritativeフィールド／既存の純粋モデル（`PublicDemoCashForecast.forecast`/`PublicDemoCashStatusPresentation.fromForecast`、共にPR #153/#154由来）の読み取りのみで、新しい計算式・閾値・永続フィールドは一切追加していない。
  - **IMPORTANT FIX（タスクが参照したFresh Auditが実際にはリポジトリ内に存在せず、本タスクが実測ベースで自ら確認した問題）**: `PublicDemoFinanceSummarySection`の見出し「今月の支出予定」は、5月以降は実際には`PublicDemoState.latestMonthlyCashFlow`（直近確定月の実績）を表示しており、今月の予定ではなく先月実績を偽って表示していた。`PublicDemoFinanceSummaryModel`に`isSettled`（既定`false`）を追加し、決算前（4月）は「今月の支出予定」、決算後（5月〜）は「前回確定の支出（給与・固定費）」へ見出しのみを分岐させた。給与・固定費の金額自体は1円も変更していない。
  - 付随して、`PublicDemoMonthlyCashFlowCard`の内訳行（`_Row`）がTextScaler 2.0で横overflowする既存の潜在バグを新規テストで発見し、値表示を`Flexible`+`FittedBox(scaleDown)`化して解消した（表示のみの修正、金額・Finance計算は無変更）。
  - HOME（`lib/presentation/home/`配下）、Employee UI Phase 1、Sales UI Phase 1、Domain（`lib/game/public_demo/`配下）、Save/schema、Finance/Balance、Month transition、Year-End authorityは無変更。
  - Sales UI Phase 1（PR #191）が作業中にmainへマージされたため、実装・テスト完了後に`git fetch origin main`→`git merge origin/main`でコンフリクトなく再統合し、統合後に全focused testsおよび`test/game/public_demo`+`test/ui/public_demo`（904件）を再実行して緑を確認した。
  - 詳細・変更ファイル・テスト結果は`docs/reports/SES_NON-HOME-UI_ACCOUNTING_Phase1_Implementation_Result.md`を参照。
- **次のproduction priorityを以下の順に更新する**（本文書冒頭「Current execution order」および直後のPrioritized backlog tableも同時に更新済み。上記reintegrationエントリの通り、その後Visual Complete計画を挟んで更に更新済み）:
  1. April→March human replay

### 2026-09-07（Sales UI Phase 1完了 / governing plan sync）

- **Sales UI Phase 1を実装。** 営業タブ（`_buildSalesTab`、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）を、月ゲートで中身が変わるだけの平坦なカードリスト（`_salesTabItems`）から、Employee UI Phase 1と同型の4段階の情報階層を持つセクション構成へ再設計した: 1) 現在の営業・採用状況（`_salesOverviewSection`、新規）、2) 今やるべき営業アクション（`_salesNextActionCards` — 求人媒体カード、5月）、3) 採用・候補者進捗（`_salesApplicantProgressCards` — 応募者ファネル、5月）、4) 案件・参画/継続状況（`_salesProjectStatusCards` — 案件決定カード6月＋7月結果ナラティブ）。
  - Section 2〜4は既存のカード・key・月ゲート・eligibility判定を1つも変更せず、そのまま3つのメソッドへ分割移動しただけ。新しいゲームルールは追加していない。全セクションが空の場合にのみ、既存の真実の空状態（PUBLIC-DEMO-HOME-UI-3C由来、Issue #173／PR #174 Codexレビュー分を含め無変更）を表示する条件は、旧`_salesTabItems.isEmpty`と完全に同一。
  - Section 1（新規）は、`PublicDemoState.salesRemaining`/`salesCapacity`、`workflow.applicants`（`hasJoined`でフィルタ）、`workflow.assignments`（`nextOrderStatus`でフィルタ）という既存authoritativeフィールドのみから、営業残・候補者数・案件数（うち検討中件数）を常時表示する。待機/参画中の社員頭数はHOME KPI・Employee rosterと重複するため意図的に表示していない。
  - **事前調査で発見した既存の事実**: `PublicDemoWorkflowState.initial()`は4月時点から既定の候補者プール（`publicDemoMayApplicants`、2名）を保持しているが、応募者ファネル自体（Section 3）は引き続き5月より前には描画されない。Section 1の候補者カウントをこの理由で`s.month < 5`のとき常に0を返すようガードし、画面上どこからも確認・操作できない数字を表示しないようにした（表示上の判断であり、応募者ファネルの既存月ゲートと完全に一致させただけ）。
  - **将来候補として記録（未着手）**: `canUseRecruitmentMediaInMonth`はドメイン上4〜8月の求人媒体利用を既に許可しているが、営業タブのUIは旧実装から変更せず5月のみ求人媒体カードを描画する。この既存eligibilityとUI描画月の不一致は、Sales gameplay authority/eligibility変更禁止の指示を厳守するため本Phaseでは意図的に手を付けず、Phase 2以降の候補として記録した（詳細: `docs/reports/SES_NON-HOME-UI_SALES_Phase1_Implementation_Result.md`）。
  - HOME（`lib/presentation/home/`配下）、Employee UI Phase 1（`_buildEmployeesTab`及び4つの`_employee*Section`）、Domain（`lib/game/public_demo/`配下）、Save/schema、Finance/Balance、Month transition、Sales/Employee gameplay authority、Year-Endは無変更。
  - 詳細・変更ファイル・テスト結果は`docs/reports/SES_NON-HOME-UI_SALES_Phase1_Implementation_Result.md`を参照。
- **次のproduction priorityを以下の順に更新する**（本文書冒頭「Current execution order」および直後のPrioritized backlog tableも同時に更新済み）:
  1. Accounting UI Phase 1
  2. April→March human replay

### 2026-09-06（Employee UI Phase 1完了 / governing plan sync）

- **Employee UI Phase 1を実装。** 社員タブ（`_buildEmployeesTab`、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）を、単一`Column`内の条件分岐カード列から、4段階の情報階層を持つセクション構成へ再設計した: 1) 社員一覧・現在状態（`_employeeRosterSection`、新規）、2) 今やるべき社員アクション（`_employeeNextActionsSection`）、3) 参画中案件（`_employeeActiveProjectsSection`、Active Project Visibility Phase 1のカードをそのまま統合）、4) 成長・SkillSheet・研修（`_employeeGrowthSection`）。
  - Section 2〜4は既存のカード・key・月ゲート・eligibility判定を1つも変更せず、そのままセクションメソッドへ移動しただけ。新しいゲームルールは追加していない。
  - Section 1（新規）は、`workflow.engineers`（既存の全社員ロースター）を1行ずつ列挙し、既存authoritativeフィールド（`PublicDemoState.engineersWaiting`/`engineersAssigned`、`PublicDemoEngineerSales.stage`、`PublicDemoWorkflowState.assignedEngineerIds`）のみから現在状態バッジと集計を表示する。新規の永続フィールドや集計ロジックは追加していない。
  - **stale「翌月参画予定」の社員タブ側を解消**: HOMEのOffice Stage表示はPOST-HOME-FREEZE Small-UX-Fixで既に修正済みだったが、社員タブの`ec(i)`バッジは当時明示的にスコープ外だった。本Phaseで社員タブ専用の`_currentEmployeeStatusLabel`を新規追加（HOME側の`_officeStageStatusFor`と同一ロジックだが独立したメソッド — HOME側のコードは1行も変更していない）し、実際に参画済みの`ordered`社員には「参画中」を表示するようにした。
  - 実装過程で、既存回帰テスト（`public_demo_01_home_consolidation_test.dart`の「待機」テキスト重複防止アサーション）により、Section 1の新規バッジと`ec(i)`カード自身のバッジが重複することが判明したため、`ec(i)`のバッジは削除し、現在状態表示をSection 1に一元化した（SSOTが求める「重複情報を減らす」の実践）。
  - HOME（`lib/presentation/home/`配下）、Domain（`lib/game/public_demo/`配下）、Save/schema、Finance/Balance、Month transition、Sales/Employee gameplay authority、Year-Endは無変更。`fieldEvaluation`は引き続き非表示。
  - 詳細・変更ファイル・テスト結果は`docs/reports/SES_NON-HOME-UI_EMPLOYEE_Phase1_Implementation_Result.md`を参照。
- **次のproduction priorityを以下の順に更新する**（本文書冒頭「Current execution order」および直後のPrioritized backlog tableも同時に更新済み）:
  1. Sales UI Phase 1
  2. Accounting UI Phase 1
  3. April→March human replay

### 2026-09-06（Active Project Visibility Phase 1完了 / governing plan sync）

- **Active Project Visibilityを実装（Phase 1）。** 社員タブに、参画中社員ごとのread-only「案件ステータス」カード（`activeProjectStatusCard`、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`内の新規メソッド）を追加した。表示項目は`engineerName`/`projectName`/`deliveryPressure`/`budgetHealth`の4項目のみで、いずれも既存の`PublicDemoAssignment`（`PublicDemoWorkflowState.assignments`）が既に持つフィールドの読み取りにとどまる。新規のpersist/Finance/save-schemaフィールドは追加していない。
  - 表示対象は`PublicDemoWorkflowState.assignedEngineerIds(month:)`が返す「その月に実際に参画中」の社員のみで、月による除外を設けていない — 8月〜翌3月（internal month 8-15）を含むどの月でも、参画が続く限りカードが表示され続ける。待機（waiting）社員には表示されない。
  - `fieldEvaluation`はPhase 1では意図的に非表示とした。現状のproduction経路では`PublicDemoAssignment.fieldEvaluation`は常にコンストラクタ既定値（50）のままで、`withAssignmentUpdate`の`fieldEvaluation`引数を渡す呼び出しが存在しないため実質固定値であり、意味のある評価として提示できないため。
  - 顧客名・会社名・単価・契約金額・契約期間など、`PublicDemoAssignment`が保持していない情報は一切生成していない。
  - Issue #167 founder follow-upカード（`founderFollowUpCard`）とは同じ社員タブの同一`Column`内に共存させ、どちらの既存ロジック・キーも変更していない。HOME（`lib/presentation/home/`配下）、Year-End（`PublicDemoYearEndResultCard`等）、Save/schema、Finance計算、Balance、Month transition、workflow authorityは無変更。
  - 詳細・変更ファイル・テスト結果は`docs/reports/SES_ACTIVE-PROJECT-VISIBILITY_Phase1_Implementation_Result.md`を参照。
- **次のproduction priorityを以下の順に更新する**（本文書冒頭「Current execution order」および直後のPrioritized backlog tableも同時に更新済み）:
  1. stale「翌月参画予定」/ 空の「○月開始結果」等の小規模UX修正
  2. Employee UI Phase A 再評価
  3. April→March human replay

### 2026-09-06（Year-End Phase 1完了 / governing plan sync）

- **Year-End Phase 1を実装。** 会計タブの既存「第1期終了」領域を強化し、`PublicDemoYearEndDisplayData`/`PublicDemoYearEndResultCard`（いずれも新規、`lib/ui/public_demo/`配下）として、開始時現金→終了時現金と年間の増減、最終社員数（`engineerCount+adminCount`）、年間採用数（`joinedApplicantIds.length`）、最終参画/待機人数（`engineersAssigned`/`engineersWaiting`）、創業社員（eng-01/eng-02）の成長（`publicDemoInitialEngineerRuntimes`比較の`actualCapability`）、事実ベースのひより総括、および「4月からもう一度」CTAを表示する。
  - すべての値は既存authoritativeフィールドの読み取りまたは単純な差分計算のみで、新規persist/Finance/save-schemaフィールドは追加していない。年間売上・年間営業回数・危機回数・回復回数など、Public Demo 0.1が年間集計として保持していない値は一切表示しない（監査結果は`docs/reports/SES_YEAR-END-PHASE1_Implementation_Result.md`§2参照）。
  - 「4月からもう一度」は既存の`_confirmRestartFromApril`/`_restartGame`（開発・テストメニューおよび倒産カードの「最初からやり直す」と同一のcanonical reset/replay経路）をそのまま再利用し、新しいreset authorityは追加していない。
  - HOME（レイアウト・`lib/presentation/home/`配下）、Save/schema、Finance計算、Balance、Month transition、workflow authorityは無変更。Issue #167（founder follow-up）・PR #186（truthful HOME Office Stage / 空の会計見出し除去）の既存挙動は無変更・回帰テストで確認済み。
  - 詳細・監査結果・変更ファイル・テスト結果は `docs/reports/SES_YEAR-END-PHASE1_Implementation_Result.md` を参照。
- **次のproduction priorityを以下の順に更新する**（本文書冒頭「Current execution order」直後のPrioritized backlog tableも同時に更新済み）:
  1. Active Project Visibility
  2. stale「翌月参画予定」/ 空の「○月開始結果」等の小規模UX修正
  3. Employee UI Phase A 再評価
  4. April→March human replay

### 2026-09-06（HOME Freeze / Issue #167 Late Game Phase 1完了 / governing plan sync）

- **HOME One-Screen Final Fit がPR #184のマージ・main CI・実機確認まで完了し、HOMEをFreezeする。** HOMEの追加レイアウト変更は禁止。
- **Issue #167 FIRST-FUN-YEAR-LATE-GAME-1 Phase 1を実装。** 設計監査（Issue #167コメント、`READY WITH CONDITIONS`）が推奨した「参画中エンジニアへのフォロー投資」方向を、監査どおり**創業エンジニア（`publicDemoInitialEngineers`: eng-01/eng-02）限定**でPhase 1として実装。
  - トリガー: 対象エンジニアが8月〜2月（internal month 8-14）の間、実際に案件へ参画中（`PublicDemoWorkflowState.assignedEngineerIds`）であり、当該年度でまだこの決定を行っていないこと（1エンジニア1回、`PublicDemoEngineerSales.founderFollowUpMonth`で管理）。
  - 選択肢: 「そのまま任せる」（無料・メンタル/信頼small減）「声をかける」（無料・small増）「支援に投資する」（¥50,000・larger増）の3択で、単一の明白な正解を作らない。
  - 既存のPublicDemoEngineerSales.mental/trustフィールド（既存だが従来どこからも更新されていなかった）を再利用し、新規のrelationship/employee-stateシステムは追加していない。
  - 新規追加はnullableな`PublicDemoEngineerSales.founderFollowUpMonth`（1フィールドのみ、`fromJson`は既存save向けに`null`へ後方互換デフォルト）。Finance側は既存の`monthTrainingSpent`バケットを再利用し、新しいFinance/save-schemaカテゴリは追加していない（`PublicDemoSaveCodec`の資金整合チェックとの整合のため）。
  - HOME Recommended Actionには新規`HomeRecommendedActionKind.founderFollowUp`を追加したが、**Month Guardの「未対応の推奨アクション」警告からは明示的に除外**した — この決定は8月〜2月の間ずっと有効なままにしてよい設計（「毎月強制モーダルにする必要はない」）であり、含めると月送りのたびに警告が出る回帰を招くため。
  - 詳細・監査結果・変更ファイル・テスト結果は `docs/reports/SES_ISSUE-167_Late-Game-Phase1_Implementation_Result.md` を参照。
- **次のproduction priorityを以下の順に更新する**（本文書冒頭「Current execution order」および直後のPrioritized backlog tableも同時に更新済み）:
  1. Year-End Phase 1
  2. Active Project Visibility
  3. stale「翌月参画予定」/ 空の「○月開始結果」等の小規模UX修正
  4. Employee UI Phase A 再評価
  5. April→March human replay
- **#148の追加production実装は次P0として扱わない。** #183（CI高速化）はdev-efficiency用の別ラインとして記録し、gameplayより前へ出さない — これは新しい方針ではなく、本ユーザー指示に基づく既存優先順位の明文化。
- Domain/Save/Balance/Finance truth/Month transition/Recovery/Sales/Employee/SkillSheet domain logic/HOME layout/Year-End仕様/workflowは、上記フィールド追加とMonth Guard除外を除き無変更。

### 2026-09-05（HOME Final Polish 完了 / governing plan sync — PR #180 Codex P2対応）

- **HOME Final Polish が完了し、PR #180としてレビュー中。** 直下の
  「2026-09-05（Issue #168 完了 / HOME Final Density）」エントリが
  「SES HOME Final Densityを現在のproduction最優先とする」と記載していたのは
  この完了より前の状態であり、本エントリで**明示的にsupersede**する
  （そのエントリ自体は履歴として残し、書き換えない）。
- P0「進行中HOME UI改修を完成」は、HOME Final Density（PR #179）に続き
  HOME Final Polish（PR #180）が完了したことで**完全に完了**した。KPI/ひより
  カード/月次処理/今月の重要タスクの視認性を仕上げ、ひよりカードの
  「他の行動を確認する」二次CTAとQuick Accessセクションを削除、Bottom
  Navigationと「今月の重要タスク」を他タブへの唯一の入口へ一本化した。
  プレイヤー向け「SkillSheet」表記もHOME側の実文言に限り「スキルシート」へ
  統一。Domain/Save/Balance/Finance/Month transition/Recovery/Sales/
  Employee/SkillSheet domain logic/Active Project Visibility/Employee UI
  Phase A/Issue #167（Late Game）/Year-End仕様/workflowは無変更。詳細:
  `docs/reports/SES_PUBLIC-DEMO-HOME-FINAL-POLISH_Result.md`。
- **直前エントリが次タスクとして指示していた「360x800でクイックアクセスが
  完全なfold内表示に至っていない」残差は、Quick Accessセクション自体を
  HOME Final Polishで削除したため解消（対応不要・moot）**。Quick Access
  が担っていた遷移先（社員の様子/収支・会計/案件・営業/開発・テスト）は
  Bottom Navigationと「今月の重要タスク」、および既存のAppBarメニューから
  引き続き到達可能であることを確認済み（詳細は上記Result report）。
- **次のproduction priorityを以下の順に更新する**（Prioritized backlog
  table も同時に更新済み）:
  1. **Employee UI Phase A** — 社員個々の状態・スキル・経歴を安全に閲覧できる
     UIを整える。
  2. **Active Project Visibility** — 参画中案件の状態を社員/営業視点で可視化
     する。
  いずれもHOMEへの先取りは禁止（HOME Final Polishでも明示的に先取りしていない
  ことを確認済み）。First Fun Yearを最優先目標とする方針（本文書冒頭「Primary
  Goal — First Fun Year」節）自体は変更しない — 上記は同方針の下での
  実行順・backlogの更新であり、目標そのものの変更ではない。
- 本エントリはCodex（PR #180レビュー, P2）が指摘した「governing planが
  Final Densityを現在のpriorityとして残し、既に削除済みのQuick Access残差を
  次タスクとして指示している」という不整合の是正が目的。production/test/
  workflowコードは本対応で一切変更していない（docs-onlyの追加変更）。

### 2026-09-05（Issue #168 完了 / HOME Final Density）

- **Issue #168は完了済み。** mainはPR #177まで統合済み（`a80d6e473e344655f120cac597ff104444b48e51`）。
- HOME UI改修の残作業として、**SES HOME Final Density（HOMEをスマホ1画面で
  理解できる密度に仕上げる）を現在のproduction最優先とする**。P0「進行中
  HOME UI改修を完成」の直接の継続であり、新しい優先項目ではない。
- 実施内容: KPI / ひより(Navigator) / 月次処理 / 今月の重要タスク各カード
  のpadding/gapを詰め、今月の重要タスクのCTAをicon化（`Semantics(label:
  item.ctaLabel)`で実ラベルを保持）。クイックアクセスの`top`位置を
  390x844/360x800共通で109px前進させ、390x844では全6セクション
  （KPI/ひより/月次処理/社員概要/重要タスク/クイックアクセス）が
  unscrolled初期viewport内で開始するようになった。社員概要はこれ以上
  圧縮していない（既存の安全マージンテストに基づくfloor）。Domain/Save/
  Balance/Finance/Issue #167は無変更。詳細:
  `docs/reports/SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_PreImplementation_Audit.md`
  （このタスクが参照した監査文書がリポジトリ内に存在しなかったため、実測
  ベースで新規作成）と
  `docs/reports/SES_PUBLIC-DEMO-HOME-UI_FINAL-DENSITY_Result.md`。
- **360x800でクイックアクセスは完全なfold内表示に至っていない**（fold手前
  +46px、開始前の+155pxから短縮）。次にHOME密度へ戻る場合はこの残差から
  着手する。

### 2026-09-04（Issue #122）

- Issue #122 / PR #165: HOMEの総社員数が技術者数だけを表示していた問題を修正し、総務社員を含む合計人数へ統一。PR #165はmerge SHA `114147db1ebc4e8268f27311b37258a99fabcc7a` でmainへ統合され、Fast CI / Pages deploy成功を確認済み。
- デプロイ済みHOMEの実画面証拠では「社員 3名」と「社員3名・待機2名」が一貫して表示され、総務社員が総数から欠落していた元の不具合は解消を確認。添付された実画面範囲では明らかな横overflowなし。
- **Screen Verification Gateは一部未完了**: 添付画像だけではCSS viewportが360px/390pxの両方だったことを証明できないため、両viewportの可読性・overflow確認が残る。Issue #122はこの確認完了までOPENを維持する。
- 実装結果: `docs/reports/SES_ISSUE-122_Employee-Count_Result.md`。

### 2026-09-04（続報）

- Issue #163: 最新main（SHA `39d6f40e0d43561766f5cbf2c33a26ccbf9fd6f1`）を
  基準に、4月→翌3月の通しプレイ監査を実施。**年度完走PASS**（連続プレイ中
  P0ゼロ、最終現預金+¥700,000、倒産・資金ショート失敗なし）。追加の
  リロード/復帰デューデリジェンスでP0相当の問題を発見: (1)
  ブラウザリロード時に誤った画面（Public Demoと無関係な初心者/自由モード
  選択画面）へ飛ばされる問題は最小修正・検証済み。(2) より深い
  「タブを閉じて再訪問した際、実在するセーブが`SharedPreferences`経由で
  確実に読めない」問題を発見したが根本原因を特定できず未解決 —
  次タスクとして切り出した。単調だった箇所（8月〜2月の7か月間、参画中の
  社員向け判断が皆無で同一の推奨アクションが居座り続ける）、年度末演出の
  薄さも記録。詳細:
  `docs/reports/SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md`。

### 2026-09-04

- First Fun Year P0「資金不足の表示が誤って回復を示唆する」を解消。既存の
  `PublicDemoCashForecast`の次回決算見込みを読み取り専用で用い、マイナスの
  ときは回復を示唆せず、次回決算後も資金不足であることと根拠数値を表示する。
  詳細: `docs/reports/SES_FIRST-FUN-YEAR_P0_Cash-Shortage-Truth_Result.md`。

- Fast CIをFlutter検証・Replay unit・Chromium smokeの並列必須ゲートへ再編。検証範囲を縮めず、Node lockfileキャッシュ優先で通常PRからデプロイまでの待機を短縮。

### 2026-09-02

- First Fun Yearを最優先目標として固定。
- 100人テストより年間プレイの面白さを優先。
- E2EをBlocking / Non-blockingに分類。
- Claude Codeを主実装ラインとする方針を設定。
- 優先タスク一覧とClaude Code/Codex処理時間見積りを追加。
- 原則2〜3時間/タスク、5時間超は分割するルールを追加。
- HOME完成→年間プレイ→Blocker→面白さ改善の実行順を明文化。
- 計画変更時にこの文書を都度更新するLiving Source of Truth運用を明文化。
