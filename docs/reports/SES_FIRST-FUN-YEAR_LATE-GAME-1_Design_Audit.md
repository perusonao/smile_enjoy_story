# SES_FIRST-FUN-YEAR_LATE-GAME-1 Design Audit

Issue #167 — READ-ONLY DESIGN AUDIT（production実装なし）。

## 0. 監査対象・base情報

- **audited branch**: `claude/first-fun-year-late-game-audit-aogdzg`
- **audited origin/main SHA**: `d68bd8a9c6d2de50b9bab16dbf8564cbb6990ff8`
  （`git fetch origin main` 実行後の最新値。ローカルの作業ブランチはこの
  SHA から作成し直した — 開始時にローカルに残っていた古い作業ブランチ
  （`f4ca78f` 一本、本Issueと無関係な "Phase 0A/0B" commit）は origin/main
  より大幅に古かったため、それを現在のmainと仮定せず origin/main へ
  `checkout -B` し直している）。
- **current HEAD**: 上記と同一（`d68bd8a9`）。ドキュメント追加のみで
  コード変更なし。
- **working tree**: 開始時 clean。本レポート追加のみ。
- 本Issueが依存する #166（Persistence P0-1）・#147（HOME-UI-3A）は
  いずれも本SHA時点で **未着手（open, 未マージ）**。本監査はその待ち時間
  に行う設計監査であり、production実装はここでは行わない。

## 1. スコープの確定：「First Fun Year」＝ Public Demo 0.1

最初に明確にしておく必要がある事実（実コードで確認済み）：

Issue #167 が参照する「full-year human playtest audit（PR #164でマージ済み）」
＝ `docs/reports/SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md` は、
**`lib/ui/public_demo/public_demo_01_placeholder_screen.dart` を起点とする
「S.E.S. Public Demo 0.1」** をプレイしたものである。#166 (persistence)・
#147 (HOME-UI)・#148 (資金危機予告) はいずれも `PublicDemo*` 名を冠しており、
同一の対象を指している。

一方、リポジトリには **もう一つ完全に別の経営シミュレーション**
（`lib/game/engine/game_engine.dart` / `lib/game/models/game_state.dart`
を中心とした「Development / 自由経営モード」、週単位・48週制、
`ActiveAssignment.contractDecision`（延長/撤退）等の遥かに大きな
経営システムを持つ）が同居している。この2つ目のシステムは
**First Fun Yearのスコープ外**（`lib/game/public_demo/**` /
`lib/ui/public_demo/**` の外側）であり、本監査ではこちらの既存機能
（契約延長/撤退判断、福利厚生（PC/健康診断/社員旅行）、Company Trust等）
は「First Fun Yearで直接再利用できる既存authority」としては扱わない。
以降の監査・candidate はすべて **Public Demo 0.1
（`lib/game/public_demo/**`, `lib/ui/public_demo/**`）** を対象とする。

## 2. 現状の late-game gameplay inventory（実コード確認）

Public Demo 0.1 の内部月は `4`〜`15`（4=4月 … 12=12月、13=1月、14=2月、
15=3月）。8月〜2月は内部月 `8`〜`14` の7か月（`lib/game/public_demo/public_demo_month_label.dart`,
`public_demo_recovery.dart` の `firstEligibleMonth=7`/`lastEligibleMonth=14`
コメントで整合）。

月ごとに存在する既存プレイヤー操作を実コードから棚卸しした結果：

