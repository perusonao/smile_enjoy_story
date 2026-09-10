# SES First Fun Year — Monthly Management Report（月末ひより経営報告）Fresh Audit

Status: **READ-ONLY Fresh Audit — no production/test/workflow change**

## 0. Audit metadata

| item | value |
|---|---|
| Audited origin/main SHA | `160b78ab972b00d787dc827620c23e1335144728`（`git fetch origin` 実行後の最新値。PR #230 merge時点と一致を確認済み） |
| Audit branch | `claude/monthly-report-fresh-audit-7bt7ag`（session開始時点でrepository default branch `claude/ses-game-core-phase-0-h7e8om` から派生していたため、`origin/main`へreset済み — 唯一のBASEとしてorigin/mainのみを使用） |
| Scope | Monthly Management Report（月末ひより経営報告）のFresh Audit。実装・テスト変更・workflow変更・Issue/PR作成は一切なし |
| Excluded | Employee / SkillSheet領域（Issue #231 Package B並行実装中）。Package Bのbranch/未merge変更は一切参照していない |
| Deliverable | 本Result Reportのみ（`docs/reports/`へcommit） |

---

## 1. Final audit verdict

**GO — ただし1 PRではなく Phase A / Phase B の2分割を推奨。**

- 既存authority（`PublicDemoState.latestMonthlyCashFlow` / `PublicDemoWorkflowState.assignedEngineerIds` / `HomeRecommendedActionKind`）だけで、Reportが要求する情報のほぼ全て（現金Before→After、当月収支、参画/待機分類、次の推奨アクション）を **read-onlyで安全に取得できる**。
- ただし「今月の応募N名／面談N名／採用決定N名」のような **月内発生件数（delta）** は、現在の永続stateに「いつ発生したか」を示すフィールドが存在しないため、単純な現状readでは導出できない（詳細§5.2, §18 Known Limitations）。これがPhase分割の主因。
- Dialog自体はauthorityのcommit後にread-onlyで挿入でき、二重実行・二重計上のリスクは構造的に低い（§9, §10）。
- Bankruptcy/terminal state表示は既存の`isCloseBlocked`/`isFinanciallyTerminal`を再利用すれば、新しい判定ロジックなしで安全に共存できる（§11）。

---

## 2. Recommended architecture（要約）

```
[プレイヤー: "○月を終了"]
        │
        ▼
[既存 Month Guard 確認 (_confirmMonthCloseIfRecommendedOutstanding)]  ← 既存、無変更
        │
        ▼
[既存の一度きりイベントDialog（4月/5月のみ）]                        ← 既存、無変更
        │
        ▼
[_commitAggregate(_game.closeX(...))]  ← 既存の唯一の月次決算=月transition。ここで
        │                                 PublicDemoState.latestMonthlyCashFlow が
        │                                 確定済み結果として書き込まれる（read-only消費側）
        ▼
[NEW: PublicDemoMonthlyReportDialog]
   - _game（closeX後、既にcommit済みのaggregate）から
     latestMonthlyCashFlow / assignedEngineerIds / applicants /
     _recommendedActionCandidates を「読むだけ」
   - close/commandを一切呼ばない（true read-only）
   - CTA: 「○月へ進む」は s.isCloseBlocked を再利用し、
     terminalなら自動的に出さない（bankruptcy/年度末は別CTA）
        │
        ▼
[_resetMonthScroll() → 通常のHOME再描画]
```

Reportは **Result Presentation Layer専用の新規Dialogウィジェット1つ**として追加し、Finance/Payroll/Recruitment/Sales/Assignment/monthly-closeの計算は一切再実装しない。

---

## 3. Current monthly-close call flow（コード根拠つき）

UI側エントリポイント（すべて `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`）:

| 月 | ハンドラ | 呼び出すaggregate command | 備考 |
|---|---|---|---|
| April | `april()` (L1686) | `_game.closeApril(monthlyExpenses:)` (L1723) | 求人媒体の一度きりイベントDialog表示後にcommit |
| May | `may()` (L1860) | `_game.closeMay(week:9, monthlyExpenses:)` (L1890) | 入社者がいれば「入社・初参画！」イベントDialog表示後にcommit |
| June | `june()` (L1951) | `_game.closeJune(assignedInJuly:, monthlyExpenses:)` (L1967) | イベントDialogなし |
| July | `july()` (L2151) | `_game.closeJuly(monthlyExpenses:)` (L2169) | 夏季賞与決定が未済なら`decideSummerBonus()`へ先に分岐 |
| Aug〜Mar | `closeOrdinaryMonth()` (L2189) | `_game.closeOrdinaryMonth(monthlyExpenses:)` (L2192) | 3月（month 15）も同じ経路。`completeFiscalYear`へ内部分岐 |

いずれも共通パターン:

```dart
if (!await _confirmMonthCloseIfRecommendedOutstanding()) return;  // Month Guard（既存）
await showDialog(...);                                            // 4/5月のみ、既存の一度きりイベント
_commitAggregate(_game.closeX(...));                               // 唯一の状態遷移点
_resetMonthScroll();
```

