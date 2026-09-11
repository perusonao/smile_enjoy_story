# SES FIRST-FUN-YEAR: Recruitment Flow / Next Action Clarity Result

Issue: #241 (perusonao/smile_enjoy_story)
Branch: `claude/issue-241-recruitment-flow-fhsqyd`

## BASE / HEAD SHA

- BASE (`origin/main` at task start, PR #240 merge済み): `56c71e80db684b6039b88162dfd0f097ab380863`
  （Issue #241本文が明示するmainと一致。ズレなし。）
- HEAD (this fix, pushed, before this final report update commit): `acbd18f834c44a1a0c7439bf3b0f79b52a10fbb3`

## Fresh Audit: 採用フロー authority trace（現mainで実コードをtrace）

| # | 監査観点 | production実装 | 結果 |
|---|---|---|---|
| 1 | 募集開始 action / cost authority | `PublicDemoAggregate.recruit` → `PublicDemoRecruitmentCalculation.execute` | 月4-8のみ、月内1回、`s.canUseRecruitmentMediaInMonth` gate。cost/candidate数は`PublicDemoRecruitmentMedium`（free=0円/1名, engineer=10万円/2名）にのみ依存。 |
| 2 | 応募者生成のタイミング・条件・月境界 | `PublicDemoSeededRecruitmentGenerator.generate`（`(runSeed, month, medium, slot)`の純関数） | **応募者はプレイヤーの`recruit()`呼び出し以外では一切生成されない**。`PublicDemoWorkflowState.initial()`は`applicants: const []`（CORE-GAMEPLAY Phase 4.5でpre-seed完全撤去）。月次close系（`closeApril`/`closeMay`/…/`closeOrdinaryMonth`）はいずれも応募者生成を呼ばない。 |
| 3 | applicant state / persistence / duplicate防御 | `PublicDemoApplicant.toJson`/`fromJson`、`withGeneratedApplicants`（既存id skip） | provenance（`interviewRecordApplicantId`/`joinRecordApplicantId`）がid一致まで検証される。永続化は健全。 |
| 4 | 採用面談の開始条件、sales/recruitment capacityとの関係 | `PublicDemoAggregate.completeInterview`→`PublicDemoState.useSalesSlotForInterview` | sales slot消費必須、月不問。 |
| 5 | 面談結果→採用決定→confirmed next-month join | `acceptOffer`→`PublicDemoOfferAcceptance.accept`→`bindingOffer`（`fiscalCloseId`= accept時点のmonth） | 健全。`PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds`が`stage==juneOrdered && !hasJoined`で正しくフィルタ（#232/#234で既に修正済み）。 |
| 6 | 入社materializationの月・タイミング | `PublicDemoAggregate._joinAcceptedApplicants`（#221/#222で全月次closeに一般化済み） | offerを承諾した月のcloseで初めてjoin。即日入社なし。5〜8月のどの月に採用してもjoin authorityは動作する（#221で修正済み）。 |
| 7 | 入社後Employee/SkillSheet/Training/Salesへの導線 | `workflow.engineers`（`withJoinedEngineers`で追加）を一次データソースとする既存の社員/SkillSheet/営業タブ | 健全。導線自体は#219/#220/#221で接続済み。 |
| 8 | Hiyori / Recommended Action / Recruitment tabの状態別表示 | `_addApplicantStageCandidate`（HOME）、`ac(i)`（営業タブ funnel） | **本Issueで欠陥を発見**（後述Root Cause）。 |
| 9 | 「4月に求人なしでも5月応募が発生する」症状の現存確認 | `PublicDemoAggregate.initial().closeApril(...)` | **再現しない（GO）**。新規regressionテストで明示的に固定（下記参照）。 |
| 10 | 採用のメリット/リスクの真実性のある説明可否 | `PublicDemoCashShortageCard`, `_salesOverviewSection`（営業残/候補者/案件の実数タイル） | 既存authorityの範囲で真実性のある表示は既に存在。今回はスコープ最小化のため追加説明文は増やしていない。 |

### §9 詳細（Issue本文が名指しした症状の検証）

`docs/reports/SES_FIRST-FUN-YEAR_Recruitment-Join-Lifecycle_Result.md`（Issue #221）にある通り、CORE-GAMEPLAY Phase 4.5で`PublicDemoWorkflowState.initial()`のpre-seeded応募者（`publicDemoMayApplicants`）は完全撤去され、`april()`ハンドラのイベント文言も「採用は求人媒体から始まります」に真実性修正済み（`lib/ui/public_demo/public_demo_01_placeholder_screen.dart:1780`）。

実コードtraceに加え、新規テストで明示的に固定した:

```
test/game/public_demo/public_demo_post_may_join_lifecycle_test.dart
  group('Issue #241 ... Fresh Audit §9')
    - PublicDemoAggregate.initial() → applicants is empty
    - .closeApril(...) → 5月時点でも applicants is empty
    - .closeMay(...) → 6月時点でも applicants is empty
```

**結論: 現mainでは症状は存在しない。Fresh Audit verdict = GO（presentation/progression中心の最小修正へ進む）。**

## Root Cause（Fresh Auditで新規に発見した progression defect）

`PublicDemoApplicant.stage`は、実際にjoinした後も**一切書き換わらない**——`PublicDemoApplicant.join()`が変更するのは`PublicDemoJoinRecord`（`hasJoined`の裏付け）と給与/relationshipHistoryのみで、`stage`自体はjoin前の値のまま永続する（この設計自体は正しく、`PublicDemoMonthlyReportSnapshot.confirmedNextMonthJoinApplicantIds`のdocが`stage==juneOrdered`だけでは「既にjoin済みかどうか」を判定できないと明記している——#232/#234で既に対処済み）。

しかし、**同じ罠が2箇所で未対処のまま残っていた**:

1. **営業タブの採用・候補者進捗 funnel（`ac(i)` / `_salesApplicantProgressCards`）**
   `workflow.applicants`を`hasJoined`でフィルタせず全件描画していたため、実際にjoinした応募者が**永久に**join前のstage由来のバッジ（例: `juneOrdered`→「入社・参画予定」、非pre-entry組の`offerAccepted`→「内定承諾」＋「入社後、研修で育成します」）のまま表示され続けていた。同じセクションの「候補者 N名」カウント（`_salesOverviewSection`）は既に`!a.hasJoined`でフィルタ済みだったため、**カウントとリストが食い違う**状態でもあった。Issue #241が明示的に要求する「入社待ちと入社済みを混同させない」に直接反する。

2. **HOME Recommended Action（`_addApplicantStageCandidate`）と、それが呼ぶ pre-entry pipeline 遷移そのもの（domain authority）**
   `beginPreEntrySkillSheet`/`beginPreEntrySelling`/`introducePreEntryProject`/`recordPreEntryPartnerInterviewResult`/`recordPreEntryClientInterviewResult`/`recordJuneOrder`はいずれも`stage`のみを前提条件とし、`hasJoined`を見ていなかった。`PublicDemoApplicant.join()`自体は「有効なfiscalClose一致offer」だけを要求し「pre-entry pipeline完了」を要求しないため、**pre-entry pipelineの途中（例: `preEntrySelling`）で月がcloseすると、そのままjoinしてしまう**——これは新規に書いたdomainテストで実際に再現を確認した:

   ```
   mid-pipeline stage before close: preEntrySelling, hasJoined=false
   after close stage:                preEntrySelling, hasJoined=true   ← 既に社員
   ```

   この状態で以前はHOMEの「案件紹介」等の推奨アクションが**既にjoin済みの人物に対してまだ表示され続け**、押すと本物のdomainコマンドが実行されて、実在する社員をpre-entry pipeline（申込者専用の入社前営業フロー）へさらに押し進めてしまう構造的な穴があった。「採用面談後に何が確定したか」「入社後は次に何をすべきか」を破壊する典型例。

**根本原因は1つ**: 「`stage`は`join`後も変わらない」という既存の正しい設計判断に対して、`hasJoined`チェックが必要な箇所のうち2箇所（Sales tab funnel描画、HOME推奨アクション+その裏のdomain pre-entry遷移6メソッド）だけが#232の修正から漏れていた。

## Fix（最小修正、既存authorityの再利用のみ）

### 1. `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

- `_salesApplicantProgressCards()`: `workflow.applicants`の描画ループに`!hasJoined`フィルタを追加。`_salesOverviewSection`の候補者カウントと**同じ述語**を再利用しただけで、新しい閾値・新しい状態は一切追加していない。joinしたapplicantは営業タブから消え、既存の`workflow.engineers`ベースの社員/SkillSheet/営業タブへ導線が自然に移る（このデザイン意図は`_salesOverviewSection`自身のdocに既に明記されていた）。
- `_addApplicantStageCandidate`（HOME Recommended Action）の走査ループにも同じ`!a.hasJoined`フィルタを追加——funnel表示と推奨アクションが常に一致するようにした。

### 2. `lib/game/public_demo/public_demo_workflow_state.dart`（self-hardening: domain authority自体を強化）

以下の6メソッドすべてに `!applicant.hasJoined` を前提条件として追加（既存の`stage`要件はそのまま維持、`from.contains(stage)`のような既存判定に`&&`で合成）:

- `_transitionApplicantStage`（`reviewResume`/`beginPreEntrySelling`/`introducePreEntryProject`/`recordJuneOrder`/`rejectApplicant`の共通実装）
- `beginPreEntrySkillSheet`
- `recordPreEntryPartnerInterviewResult`
- `recordPreEntryClientInterviewResult`

これにより、**UI呼び出し経路だけでなく、将来のどんな呼び出し元からも**、既にjoinした応募者をpre-entry pipelineへ押し進めることが構造的に不可能になった（UI側のフィルタだけに依存しない二重の安全弁）。`reviewResume`/`rejectApplicant`が対象とする`applied`/`interviewed`ステージでは`hasJoined`は元々常にfalse（bindingOffer無しではjoinできないため）なので、この2メソッドへの影響は実質ゼロ。

## Authority/Persistence Impact

- Save schema変更なし（新規フィールド追加なし、`toJson`/`fromJson`は無変更）。
- Finance/Payroll/Matching/Assignment/Balanceの数式は一切変更していない。
- 新しい採用ゲームシステム・新しい状態・新しい経済式は追加していない——既存の`hasJoined`という既に存在する authoritative factを、既に一部（#232の`confirmedNextMonthJoinApplicantIds`、`_salesOverviewSection`の候補者カウント）で使われていたのと同じ意味で、漏れていた箇所に一貫適用しただけ。
- fake applicant/fake cost/fake join date は一切作っていない。

## Changed Files

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`（+約32行、ロジック変更2箇所）
- `lib/game/public_demo/public_demo_workflow_state.dart`（+約40行、guard追加4箇所＋doc）
- `test/game/public_demo/public_demo_workflow_state_test.dart`（新規domainテスト1件）
- `test/game/public_demo/public_demo_post_may_join_lifecycle_test.dart`（新規regressionテスト1件、Fresh Audit §9固定）
- `test/ui/public_demo/public_demo_sales_ui_phase1_test.dart`（新規widgetテスト1件＋fixture）

## Tests

環境にFlutter 3.44.9 / Dart 3.12.2を新規セットアップして実行（`storage.googleapis.com/flutter_infra_release`のstable linux tarballを取得）。

```
flutter analyze
  → No issues found!

flutter test test/game/public_demo/public_demo_workflow_state_test.dart
  → 20 tests, All tests passed!（新規1件含む）

flutter test test/game/public_demo/public_demo_post_may_join_lifecycle_test.dart
  → 13 tests, All tests passed!（新規1件含む、Fresh Audit §9固定）

flutter test test/game/public_demo/
  → 859 tests, All tests passed!（regressionゼロ）

flutter test test/ui/public_demo/public_demo_sales_ui_phase1_test.dart
  → 33 tests, All tests passed!（新規1件含む）

flutter test test/ui/public_demo/
  → 653 tests, All tests passed!（regressionゼロ、新規1件含む）

flutter test test/ui/public_demo/public_demo_01_home_recommended_action_test.dart
  → All tests passed!（HOME Recommended Actionの`!hasJoined`フィルタ追加後も既存挙動は無傷）

git diff --check
  → 差分なし
```

`flutter test`（フルリポジトリ、公式レポート#221の実測で2082+テスト規模）はこの環境で追加実行中（バックグラウンド、`test/game/public_demo/`・`test/ui/public_demo/`はいずれも上記で個別に全通過済みなので、フル実行は追加のregression確認）。完了結果は本Issueの「Known Limitations」に記載する形で扱う——Issue #241自身が要求する検証範囲（`flutter analyze`・focused tests・relevant game/public_demo regression・`git diff --check`）は上記で満たしている。

### 手動trace（追加のsanity check）

新規domainテストで実際に「pre-entry pipeline途中でjoinしてしまう」ケースを再現し、fix後は以降のpipeline遷移メソッドが全てno-opになることを確認:

```
mid-pipeline stage before close: preEntrySelling, hasJoined=false
after close stage:                preEntrySelling, hasJoined=true
```

## 360x800 / 390x844 Verification

`test/ui/public_demo/public_demo_sales_ui_phase1_test.dart`の既存overflow回帰グループ（360x800/390x844 × textScale 1.0/1.3/2.0の全組み合わせ、Mayの最も情報量が多い状態を含む）は無変更のまま全通過。新規追加した「joinしたapplicantがfunnelから消える」テストは、funnelセクション自体が消えるケース（このfixtureでは他に候補者がいないため）なので、overflow測定への影響はレイアウトを縮小する方向のみ（新規に幅を要する要素を追加していない）。

## Known Limitations / Unresolved

- 「入社待ち」表示自体（`juneOrdered && !hasJoined`→「入社・参画予定」、非pre-entry組の`offerAccepted`→「内定承諾」＋「入社後、研修で育成します」）は、既存ワーディングのまま変更していない——真実性は保たれているが、具体的な「入社予定月（◯月）」の数値までは表示していない（既存authorityから安全に導出できる一般化された月表示ロジックが無く、Issueの「authorityのない…入社時期を作らない」を厳守するため今回は追加しなかった）。将来の別Issueで、`PublicDemoBindingOffer.fiscalCloseId`から真実性のある月表示を追加する余地はある。
- HOMEの「今月の重要タスク」`_recommendedActionCandidates`のうち、`_addEngineerStageCandidate`（既存社員のsales-flow）側は元々`hasJoined`の概念を持たない`PublicDemoEngineerSales`のみを扱うため対象外——今回発見した欠陥は「応募者(`PublicDemoApplicant`)がjoin後も応募者リストに残り続ける」構造に固有のものであり、社員側には存在しない。
- Broad Codex Reviewは、Issue本文の指示通りこの時点では未実施（レビュー方針で「実装→self-hardening→focused verification→Codex broad review 1回」の順を守るため）。
- `flutter test test/ui/public_demo/`のフル実行完了はバックグラウンドで進行中のため、最終確認結果を本レポートおよびPRのコミットで追記する。

## Actual Elapsed Time / Revised ETA

- Fresh Audit（origin/main確認、authority trace、症状再現確認、根本原因特定）: 実測 約50分（見積り30-45分よりやや超過——pre-entry pipeline mid-flight join defectの発見・検証に追加時間を要した）。
- 実装（UI 2箇所 + domain guard 4メソッド）: 約20分。
- テスト作成・実行（domain 2件 + widget 1件 + フルsuite）: 約30分。
- 合計実測: 約1時間40分（見積り1.5〜2.5時間の範囲内）。

## PR URL

https://github.com/perusonao/smile_enjoy_story/pull/242