| 月 | 存在する操作 | 出典 |
|---|---|---|
| 4月 | 採用面接・SkillSheet・営業開始・面談進行 | `public_demo_recruitment.dart` 等 |
| 4-8月 | 求人媒体（月1回まで） | `PublicDemoState._normalizedRecruitmentMediaMonth`（`month>=4 && month<=8` のみ有効。9月以降は**恒久的に不可**、コード注記あり） |
| 5月 | `assignOrderedForMay` による参画確定（一括） | `public_demo_workflow_state.dart:619` |
| 6月以降 | 昇給要求への回答（**社員1人につき生涯1回のみ**） | `public_demo_raise.dart:59` `canRequestRaiseIn` |
| 6月以降 | 待機社員のみの社内研修（¥30,000/回、**参画中社員は選択不可** — `assignedEngineerIds.contains` で拒否） | `public_demo_internal_training_transaction.dart` |
| 7月 | 夏季賞与プラン決定（Month Guard の`required`項目、月1回のみ） | `public_demo_month_guard.dart`, `public_demo_summer_bonus_payment.dart` |
| 7-14月 | Recovery（**待機中**かつ`ordered`到達済みの社員のみ再参画可能） | `public_demo_recovery.dart` |
| 毎月 | 月末処理（Growth適用・売上計上・固定費/給与支払） | `public_demo_monthly_close.dart` |

**重要な既存設計判断（コードコメントで明記）**：
`public_demo_workflow_state.dart:757`
「一度案件参画が成立した社員は、第1期終了まで同じ案件へ継続参画する」。
6月に確定した `nextOrderStatus`/`replacementStage` は7月以降そのまま
年度末まで持ち越され、**契約更新/終了判断そのものが存在しない**
（Development側の`ActiveAssignment.contractDecision`とは別設計）。

結果として、**参画済みで安定した会社**（全員assigned、資金が破綻圏外）
は、8月〜2月の間、月末処理ボタンを押すだけで進行できる。これは実際の
プレイテスト（`SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md` 69-75行）
でも「8月〜2月、現金が毎月-¥12万で単調に減少するだけ、推奨アクションは
7か月間まったく同一文言」として確認済み。

## 3. 8月〜2月が単調になる root cause

実コードから特定できる直接原因は次の3点：

1. **求人媒体が9月以降恒久的に使用不可**（4-8月固定、コード内で意図的）。
2. **社内研修は待機社員専用**。安定企業（waiting=0）では選択肢自体が
   画面に出ない（`internalTrainingCard` は `assigned` なら
   `SizedBox.shrink()`）。
3. **昇給要求は社員あたり生涯1回**。月6以降いつでも押せる/放置できるため、
   「同じ推奨アクションが7か月間居座る」（実プレイテストで確認済みの現象）。
   これは新しい判断ではなく、「まだ答えていない1個の古い判断」が
   表示され続けているだけ。

加えて、`PublicDemoAssignment` の `deliveryPressure` / `budgetHealth` /
`humanity` と `PublicDemoEngineerSales` の `mental` / `trust` は
**参画後、一度も書き換えられない**（`copyWith` のパススルー以外に
書き込み箇所ゼロ、grep で確認済み）。つまり「会社状態によって意味が
変わる」ための最有力な既存stateが、現状は完全に静的で、プレイヤーが
働きかける手段も、時間経過で変化する仕組みも存在しない。

## 4. 既存authoritative state（実コードで確認したもののみ）

### A. 参画中社員

| 項目 | 型/場所 | 現状 |
|---|---|---|
| 個人特定 | `PublicDemoEngineerSales.id/name`, `PublicDemoApplicant.id/name` | ○ |
| stage（waiting→…→ordered） | `PublicDemoSalesStage` | ○、参画確定後は不変 |
| `employeeMorale` / `employeeCompanyTrust` | `PublicDemoApplicant` | ○ 既存・永続化済み。**join時と昇給決定時のみ**書き込み。`employeeConditionCard`で既に表示中 |
| `relationshipHistory`（reason付き変化履歴） | `PublicDemoApplicant` | ○ Development側の`EmployeeRelationshipEvent`をそのまま再利用。昇給決定でのみ1件追加 |
| `mental` / `trust`（EngineerSales側） | `PublicDemoEngineerSales` | ○永続化・表示されるが、**書き込み経路が存在せず実質固定値**（company snapshotの平均値計算のみが消費） |
| `motivation`（`interviewProfile.morale`のalias） | 同上 | ○ **Growth計算のmoraleMultiplierに実際に使われる唯一の"効く"値**（`moraleByEngineerId`経由） |
| runtime capability（言語スキル等） | `PublicDemoEngineerRuntime` | ○ 毎月`applyMonthlyGrowth`で成長 |
| assignment経済値 `deliveryPressure`/`budgetHealth`/`humanity` | `PublicDemoAssignment` | ○ 存在するが**join/assign確定時に設定されて以降不変** |
| `fieldEvaluation` | 同上 | ○ 存在するが書き込みは6月の受注フロー時のみ確認 |
| salary | `PublicDemoApplicant.acceptedMonthlySalary`/`raisedMonthlySalary` | ○ |

