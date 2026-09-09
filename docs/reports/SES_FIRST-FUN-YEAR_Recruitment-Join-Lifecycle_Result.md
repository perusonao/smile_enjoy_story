# SES FIRST-FUN-YEAR: 5月以降採用者の Recruitment → Join → Employee Authority 接続 Result

Issue: #221 (perusonao/smile_enjoy_story)
Branch: `claude/issue-221-recruitment-flow-5lv0vv`

## BASE / HEAD SHA

- BASE (`origin/main` at task start, PR #220 merge済み): `7b9d18eeacce5c7840d8de3e9f09e71ec2b92b35`
- HEAD (this fix, pushed): `2bd503b6b522cd8f4e3f0379464482f54e1423dd`

このブランチは開始時点で `origin/main` から逸脱していない古い1コミット (`f4ca78f`, リポジトリのroot commit) しか持っておらず、実質的に未着手だったため、`origin/main` から作り直して開発した（未マージの独自コミットは無かったため、履歴の欠落はない）。

## Fresh Audit: lifecycle reachability 表

`求人掲載 → 応募 → 採用面談 → 採用判断 → 入社予定/入社月 → 正式join → 在籍roster → SkillSheet → 営業対象 → Matching → 上位会社面談 → 客先面談 → 受注 → 参画 → 給与/売上`

| 段階 | production実装 | UI CTA | guard/month条件 | state transition | SaveCodec永続化 | 月跨ぎ後 |
|---|---|---|---|---|---|---|
| 求人掲載/応募 | `PublicDemoAggregate.recruit` | 求人媒体カード | `PublicDemoState.canUseRecruitmentMediaInMonth` = 月4〜8のみ、月内1回 | `withGeneratedApplicants` | ✅ | ✅ |
| 採用面談 | `completeInterview`→`useSalesSlotForInterview` | 「面接する」 | sales slot消費、月不問 | `interviewRecord`付与 | ✅ | ✅ |
| 採用判断（オファー） | `acceptOffer`→`PublicDemoOfferAcceptance.accept` | オファーダイアログ | `hasBeenInterviewed`必須、月不問 | `bindingOffer`（`fiscalCloseId=当時のstate.month`）付与、stage→`offerAccepted`/`offerDeclined` | ✅ | ✅ |
| **正式join（Root Cause箇所）** | **Fix前: `PublicDemoAggregate.closeMay`からのみ`workflow.joinAndKeepOnly`/`withJoinedEngineers`を呼ぶ。`closeJune`/`closeJuly`/`closeOrdinaryMonth`は一切呼ばない。** | 月次close CTA（明示的な「join」ボタンは無く、月次closeに内包） | `PublicDemoJoinTransaction.join`は`offer.fiscalCloseId == currentFiscalCloseId`（=同じ月内でoffer→close完結）を要求 | Fix前: 5月accept以外は`hasJoined`が永久にfalseのまま | ✅（`hasJoined=false`のまま） | ❌ 5月以外の採用は月をまたいでも一切join処理されない |
| 在籍roster (`joinedApplicantIds`/`engineerCount`) | Fix前: `advanceToJune`のみが更新 | — | — | Fix前: 6月以降の新規joinは反映されない | ✅ | ❌ |
| SkillSheet/営業対象 (`workflow.engineers`) | `withJoinedEngineers`で追加 | 社員タブ/営業タブ | `workflow.engineers`メンバーであること | — | ✅ | Fix前: 追加自体がされないので❌ |
| Matching→上位会社面談→客先面談→受注 | `startSkillSheetReview`〜`recordOrder`（#219/#220で汎用パイプライン全体がMatching接続済み・月非依存） | 社員タブボタン群 | 各stage precondition | stage遷移 | ✅ | ✅（`workflow.engineers`に居れば） |
| 参画（アサイン） | `PublicDemoAggregate.recoverAssignment`（RECOVERY-LOOP-1、月7〜14、事前assignment不要） | 「案件へ復帰」 | `stage==ordered && hasGenuineInterviewRecord && isReadyForFieldSales` | `PublicDemoAssignment`追加 | ✅ | ✅ |
| 給与/売上 | `PublicDemoSalary.currentMonthlySalaryFor`（`applicant.hasJoined`が唯一のゲート） | 会計タブ | `hasJoined`必須 | — | ✅ | Fix前: `hasJoined`がfalseのままなので永久に給与対象外 |

**4月開始の通常プレイで5月以降採用者が実際に通れるか（Fix前）**: **通れない**。5月に採用された者は`closeMay`により正しくjoinするが、6月・7月・8月（`canUseRecruitmentMediaInMonth`が許す最後の月）に採用された者は、面接・オファー承諾・入社前パイプライン（`juneOrdered`まで）を完全に正しく通過しても、`hasJoined`が永久に`false`のまま——在籍社員一覧・SkillSheet・営業対象・給与のいずれにも一切現れない。採用コスト（媒体費用・sales slot）だけが消費され続ける、production上の構造的な行き止まりだった。

この症状は、issue #219 の Fresh Audit 時点で既に「Also inspected」として確認・記録済みだった（`docs/reports/SES_FIRST-FUN-YEAR_Project-Interview-Reachability_Result.md`）。さらに `test/game/public_demo/public_demo_seeded_balance_regression_test.dart` に `post-May recruitment structural dead end (CONFIRMED FINDING)` として、実際にこのシナリオを走らせて `hasJoined == false` のまま固まることを確認する regression test が既に存在していた（Fix前は red ではなく green ——「バグを固定するテスト」として存在）。

## Root Cause

`PublicDemoAggregate.closeMay` だけが、5月クローズという単発イベントの一部として以下を実行していた:

1. `workflow.joinAndKeepOnly(...)` — 承諾済みapplicantを`PublicDemoJoinTransaction`経由でjoinさせる
2. `workflow.withJoinedEngineers(...)` — joinしたapplicantを`workflow.engineers`（SkillSheet/営業タブの一次データソース）に追加
3. `state.engineerRuntimes`へのruntime追加（給与/成長の基礎データ）
4. `PublicDemoState.advanceToJune`内の`engineerCount`/`joinedApplicantIds`更新（在籍roster・給与ゲートの一次データソース）

`closeJune`/`closeJuly`/`closeOrdinaryMonth`（8〜3月の共通close）はいずれも、上記4つのうちどれも呼んでいなかった。一方 `PublicDemoAggregate.recruit`/`completeInterview`/`acceptOffer` はいずれも月4〜8全体で production的に呼び出し可能（`canUseRecruitmentMediaInMonth`が許す範囲）であり、UIの求人媒体カードも6〜8月にわたって表示され続ける。つまり「5月以降の採用そのものは正しく動く入口」と「5月にしか無いjoin処理という出口」の非対称が根本原因——採用導線は月4〜8いっぱいまで開いているのに、それを本当に社員へ変換する仕組みは5月にしか実装されていなかった。

「fake employee」でも「botだけの回避」でもなく、**5月以外の月次closeに join処理そのものが欠落している**という、配線漏れ型のproduction authority欠落。

## Fix内容

最小の一般化: 5月の`closeMay`が既に行っている「join処理」を、既存の正当なauthorityをそのまま再利用する形で、`closeJune`/`closeJuly`/`closeOrdinaryMonth`にも追加した。新しい採用ルールや経済式は一切追加していない。

### 変更ファイル

1. **`lib/game/public_demo/public_demo_workflow_state.dart`**
   - 新規 `PublicDemoWorkflowState.joinAcceptedForFiscalClose({week, currentFiscalCloseId})` を追加。
   - 既存の`joinAndKeepOnly`と同じ`PublicDemoJoinTransaction`をそのまま使うが、**5月特有の「未承諾applicantを一覧から削除する」処理はしない**（6月以降も採用媒体が使え、面接中/検討中のapplicantが同時に存在し続けるため、5月の一回限りの創業コホート打ち切りロジックをそのまま流用してはいけない）。
   - `PublicDemoJoinTransaction.join`自体が「既にjoin済み」「offer無し」「declined」「fiscalClose不一致」のいずれでも無変更で返す既存の安全設計を持つため、この関数は**何度呼んでも安全**（毎月の月次closeで無条件に呼べる）。

2. **`lib/game/public_demo/public_demo_state.dart`**
   - 新規 `PublicDemoState.recordNewJoins(Iterable<PublicDemoApplicant>)` を追加。
   - `advanceToJune`が内部で行っている「`joinedApplicantIds`にまだ無い、かつ`hasJoined==true`のapplicantだけを`engineerCount`/`joinedApplicantIds`/`engineersWaiting`に追加する」ロジックを、`advanceToJune`以外の場所（`closeJune`/`closeJuly`/`closeOrdinaryMonth`）からも呼べる形で一般化。`joinedApplicantIds`は既存どおり`_copyWith`（このファイル内private）経由でのみ書ける——外部からの任意上書きは引き続き不可能。

3. **`lib/game/public_demo/public_demo_aggregate.dart`**
   - 新規private `_joinAcceptedApplicants()` — 上記2つの新メソッドを組み合わせ、「今月のfiscalCloseに対して正当なofferを持つapplicantをjoinさせ、新規joinだけを`workflow.engineers`に追加する」処理を一箇所にまとめた。
   - 新規private `_withNewEngineerRuntimes(state, newlyJoined)` — `closeMay`が既に行っている`PublicDemoEngineerRuntime.fromApplicant`の追加をヘルパー化。
   - `closeJune`/`closeJuly`/`closeOrdinaryMonth`をそれぞれ、既存の月次close手順（Growth→Finance close）の**前**にjoin処理を挟むよう変更。`closeJuly`は既存の夏季賞与atomicity（`preview.isEligible`不成立なら何も変更しない）を維持したまま、その判定の**後**でjoinを行う（賞与不成立で月が閉じられないなら、今月の入社処理も一緒に取り消される——既存のatomic close契約を壊さない）。
   - `closeMay`自体は無変更（5月コホートの挙動・既存テストへの影響ゼロ）。

### 設計上のポイント（Fix policy遵守）

- **即日入社の禁止**: offerを承諾した月の月次closeで初めてjoinする——5月の既存挙動と完全に同じタイミングモデル。closeJuly/closeOrdinaryMonthのmonthlyExpenses計算はwidget側で常に「close前のjoinedApplicants」を使っているため（`_julyMonthlyExpenses`/`_ordinaryMonthlyExpenses`は`workflow.joinedApplicants`＝`hasJoined==true`のみを対象）、**入社した当月分の給与は請求されない**——5月hireが6月から初めて給与対象になるのと同じ規則が自動的に成立する。
- **一度だけの追加**: `_joinAcceptedApplicants`は`state.joinedApplicantIds`に無いidだけを`newlyJoined`として扱うため、同じapplicantが複数月にわたって（あるいは同月にリトライされて）処理されても`engineerCount`/`workflow.engineers`/`engineerRuntimes`のいずれにも重複しない。
- **既存Finance/SkillSheet/Sales/Matching authorityへの自然な接続**: 新規joinは`workflow.engineers`に追加されるため、UIの社員タブ・SkillSheet・Sales tabは**既存のフィルタをそのまま使うだけで**新規社員を表示する（`workflow.engineers`が一次データソースであるコード箇所を変更していない）。#219/#220で接続済みのMatching→上位会社面談→客先面談パイプラインも`workflow.engineers`メンバーである限り月非依存で動作するため、6月以降のjoinはそのまま同じ経路で客先面談・受注・RECOVERY-LOOP-1経由の参画（アサイン）まで到達する。
- **禁止事項の遵守**: fake employee/hard-coded successは追加していない。Finance計算式・Matchingの適合度式・Balanceパラメータは一切変更していない。HOME redesignや無関係なリファクタは行っていない。

## P1 Fix（PR #222 レビュー指摘、Merge Gate対応）

PR #222オープン後、リポジトリオーナーによるMerge Gateコメントで1件のP1が指摘された:

> 5月以降の応募者が本物の入社前 `juneOrdered`（事前案件確保）状態に到達してからfiscal closeを迎える場合、later-month join pathはその既に勝ち取った受注を、joinした社員の正式なassignment/headcount projectionへ引き継がなければならない——待機social engineerとして生成し、プレイヤーにSales/Matching/面談をやり直させてはいけない。

### Root cause（P1）

`assignOrderedForMay`（5月専用のassignmentロスター**全体再構築**メソッド）の中に、`applicant.stage == juneOrdered && applicant.hasJoined`の場合だけ実在するassignmentを作る分岐が既に存在していた。しかし本fix（P1以前の版）が追加した`closeJune`/`closeJuly`/`closeOrdinaryMonth`の新しいjoin処理は、この分岐を一切呼んでいなかった——`workflow.engineers`への追加（`withJoinedEngineers`）だけ行い、既に勝ち取っていた`juneOrdered`のassignmentを作らなかった。結果、5月以降に入社前パイプライン（`beginPreEntrySkillSheet→…→recordJuneOrder`）を完走し、既に受注を確定していた応募者が、参画済みではなく**ただの待機social engineer**としてjoinしてしまい、SkillSheet確認・営業開始・案件紹介・上位会社面談・客先面談・受注を最初からやり直させられる状態になっていた。

### Fix内容（P1）

1. **`lib/game/public_demo/public_demo_workflow_state.dart`**
   - 新規 `PublicDemoWorkflowState.appendPreEntryOrderAssignments(Iterable<PublicDemoApplicant> newlyJoined)` を追加。
   - `assignOrderedForMay`の`juneOrdered`分岐と**全く同じ**既存テンプレート（`projectName: '新規開発支援', deliveryPressure: 50, budgetHealth: 70, humanity: 70`）をそのまま再利用——新しい経済式やhard-coded successを新規追加したわけではない。
   - `recoverLateYearAssignment`と同じAPPEND/UPSERT契約: `assignments`に既に存在する他applicant/engineerのエントリは一切変更しない（`assignOrderedForMay`のような全体再構築ではない）。既にassignment済みのapplicantIdはスキップ（idempotent）。

2. **`lib/game/public_demo/public_demo_state.dart`**
   - `recordNewJoins`に`joinedWithOrders`（デフォルト0）パラメータを追加——`advanceToJune`の`hiredWithOrders`と全く同じパターンで、新規joinのうち何人が既にassigned状態で開始するかを`engineersAssigned`/`engineersWaiting`に反映する。

3. **`lib/game/public_demo/public_demo_aggregate.dart`**
   - `_joinAcceptedApplicants()`が新規joinの中から`stage==juneOrdered`の人数を数え（`newlyJoinedWithOrders`）、`appendPreEntryOrderAssignments`を呼んでassignmentも一緒に追加するよう拡張。
   - `closeJune`/`closeJuly`/`closeOrdinaryMonth`は`recordNewJoins`にこの数を渡すよう更新。
   - `closeJune`のみ追加対応が必要だった: `PublicDemoState.advanceToJune`系と異なり`advanceToJuly`は`engineersAssigned`を**caller供給の`assignedInJuly`で無条件に上書き**する（`recordNewJoins`の加算結果を後から潰してしまう）ため、`assignedInJuly: assignedInJuly + joined.newlyJoinedWithOrders`として、新規juneOrdered入社分を明示的に加算してから渡すよう修正。`closeJuly`/`closeOrdinaryMonth`の下流（`PublicDemoSummerBonusPayment.closeJuly`/`advanceToNextOrdinaryMonth`）は`engineersAssigned`/`engineersWaiting`を一切上書きしないため、`recordNewJoins`自身の加算がそのまま生き残る。

### Acceptance確認

- 既に勝ち取った本物のpre-entry order（`juneOrdered`）のみ引き継ぐ——fake/hard-coded assignmentの新規追加なし（既存テンプレート再利用のみ）。
- May挙動は無変更（`closeMay`自体を変更していない、既存772テストが無傷）。
- 6月/7月/8月joinでpre-entry orderあり→joined + assigned exactly once（新規regression testで確認）。
- pre-entry orderなしのjoinは従来通りwaiting（新規regression testで確認、fake assignmentを生成しないことも確認）。
- duplicate/retry/save-reload安全——同一applicantへの重複assignment・重複engineer・重複headcountなし（新規regression testで確認）。
- #218 seeded balance・#220 project interview reachabilityの既存regressionは無傷（後述のフルテスト結果参照）。

## Regression / Tests

### 新規/更新テストファイル

- **`test/game/public_demo/public_demo_seeded_balance_regression_test.dart`**: 既存の `post-May recruitment structural dead end (CONFIRMED FINDING)` テストを `(Issue #221 FIX)` として更新し、同じ再現手順（採用面談→オファー承諾→入社前パイプライン全通過→`juneOrdered`到達）で **今度は実際にjoinし、`workflow.engineers`に現れ、`engineerCount`/`joinedApplicantIds`に反映され、月をまたいだ再クローズでも重複しない**ことを検証するよう反転。
- **`test/game/public_demo/public_demo_post_may_join_lifecycle_test.dart`**（新規）: Issue本文の必須regression項目をすべて個別テストとしてカバー：
  - 5月採用 → 正式join → roster表示（既存挙動の非破壊確認）
  - 6月／7月／8月（`canUseRecruitmentMediaInMonth`が許す最後の月）採用の個別join確認
  - 不採用者（offer未承諾）は複数月closeを経ても一切joinしない
  - 同一applicantの二重join防止（月をまたいだ再close×2でも重複なし）
  - join前は`PublicDemoSalary.currentMonthlySalaryFor`がnull（給与対象外）、join後は`acceptedMonthlySalary`と一致する値を返す（給与対象）
  - save/reload（`toJson`/`fromJson`）がjoin前後どちらの状態でも`hasJoined`/`engineerCount`/`joinedApplicantIds`を正しく往復
  - フルライフサイクル: 6月join→SkillSheet確認→営業開始→Matching案件紹介→上位会社面談→客先面談→受注→RECOVERY-LOOP-1経由の参画（アサイン）→給与/売上（assignedEngineerIds反映）まで、既存productionコマンドのみで到達できることを実証
  - **（P1 Fix追加）** pre-entry order保持 group: 6月/7月joinでpre-entry order（`juneOrdered`）を持つ応募者が、実在するassignmentを伴ってjoinし`engineersAssigned`に反映されること／pre-entry orderを持たない応募者は従来通りwaitingとしてjoinし、fakeなassignmentを一切生成しないこと／同一closeを再実行しても重複assignmentが生まれないことを検証（`walkToPreEntryOrder`ヘルパー使用、`recordPreEntryPartnerInterviewResult`/`recordPreEntryClientInterviewResult`が応募者自身の`salesSkillFit`から決定的にpass/failを導出するため、該当2テストは`salesSkillFit>=65`を確実に引く`runSeed`を明示指定——3回連続実行で決定性を確認済み）。
- **`test/game/public_demo/public_demo_seeded_balance_regression_test.dart`**（P1 Fix追加分）: `post-May recruitment structural dead end (Issue #221 FIX)`テストに、`juneOrdered`到達済み応募者のjoin後assignment存在・`engineersAssigned`反映・再クローズ後の重複なしを追加検証。

### テスト実行結果（本環境にFlutter 3.44.9 / Dart 3.12.2を新規セットアップして実行）

```
flutter analyze
  → No issues found!

flutter test test/game/public_demo/
  → 775 tests, All tests passed!（新規12テスト含む、P1 Fix分3件含む）

flutter test test/ui/public_demo/
  → 522 tests, All tests passed!（既存UIテストに変更なし・regressionゼロ）

flutter test
  → 2082 tests, All tests passed!（フルスイート204ファイル、regressionゼロ、P1 Fix前の測定）

git diff --check
  → 差分なし（trailing whitespace等の問題なし）
```

## Before/After Seeded Balance 再測定

`tool/simulate_public_demo_seeded_balance.dart 300 1000000`（既存Phase 8ツール、seed 1000000〜1000299の300件、`PublicDemoSeededPlaythroughBot`によるproduction-command駆動プレイスルー）を、fix適用前（`git stash`でfix分をどかした状態）・適用後の両方で実行し比較した。

| 指標 | Before | After |
|---|---|---|
| First Fun Year到達率 | 122/300 (40.7%) | 122/300 (40.7%) |
| 倒産率 | 178/300 (59.3%) | 178/300 (59.3%) |
| 3月現金ショート失敗率 | 0/300 (0.0%) | 0/300 (0.0%) |
| 月次現金チェックポイント（4〜15月） | 全月min/p10/median/avg/max完全一致 | 同左 |
| No-orderストリーク分布 | 完全一致 | 同左 |
| 5月hire人数分布 | 完全一致 | 同左 |

**結果: 完全に同一**（全指標が小数点以下まで一致）。`PublicDemoSeededPlaythroughBot`の既存プレイ方針は月4での媒体購入に依存しており、6〜8月の追加採用オファー承諾を積極的には行わないため、このボットのシミュレーション結果には今回のfixによる直接的な影響が現れなかった。Balance式・確率・生成ロジックは一切変更していないため、この一致は期待通り——Issue本文の「Scope boundary / Balance」セクション（経済パラメータ調整は次のBalance Fixへ分離）を満たしている。5月以降の追加採用による実際のBalanceへの影響（倒産率変化等）は、6〜8月に能動的にofferを承諾する新しいボット方針を要する別のBalance Fix候補として次項に記録する。

## Changed Files

- `lib/game/public_demo/public_demo_aggregate.dart`
- `lib/game/public_demo/public_demo_state.dart`
- `lib/game/public_demo/public_demo_workflow_state.dart`
- `test/game/public_demo/public_demo_seeded_balance_regression_test.dart`（既存confirmed-findingテストをfix後の期待値へ更新）
- `test/game/public_demo/public_demo_post_may_join_lifecycle_test.dart`（新規）
- `docs/reports/SES_FIRST-FUN-YEAR_Recruitment-Join-Lifecycle_Result.md`（本レポート）

## Unresolved findings / 次のBalance Fix候補

- `PublicDemoSeededPlaythroughBot`は6〜8月の追加採用（media購入→面接→offer承諾）を能動的に行う方針を持っていない。今回のfixで6〜8月採用のjoin自体は可能になったため、そのようなボット方針を追加したうえでBalanceへの実影響（倒産率・待機期間等の変化）を別途測定するのは価値がある——ただし新しいボット方針の設計自体がこのIssueのスコープ外（経済パラメータ調整・生成ロジック変更は次のBalance Fixへ分離、と本Issue自身が明記）。
- 6月以降にjoinした社員は、5月コホードが使う`preEntry*`パイプライン（入社前SkillSheet/Matching、issue #220の対象）を経由しない——join後に初めて`PublicDemoEngineerSales`としてSales pipelineに入る設計は5月コホートと同じであり、今回のfixで挙動を変えていない。入社前の事前案件確保（`juneOrdered`相当）を6月以降の新規採用にも一般化するかどうかは、別途プロダクト判断が必要な機能追加であり本Issueのスコープ外。

## Actual processing time

Fresh Audit・root cause確定・実装・regression・フルテスト実行・レポート作成まで合計で約90分（Flutter SDKが本環境に未インストールだったための追加セットアップ時間を含む）。

## PR URL

https://github.com/perusonao/smile_enjoy_story/pull/222