`_commitAggregate`（L368）が **この画面が保持する唯一の変異境界**:

```dart
void _commitAggregate(PublicDemoAggregate next) {
  if (identical(next, _game)) return;   // 変化なしは即return（何もしない）
  setState(() => _game = next);         // 同期的に新しい月へ
  unawaited(_enqueuePersistence(() => widget.saveService.save(captured))); // 非同期save
}
```

**重要事実: 月次決算（closeX）自体が月transitionそのもの。** `PublicDemoAggregate.closeApril`は内部で`PublicDemoMonthlyClose.closeApril(...)`→`PublicDemoState.advanceToMay(...)`を呼び、返り値の`state.month`は既に5になっている。closeMay/closeJune/closeJuly/closeOrdinaryMonthも同型（`advanceToJune`/`advanceToJuly`/`advanceToAugust`/`advanceToNextOrdinaryMonth`/`completeFiscalYear`）。

→ **「monthly close → Management Report → 次月」という3段階UXは、現在は「monthly close(=月transition) → (Reportなし) → 次月画面」の2段階しか存在しない。** Reportを挿入する場合、挿入点は`_commitAggregate(...)`の直後（`setState`は既に走っているため画面は既に次月表示に切り替わっているが、`_game.state.latestMonthlyCashFlow`は「直前に閉じた月」の確定結果を正しく保持している——`recordMonthlyCashFlow`は閉じる対象の月が実際に閉じられた場合のみ書き込まれる。§7で詳述）。

---

## 4. Pre-close / Post-close state map

| 概念 | 実体 | 備考 |
|---|---|---|
| pre-close state | `_commitAggregate`呼び出し前の`_game`（画面が保持するフィールド、まだ`setState`されていない） | UI側では明示的な「pre-close snapshot」は保存されない。close呼び出しの引数（`_game.closeApril(...)`のレシーバ）としてのみ一瞬存在する |
| post-close state | `_commitAggregate`後の`_game`（`setState`済み、`widget.saveService.save`へ非同期queue済み） | `state.month`は既に次月。`state.latestMonthlyCashFlow`は閉じた月の確定結果 |
| 閉じた月の確定結果 | `next.state.latestMonthlyCashFlow`（`PublicDemoMonthlyCashFlow`、`closedMonth`と同じ`month`値を持つ） | close対象月が実際にclose可能だった場合のみ上書きされる。`isCloseBlocked`等でno-opの場合は**前回の値がそのまま残る**（古い月のデータを新しい月のものと誤読しないよう、Report側は`latestMonthlyCashFlow.month == 直前に閉じたはずの月`を必ず照合すること — §12） |

`PublicDemoAggregate`自身は`PublicDemoMonthlyCloseResult`（`cashBefore`/`cashAfter`/`cashMovement`/`closedMonth`/`status`を持つ、L389-406）を **呼び出し元へ返していない**（`.state`のみ取り出して返す、L1224/L1297/L1337/L1385/L1414）。すなわちAggregate層で`cashBefore`は失われるが、**`PublicDemoMonthlyCashFlow.openingCash`が同じ値を別ルートで保持しているため実害はない**（§8）。

---

## 5. Finance authority map

### 5.1 既に存在する単一authority

`PublicDemoState.latestMonthlyCashFlow`（`public_demo_state.dart` L294, `recordMonthlyCashFlow`はL710）が持つ`PublicDemoMonthlyCashFlow`（`public_demo_monthly_cash_flow.dart`）:

| フィールド | 意味 | Reportでの用途候補 |
|---|---|---|
| `month` | 閉じた月 | 表示対象月の照合キー |
| `openingCash` | 当月開始時点の現金 | 現金Before |
| `closingCash` | 当月終了時点の現金 | 現金After |
| `cashReceived` | 前月売掛からの入金 | 収入内訳 |
| `revenue` | 当月新規認識売上 | 【今月の収支】売上 |
| `receivables` | 翌月回収予定の売掛残高 | 参考表示 |
| `salaryPaid` | 給与支出 | 【今月の収支】給与 |
| `fixedCostsPaid` | 固定費（家賃等） | その他支出の一部 |
| `bonusPaid` | 夏季賞与（7月のみ非0） | その他支出の一部 |
| `trainingCost` | 研修費 | その他支出の一部 |
| `recruitmentCost` | 採用媒体費 | その他支出の一部 |
| `totalOutflow`（getter） | 上記5支出の合計 | その他支出（合算） |
| `netCashMovement`（getter） | `closingCash - openingCash` | 現金増減（=収支の結果） |

契約（クラス doc内に明記）: `openingCash + cashReceived - salaryPaid - fixedCostsPaid - bonusPaid - trainingCost - recruitmentCost == closingCash`

### 5.2 「純損益」は既存authorityに直接値が無い（GAP）

タスクの要求「純損益」（会計上の当月損益）に対応する単一フィールドは存在しない。存在するのは:

- `netCashMovement`（現金の増減、cashベース） — 「純損益」とは意味が異なる（前月売掛の入金と当月新規売上のタイミングがずれるため）
- 会計的な「純損益」相当は `revenue - totalOutflow`（当月認識売上 − 当月支出合計）として **既存フィールドの単純な減算のみ** で導出可能。新しい閾値・判定・ゲームルールを一切含まない純粋な算術であり、既存の`PublicDemoCashStatusPresentation`/`PublicDemoFinanceSummaryModel`と同じ「presentation-layer derived value」パターンに合致する。

**推奨**: UIのDialog内でインラインに`revenue - totalOutflow`を計算するのではなく、`PublicDemoMonthlyCashFlow`と同じ設計会話を踏襲し、`netCashMovement`と並ぶ**もう1つの純粋getter（例: `netIncome => revenue - totalOutflow`）をドメインクラス自身に追加**するのが最も安全（新しいクラスや新しい永続フィールドは不要、既存フィールドの読み取り専用計算プロパティ1行の追加のみ）。これは実装フェーズでの最小変更候補として記録する（本Auditでは変更しない）。

### 5.3 Payroll / その他支出の内訳authority

`salaryPaid`は`PublicDemoMonthlyClose._cashFlow`内で`monthlyExpenses - PublicDemoSalary.otherMonthlyFixedCost`として **既に給与と固定費に分離済み**（`public_demo_monthly_close.dart` L373、FIX1コメント参照）。「その他支出」は`fixedCostsPaid + bonusPaid + trainingCost + recruitmentCost`として安全に1項目へ合算可能（すべて同一`PublicDemoMonthlyCashFlow`インスタンスの既存フィールド）。7月以外は`bonusPaid`が常に0なので、月による表示の出し分け（「賞与」を7月だけ表示等）はUI側の条件分岐のみで対応可能——新しいgameplay authorityは不要。

---

## 6. Recruitment authority map

### 6.1 現状stateから確定的に取得できるもの（delta不要）

- `workflow.applicants.where((a) => a.stage == PublicDemoApplicantStage.juneOrdered)` — 「受注済み・翌月入社予定」の応募者（`may()`ハンドラ自身がこの集合を使って「入社・初参画！」イベントを出している、L1865-1867を参照）
- `workflow.applicants.where((a) => accepted(a))`（`offerAccepted`〜`juneOrdered`の各preEntryステージ集合、L1849-1859で定義済み）— 「内定済み・入社待ち」
- `workflow.joinedApplicants`（`joinAndKeepOnly`/`joinAcceptedForFiscalClose`で管理される既に入社済みの集合）

これらは **「現在のパイプライン状態」であり、時間依存の「今月何名発生したか」という質問には答えない** が、「田中さん → 5月入社予定」のような個別表示には十分（現在`juneOrdered`/`offerAccepted`ステージにいる人物を列挙すればよい）。

### 6.2 「今月の応募N名／面談N名」はGAP（永続フィールドなし）

`PublicDemoApplicant`（`public_demo_recruitment.dart` L80-146）には応募が発生した月を示すフィールドが存在しない。加えて`closeMay`の`joinAndKeepOnly`は非採用の応募者を**丸ごとプルーニング**する（一度きりの創業コホート処理、`public_demo_aggregate.dart` L1268前後のdocコメント参照）が、6月以降の`joinAcceptedForFiscalClose`は**プルーニングせず応募者が累積し続ける**（同ファイルL1421-1432のdoc）。したがって`workflow.applicants.length`のような単純カウントは「今月」ではなく「これまでの累積（6月以降）」を返してしまい、そのまま使うと誤った表示になる。

→ 「応募3名／面談1名／採用決定1名」のような **月内発生件数** を正確に出すには、closeコマンド呼び出し直前（=月が始まってから今この瞬間までの状態）と、前回close直後（=月が始まった時点の状態）の**差分（diff）**が必要。これは新しいgame authorityではなく、**presentation層でのsnapshot比較**で実現できるが、現在そのsnapshotを保持する仕組みが存在しない（§14 Save/Reload戦略で詳述）。

---

## 7. Sales / Order / Assignment authority map

### 7.1 参画/待機のSSOT

`PublicDemoWorkflowState.assignedEngineerIds({required int month})`（`public_demo_workflow_state.dart` L1271）が唯一のSSOT:

- month < 7: `assignedEngineerIdsUnfiltered`（当月のロースター全員）
- month >= 7: `nextOrderStatus == accepted || replacementStage == ordered` のみ

`_validateForPersistence`（`public_demo_aggregate.dart` L274-280）はmonth >= 6で`state.engineersAssigned == assignedIds.length`かつ`state.engineersWaiting == engineerCount - assignedIds.length`を強制しており、**この投影は常に整合している**。Reportの「現在参画中/待機社員」は`workflow.engineers`をこの集合でフィルタするだけで安全に取得可能。UI独自の分類は不要（既存の`_officeStageStatusFor`/Employee UI Phase 1の`_currentEmployeeStatusLabel`と同じ読み方を踏襲すればよい）。

### 7.2 Order → Assignment（PR #228, Issue #227 fix）のFresh確認