### B. 案件

- 案件名・`deliveryPressure`・`budgetHealth`・`humanity` は存在（`PublicDemoAssignment`）。
- **単価・粗利・支払サイトの個社別詳細フィールドは存在しない**（Public Demo
  0.1は月次売上を`PublicDemoRevenue`系で集計する簡略モデルで、Development側
  の`Project.monthlyRate`/`paymentTermDays`のような詳細案件モデルは
  **移植されていない**）。
- 契約期間・契約終了日に相当するフィールドは**存在しない**
  （`contractStartWeek`/`contractEndWeek`相当なし）。§3で述べた
  「年度末まで同一案件継続」という設計により、そもそも終了判定が
  不要な設計になっている。

### C. 会社

- `cash`, `monthOpeningCash`, `pendingRevenue`, `financialStatus`
  （`PublicDemoFinancialStatus`：健全/cashShortage/bankruptcy/marchCashShortageFailure）。
- `salesCapacity`/`salesUsed`（月内アクション消費枠）。
- `recruitmentMediumUsedMonth`, `monthRecruitmentSpent`, `monthTrainingSpent`。
- `summerBonusSelection`/`summerBonusPaid`（7月のみ）。
- `trainingSelections`（月次リセットのMap、待機社員専用）。
- **companyTrust相当（会社単位の信頼指標）は存在しない**。福利厚生
  （PC支給・健康診断・社員旅行）もPublic Demo 0.1には**存在しない**
  （Development側のみ）。

### D. 月次処理

- `PublicDemoAggregate.closeJuly` / `closeOrdinaryMonth`（8-15月共通）。
- `applyMonthlyGrowth`：assigned/waiting/trainingソース別に成長計算
  （`PublicDemoGrowthEngine`）、morale（motivation）が乗数として実際に影響。
- `PublicDemoMonthGuard`：`required`（7月賞与のみ）と`recommended`
  （HOME推奨アクション由来のcandidateをそのまま警告化するだけ、独自ロジック
  なし）の2段。
- `HomeRecommendedActionKind`：優先順位付き推奨アクション語彙。P1帯に
  `summerBonusDecision`（7月固定）と`raiseRequest`（6月以降、社員あたり
  1回）が存在。**「参画済み社員向けの新しい経営判断」に対応する枠は
  現状ゼロ**。
- `PublicDemoRecoveryEligibility`：7-14月、**待機中**社員限定の再参画。
- 年度末：`fiscalYearCompleted`フラグのみ、詳細な振り返り演出なし
  （既存プレイテストレポートでも指摘済み）。

## 5. 既存Issueとの重複・競合確認

