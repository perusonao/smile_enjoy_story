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
- `docs/reports/SES_CORE-GAMEPLAY_Phase*_Result.md` — First Fun Year本体（HOME/Visual/April→March replay）とは別建てで並行進行するCORE-GAMEPLAY（Seeded RNG→Random Recruitment→Recruitment Interview→Random Projects…）施策系列の実施結果と証拠。この系列は各Phase自身のresult reportチェーンのみで追跡され、本文書の「Current execution order」「Prioritized backlog」には含めない（2026-09-08 Update history参照）。

## Update history

### 2026-09-12（Issue #245 Finding #4 — Parallel Sales / Offer Selection Phase 1a「Domain Foundation」実装完了 / governing plan sync）

- **前回セッションのFresh Audit（直下のエントリ）で設計されたPhase 1aを実装した。** 開始時`git fetch origin`で`origin/main`が指定base SHA `e6717b8c0f237d1c6ae86f2deebdb823bcbfb728`（前回Fresh Audit + Phase B設計docのマージコミット）と完全一致していることを確認（drift無し）。
- 新規`PublicDemoOfferCandidate`/`PublicDemoOfferCandidateStage`（`lib/game/public_demo/public_demo_offer_candidate.dart`）と`PublicDemoWorkflowState.offerCandidates`を追加。`(engineerId, projectId)`単位でimmutable identity・lifecycle・serialization・legacy migration・lookup/upsert helper・validationを実装。**既存の`PublicDemoEngineerSales.stage`/`matchingProposals`/`projectInterviewSessions`/`recordOrder`/`assignOrderedForMay`はすべて無変更**——新domainはどの既存callerからも参照されない、純粋additive実装。
- **セルフレビューで重大な既存save破壊リスクを発見・修正**: 本番のsave/load gateである`PublicDemoSaveCodec`は厳密なround-trip比較を行い、additive fieldごとに専用migration spliceが必要な構造になっている——`offerCandidates`用のspliceを追加しなければ、このPhase 1aがmergeされた瞬間に**既存の全save**が読み込み不可能になっていた。`_withMigratedOfferCandidates`を追加し、専用テストで検証済み。
- schemaVersionは既存の全additive field（`matchingProposals`等）と同じ前例に従いbumpしていない（`schemaVersion`は"whole-envelope compatibility"のgateであり、per-field追加はsplice機構で扱う既存方針を踏襲）。
- `flutter analyze`（全体）issue無し、`flutter test test/game/public_demo`（944件）・`test/ui/public_demo`（741件）すべてPASS、`git diff --check`クリーン。詳細・security self-hardening findings・known limitations・Phase 1bへのhandoffは`docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1a_Result.md`。
- PR #254（`claude/ses-parallel-sales-phase-1a-vo0idf` → `main`）。Phase 1b（既存callerのcutover）/Phase 1c（比較UI）は本セッションでは未着手——次セッションの引き継ぎ事項として上記Result Reportに明記。

### 2026-09-12（Issue #245 Finding #4 — Parallel Sales / Offer Selection Fresh Audit完了、Phase B「設計のみ」判断 / governing plan sync）

- **Issue #245 Finding #4（並行営業/複数案件面談結果からの受注・辞退判断）についてFresh Auditを実施し、Phase B（詳細設計のみ、schema/domain実装なし）と判断した。** 開始時`git fetch origin`で`origin/main`が指定base SHA `afd34333c0e6a4f3db104e8159317bbdc068b544`と完全一致していることを確認（drift無し）。
- Fresh Auditの結論: 現行Public Demoの営業pipelineは`PublicDemoEngineerSales.stage`という**エンジニア1人につき1個のscalar**が、面談進行カーソルと受注/アサイン適格性の証明を兼務しており、`matchingProposals`/`projectInterviewSessions`もいずれも1エンジニアにつき1件のみ保持（新規が既存を置換）。`availableEngineersForMatching`は`clientInterviewPassed`/`ordered`のエンジニアをMatching対象から除外するため、1案件に合格すると別案件を並行して面談すること自体が構造的に不可能——これがFinding #4の症状の直接原因であることを、実コード（`public_demo_sales.dart`/`public_demo_workflow_state.dart`/`public_demo_aggregate.dart`）から確認した。
- 本家Main Game側には`ProjectProposal`+`Offer`（engineerId単位で複数保持、受注時に同一engineerの他offerを自動`declined`にする`game_engine.dart:372-380`）という、まさに同じ要件を満たす実装が既に存在することを確認したが、Issue #245自身の非ゴール（「Main Game側との全面統合はしない」）に従い、統合はせずパターン参照のみとした。
- 受注適格性の証明をエンジニア単位からエンジニア×案件単位（新設`PublicDemoOfferCandidate`）へ移す設計を提案。これは`assignOrderedForMay`/`recoverLateYearAssignment`/`_validateForPersistence`が依拠する既存のunforgeable-record防御機構（WORKFLOW-STATE-1AB FIX1〜FIX7、PR #214/#215/#216のCodex P1/P2 fix群）に影響する真のschema変更であり、独立設計レビューなしに1セッションで実装することは「無理な実装」のリスク（二重受注・sales slot二重消費・save破損）を伴うと判断した。この判断はIssue #245自身が既に想定していたもの（「大きなstate/schema redesignが必要ならこのIssueで即実装せず、設計Phaseへ分離する」）であり、同日merge済みのPR #247も同じ結論（Finding #4は「未実装（指示通り）」）に達している。
- Phase 1a（domain-only、`offerCandidates`+migration）/Phase 1b（既存caller切替）/Phase 1c（比較UI）への分割、legacy save migration計画、必須テストmatrix（18シナリオ）まで詳細設計として作成した。production/test codeは無変更（docs-onlyコミット）。
- 詳細: `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md`。
- 本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。次にParallel Sales/Offer Selectionへ着手する場合は、このエントリが指すResult Reportの「Phase 1a」から開始する。Finance/Payroll/Matching outcome formula・HOME・5-tab構造はいずれも無変更。