`PublicDemoAggregate.closeApril()`（L1220-1231）が`PublicDemoWorkflowState.assignOrderedForMay()`を**April close内で直接呼ぶ**（PR #228 by Issue #227の修正）。それ以前は`closeMay()`内でしか呼ばれておらず、4月受注が5月中ずっと未反映（Assignmentが存在しない）というP1回帰があった。現在のmainではApril close時点で真正受注（`stage == ordered`）のエンジニアは**Aprilを閉じた瞬間から**`PublicDemoAssignment`を持つ。`closeMay()`も同じ`assignOrderedForMay()`を再度呼ぶが、そちらは**冪等なupsert**（既存エントリの`nextOrderStatus`/`replacementStage`等を保持）に変更済みなので、April→May間で2回呼ばれても情報が失われない設計になっている。

→ Reportで「佐藤さん 受注 → 5月参画」を表示する場合に読むべきauthority: **`workflow.assignments`（`PublicDemoAssignment`のリスト。`engineerId`/`engineerName`/`projectName`を持つ、`public_demo_assignment.dart` L14-）**。ただし§6.2と同じ理由で「今月新たに受注が確定したのは誰か」というdelta情報は`assignments`自体には無い（受注済みassignmentは翌年度末まで同じ行が存続し続ける、design decision "一度案件参画が成立した社員は、第1期終了まで同じ案件へ継続参画する"）。新しいassignment判定ロジックの追加は禁止されているため、**Reportがこのdeltaを正確に出したい場合は、pre-close/post-closeのassignedEngineerId集合差分（純粋なSet演算、Domain変更なし）** で導出するのが唯一の安全な方法（§14で設計制約として記録）。

---

## 8. Cash Before→After取得方法

**`_game.state.latestMonthlyCashFlow.openingCash` / `.closingCash`** を読むだけでよい。`PublicDemoMonthlyClose`の各`closeX`メソッドが、close対象月が実際に閉じられる場合に限り`recordMonthlyCashFlow`でこの値を書き込む（§5.1）。

- **monthly closeの再実行は一切不要**（タスクで明示的に禁止されている設計だが、そもそも既存authorityだけで満たせるため問題にならない）。
- `PublicDemoMonthlyCloseResult.cashBefore`/`cashAfter`はAggregate層で握りつぶされているが、`openingCash`/`closingCash`という同値の情報が`PublicDemoMonthlyCashFlow`側に既に残っているため実質的な情報損失はない。

---

## 9. Management Report snapshot設計案

新規クラス（実装フェーズの提案、本Auditでは作成しない）:

```dart
// 提案: lib/game/public_demo/public_demo_monthly_report_snapshot.dart
// 既存 PublicDemoWorkflowSnapshot（public_demo_workflow_snapshot.dart）と
// 同じ「point-in-time capture」パターンを踏襲する。
class PublicDemoMonthlyReportSnapshot {
  factory PublicDemoMonthlyReportSnapshot.fromAggregate(
    PublicDemoAggregate aggregate,
  ) {
    final flow = aggregate.state.latestMonthlyCashFlow;
    // flow == null の場合（記録前）は Report を出さない no-op 扱い。
    ...
    // すべて既存 state / workflow の読み取りのみ。command は一切呼ばない。
  }
}
```

- 入力は **close済みの`PublicDemoAggregate`1つのみ**（`_commitAggregate`後の`_game`）。
- 新しい永続フィールド・save schema変更は不要（§14）。
- 「今月発生した件数」系（§6.2, §7.2）は、実装時にスコープを絞るか、Phase Bへ回すことを推奨（§19）。

---

## 10. Dialog sequencing（最重要監査項目）

**実call flow（推測なし、コード根拠あり）**:

```
月終了ボタン
  → Month Guard確認（既存、変更なし）
  → 4/5月のみ既存イベントDialog（既存、変更なし）
  → _commitAggregate(_game.closeX(...))   ← monthly close = 月transition が同時に発生
  → [ここに Management Report Dialog を新規挿入]
  → _resetMonthScroll()
  → 通常のHOME再描画（既に次月）
```

**「monthly close内部で既に月transitionしている」が正しい**。「月終了→monthly close→Management Report→次月」という4段階UXは実装できない（月transitionとmonthly closeは分離不可能な1つの操作のため）。正しい3段階は:

**「月終了 = monthly close(月transition込み) → Management Report(直前月の結果を表示) → 次月」**

Reportは「次月が始まったことをまだプレイヤーに提示する前に、閉じた月の結果を見せる」という単純なDialog挿入であり、`_commitAggregate`とその後の`build()`再描画（`_resetMonthScroll()`より後）の間に`await showDialog(...)`を挟むだけで実現できる。既存の`may()`が「入社・初参画！」イベントを`_commitAggregate`の**前**に出しているのとは逆で、Reportは`_commitAggregate`の**後**に出す必要がある（結果を表示するには結果が既にcommitされていなければならないため）。

---

## 11. Bankruptcy sequencing

既存実装（`_bankruptcyTerminalCard()`, L1312-1340、`s.isFinanciallyTerminal`, `s.isCloseBlocked`）の構造:

- Bankruptcy/3月資金不足は**別画面や別Dialogではなく、HOME上に表示される1枚のカード**（`_bankruptcyTerminalCard`）。`s.isFinanciallyTerminal`が真の間、常にHOMEに表示され続ける（L3735 `if (s.isFinanciallyTerminal) _bankruptcyTerminalCard()`）。
- `_monthlyPrimaryAction`（L767-810）は**既に**`s.isCloseBlocked`（`fiscalYearCompleted || isFinanciallyTerminal`）でnullを返し、月終了CTA自体を消す設計になっている。
- 各`closeX`コマンド自身も`isCloseBlocked`をガードしており（`public_demo_aggregate.dart`各所）、万一CTAが誤って表示されても二重実行にはならない（構造的な二重防御）。

**判定: Option A（Management Report → Bankruptcy）が既存architectureと最も整合する。**

理由:
1. Bankruptcyを引き起こす月の`closeX`呼び出し自体が「その月の最終収支」を確定させる（例: 赤字が続いて資金不足→倒産という`financialStatus`遷移は`closeX`の内部、`advanceToX`系メソッドで決まる）。この最終月の数字（売上・支出・現金Before→After）はプレイヤーが「なぜ倒産したか」を理解する材料そのものであり、`docs/DEVELOPMENT_PLAN.md` §3.7「Beginner Mode failure/bankruptcy feedback」の要求（"state-based feedback such as waiting salary burden became too high..."）に直結する。Reportを先に見せることで、直後に表示され続ける`_bankruptcyTerminalCard`の理由づけが強化される。
2. `_commitAggregate`後は既に`s.isFinanciallyTerminal`が真になっているため、Reportの「○月へ進む」的CTAは§10と同じく`s.isCloseBlocked`を再利用するだけで自動的に非表示にできる（新しい判定ロジック不要）。CTAの代わりに「経営状況を確認する」のような単純な閉じるボタンにすればよい。
3. Option C（Bankruptcy時はReportを出さない）は「結果から次を考える」というFirst Fun Yearの主目的（本タスク冒頭の目標）と矛盾する——失敗した月こそ結果の理解が最も重要。
4. Option B（Bankruptcy→Report）は、既存の`_bankruptcyTerminalCard`がHOME常駐カードでありDialogではないため、"先にcardが見え、後からDialogが被さる"UXになり不自然。

**結論**: Report Dialog（terminal-aware, CTAはisCloseBlockedで自動抑制）→ Dialogを閉じる → 既存の`_bankruptcyTerminalCard`が常駐するHOME、という順序を推奨。

年度末（3月、`fiscalYearCompleted`）も同型: Reportで3月の結果を見せた後、CTAは「4月へ進む」ではなく「年間の振り返りを見る（会計タブ→`PublicDemoYearEndResultCard`へ遷移）」のような、既存Year-End導線への案内に置き換える。Year-End自体のロジック・表示は一切変更しない（既存の会計タブSection 5をそのまま再利用）。

---

## 12. Double execution prevention

| 操作 | 起こりうるstate mutation | 評価 |
|---|---|---|
| Dialog表示 | なし（`await showDialog`は`_commitAggregate`後に呼ぶだけ、command呼び出しなし） | 安全 |
| Dialog close | なし（読み取り専用データを破棄するだけ） | 安全 |
| CTA（「○月へ進む」） | Dialogを閉じてタブ切替/次アクションへ誘導するのみ。**close系commandを再度呼んではならない**（既に`_commitAggregate`済み） | 設計上の絶対要件として明記が必要 |
| rebuild（`setState`再描画） | `_game`はDialog表示中も不変（画面の`State`フィールドはDialogの外側で保持され続ける） | 安全 |
| reload | §14参照 | 要設計 |

**核心的な安全設計**: Reportは`_commitAggregate`の**後**にのみ開くこと。仮に`_commitAggregate`の**前**にReportを開き、Report内のCTAが誤ってclose commandを呼べるように実装すると、二重決算のリスクが生まれる。本Auditが推奨するのは「Reportは常にpost-commitの`_game`を読むだけの、command呼び出し手段を一切持たないwidget」という設計であり、これにより二重実行は構造的に不可能になる（Reportのコンストラクタに`onCommit`のようなコールバックを一切持たせない）。

---

## 13. Save / Reload strategy

`_commitAggregate`のsave呼び出しは`_enqueuePersistence`で**直列化**されており（`_persistenceTail`によるFIFOチェーン、L357-364）、closeコマンドのcommit直後に必ず永続化がqueueされる。Reportダイアログの表示・close自体はstateを変更しないため、以下のタイミングでreloadしても副作用は発生しない:

| reloadタイミング | 挙動 | 二重実行/スキップリスク |
|---|---|---|
| monthly close直後・Report表示前 | 既にsaveがqueue済み（非同期）。復元後は次月の状態で、Reportは**表示されない**（Reportは画面ローカルのDialog起動フローの一部であり、永続stateには「Report未表示」というフラグが存在しない） | Report skip（後述） |
| Report表示中 | Dialogはread-only。reloadは通常のアプリ再起動を意味し、Dialogごと消える | Report skip |
| Report閉じた直後 | 通常のHOME状態 | なし |
| 次月開始直後 | 通常のHOME状態 | なし |