| Issue | 内容 | 本Issueとの関係 |
|---|---|---|
| **#166** | Public Demo persistenceのP0修正 | 先行Issue。本監査はブロックしない（design onlyのため） |
| **#147** | Public Demo HOME UIの再構築（見た目のみ、`lib/domain/**`・進行・save schema変更禁止と明記） | 先行Issue。本監査の候補実装はHOME UIの構造変更を必須としない設計を選ぶ必要がある |
| **#148** | 資金危機予告＋対応アドバイス（`PublicDemoCashAdviceSelector`） | **重複なし**（実コード確認済み）。`cashStatus.status==shortage`の時のみ発火し、**待機中の社員**（研修/SkillSheet確認/営業開始）にしか助言しない。参画中社員のmorale/trustには一切触れない |
| **#125** | PUBLIC-DEMO-MONTHS-1A（9-2月の月別ガイダンス文言の改善） | **レイヤーが異なるため重複しない**が密接に関連。#125は「新しいgameplay mechanicを追加しない」ことが明記された**コピー文言のみ**の変更。本Issueの候補（実際の意思決定を追加）とは競合しないが、HOMEの推奨アクション/フォールバック文言に影響するため、実装順序として#125の変更内容を把握してから着手する方が安全 |
| **#129** | **PUBLIC-DEMO-EMPLOYEE-1ON1-1A**：社員との1on1/面談ミニゲーム。「morale/salary/career/retention等の経営判断」「existing employee state/condition authoritiesを再利用」「meaningfulな選択→社員の反応→結果」という記述 | **重大な重複候補**。これは本Issueが検討すべき「Family A: 参画中エンジニアへのフォロー判断」と**ほぼ同じ対象領域**（`employeeMorale`/`employeeCompanyTrust`/`relationshipHistory`を使った個人単位の会話的判断）を指している。ただし#129は「ミニゲーム」規模で#128（PROJECT-INTERVIEW-1A、これも未着手）に依存する、より大きな体験実装。**個人単位・会話形式の"1on1"実装は#129の担当領域と衝突するため、本Issueでは推薦しない** |
| #124 | HOME-UI-2A（1画面に収める） | #147の前提。直接の重複なし |
| #123 | GROWTH-1A（成長の可視化） | 既にGrowth結果表示強化が別Issueとして走っている前提。本Issueの候補は既存の`PublicDemoGrowthResultCard`をそのまま再利用し、新しい成長可視化UIを重ねて作らない |
| #108 | PLAYTEST-BLOCKER-1（初年度の進行/フィードバック課題） | 過去のブロッカー、本Issueとの直接衝突なし |
| #130 | STAFF-ROLE-EXPANSION-1A（新職種） | 明確にスコープ外（Non-goalsで除外済み） |

**結論**：Family A（個人単位のフォロー判断）は #129 と重複するため、
本Issueでは**個人対話・ミニゲーム形式では推薦しない**。Family B（契約
更新/終了）は§3の設計判断・実コード不在によりそもそも実装不可（§6で
詳述）。したがって、実装可能かつ他Issueと衝突しない候補は
**会社レベルの投資判断（Family C）** および **既存stateから合成する
軽量な定期チェックポイント（Family D）** に絞られる。

## 6. Candidates（最大3件）

### Candidate #1（推奨）: 「社員フォロー投資」— 会社単位の cash vs morale/trust 判断

**概要**：参画中社員全体のコンディション（`employeeMorale`/
`employeeCompanyTrust` の平均、または`budgetHealth`/`deliveryPressure`
の悪化）が既存stateから見て一定水準を下回ったときにのみ、HOMEの
recommended action として「フォロー投資（現金を使って全参画社員の
morale/trustを引き上げる）」 vs 「見送り（現金温存）」を提示する。
実行すると`employeeMorale`/`employeeCompanyTrust`が上がり、
`relationshipHistory`に理由付きイベントが追加され（既存の昇給決定と
同じ表示パターン）、翌月以降の`PublicDemoGrowthEngine`のmorale乗数
（既存の`moraleByEngineerId`経路）を通じて成長速度に実際に反映される。

**個人単位の1on1ではなく会社単位の一括判断**とすることで#129
（個人対話ミニゲーム）と重複しない。トリガーは「毎月強制」ではなく、
既存stateから導出される条件（例：既存プレイテストが示した通り
Aug-Feb はcashが毎月-¥12万で減り続ける構造のため、投資すれば
runwayが縮む一方でmorale経由の成長が上がる、という綱引きが実際の
数値としてすでに存在する）に基づく。

- FUN impact: 中〜高。プレイテストで確認された「7か月間何もない」を
  直接埋める。
- implementation size: 小。新規transactionクラス1つ（`public_demo_raise.dart`/
  `public_demo_internal_training_transaction.dart`と同型）＋
  `PublicDemoAggregate`へのメソッド1つ＋UIカード1つ＋HOME推奨アクションへの
  候補追加（任意、最小実装ではUIカード単独でも成立）。