### 2026-09-12（Issue #248完了 — Applicant→Engineer Data Preservation / SkillSheet Expansion、Codex P1修正込み / governing plan sync）

- **Issue #248（PR #249）を実装完了。** First Fun Yearの採用判断を「評価値で選ぶ」から「候補者の経験・技術・給与を比較して採用し、その人物固有の能力が入社後の社員/SkillSheet/案件適性へ継続する」ループへ改善する施策。Fresh Audit（実コードベース。issueが参照した`docs/reports/SES_DATA-ASSET_FULL-INVENTORY_2026-09-12.md`はリポジトリ内に存在しないため、現在のコードを直接追跡）が、`PublicDemoEngineerRuntime.fromApplicant`が経験者採用者全員の`primaryLanguage`を無条件に`ProgrammingLanguage.java`へ、`techSkills`を`TechSkillLevels.zero()`へ固定していたことを確認した——社員タブの実力バー・SkillSheetの主言語チップ/実経験比較/技術スキルチップ・Matchingの言語/技術領域fit次元のいずれも、この既存authorityが常に空/ゼロだったため実際には機能しておらず、採用した人物の技術情報が「Java・スキルなし」という汎用値へ事実上置き換わっていた（本Issueが問題視する「同一汎用社員データへの置き換わり」そのもの）。
  - **Applicant→Engineer continuity（Phase 1）**: `fromApplicant`に、既存の`PublicDemoSeededRecruitmentGenerator.regenerateDomainApplicant`（Recruitment Interview工程が既に使用している、`(runSeed, applicantId)`のみから再導出する既存機構、新規save data不要）で復元した実際の生成元`Applicant`を渡せるようにし、実際の`mainLanguage`/`languageSkills`/`techSkills`を通すよう修正した。`app-01`/`app-02`/`free-template-*`の旧hand-authoredプールは`regenerateDomainApplicant`が`null`を返すため、既存のフォールバック（Java固定・ゼロ技能）を完全に維持——legacy save/挙動は無変更。**save schema変更なし**（`PublicDemoEngineerRuntime`のJSON形状はテストで検証済みのまま無変更）。この1点の修正だけで、社員タブ・SkillSheet・Matchingの既存表示ロジック自体は無変更のまま、実データを表示するようになった。
  - **Recruitment比較UX（Phase 2）**: 応募者カードに「経験｜希望/確定給与」行を初回表示（`applied`段階）から追加した——いずれも面談前から既に非隠匿・résumé-level事実（先行Phase 2レポートに明記済み）であり、従来は面談実施後（`interviewed`段階）まで表示されていなかった表示上のギャップを解消。面談でのみ判明する`interviewScore`/`acceptanceScore`/`salesSkillFit`は引き続き非表示のまま。
  - **PRレビューP1修正（Codex broad review、本エントリと同一PR内で対応）**: 「recruitment-<month>-<medium>-<slot>形式のIDのみでは生成元の証明にならない」という指摘——Phase 2（Random Recruitment）導入前の旧固定/循環テンプレートプール（`PublicDemoRecruitmentCalculation`の旧デフォルト）も同じID形式を使っていたため、その頃の旧saveに残る未入社applicantを、IDだけを根拠に`regenerateDomainApplicant`で無関係な人物のプロファイルへ置き換えてしまう経路が存在した。`PublicDemoSeededRecruitmentGenerator`に`regenerateProjectedApplicant`（`generate()`と同じ per-slot projectionを`(runSeed, id)`のみから再構成）と`verifiedSourceApplicantFor`（再構成結果が実際に保存されているapplicantの résumé-visible fields — name/resumeSummary/experienceMonths/salesSkillFit/interviewScore/acceptanceScore/requestedMonthlySalary — と完全一致する場合のみ`sourceApplicant`として採用し、一致しなければ`null`＝既存フォールバックへ）を追加し、両materialization call siteをこれ経由に変更した。新しいschema/provenance fieldは追加していない。
  - `flutter analyze`（プロジェクト全体）No issues、`test/game/public_demo`全体（872件）・`test/ui/public_demo`全体・`git diff --check`いずれもgreen。新規focused test（`public_demo_issue248_applicant_engineer_continuity_test.dart`: language/techSkills/confirmedLanguages continuity、legacy-fixture no-op、inexperienced-hire no-fabrication、toJson key-set/round-trip、SkillSheet/Matching反映確認、実際のproduction join pipelineでのend-to-end確認、およびCodex P1修正の旧テンプレIDなりすまし拒否・legacy fallback確認・duplicate/retry確認の計11件、`public_demo_issue248_recruitment_comparison_display_test.dart`: 360x800/390x844×TextScaler 1.0/1.3の比較行表示・重複なし確認の計5件）。
  - 詳細・authority map・schema影響・legacy save挙動・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Applicant-Engineer-Data-Preservation_Result.md`を参照。PR: https://github.com/perusonao/smile_enjoy_story/pull/249 。
- **本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。** 本Issueは#235/#231と同じくPrioritized backlog表のP2「採用・社員マネジメント強化」（「採用・給与・昇給・定着が一連の経営判断になる」）に近い、Applicant→Engineer continuity改修として扱う——First Fun Yearを最優先とする既存方針、Visual Complete系列やApril→March human replayの実行順自体は本エントリ以前と同じ。Finance/Payroll/Matching outcome formula・HOME・5-tab構造はいずれも無変更。

### 2026-09-11（Employee Status Unified Display完了 — 社員Player-facing status一本化 / governing plan sync）

- **Employee Status Unified Display（Fresh Audit → 実装）を完了。** READ-ONLY Fresh Audit（`docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Fresh-Audit.md`）が確認した「社員のPlayer-facing status判定が社員タブ/HOME/SkillSheetの3〜4箇所で独立に重複実装されている」問題のうち、社員タブとSkillSheetを対象に統合を実装した。新規`PublicDemoEmployeeStatusResolver.resolve(...)`（純粋関数、`lib/ui/public_demo/public_demo_employee_status_resolver.dart`）が唯一のplayer-facing status（label+tone）判定箇所となり、旧`_currentEmployeeStatusLabel`/`_employeeStatusTone`（社員タブ）と、SkillSheetの2箇所（`_openSkillSheetReview`/`_viewEmployeeSkillSheet`、いずれも従来raw `engineerStatus(engineer)`を直接渡していた）を置き換えた。
  - **Fresh Auditが確認した2件の不整合を修正**: (1) `ordered`かつ`assignedEngineerIds`済みの社員のSkillSheetが、社員タブ/HOMEが既に「参画中」と表示している同一社員に対して、stale「翌月参画予定」を表示し続けていた — 解消。(2) field-sales-ready（または営業中等）な社員が今月分の社内研修も選択している場合、ラベルは正しい値のままバッジ色だけが研修（training）色になっていた — `trainingSelections`はresolverの入力から完全に除外し、labelとtoneを常に同一のresolve呼び出しから生成することで構造的に解消。
  - **実装中に追加で発見した関連P2も同時修正**: 旧`_employeeStatusTone`は参画中判定を`_currentlyAssignedEngineerIds`のみで行い、旧`_currentEmployeeStatusLabel`の`stage == ordered`要件を伴っていなかった。`PublicDemoWorkflowState.endAssignment`が7月未満で「行を残したままstageをwaitingへ戻す」ケース（当月分の売上はendAssignment後も引き続きカウントされる、ドキュメント済みの挙動）でこの2つが乖離し得た——resolverは両方を1つの条件（`stage == ordered && isCurrentlyAssigned`）に統合し、この乖離も解消した。
  - **domain authority・save schema・経済バランスは無変更**: `PublicDemoSalesStage`/`PublicDemoWorkflowState.assignedEngineerIds`/`PublicDemoEngineerRuntime.isReadyForFieldSales`/`fieldSalesCapabilityRequirement`/`PublicDemoState.trainingSelections`はいずれも無変更。resolverは既存の`engineerStatus`（生ステージlabelの唯一のSSOT）を再実装せず、呼び出し元が計算済みの値を渡す設計。`schemaVersion`は`1`のまま。
  - **HOME Freeze**: HOME自身の`_officeStageStatusFor`は今回のPRでは統合していない（#231/#235/#236と同じ既存の判断を踏襲——HOME所有コードへは挙動保存的な変更であっても触れない）。HOMEは引き続き同じ既存事実（`stage == ordered && assignedEngineerIds`）を独立に読んでいるため、事実として食い違うことはない。HOME Freeze解除または「挙動保存的な内部リファクタは許容」という明示的な合意が得られ次第、追随可能な状態にしてある。
  - 社員カードへ新しいCTA行は追加していない。既存の4段階情報階層（社員一覧・現在状態 → 今やるべき社員アクション → 参画中案件 → 成長・SkillSheet・研修）とモバイル密度は維持。
  - `flutter analyze`（プロジェクト全体）No issues。新規focused test 2ファイル（`public_demo_employee_status_resolver_test.dart`: resolverの全status・priority・training非干渉のpure unit test、`public_demo_employee_status_unified_display_test.dart`: SkillSheet参画中修正・training選択済み時のlabel/tone一致・360x800/390x844×TextScaler 1.0/1.3の実画面widget test）。既存`test/ui/public_demo/`全体・`test/game/public_demo/`全体、いずれもgreen（件数・詳細はResult Report参照）。#233（`public_demo_issue231_employee_skillsheet_clarity_test.dart`）・#236（`public_demo_employee_roster_phase_b1_test.dart`）・#237（`public_demo_01_monthly_report_test.dart`/`public_demo_monthly_report_display_data_test.dart`）はいずれも無変更のまま green。
  - 詳細・authority trace・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Employee-Status-Unified-Display_Result.md`を参照。