**起きないことを確認**: Report重複（新close commandを呼ばない設計のため、closeが2回走ることはない）、monthly close再実行（Reportはcommand呼び出し手段を持たない）、月二重進行、cash二重変動 — いずれも「Reportはcloseの外側の純粋な表示ステップ」という設計により構造的に排除される。

**起きうること（Known Limitation）: Report skip（永続化なし）。** `latestMonthlyCashFlow`は**永続化される**（`PublicDemoState.toJson`/`fromJson`に含まれる、L962/L1033-1035）ため、reloadしても「直前に閉じた月の数字」自体は失われない。しかし「このReportを既にプレイヤーに見せたか」という状態はどこにも保存されないため、**close直後にreloadした場合、次に画面を開いたときはReportが自動表示されず、そのまま次月のHOMEになる**（＝Reportが「スキップされた」状態になるが、二重表示や二重計算にはならない——単に一度だけ見せるはずだった画面を見逃すだけ）。

**Save schema変更なしで安全に実装できるか**: **YES、ただしReport skipの可能性を許容する前提で。** Report表示要否を保存しない設計は、①誤ってReportが複数回出る、②誤って古いReportが出る、のどちらのリスクも生まないため、First Fun Yearの完走性（進行不能・二重処理なし）を損なわない。一方で「必ず1回は見せたい」という体験保証をしたい場合は、`latestMonthlyCashFlowAcknowledged: bool`のようなフィールド追加が必要になるが、**本Auditではこの変更を推奨しない**理由:
- 既存のセーブ整合性チェック（`PublicDemoSaveCodec`の資金整合チェック、`_validateForPersistence`）に新しいフィールドを追加すると、そのチェックの拡張・後方互換のfromJsonデフォルト・関連testの追加が必要になり、Phase分割の理由になるほどのスコープ増になる。
- Reportは「結果を見せる」ことが目的であり、「見た/見ていない」を追跡するゲーム上のconsequenceは無い（見逃しても次月以降のプレイに支障はない——現金・給与・受注等の実際の数字はどのタブでも常時参照可能）。

**結論**: 「なぜ必要か」の記録として、本節を将来の拡張候補として残す。今回のPhaseでは schema 変更なしで進める。

### 6.2 / 7.2の月内delta（応募数・受注数等）についての補足

§6.2, §7.2で述べた「今月の新規件数」を正確に出したい場合、月またぎで比較するsnapshotが必要になる。これは画面の`State`が保持する**非永続の一時フィールド**（例: `PublicDemoAggregate? _monthStartSnapshot`、直前のcloseコミット時に更新するだけ）で実現可能であり、これも**save schema変更を必要としない**。ただし非永続であるため、**月の途中でブラウザをreloadすると、そのsnapshotは失われる**——結果として、その月のReportで「今月の応募」的なdelta表示だけが取得不能になる(グレースフルに「非表示」にするのが安全)。累積ではなく「現在のパイプライン状態」（§6.1, §7.1のような値）は永続stateから常に復元できるため影響を受けない。

---

## 14. Implementation分割判断（Fresh Audit結論）

**1 PR / 2〜4時間には収まらない。Phase A / Phase Bへの分割を推奨。**

### Phase A — Result Snapshot / authority adapter（目安 1.5〜2.5h）

- `PublicDemoMonthlyReportSnapshot`（または同等の純粋データクラス）の追加。既存`latestMonthlyCashFlow`/`assignedEngineerIds`/`_recommendedActionCandidates`相当のロジックを読むだけの新規ファイル。
- §5.2の`netIncome`ライクなgetter追加（`PublicDemoMonthlyCashFlow`への1行追加、または別のpresentation-layer derived-value class）。
- §6.1/§7.1の「現在パイプライン状態」（delta不要な項目）のみをスコープに含める。
- focused domain testの追加。

### Phase B — Management Report UI（目安 2〜3h）

- Dialog widget（`PublicDemoMonthlyReportDialog`）の追加、Phase Aのsnapshotを読んで表示。
- `april()`/`may()`/`june()`/`july()`/`closeOrdinaryMonth()`各ハンドラへの`_commitAggregate`後の呼び出し追加（既存メソッドへの最小差分）。
- Bankruptcy/Year-End分岐のCTA切り替え（`s.isCloseBlocked`再利用）。
- 360x800/390x844 widget test、reload/skip test。

**不要な追加Phaseは作らない**: §6.2/§7.2の「月内delta」表示は、Phase Aでは**スコープ外**とし、現在のパイプライン状態（誰が待機中/参画中/入社予定か）のみを表示する設計に絞れば、追加のsnapshot機構（§13末尾の非永続`_monthStartSnapshot`）も不要になり、Phase A+Bの2分割で完結できる。delta表示（「今月何名応募したか」)はPhase C相当として別途起票するか、Phase Bのオプション項目として持ち越す判断を推奨（本Auditの範囲では判定のみ、着手しない）。

---

## 15. Mobile UI recommendation