- domain risk: 低。既存の`employeeMorale`/`employeeCompanyTrust`/
  `relationshipHistory`書き込みパターンをそのまま踏襲。
- save schema risk: 低（詳細は§9）。
- explanatory clarity: 高。既存の`relationshipHistory`理由文言・
  `PublicDemoGrowthResultCard`の成長差分表示をそのまま使って説明できる。
- replay value: 中。cashが潤沢な回とギリギリの回で最適解が変わる
  （実測されたAug-Feb -¥12万/月の下降トレンドと直接competing）。
- reused existing authorities: `employeeMorale`/`employeeCompanyTrust`/
  `relationshipHistory`（`EmployeeRelationshipEvent`）/ `cash` /
  `moraleByEngineerId`→Growth乗数 / `PublicDemoGrowthResultCard`。

### Candidate #2: 「経営チェックポイント」— 既存factsを合成した軽量な定期判断（Family D）

**概要**：新しい経済値を一切増やさず、既存の`PublicDemoCompanySnapshot`
（稼働率・平均morale/trust/フィールド評価）と`latestMonthlyCashFlow`
から「今月の会社状態」を要約し、状態が既存の閾値（例：
`financialStatus`が健全かつ数か月連続で推奨アクションが空
＝現状の`HomeRecommendedActionNone`）の時にだけ、「コスト重視で進める」
か「投資に回す」かの**プレイヤー宣言（大きな効果を持たない、次の
Candidate的な選択肢が出た時の既定値だけを変える程度の軽い選択）**
を1回提示する。

- FUN impact: 低〜中。判断の"重み"がCandidate #1より薄く、単なる
  雰囲気演出に近くなるリスクがある。
- implementation size: 小〜中。新しい状態合成ロジックが要る分
  Candidate #1よりわずかに大きい。
- domain risk: 低。
- save schema risk: 低〜中（宣言した方針を次月以降も憶えておく場合は
  新規フィールドが要る）。
- explanatory clarity: 中。「宣言したことで何が変わったか」が薄いと
  「結果の理由が説明可能」という要件（原則5）を満たしにくい。
- replay value: 低〜中。効果が弱いと"常に投資一択"になりやすく、
  原則6（常に同じ選択が正解にならない）を満たすための調整が難しい。
- reused existing authorities: `PublicDemoCompanySnapshot`,
  `latestMonthlyCashFlow`, `HomeRecommendedActionNone`。

Candidate #1と同じ既存stateを使うが、効果が具体的な数値変化
（morale/trust→growth）に直結しないぶん設計難易度が上がる。
Phase 1としては Candidate #1 の方が「小さく、効果が説明可能」という
要件に強く適合する。

### Candidate #3: 「契約継続/終了判断」（Family B）— 監査の結果 NOT RECOMMENDED

Issue本文が例示するFamily Bをそのまま監査した結果を記録する。

- Public Demo 0.1には契約開始/終了日、契約期間に相当するフィールドが
  **存在しない**（`PublicDemoAssignment`に`contractStartWeek`/
  `contractEndWeek`相当なし）。
- `public_demo_workflow_state.dart:757`のコメントに明記された既存の
  **意図的な設計判断**「一度案件参画が成立した社員は、第1期終了まで
  同じ案件へ継続参画する」に真正面から反する。
- Issue本文で明示的に禁止されている「契約日・更新メカニクスが
  存在しないなら架空の仕組みを前提にしない」に該当する。

- FUN impact: 潜在的には高い（Development側の`decideContract`が
  実証済みの通り、この種の判断は面白い）が、Public Demo 0.1では
  実現コストが跳ね上がる。
- implementation size: 大。契約期間フィールドの新規追加、6月の
  一括assignロジック・Recovery・Growth・Revenue全体への影響範囲の
  見直しが必要。
- domain risk: 高。年度末まで固定という既存invariantとの整合を
  取り直す必要がある。
- save schema risk: 高。新規フィールド必須、かつ既存セーブとの
  互換性設計が必要。