- **PR #238レビューP1 follow-up（同日中に対応、mainへの初回マージ前）**: PR公開後のレビュー（Codex自動レビューP2 + owner P1）が、初回実装のresolverが依然として`skillSheet`/`selling`/`introduced`/各面談通過・不合格の6サブステージと、`ordered`未参画時に、Fresh Audit §4が明示する統一6値タクソノミー（研修が必要/営業可能/**営業中**/**参画予定**/参画中/待機）ではなく、呼び出し元から渡された生の`engineerStatus`ラベル（営業準備/案件紹介済/各面談通過・不合格/翌月参画予定）へfallbackし続けていた点を指摘した。`PublicDemoEmployeeStatusResolver.resolve`を`rawStageLabel`引数なしの`PublicDemoSalesStage`網羅的`switch`へ書き換え、6サブステージすべてを**営業中**、`ordered`未参画を**参画予定**（`ordered`+参画済みの**参画中**とは別ラベル）へ明示的に集約した——`switch`が網羅的になったため、将来`PublicDemoSalesStage`に新しい値が追加された場合はこのファイルがコンパイルエラーになる（サイレントに生ラベルへ逃げない）。既存の生ステージ`engineerStatus`switch自体（`PublicDemoSalesProgress`のstepper・営業タブが引き続き参照する詳細表示）とHOME（`_officeStageStatusFor`、依然resolver未統合）は無変更。この修正により、HOMEと社員タブ/SkillSheetの間の文言差は「待機 vs 研修が必要/営業可能」に加えて「翌月参画予定 vs 参画予定」「営業準備等の生サブステージ vs 営業中」にも広がった——これは新たな不整合ではなく、HOME Freezeにより意図的に未統合のまま残る既知の差分であり、コード内コメント（`_employeeStatusDisplayFor`）とResult Reportに明記した。新規/既存test更新: `public_demo_employee_status_resolver_test.dart`を7サブステージ全て**営業中**へ集約されることを固定するよう更新、`public_demo_employee_status_unified_display_test.dart`に実画面でのpipeline集約（`selling`ステージ→社員タブ・SkillSheet双方で営業中）と`ordered`未参画→参画予定のwidget testを追加、既存`public_demo_employee_ui_phase1_test.dart`の「ordered未参画は翌月参画予定を表示する」テストを新ラベル「参画予定」へ更新（意図的な文言変更に伴う既存assertion更新——#231等の過去の同種修正と同じ扱い）。`flutter analyze`（プロジェクト全体）No issues、focused tests・`test/ui/public_demo`全体・`test/game/public_demo`全体・`git diff --check`いずれもgreen（件数・詳細はResult Report参照）。同一PR #238・同一branchへcommit/pushのみ（新PR・新規Broad Reviewは実施していない）。
- **本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。** 本タスクは`docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`の実行順4「Employee lifecycle status clarity」（P1、2〜3h見積り）が指す作業そのものであり、#231/#235と同じくPrioritized backlog表のP3「Public Demo UX仕上げ」/「採用・社員マネジメント強化」に近いEmployee Status/Roster clarity改修として扱う——Visual Complete系列やApril→March human replayの実行順自体は本エントリ以前と同じ。