想定viewport 360x800 / 390x844。既存Public Demoの他のDialog群（`PublicDemoEventDialog`, `PublicDemoSummerBonusDialog`, `PublicDemoRaiseDialog`, `PublicDemoInterviewResultDialog`等）はいずれも`showDialog`ベースの**中央モーダル**として実装されている（画面いっぱいのbottom sheetではない）。一方でReportが要求する情報量（収支・採用・営業/参画の3セクション＋ひよりコメント）は既存イベントDialogより明らかに多い。

**推奨: scrollable modal Dialog（1画面Dialog + 内部scroll）。** 理由:
- HOMEの「1画面要件」（HOME Freeze）はHOME本体のレイアウトに対するルールであり、月末のResult Dialogには別問題として適用しない、という本タスクの前提と整合する。
- 既存Dialog群と同じ`showDialog`パターンを踏襲することで、`PublicDemoProjectInterviewDialog`等が既に確立している「二重起動防止（`_xxxLaunchInProgress`フラグ）」や`barrierDismissible: false`のような既存の安全パターンをそのまま再利用できる。
- BottomSheetやstep形式（ウィザード）は、既存Public DemoのDialog体系に前例がなく、新しいUIパラダイムの追加になり複雑化する。step形式は特に「途中でバックグラウンドタップ/reloadした場合にどのstepだったか」という新しい状態管理が必要になり、§12/§13の「read-only・非永続」という安全設計と相性が悪い。
- 1画面scrollable modalなら、セクションが多い月（複数採用・複数受注）でも「情報を削りすぎない」要求（§16）を満たしたまま、`SingleChildScrollView`一つで実装できる。

---

## 16. 長い/複数データへの戦略

固定人数を前提にしないため、以下のsummary方式を推奨（既存の`_salesOverviewSection`が既に同種のsummary表示——応募者数・案件数・うち検討中件数——を行っており、同じパターンの踏襲で実装可能）:

- 受注: 「受注 2件」+ 代表1〜2件（名前）+ 残りは「他N件」
- 採用: 「採用決定 N名」+ 代表1〜2件 + 「他N名」
- 長い社員名: 既存のEmployee/Sales tabで使われている`Flexible`/`FittedBox(scaleDown)`パターン（Accounting UI Phase 1で発見・修正済みの横overflow対策、§DEVELOPMENT-PRIORITY 2026-09-07エントリ参照）を流用する。

---

## 17. Focused Test Matrix

既存test helper（`test/ui/public_demo/public_demo_tab_test_helpers.dart`、`test/game/public_demo/test_support/*`）を再利用可能と判断（すべてaggregate/workflow構築のための既存ビルダーが揃っている）。

| # | テスト観点 | 既存の類似/再利用可能テスト |
|---|---|---|
| 1 | April→May Report表示・数値一致 | `public_demo_monthly_close_test.dart`, `public_demo_01_single_month_advance_cta_test.dart` |
| 2 | 後続月（June〜March）Report | `public_demo_monthly_close_ordinary_month_test.dart` |
| 3 | Revenue表示一致 | `public_demo_monthly_close_revenue_test.dart` |
| 4 | Payroll表示一致 | `public_demo_monthly_cash_flow_test.dart` |
| 5 | Expenses（その他支出合算）表示一致 | `public_demo_monthly_cash_flow_card_test.dart` |
| 6 | Net（導出値）表示一致 | 新規（`netIncome`相当のgetterを追加した場合） |
| 7 | Cash Before→After一致 | `public_demo_monthly_cash_flow_test.dart` |
| 8 | 採用→翌月入社の個別表示 | `public_demo_01_skill_sheet_flow_test.dart`, `public_demo_post_may_join_lifecycle_test.dart` |
| 9 | 受注→翌月参画の個別表示（PR #228整合） | `public_demo_01_assignment_carryforward_test.dart` |
| 10 | 待機社員の分類 | `public_demo_active_project_visibility_test.dart` |
| 11 | 複数社員/複数受注のsummary表示 | 新規（`public_demo_tab_test_helpers.dart`の複数エンジニアbuilder再利用） |
| 12 | 長い社員名でのoverflowなし | 既存Employee/Sales UI Phase 1 testの360/390パターン踏襲 |
| 13 | Dialogによるstate mutationなし | 新規（`identical(before, after)`アサーション） |
| 14 | monthly close二重実行なし | 新規（CTA連打シミュレーション、既存`public_demo_01_project_interview_launch_guard_test.dart`の二重起動防止パターン踏襲） |
| 15 | reload時の挙動（Report skip） | `public_demo_01_persistence_test.dart` |
| 16 | Report duplicate防止 | 新規 |
| 17 | Report skip許容確認 | 新規 |
| 18 | Bankruptcy時のReport→terminal card遷移 | `public_demo_01_bankruptcy_ux_test.dart` |
| 19 | terminal stateでCTA非表示 | `public_demo_01_completion_lock_ui_test.dart`, `public_demo_fiscal_year_completion_lock_test.dart` |
| 20 | Year-End（3月）との整合 | `public_demo_01_year_end_result_test.dart`, `public_demo_year_end_display_data_test.dart` |
| 21 | 360x800 / 390x844 | 既存Visual Complete系test群のviewport patternを踏襲 |

---