- explanatory clarity: 中（設計次第）。
- replay value: 高（設計できれば）。
- reused existing authorities: ほぼなし（Development側の`ContractDecision`
  はPublic Demo 0.1のドメインとは別モデルであり、直接移植はできない）。

**判定：Phase 1として選定しない。** 大規模な設計変更が要るため、
Issue本文の「巨大なシステムになりそうなら無理に実装案へ落とさず
READY WITH CONDITIONSとする」に従い、実装候補からは除外する
（必要であれば別Issueとして起票する価値はあるが、本Issueのスコープ外）。

## 7. Comparison

| | #1 社員フォロー投資（推奨） | #2 経営チェックポイント | #3 契約継続/終了判断 |
|---|---|---|---|
| FUN impact | 中〜高 | 低〜中 | 高（だが実現コスト大） |
| implementation size | 小（2-3h） | 小〜中 | 大（別Issue相当） |
| domain risk | 低 | 低 | 高 |
| save schema risk | 低 | 低〜中 | 高 |
| explanatory clarity | 高 | 中 | 中 |
| replay value | 中 | 低〜中 | 高（設計できれば） |
| 既存Issueとの衝突 | なし（#129は個人1on1、本案は会社単位） | なし | なし（実装しないため） |
| 既存authority再利用度 | 高 | 中 | 低（Public Demo内には無い） |

## 8. 推奨 Phase 1：Candidate #1「社員フォロー投資」

### 何を作るか（設計スケッチ、実装詳細はPhase 1担当が決定）

1. **トリガー判定**（純粋関数、新規1ファイル）：既存の
   `workflow.engineers`（`mental`/`trust`はまだ使わず、既に生きている
   `PublicDemoApplicant.employeeMorale`/`employeeCompanyTrust`の平均、
   または`PublicDemoAssignment.budgetHealth`/`deliveryPressure`）から、
   「フォローが必要」という真偽値を導く。強制モーダルにはせず、
   HOMEの推奨アクション/月次タスクの1候補として自然に出す
   （原則7の遵守）。
2. **実行**（新規transactionクラス、`public_demo_raise.dart`と同型）：
   cashを消費し、参画中社員の`employeeMorale`/`employeeCompanyTrust`
   を引き上げ、`relationshipHistory`に理由付きイベントを追加する。
   `PublicDemoRaiseTransaction`と同じく`state.fiscalYearCompleted`/
   `isFinanciallyRestricted`ガードを踏襲。
3. **見送り**：何もしない（既存状態を維持）。
4. **結果説明**：既存の`employeeConditionCard`のmorale/trustラベル
   表示、既存の`PublicDemoGrowthResultCard`の成長差分表示（morale
   乗数の効果は翌月Growth結果に自然に反映される）をそのまま使う。
   新しい結果画面は作らない。

### なぜこれが最初の実装として最適か

- **原則4（既存authority再利用）** を最も厳格に満たす：新しい経済値・
  新しい案件モデル・新しい月ロジックを一切増やさず、`employeeMorale`/
  `employeeCompanyTrust`/`relationshipHistory`/`cash`/既存Growth乗数
  という**既に生きている**stateだけを使う。
- **#129（1on1ミニゲーム）と衝突しない**：会社単位の一括判断として
  設計するため、個人対話UIを新設しない。
- **原則5（結果説明）**：`relationshipHistory`のreason文言と
  `PublicDemoGrowthResultCard`の成長差分は既に「理由付きで見せる」
  実装が存在し、そのまま転用できる。
- **原則6（常に同じ選択が正解にならない）**：実測されたAug-Feb
  -¥12万/月というcash下降トレンドと直接綱引きになるため、cashに
  余裕がある回・ギリギリの回で最適解が変わる。
- **原則1・7（強制しない・状態依存で発生）**：トリガーを既存状態の
  閾値から導出するため、「安定していて本当に何も問題がない月」は
  今まで通り月末処理のみで進行できる（Issue本文が明示的に禁止する
  「毎月必ずイベントモーダル」を回避）。

### 見積り