### 2026-09-10（Issue #232 Phase B完了 — Monthly Management Report Dialog/UI統合 / governing plan sync）

- **Issue #232のPhase B（Dialog/UI統合）を実装完了。** Phase A（`PublicDemoMonthlyReportSnapshot.fromAggregate`、read-only authority adapter）をそのままauthorityとして使用し、新規`PublicDemoMonthlyReportDisplayData`（pure presenter、`lib/ui/public_demo/public_demo_monthly_report_display_data.dart`）と新規`PublicDemoMonthlyReportDialog`（`StatelessWidget`+`AlertDialog`、`lib/ui/public_demo/public_demo_monthly_report_dialog.dart`）を追加し、5つの月末close handler（`april()`/`may()`/`june()`/`july()`/`closeOrdinaryMonth()`、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）すべてに「既存Month Guard → 既存event → 既存closeX() → `_commitAggregate` → NEW Monthly Management Report → dismiss → `_resetMonthScroll()` → 既存HOME」の順で統合した。
  - close前に`final closedMonth = s.month;`で対象月をcaptureし、close後は新規`_maybeShowMonthlyReport(closedMonth)`が`PublicDemoMonthlyReportSnapshot.fromAggregate(_game, closedMonth: closedMonth)`を読むだけ（closeXを再実行しない）。`snapshot.isReady`のときだけReportを表示し、`notYetRecorded`/`staleClosedMonth`では表示しない。
  - 表示項目: 対象月、現金（月初→月末・増減）、売上・入金・売掛金、支出（合計・給与・固定費・賞与・研修費・採用費）、`netIncome`（純利益相当）、社員（参画人数/待機人数）、翌月入社予定（`confirmedNextMonthJoinApplicantIds`の氏名、既存`workflow.applicants`からの読み取りのみ）。ひよりコメントは新規`publicDemoMonthlyReportHiyoriComment`（pure function、AI生成なし）が`cashDelta`の符号と`waitingCount`/`assignedCount`のみで分岐する、安全な既存authorityのみを使う1〜2文。
  - **表示しない項目（Issue #232 Fresh Auditの既存GAPどおり）**: 今月の採用人数・受注人数・新規参画人数、参画人数の前月比。`joinedApplicantIds`の累積値を「今月の採用人数」として使っていない。新しい経済的しきい値も追加していない。
  - Bankruptcy/Year-Endの既存terminal UI（`_bankruptcyTerminalCard`/`PublicDemoYearEndResultCard`）はstate-driven（`s.isFinanciallyTerminal`/`s.fiscalYearCompleted`をbuild()内で読むだけ）のため無変更。Reportのdismiss後、既存のbuild()が同じ条件で再描画されるだけで、skip/duplicateは発生しない（widget testで確認）。
  - **save-schema変更なし**（`schemaVersion`は`1`のまま）。`PublicDemoMonthlyReportSnapshot`/`PublicDemoMonthlyReportDisplayData`/`PublicDemoMonthlyReportDialog`はいずれも`toJson`/`fromJson`を持たない非永続の表示専用クラス。Finance/Payroll/Recruitment/Assignment/Sales/月次決算/Month Guard/HOMEのロジックはいずれも無変更（closeXの呼び出し箇所・引数も無変更、追加したのはclose直後の読み取り専用Dialog表示のみ）。
  - **Known limitation**: Report表示中にreloadするとReport自体は消える（Phase B既知の制約として許容、Issue #232指示どおり）。domain state/save結果自体は正しく維持される（widget testで確認）。
  - `flutter analyze`（プロジェクト全体）No issues。新規focused test 2ファイル（`public_demo_monthly_report_display_data_test.dart`: presenter mapping + Hiyori分岐、`public_demo_01_monthly_report_test.dart`: 5 close handlers全部・dismiss後1回だけ月が進む・blocked/no-op closeでReportなし・Bankruptcy/Year-End既存UIとの共存・save/reload・360x800/390x844×TextScaler 1.0/1.3でoverflowなし）。既存Month Guard/single-month advance/Bankruptcy/Year-End/Employee clarity・roster関連suiteを含む`test/ui/public_demo/`全体・`test/game/public_demo/`全体、いずれもgreen（件数はResult Report参照）。新しいDialogを既存の月末closeフローへ挿入したことで、既存suiteのうち月末closeをUI経由（実際のCTAタップ）で駆動していたファイル（`public_demo_tab_test_helpers.dart`の共有ヘルパー`switchPublicDemoTab`/`dismissMonthGuardIfPresent`と、複数ファイルのローカルなclose用ヘルパー）へ、新規Reportの自動dismiss呼び出しを追加する形で回帰修正した（production authority/挙動は無変更、テストヘルパーのみの変更）。
  - 詳細・authority trace・設計・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_PhaseB_Result.md`を参照。PR: https://github.com/perusonao/smile_enjoy_story/pull/237 。
- **Prioritized backlog表のP1「月次結果・経営フィードバック改善」（2〜4h、「前月比・収支理由・危険要因が次の判断につながる」）は、本エントリで一部消化——収支理由（売上・支出内訳・純利益相当）とHiyoriコメントによる簡易な注意喚起（資金減少時の注意喚起、待機社員がいる場合の示唆）は実装したが、「前月比」（month-over-month比較）と、forward-lookingな資金危険（`PublicDemoCashStatusPresentation`の予測ベース危険）は本Phase Bでは統合していない（新しいauthority/しきい値を追加しないという制約の中で、既存の`PublicDemoMonthlyReportSnapshot`は単月のスナップショットのみを提供するため）。よって本行は依然「完了」に変更しない——事実のみを記録する。** Current execution order・Prioritized backlog tableの構成自体は変更しない。First Fun Yearの実行順（Visual Complete系列 → April→March human replay）自体は本エントリ以前と同じ。

### 2026-09-10（Issue #235 Phase A + Phase B-1完了、Codex P2修正・#233統合込み — Employee Roster Management Data / governing plan sync）

- **Issue #235のPhase A（READ-ONLY Fresh Audit）とPhase B-1（実装）を完了。** 社員一覧を「社員を経営資源として比較できる一覧」へ改善する施策。対象は`publicDemoOl`経験の社員タブ（`_employeeRosterSection`/`_employeeRosterCard`、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）。
  - **Phase A（Fresh Audit）**: 氏名・年齢・性別・月給・スキル・経験年数・参画状況・単金の8項目についてauthorityを追跡した。氏名・月給・スキル・経験年数・参画状況の5項目は既存authorityがそのまま安全に参照可能（save-schema変更不要）。年齢・性別は**リポジトリ内のどこにも既存authorityが存在しない**（`prologue_engine.dart`のドキュメントコメントが示す通り、意図的にgender-blindな設計）。詳細は`docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_Fresh-Audit.md`（本エントリで`origin/main`へ取り込み。Phase A自体は別セッション/別ブランチ（コミット`a2d62ad`）で2026-09-10 14:03Zに実施済みのREAD-ONLY監査で、PRは作成されずmainに未反映だったため、Phase B-1の一部として本docsを本ブランチへ持ち越した）。
  - **Phase B-1（実装）**: Fresh Auditが「既存authorityでGO」と判定した5項目（氏名・月給・スキル・経験年数・参画状況）を`_employeeRosterCard`へ接続した。追加した主な表示は「経験年数・月給・単金」の1行（例: `経験 3 年 ｜ 月給 30万円 ｜ 単金 60万円`、未参画時は`単金 —`）——氏名・スキル（能力バー）・参画状況バッジは既存表示のまま無変更。
    - 経験年数: `PublicDemoEngineerRuntime.totalItExperienceMonths`（既存の`formatExperience()`を再利用、新規フォーマッタなし）。
    - 月給: `PublicDemoSalary.currentMonthlySalaryFor(employeeId, applicants:, month:)`（既存のPayroll authorityをそのまま呼び出し、UIローカル給与テーブルは追加していない）。
    - 年齢・性別は本Phaseで実装していない（Issue指示どおり）。UIローカルの仮値も追加していない。
  - **単金（PR #236へのCodex Broad Review P2「Use project-backed rates instead of always showing a dash」を受けた修正、reconcile時に実装）**: 当初のPhase B-1実装では「単金authorityはどこにも存在しない」と断定し全社員一律`—`表示にしていたが、Codexレビューにより**現行最新main（`d45e375`）でも、`PublicDemoAssignment.projectId`が実在する場合は`PublicDemoSeededProjectGenerator.regenerate(runSeed:, projectId:)`（`PublicDemoAggregate._industryByEngineerId`/`endAssignment`が同一案件解決に既に使っている既存authority）経由で`PublicDemoProjectCandidate.monthlyRate`を安全に取得できる**ことをFresh Authority Traceで確認し、修正した。新規`_currentUnitPriceDisplayFor(engineerId)`ヘルパーが、(a) `_currentlyAssignedEngineerIds`で真に参画中であること、(b) 対応する`PublicDemoAssignment.projectId`がnullでないこと、(c) `regenerate`が実在の候補を返すこと、の3条件を満たす場合のみ実案件単金（`candidate.monthlyRate`）を表示し、いずれか欠ける場合（待機社員・`projectId`がnullのlegacy/generic assignment・解決不能なid）は引き続き`単金 —`を表示する。**`PublicDemoRevenue.ratePerAssignedEngineer`（全社一律¥600,000）を個別契約単金として表示することは行っていない**——新しいAssignment/Finance domain変更・新しい単金データモデル・save schema変更はいずれも行っていない（既存authorityの新規接続のみ）。
  - **save-schema変更なし**（`schemaVersion`は`1`のまま）。Assignment生成・Finance計算・Revenue計算・Sales/Recruitmentロジック・Monthly Management Report・HOMEはいずれも無変更（`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`の`_employeeRosterCard`と新規`_currentUnitPriceDisplayFor`ヘルパーのみ変更）。
  - **Package B（Issue #231 / PR #233、社員一覧の「営業可能」「研修が必要」理由caption）は2026-09-10 23:23 JSTにmainへマージ済み**（Merge commit `2abbef8`、直後のUpdate historyエントリ参照）。PR #236の本文・Result Reportに残っていた「PR #233はまだmainへマージされていない」という記述はreconcile時に修正した。最新`origin/main`への`git merge`によりPackage Bの`_currentEmployeeStatusLabel`の「営業可能」/「研修が必要」ステータスバッジおよび研修理由caption（`_employeeRosterCard`内、waiting かつ `!readyForFieldSales`の場合のみ表示）と、本Phase B-1の経験年数/月給/単金行は同一カード内で共存し、いずれの既存key・文言・`readyForFieldSales`等の既存authorityも変更していない。360x800/390x844×TextScaler 1.0/1.3で氏名・参画状況・営業可能/研修が必要理由caption・スキル・経験年数・月給・単金が同一カードに共存してもoverflowしないことを新規/既存テストで確認済み。
  - `flutter analyze`（プロジェクト全体）No issues、新規focused test（`test/ui/public_demo/public_demo_employee_roster_phase_b1_test.dart`）、既存roster関連suite（`public_demo_employee_ui_phase1_test.dart`、`public_demo_employee_visual_complete_test.dart`）、`test/ui/public_demo/`全体、`test/game/public_demo/`全体、いずれもgreen（件数・詳細はResult Report参照）。
  - 詳細・authority trace・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Employee-Roster-Management-Data_PhaseB1_Result.md`を参照。PR: https://github.com/perusonao/smile_enjoy_story/pull/236 。