## 18. Package B（Issue #231）との予想競合

- Issue #231 Scopeは「Out of Scope」に **明示的にMonthly Management Reportを除外**しており、Package B側の変更はEmployee/SkillSheet表示・初回4月導線に限定される（Issue本文確認済み）。
- ただし両者とも巨大な単一ファイル`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`（5,369行）を編集対象とする。Management Report実装が触る箇所は`april()`/`may()`/`june()`/`july()`/`closeOrdinaryMonth()`（月終了ハンドラ群、L1686〜L2200付近）であり、Package Bが触るであろう箇所（`_buildEmployeesTab`/`_employee*Section`/SkillSheet関連メソッド群、HOME 4月導線コピー）とは**行範囲が離れている**ため、テキストレベルの直接衝突は低いと判定する。
- **予想される競合ファイル**: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`自体（同一ファイルへの並行編集は、diffの近接度次第でgit mergeの自動解決対象になる可能性はあるが、確実ではない）。
- **推奨**: タスク記載の通り、Package B（Issue #231）のmerge後に最新`origin/main`から新branchを切ることでほぼ競合を回避できる。現時点でPackage Bの未merge変更を前提にした設計判断は行っていない。

---

## 19. Implementation changed-files予測

Phase A:
- 新規: `lib/game/public_demo/public_demo_monthly_report_snapshot.dart`（または同等名）
- 変更: `lib/game/public_demo/public_demo_monthly_cash_flow.dart`（`netIncome`相当のgetter追加、1行程度）
- 新規: `test/game/public_demo/public_demo_monthly_report_snapshot_test.dart`

Phase B:
- 新規: `lib/ui/public_demo/public_demo_monthly_report_dialog.dart`
- 変更: `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`（`april()`/`may()`/`june()`/`july()`/`closeOrdinaryMonth()`への呼び出し追加、5箇所程度の局所差分）
- 新規: `test/ui/public_demo/public_demo_monthly_report_dialog_test.dart`

いずれもEmployee/SkillSheet関連ファイル（`public_demo_sales.dart`, Skill Sheet系widget等）には触れない設計。

---

## 20. Implementation estimate

| Phase | 目安（AI処理時間、CI待ち除く） |
|---|---|
| Phase A（Result Snapshot / authority adapter） | 1.5〜2.5h |
| Phase B（Management Report UI） | 2〜3h |
| 合計 | 3.5〜5.5h（`SES_DEVELOPMENT-PRIORITY_2026-09-02.md`のsizingルール「3〜5h: 原則2タスクへ分割」に整合） |

---

## 21. Blockers / Known Limitations

1. **「今月の応募/面談/採用決定N名」のような月内新規件数は、現在の永続authorityから直接導出できない**（§6.2）。応募発生月を示すフィールドがなく、応募者プールは6月以降プルーニングされず累積するため。Phase Aでは「現在のパイプライン状態」表示に絞ることで回避。
2. **「今月何名が新規受注したか」も同様にdeltaが必要**（§7.2）。受注済みAssignmentは年度末まで同じ行が存続するため、単純な現状読み取りでは「今月の新規」を特定できない。
3. **「純損益」フィールドは既存authorityに存在しない**（§5.2）。`revenue - totalOutflow`の単純算術で導出可能だが、Domainクラスへの1行追加（`netIncome`相当のgetter）を推奨——本Auditでは未実施。
4. **Report「見た/見ていない」は永続化されない設計を推奨**（§13）。close直後のreloadでReportが1回だけスキップされうるが、二重表示・二重計算のリスクは生まない。必要性が生じた場合はsave schema拡張が要るが、本Auditでは非推奨と判定。
5. **DEVELOPMENT_PLAN.md（Phase 3 "Beginner Mode"）と実際に稼働しているPublic Demo（`lib/game/public_demo/`, `lib/ui/public_demo/`）は別系統**である点に注意（`DEVELOPMENT_PLAN.md`の`BeginnerModeEngine`/`lib/game/engine/`は現行のPublic Demo導線とは異なるレガシー/並行ラインと見られる）。本Auditは`SES_DEVELOPMENT-PRIORITY_2026-09-02.md`が指す実際の実行系列（`lib/game/public_demo/`, `lib/ui/public_demo/`）のみを対象にした。

---

## 22. Recommended next action

1. 本Result Reportをレビューし、Phase A / Phase Bの2分割方針を承認する。
2. Issue #231（Package B）のmerge・origin/main反映を待つ（ファイル競合最小化のため）。
3. Package B merge後、最新origin/mainから新branchを切り、Phase A（Result Snapshot / authority adapter）から着手する。
4. §5.2の`netIncome`相当getter追加は、Phase A着手時に実装Issueへ明記し、既存`PublicDemoMonthlyCashFlow`のtoJson/fromJsonとの整合（新規永続フィールドではなく計算専用getterであることを保つ）を確認しながら追加する。
5. §6.2/§7.2の月内delta表示はPhase Bのスコープ外として明示的に除外するか、着手前にAskUserQuestion等で製品判断者（ユーザー）に必要性を確認する。

---

_Generated by [Claude Code](https://claude.ai/code)_