- **Claude Code実装時間**: 約2〜3時間（Issue #167のPhase 1サイズ制約に
  合致。`public_demo_raise_transaction.dart`（60行程度）＋
  `public_demo_raise.dart`（97行程度）と同規模のtransactionを1つ追加
  する作業に近い）。

### 想定される変更ファイル/システム

- 新規: `lib/game/public_demo/public_demo_followup_support.dart`
  （仮称。トリガー判定＋transaction本体、`public_demo_raise.dart`型）
- 変更: `lib/game/public_demo/public_demo_aggregate.dart`
  （メソッド1つ追加、`withAssignmentUpdate`と同型の薄いラッパー）
- 変更: `lib/game/public_demo/public_demo_state.dart`
  （§9参照。最小1フィールド追加の可能性）
- 変更: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
  （`employeeConditionCard`/`internalTrainingCard`と同型のカード1つ追加）
- 任意（Phase 1に含めるかは実装者判断）:
  `lib/presentation/home/models/home_recommended_action.dart`への
  候補kind追加。含めない場合は既存employee詳細カードのみに置く
  最小実装でも要件を満たせる。

### Domain impact

- Development側（`lib/domain/**`, `lib/game/engine/**`,
  `lib/game/models/**`）には**触れない**（今回のスコープが
  `lib/game/public_demo/**`/`lib/ui/public_demo/**`に閉じるため）。
- Public Demo内の既存ドメイン不変条件
  （`PublicDemoAggregate._validateForPersistence`）は壊さない設計：
  新フィールドを追加する場合は`trainingSelections`と同じ
  additive/backward-compatible方式に合わせ、既存チェック
  （`state.engineersAssigned + state.engineersWaiting == state.engineerCount`
  等）に影響しないことをPhase 1実装時に確認する。

### Save schema impact

- **新規save schema versionは不要**（Public Demo 0.1にはDevelopment側の
  `currentSchemaVersion`のような明示的なversion番号が存在せず、各
  フィールドはnull許容/デフォルト値によるbackward-compatible方式で
  読み込まれている）。
- 「今月すでにフォロー投資済みか」を憶える最小限の状態は必要になる
  可能性が高い（連打防止）。既存の`trainingSelections`
  （`Map<String, PublicDemoGrowthSource>`、月次リセット、
  `const {}`デフォルト）と全く同じ形の
  `Map<String,int>`（値は「最後に実行した月」）程度の追加で足りる
  設計が可能で、これは`recruitmentMediumUsedMonth`（`int?`、既存）と
  同種の**precedentのある最小限の追加**であり、Issue本文が警戒する
  「大規模なsave schema変更」には当たらない。
- ただし追加フィールドである以上、`PublicDemoAggregate.fromJson`/
  `_validateForPersistence`との整合をPhase 1実装で確認する必要がある
  （既存セーブが読み込めることをテストする）。

### Focused test plan

既存のテスト命名・配置規約（`test/game/public_demo/public_demo_raise_test.dart`,
`public_demo_internal_training_transaction_test.dart`,
`public_demo_month_guard_test.dart`）に倣う：

1. `test/game/public_demo/public_demo_followup_support_test.dart`（新規）
   - トリガー条件が既存stateから正しく導出されるか（morale/trust
     閾値、cash不足時は`isFinanciallyRestricted`で拒否）。
   - 実行後、morale/trust/`relationshipHistory`/cashが期待通り変化する。
   - `fiscalYearCompleted`後は何もしない（既存ガードと同型）。
   - 見送り（no-op）で状態が変化しない。
2. `test/game/public_demo/public_demo_aggregate_test.dart`（既存に追記）
   - 新メソッドの往復（呼び出し→state反映）。
3. `test/game/public_demo/public_demo_monthly_growth_test.dart` 付近
   （既存に追記可）
   - morale上昇後の翌月`applyMonthlyGrowth`で成長量が増えることの
     回帰確認（既存のmoraleMultiplier境界値テストと同型）。
4. `test/game/public_demo_save_service_test.dart` / 既存save系
   - 新フィールドを含むセーブの保存・復元、および新フィールドが
     **存在しない旧セーブ**の読み込み互換性（後方互換デフォルト）。