- **本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。** Issue #235はPackage Bと同じくPrioritized backlog表のP3「Public Demo UX仕上げ」／「採用・社員マネジメント強化」に近い、Employee Status/Roster clarity改修として扱う——Visual Complete系列（Employee Visual Complete → Sales Visual Complete → …）やApril→March human replayの実行順自体は本エントリ以前と同じ。年齢・性別のPhase B-2（追加的なsave-schema拡張、product decision前提）は、引き続き未着手のまま記録する。

### 2026-09-10（Issue #232 Phase A完了 — Monthly Management Report Result Snapshot / authority adapter / governing plan sync）

- **Issue #232のPhase Aのみを実装完了。** Fresh Audit（`docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_Fresh-Audit.md`）のGO判定（Phase A/Phase Bの2分割推奨）に従い、月末の月次結果を安全に取得するための**read-only Result Snapshot / authority adapterのみ**を実装した。`PublicDemoMonthlyCashFlow.netIncome`（`revenue - totalOutflow`、1行の非永続derived getter）と、`PublicDemoMonthlyReportSnapshot.fromAggregate`（`PublicDemoState.latestMonthlyCashFlow`/`PublicDemoWorkflowState.assignedEngineerIds`を読むだけの新規クラス、close/commandを一切呼ばず、stale month mismatchを型レベルでガード）を追加した。
  - **Phase B（月末Management Report Dialog/UI、`public_demo_01_placeholder_screen.dart`への統合）は本エントリの対象外・未実装のまま。** 「月次結果・経営フィードバック改善」（Prioritized backlog表P1、「前月比・収支理由・危険要因が次の判断につながる」）のうち、本エントリはその**土台となるauthority adapterの消化のみ**であり、このP1項目自体は未完了のまま残る。Dialog/UIはPhase B（別Issue/別タスクとして今後着手）で扱う。
  - Finance/Payroll/Recruitment/Assignment/月次決算/HOME/save schema（`schemaVersion`）はいずれも無変更。月内delta（今月の応募数・面談数・新規受注数）はFresh Auditで確認された既存authorityのGAP（発生月を示す永続フィールドが存在しない）のため、Phase Aでは実装していない。
  - `flutter analyze`（プロジェクト全体）No issues、新規focused test 1ファイル14件（`public_demo_monthly_report_snapshot_test.dart`）+ 既存`public_demo_monthly_cash_flow_test.dart`への追加3件、プロジェクト全体`flutter test`いずれもgreen。
  - 詳細・authority trace・snapshot設計・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Monthly-Management-Report_PhaseA_Result.md`を参照。PR: https://github.com/perusonao/smile_enjoy_story/pull/234 。
- **本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。** 本修正はPrioritized backlog表のP1「月次結果・経営フィードバック改善」枠（2〜4h）のうち、Phase A（authority adapterのみ）分の部分消化として記録する — この項目自体は未完了（Phase B待ち）であり、表の行は「完了」に変更していない。First Fun Yearの実行順（Visual Complete系列 → April→March human replay）自体は本エントリ以前と同じ。

### 2026-09-10（Issue #231 Package B完了 — Initial Employee / SkillSheet Gate Clarity / governing plan sync）

- **Issue #231（Package B）を実装完了。** #225 Human Replay → Package A（#229、PR #230、mainへ統合済み）に続く次P1として、初回4月に佐藤健（founding capability 78、営業可能）と鈴木葵（52、研修が必要）を社員タブの社員一覧（Section 1）だけで見分けられるようにした。Fresh Auditの結果、`_currentEmployeeStatusLabel`/`engineerStatus`が待機中の社員全員を一律「待機」と表示しており、既存authority（`PublicDemoEngineerRuntime.isReadyForFieldSales`/`fieldSalesCapabilityRequirement`=60、Section 2の既存lock bannerが既に読んでいた値と同一）が社員一覧側に一切反映されていなかったことが判明した。
  - `_currentEmployeeStatusLabel`/`_employeeStatusTone`が同じ既存authorityから「営業可能」/「研修が必要」を導出するよう変更し（新規`PublicDemoEmployeeStatusTone.readyForSales`を追加）、研修が必要な社員の社員一覧行にはSection 2のlock bannerと同一authorityを再利用した理由キャプション（例:「営業には実力60以上が必要（現在52）」）を追加した。`engineerStatus`自体・HOME側の`_officeStageStatusFor`・SkillSheet sheetの`statusLabel`は無変更（HOME Freeze維持）。
  - SkillSheet確認hard gate（`waiting→skillSheet→selling`）はFresh Auditの結果、read-onlyではあるがHOME Recommended Action設計authority（`home_recommended_action.dart`のP2帯）とCash Advisor（`PublicDemoCashAdviceSelector`）に組み込まれておりPackage Bのスコープ外であるため、**弱化/削除せず維持**（維持理由はResult Report参照）。
  - Sales/Employee/Recruitment/Finance/月次決算/HOME/save schema（`schemaVersion`=1）はいずれも無変更。
  - `flutter analyze`（プロジェクト全体）No issues、既存テスト3件（「待機中の社員全員が同じ表示」を前提としていたassertion）を更新、新規focused test 1ファイル3件を追加、`test/game/public_demo`+`test/ui/public_demo`+`test/widget_test.dart`（1389件）いずれもgreen。
  - 詳細・authority trace・gate維持理由・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Initial-Employee-SkillSheet-Clarity_P1_Result.md`を参照。PR: https://github.com/perusonao/smile_enjoy_story/pull/233 。
- **本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。** 本修正はPrioritized backlog表のP3「Public Demo UX仕上げ」枠（3〜6h、「初見でも基本ループを理解できる」）のうちPackage B分の消化として記録する — First Fun Yearの実行順（Visual Complete系列 → April→March human replay）自体は本エントリ以前と同じ。production code以外のtests/workflowも本エントリの対象範囲（Employee tab presentation）に限定される。

### 2026-09-10（Issue #229完了 — Public Demo Opening Context Package A / governing plan sync）

- **Issue #229を実装完了（PR #230、Package Aのみ）。** #225 Human Replayで発見されたPublic Demo初回プレイのOpening理解ギャップ（目的・初期資金・毎月の固定支出・売上ゼロを継続した場合の倒産リスクを理解しないまま4月の通常操作に入ってしまう）のうち、Package A（Opening Context画面の追加）を実装した。`PublicDemo01PlaceholderScreen`に、ブラウザ単位で一度だけ表示するOpening Context画面（目的・初期資金・毎月の固定費・倒産リスク・最初にすること + 既存のひよりナビゲーター紹介 + 「4月の経営を始める」CTA）を追加し、表示済み状態は新規の`PublicDemoOpeningMarker`（`SharedPreferences`、既存save schemaとは完全に独立したisolated key）で管理する。画面に表示する金額（初期資金¥4,000,000・月次固定費¥800,000）はいずれもcopyへハードコードせず、既存のFinance/Payroll authority（`PublicDemoState.aprilStart().cash` / `PublicDemoSalary.baselineMonthlyExpenses`）からそのまま取得している。Finance/Sales/Employee/月次決算のauthorityおよびsave schema（`schemaVersion`）は変更していない。
  - 既存の約80件のPublic Demo widget testとPlaywright e2e suiteへの影響を避けるため、`PublicDemoOpeningMarker`の既定コンストラクタはinert（常に「表示済み」）とし、実プレイヤーの入口（`main.dart`）でのみ`.persistent()`を明示的に使用する設計とした（既存の`?e2e=1`と同じ分岐でe2e specファイルは無編集）。詳細は`docs/reports/SES_FIRST-FUN-YEAR_Opening-Context_P1_Result.md`§4を参照。
  - Package B（初期社員＋SkillSheet導線、SkillSheet hard gate変更、Employee画面再設計等）は本Issueの対象外のまま未着手。
  - `flutter analyze`（プロジェクト全体）No issues、変更ファイルを直接カバーする対象suite群（`test/game/public_demo` 842件、`test/ui/public_demo` 522件、`test/widget_test.dart` 11件、新規focused test 3ファイル23件）、プロジェクト全体`flutter test`（2170件）いずれもgreen。
  - 詳細・authority trace・persistence/replay検証マトリクス・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Opening-Context_P1_Result.md`を参照。PR: https://github.com/perusonao/smile_enjoy_story/pull/230 。
- **本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。** 本修正はPrioritized backlog表のP3「Public Demo UX仕上げ」枠（3〜6h、「初見でも基本ループを理解できる」）のうちPackage A分の消化として記録する — First Fun Yearの実行順（Visual Complete系列 → April→March human replay）自体は本エントリ以前と同じ。production code/tests/workflowは本docs-only追記で変更していない。
- 本エントリはPR #230のCodex Review P1（「governing plan（本文書）が#229完了を反映しておらず、以降の優先順位判断を誤らせ得る」）への対応。

### 2026-09-10（Issue #227完了 — 受注翌月Assignment materializeのP1修正 / governing plan sync）

- **Issue #227を実装完了（PR #228）。** #225 Human Replay → #226 Focused Audit（verdict: A — REAL P0/P1 PROGRESSION DEFECT）で発見された、First Fun Year本体の進行整合性に関わるP1回帰を修正した: 4月に真正受注（`engineer.stage == ordered`かつ真正なPhase 6面談合格）したエンジニアの`PublicDemoAssignment`が、5月中は一切存在せず、5月の月次決算（`closeMay`）が実行されて初めて生成されていた — 受注の1か月後ではなく2か月後の参画になっていた。社員/オフィスタブの状態表示・研修可否・参画中案件カードはいずれも`workflow.assignments`/`assignedEngineerIds`を読むため、既に正しかった売上側の`engineersAssigned`カウンタと5月中ずっと不整合を起こしていた。
  - **修正**: `PublicDemoAggregate.closeApril()`が、`closeMay()`が既に使っていた既存のドメイン権威`PublicDemoWorkflowState.assignOrderedForMay()`をそのまま呼ぶようにした（新しい割当式は追加していない）。同メソッド自体は、1シーズンに1回だけ呼ばれる前提の「毎回全ロスターを再構築する」実装から、既存エントリ（`nextOrderStatus`/`replacementStage`/`fieldEvaluation`/`projectId`/`monthsCredited`）を保持する冪等なupsertへ変更した — 4月→5月で2回目の呼び出しが発生するようになったため、これをしないと5月中の決定が5月決算時に無言で破棄される回帰を新たに生んでいた。
  - 次順序CTA（「7月分の発注を確認」）のタイミング早期化、6月以降（6月→7月・7月以降）の受注→参画タイミング、save/reload・リトライ冪等性・真正projectId保持は、いずれも既存の月ゲート・別機構（`recoverLateYearAssignment`等）により無影響であることをコードレベルで確認済み。
  - `flutter analyze`（プロジェクト全体）No issues、変更ファイルを直接カバーする対象suite群（workflow state/aggregate/monthly close/month guard/persistence/save codec、#220・#222・#224回帰含む）、プロジェクト全体`flutter test`（2152件）いずれもgreen。
  - 詳細・root cause・before/after状態遷移表・テスト証跡は`docs/reports/SES_FIRST-FUN-YEAR_Order-Assignment_Timing-Fix_Result.md`を参照。PR: https://github.com/perusonao/smile_enjoy_story/pull/228 。
- **本エントリはCurrent execution order・Prioritized backlog tableの構成自体は変更しない。** 本修正はPrioritized backlog表のP0「年間進行Blocker修正」枠（1件0.5〜3h）の消化として記録する — First Fun Yearの実行順（Visual Complete系列 → April→March human replay）自体は本エントリ以前と同じ。production code/tests/workflowは本docs-only追記で変更していない。
- 本エントリはPR #228のCodex Review P1（「governing plan（本文書）が#227完了を反映しておらず、以降の優先順位判断を誤らせ得る」）への対応。

### 2026-09-08（CORE-GAMEPLAY Phase 4.5完了 — Recruitment/SkillSheet authority是正）

- **CORE-GAMEPLAY Phase 4.5を実施。** Phase 5（Matching）着手前の必須是正として、Phase 1-4完了時点で残っていたRecruitment/SkillSheet周りの authority 不整合を修正した（`docs/reports/SES_CORE-GAMEPLAY_Phase4.5_Recruitment-SkillSheet_Result.md`）:
  1. **新規ゲーム開始時の応募者0人化** — `PublicDemoWorkflowState.initial()`が内部的に保持していたapp-01/app-02の固定ペア（4月存在・5月UI解禁）を初期applicantsから除去し、`recruit()`（Phase 2の`PublicDemoSeededRecruitmentGenerator`）のみを通常プレイの唯一の応募者発生経路とした。app-01/app-02定数自体はlegacy save/testの互換性のためにのみ残置。
  2. **表記統一** — Employee/Sales等の利用者向け表記を「スキルシート」に統一（内部クラス識別子は無変更）。
  3. **入社前スキルシート導線の真実性** — 「スキルシート確認」系ボタンの実体表示を候補者の実データに合わせ、面談質問でのみ判明する情報（interviewScore/acceptanceScore/salesSkillFit等）は入社前スキルシートから除外。
  4. **社員スキルシートの常時参照可能化** — 社員タブの一度きりのゲーティングとは独立に、いつでも当該社員のスキルシートを開けるエントリポイントを追加し、Sales側からも同じ表示構造を再利用可能にした（Phase 5 Matchingでの再利用を想定）。
- **本エントリはFirst Fun Yearの「Current execution order」「Prioritized backlog」を変更しない。** Phase 4.5はCORE-GAMEPLAYトラックの一部であり、HOME/Employee/Sales/Accounting/Menu Visual作業やApril→March human replayの優先順位・スコープを変更していない。Finance/Month transition authorityも無変更。
- Phase 4.5のresult reportに、Phase 5（Matching）へのhandoffポイント（`PublicDemoSkillSheetSheet.show(...)`／`PublicDemoCandidateSkillSheetSheet.show(...)`の直接再利用）と既知の制約を記録済み。

### 2026-09-08（CORE-GAMEPLAY Phase 1-4完了 — governing plan初出記録）

- **CORE-GAMEPLAY Phase 1-4が完了した。** First Fun Year本体（HOME/Visual/April→March replay）とは別建てで並行進行してきた施策系列で、本文書には従来一度も記載していなかった:
  1. Phase 1 — Seeded RNG基盤（PR #201、`docs/reports/SES_CORE-GAMEPLAY_Phase1_Seeded-RNG_Result.md`）
  2. Phase 2 — Random Recruitment（PR #202、`docs/reports/SES_CORE-GAMEPLAY_Phase2_Random-Recruitment_Result.md`）
  3. Phase 3 — Recruitment Interview（PR #203、`docs/reports/SES_CORE-GAMEPLAY_Phase3_Recruitment-Interview_Result.md`）
  4. Phase 4 — Random Projects（PR #204、`docs/reports/SES_CORE-GAMEPLAY_Phase4_Random-Projects_Result.md`）
- Phase 1-3はいずれも本文書を一度も更新せず、各Phase自身のresult reportのみで追跡されていた（`git log -- docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`で確認済み — 本エントリが本文書における"CORE-GAMEPLAY"の初出）。Phase 4のPRレビュー（Codex自動レビュー、PR #204）でこの空白を指摘され、著者確認の上、本エントリとして遡及的に記録する。
- **本エントリはFirst Fun Yearの「Current execution order」「Prioritized backlog」を変更しない。** CORE-GAMEPLAY Phase 1-4はFirst Fun Year本体の実行順とは独立した並行トラックであり、いずれのPhaseもHOME/Employee/Sales/Accounting/Menu Visual作業やApril→March human replayの優先順位・スコープを変更していない。
- Phase 4のresult reportはPhase 5（Matching）へのhandoffポイント（`PublicDemoAggregate.projectCandidatesForMonth`ほか）を記録済み。次Phaseの着手判断・優先順位付けは本文書のFirst Fun Year方針とは別に行う。

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