5. UIレベル（`test/ui/public_demo/`）
   - 新カードの表示条件（トリガーが立っている時だけ出る／
     出ていない時は何も表示しない＝原則7の回帰防止）。
   - 360/390pxでのoverflow無し確認（既存レイアウトテストに準拠）。

### 想定されるプレイヤー体験の変化

- 「参画済みで安定している」だけでは何も変わらないが、実際に
  プレイテストで観測された cash 下降トレンドやプロジェクトの状態
  次第で、8月〜2月のどこかで「今、投資すべきか、様子を見るべきか」
  という**現金と社員コンディションの綱引き**が最低1回は発生する。
- 選んだ結果は既存の関係イベント表示・成長結果表示にそのまま
  反映されるため、「なぜ数字が変わったか」が既存UIパターンのまま
  説明可能。
- 何もしない選択も legitimate（現状維持）であり、強制モーダルには
  ならない。

### Known risks

- トリガー条件を緩く作りすぎると「毎月出る」＝実質的な強制モーダルに
  近づき、原則7に反する。逆に厳しすぎると「安定企業では一度も
  出ない」ため、Issue受け入れ基準（「8月〜2月の間に最低1回は発生
  すべき」）を満たさない可能性がある。閾値のチューニングはPhase 1
  実装時にプレイテストで検証する必要がある。
- `mental`/`trust`（`PublicDemoEngineerSales`側）は現状どこからも
  消費されない値であるため、これらを巻き込む設計にすると「触っても
  何も変わらない飾りの数値」を追加することになりかねない。Phase 1
  では`employeeMorale`/`employeeCompanyTrust`（`PublicDemoApplicant`側、
  Growthに実際に効く`motivation`と同じ`employeeMorale`が入力元）を
  優先して使うべきで、`EngineerSales.mental`/`trust`には触れない
  ことを推奨する。
- HOME推奨アクションへの統合（`HomeRecommendedActionKind`への追加）は
  #147/#166が完了する前のmainには乗せない方が安全。Phase 1の最小
  スコープでは、まずemployee詳細カード単体の実装に留め、HOME統合は
  任意/follow-upとして切り出すことを推奨する。

### Implementation dependencies

- #166（persistence）・#147（HOME UI）が完了した後の新しいmainを
  ベースにすること（Issue #167本文の実行順序どおり）。
- #125（月別ガイダンス文言）が並行して進んでいる場合、フォールバック
  文言と新しい推奨アクション文言が重複/矛盾しないよう、実装直前に
  最新mainを再監査すること。
- #129（1on1ミニゲーム）とスコープが重ならないよう、個人対話UIを
  新設しないという設計方針を実装時にも維持すること。

## 9. Final Verdict

**READY WITH CONDITIONS**

理由：
- Candidate #1「社員フォロー投資」は、既存stateのみで実装でき、
  ファイル規模・実装時間ともにIssue #167のPhase 1サイズ制約
  （Claude Code 2-3時間）に収まる設計が描けている。
- ただし以下の3条件が満たされてから着手すべきであり、現時点で
  「即READY」とはしない：
  1. #166（persistence P0-1）・#147（HOME-UI-3A）のマージ完了後、
     fresh mainで本レポートの§2-5の前提（特に#125/#129の実装状況）
     を再確認すること。
  2. トリガー閾値（いつ「フォローが必要」と判定するか）を、実際の
     Aug-Feb playtestデータ（cashの下降ペース、morale/trustの初期値）
     に基づいてPhase 1実装冒頭で具体的に決定すること（本監査は
     設計方向のみを示し、数値バランスの決定はPhase 1実装のスコープ）。
  3. HOME推奨アクションへの統合は任意とし、最小スコープ
     （employee詳細カード単体）から着手すること。

Family B（契約継続/終了判断）はBLOCKED（§6 Candidate #3参照、既存の
「年度末まで同一案件継続」という設計判断と正面衝突するため、この
Issueのスコープでは実装しない）。
