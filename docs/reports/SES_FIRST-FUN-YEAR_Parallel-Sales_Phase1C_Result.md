# SES First Fun Year — Parallel Sales Phase 1C（候補案件比較・受注選択UI）

Status: **Implemented, self-hardened, full regression suite green. Issue #245 Finding #4（並行営業／複数案件面談結果からの受注選択）は Phase 1a → 1b → 1c を通じて実プレイで完結する。**

## Base SHA

- `git fetch origin` をセッション開始時に実行。`origin/main`（`refs/heads/main`）は指定どおり **`e46efba0dcf969cbbad138632bc723d21a9ac73c`**（PR #258 のマージコミット）と完全一致（drift無し）。
- 作業ブランチ `claude/parallel-sales-phase-1c-501dpp` を `origin/main` から新規作成。

## Fresh Audit

セッション開始時のリポジトリ誤認識について: 本タスクは当初 `perusonao/shogi-review`（将棋解析PWA、無関係リポジトリ）にアタッチされていたが、指定Base SHA・Issue番号・`docs/reports/SES_*`ファイル群が一致しないことを確認し、`perusonao/smile_enjoy_story` を `list_repos`/`add_repo` で特定・追加した（詳細は本セッションの会話ログ）。以降はこのリポジトリで作業。

必読ドキュメント（全文読了）:
- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Result.md`（Fresh Audit / 設計）
- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1a_Result.md`
- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1B_Result.md`
- `docs/reports/SES_PR-258_Parallel-Sales-Phase1B_Claude-Broad-Review.md`
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`
- `docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`
- Issue #245（Finding #4 全文）、Issue #257（全文）

コード監査で確認した、Phase 1c実装前の実状態:

1. **`PublicDemoAggregate.offerCandidates`は既にPhase 1B cutoverでlive authority化済み**（`proposeMatch`/対話式Partner・Client Interview/`recordOrder`が同期）。ただし読む画面が存在しない（Phase1B自身の Known limitations で明記済み）。
2. **`recordOrder(engineerId)`は単一slot `matchingProposalFor`から解決したプロジェクトしかorderできない** — 複数のclientInterviewPassed候補から「選ぶ」操作を安全に行うための、project指定型のorder authorityが存在しなかった。
3. **`PublicDemoEngineerSales.stage`（coarse scalar）は対話式interviewエンジンの単一カーソル** — `introduced→partnerInterviewPassed→clientInterviewPassed`の状態機械を、別プロジェクトのために「巻き戻す」遷移が存在しない。このため対話式ミニゲーム（フォローアップ質問付き）を2件目以降の案件に再利用することは、Phase 1B までのauthorityでは構造的に不可能（Main Game統合なし・Phase 1B domain再設計なしという本タスクのガードレール内では対話式ミニゲームの複線化は範囲外と判断）。
4. **Phase 1a で追加済みの"safe building block"（`PublicDemoAggregate.evaluatePartnerInterviewForCandidate`/`evaluateClientInterviewForCandidate`）が実装済みだが未配線** — `PublicDemoInterviewEvaluator`（既存・確定的評価式、`score>=60`で合格）を再利用し、対象engineerの実プロファイルから安全に導出、正しいsales slotを消費する。engineer側coarse stateには一切触れない。これが2件目以降の候補案件の面談に安全に使える既存authorityであることを確認した。
5. **`assignOrderedForMay`/`recoverLateYearAssignment`は`engineer.genuineInterviewProjectId`のみを読む** — 複数候補から選んだ案件が、engineer単位のcoarse recordと一致しない場合、月次assignmentが誤ったproject（または汎用placeholder）に対して作られるリスクを特定（下記「Self-hardening」参照）。

## UI design

対象: 社員タブ（`ec(i)`、既存の受注/面談ボタン群と同じカード）。

- **候補が2件以上ある技術者**: 明確なCTA「候補案件を比較」（`FilledButton.tonalIcon`）。
- **候補は1件以下だが、既に営業パイプライン中（waiting/skillSheet以外、未受注）**: 控えめなCTA「他の案件も提案する」——同じ画面を開くが、比較の必要が生じるまで「比較」を名乗らない。
- **候補が0件でwaiting/skillSheet**: 何も表示しない — 既存の単一案件オンボーディング導線（スキルシート確認→営業開始→案件紹介→面談→受注）は完全に無変更。

比較画面 `PublicDemoOfferComparisonScreen`（フルスクリーン push、`Navigator.push`、既存の`PublicDemoProjectMatchingScreen`と同じ規約）:

- 縦スクロールの`ListView` + 候補ごとの`Card`（**横スクロールtableは使用していない**）。
- 各カードに表示: 案件名・案件種別（`projectTypeLabels`再利用）・単価（`formatYen`再利用）・取引先名+商流（`commercialFlowLabels`再利用）・パートナー面談結果（未実施/合格(点数)/不合格(点数)）・客先面談結果（同様）・candidate状態バッジ（日本語ラベルのみ、内部enum名は非表示: 提案中/パートナー面談 通過/パートナー面談 不通過/客先面談 通過/客先面談 不通過/受注/見送り）。
- 「この案件を受注」は`clientInterviewPassed`のcandidateにのみ表示。`ordered`/`declined`は理由テキストのみ（ボタン自体を非表示にし、押せない状態を残さない設計）。
- 押下前に確認ダイアログ（技術者名・案件名・単価を表示、「受注すると他の候補案件は自動的に見送りになります」を明記）。
- 「別の案件も提案する」ピッカー: 今月の実在プロジェクトプール（`projectCandidatesForMonth`）から、既に候補を持つプロジェクトを除外して表示 — 捏造データなし。
- 案件解決に失敗した場合（stale project）は「この案件のデータが古い、または取得できません。この候補は操作できません。」を表示し、操作ボタンを一切出さない。

360px/390px両方で確認（自動テスト、下記）。既存ゲームUIトーン（`PublicDemoSalesCard`/`PublicDemoSalesStatusBadge`等、既存のvisual kit）を再利用。HOMEは無変更。

## Authority mapping

| 目的 | 使用authority | 新規/既存 |
|---|---|---|
| 候補一覧の読み取り | `PublicDemoAggregate.offerCandidatesForEngineer` | 新規（`offerCandidates`/`offerCandidateFor`の単純な拡張、Phase1a/1Bのlist authorityを再利用） |
| 案件title/rate/type/client | `PublicDemoSeededProjectGenerator.regenerate` | 既存（Matching画面・`PublicDemoProjectContextResolver`と同一） |
| 2件目以降の提案 | `PublicDemoAggregate.proposeOfferCandidate`（Phase1a） | 既存・新規ゲート（`canProposeAdditionalOfferCandidate`/`proposeAdditionalOfferCandidate`を追加、`proposeMatch`/`withMatchingProposal`は無変更） |
| 2件目以降の面談 | `PublicDemoAggregate.evaluatePartnerInterviewForCandidate`/`evaluateClientInterviewForCandidate`（Phase1a、未配線だったsafe building block） | 既存（配線のみ、新しい評価式なし） |
| 受注 | `PublicDemoAggregate.recordOfferCandidateOrder`（新規、`PublicDemoWorkflowState.recordOfferCandidateOrder`を拡張） | Phase1aのbuilding blockを完成させたもの。新しいorder authorityではない |
| 月次assignment作成 | `assignOrderedForMay`/`recoverLateYearAssignment`（既存、projectId解決のみ拡張） | 既存 |

新しいorder/interview評価authorityは一切作成していない。既存の`recordOrder(engineerId)`（単一candidate、`matchingProposalFor`ベース）は**完全に無変更**で、既存の受注導線として残る。

## Implementation

### Domain（最小限の拡張）

1. **`lib/game/public_demo/public_demo_sales.dart`**: `PublicDemoEngineerSales.syncOrderedFromCandidate({required int score})`を追加。候補side の genuine pass から coarse scalar（`stage`/`lastInterviewScore`/`interviewRecord`）を同期する。`interviewRecord`は意図的に`projectId: null`（legacy generic-path と同じ形）で作る——理由は「Self-hardening」参照。スコアは`>=60`にクランプ（表示用のcandidate側`clientScore`はクランプしない、真の値のまま）。

2. **`lib/game/public_demo/public_demo_workflow_state.dart`**:
   - `recordOfferCandidateOrder`を拡張し、候補のorder+sibling declineと同じ`_copyWith`呼び出しで`engineers`側も`syncOrderedFromCandidate`する。
   - `_orderedOfferCandidateFor(engineerId)`（private）を追加——`offerCandidates`から`stage==ordered && hasGenuineInterviewRecord`の候補を解決。
   - `_freshOrderedAssignment`/`recoverLateYearAssignment`のprojectId解決を`engineer.genuineInterviewProjectId ?? _orderedOfferCandidateFor(...)?.projectId`へ拡張（既存の単一経路では両者が常に一致するため既存挙動は無変更、candidate-aware orderの場合のみ後者が効く）。
   - `orderedOfferCandidateFor(engineerId)`（public）を追加——UIの`_projectContextFor`など読み取り専用の表示ロジックが利用。

3. **`lib/game/public_demo/public_demo_aggregate.dart`**:
   - `offerCandidatesForEngineer`（委譲）、`orderedOfferCandidateProjectIdFor`（委譲）を追加。
   - `canProposeAdditionalOfferCandidate(engineerId)`: waiting/skillSheet/ordered、既に受注済みcandidate保持中、当月assigned済みのいずれでもfalse。
   - `proposeAdditionalOfferCandidate({engineerId, projectId})`: 上記ゲート越しに既存`proposeOfferCandidate`へ委譲。
   - `recordOfferCandidateOrder({engineerId, projectId})`: candidate自体のstage/genuine recordを再検証したうえで`workflow.recordOfferCandidateOrder`へ委譲。当月assigned済みなら拒否。

4. **`lib/game/persistence/public_demo_save_codec.dart`**: 2件のself-hardening修正（下記）。

### UI

5. **`lib/ui/public_demo/public_demo_offer_comparison_screen.dart`**（新規）: `PublicDemoOfferComparisonScreen`（StatefulWidget、live getterで再描画）+ `_OfferCandidateCard`/`_AdditionalProjectPicker`。

6. **`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`**: `ec(i)`にCTA追加、`_openOfferComparison(engineer)`ハンドラ追加（既存の`_commitAggregate`/`_openProjectMatching`パターンを踏襲）。`_projectContextFor`の`genuineInterviewProjectId`引数に`orderedOfferCandidateProjectIdFor`フォールバックを追加（candidate-aware orderされたengineerでも「受注案件」表示が引き続き機能するように）。

## Changed files

- `lib/game/public_demo/public_demo_sales.dart`（変更）— `syncOrderedFromCandidate`追加。
- `lib/game/public_demo/public_demo_workflow_state.dart`（変更）— `recordOfferCandidateOrder`拡張、`_orderedOfferCandidateFor`/`orderedOfferCandidateFor`追加、`_freshOrderedAssignment`/`recoverLateYearAssignment`のprojectId解決フォールバック追加。
- `lib/game/public_demo/public_demo_aggregate.dart`（変更）— `offerCandidatesForEngineer`/`orderedOfferCandidateProjectIdFor`/`canProposeAdditionalOfferCandidate`/`proposeAdditionalOfferCandidate`/`recordOfferCandidateOrder`追加。
- `lib/game/persistence/public_demo_save_codec.dart`（変更）— self-hardening修正2件（offer candidate score floor `>=60`→`>=5`、`declined`状態でのgenuine record許容）。
- `lib/ui/public_demo/public_demo_offer_comparison_screen.dart`（新規）— 比較画面本体。
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`（変更）— CTA追加、ハンドラ追加、project context resolverフォールバック追加。
- `test/game/public_demo/public_demo_parallel_sales_phase1c_test.dart`（新規、19 tests）。
- `test/ui/public_demo/public_demo_offer_comparison_screen_test.dart`（新規、6 tests）。
- `test/game/public_demo/public_demo_save_codec_test.dart`（変更）— self-hardening修正に伴う既存テストのスコア値修正（1件）。
- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`（変更）— governing plan sync。
- `docs/reports/SES_FIRST-FUN-YEAR_Parallel-Sales_Phase1C_Result.md`（新規、本ファイル）。

他のproduction/testファイルは無変更（HOME/Finance/Payroll/Matching式/Interview outcome式/`projectInterviewSessions`は無diff）。

## Tests

- 新規: `test/game/public_demo/public_demo_parallel_sales_phase1c_test.dart`（19 tests）— 比較読み取り、candidate-aware order、save/reload、追加提案ゲート、既存単一案件flow回帰、replacement sales無関係性確認、self-hardeningのcodec修正の直接回帰テストを含む。
- 新規: `test/ui/public_demo/public_demo_offer_comparison_screen_test.dart`（6 tests）— CTA表示条件、比較画面の内容、受注確認ダイアログ→受注→sibling見送り→重複タップ不可、不合格候補には受注ボタンなし、360x800/390x844でのoverflowなし。
- 既存修正: `test/game/public_demo/public_demo_save_codec_test.dart`の1テストのスコア値を`10`→`2`へ修正（下記Self-hardening参照、意味的な弱体化ではなく、正しい閾値の反映）。

実行結果:
- `flutter analyze`（全体）: **No issues found.**
- `flutter test test/game/public_demo`: **1015/1015 passed**（既存996 + Phase1c新規19、既存save_codec_testの1件修正込み）。
- `flutter test test/ui/public_demo`: **747/747 passed**（既存741 + Phase1c新規6、全件フルスイート実行・失敗ゼロ）。
- `git diff --check`: クリーン。

## Self-hardening

実装後、自分で以下を再確認し、2件のP0/P1級の**既存コード（Phase 1a/1B由来）のバグ**を発見・修正した。いずれも本Phase 1cの新シナリオ（複数候補が存在し得る状態を実際に読む/書く）を初めて実exerciseしたことで顕在化した、通常プレイのみで到達可能な問題。

### 発見1（P0級）: offer candidateのscore floorが確率的合格を弾いていた

`PublicDemoSaveCodec._hasConsistentAuthorityFacts`のoffer candidate向けチェックは、Phase 1a時点（`PublicDemoInterviewEvaluator`の確定的`score>=60`のみが評価経路だった頃）に書かれた`clientScore>=60`を要求していた。Phase 1Bが対話式Project Interview Gameplay（`ProjectInterviewEngine.roll`、`rng.nextInt(100) < rate`という確率ロール、`rate`自体は`[5,95]`にクランプ）を`offerCandidates`へも同期するcutoverを行った際、**このチェックは更新されなかった**。確率ロールは`rate`が60未満でも合格し得るため、**通常の対話式面談プレイだけで、合格したのにsaveがrejectされる状態**が生まれていた。`>=5`（実エンジンの実クランプ下限）へ修正。既存save_codec_testの該当テスト（旧: `clientScore:10`でreject確認）を`clientScore:2`（実エンジンでは絶対に到達し得ない値）へ修正——弱体化ではなく、閾値の正しい理解の反映。

### 発見2（P0級、本Findingの中心シナリオそのものを直撃）: declined候補が持つ正当なrecordを誤ってreject

同チェックは、`interviewRecord`を保持するcandidateの`stage`が`clientInterviewPassed`/`ordered`のいずれかであることを要求していた。しかし`PublicDemoOfferCandidate.decline()`は`interviewRecord`を一切clearしない——`clientInterviewPassed`から直接`declined`へ遷移する（受注時の自動sibling decline、または本Phaseで追加した候補比較の受注確定）のはこのFindingが実現しようとしている**まさにその中心シナリオ**であり、genuine recordを保持したまま`declined`になるcandidateは正常な、むしろ必然的な形。`clientPassStage`許容リストへ`declined`を追加。「1 engineer / 2 passed projects → 1件受注→もう1件は自動見送り」という要求仕様どおりのシナリオをsave/reloadすると、この修正前は**必ずsave全体がrejectされていた**（デバッグスクリプトで再現・修正確認済み）。

### 確認済み・問題なし

- **UIがlegacy matchingProposalを唯一のauthorityとして誤って扱っていないか**: `ec(i)`のCTA判定・比較画面はすべて`offerCandidates`/`offerCandidateFor`を読む。既存`_projectContextFor`は`matchingProposalProjectId`を最後のfallbackとしてのみ使用（既存挙動を保持しつつ、`orderedOfferCandidateProjectIdFor`を追加）。
- **Project title/rateを別生成していないか**: 全て`PublicDemoSeededProjectGenerator.regenerate`経由。捏造なし。
- **UIから直接candidate.stageを書き換えていないか**: UIは`PublicDemoAggregate`の各メソッド呼び出しのみ。stage遷移は全てdomain層内で行われる。
- **二重受注できないか**: `recordOfferCandidateOrder`は候補が現在`clientInterviewPassed`かつgenuine recordを持つ場合のみ有効。既に`ordered`の候補への再呼び出しはno-op（テスト済み）。`recordOfferCandidateOrder`（aggregate層）は当月assigned済みengineerも拒否。
- **save/reloadで比較候補が消えないか**: 2候補・受注前/受注後いずれもbyte-identicalにround-trip（テスト済み、self-hardening発見の2件を修正後）。
- **failed/declinedを受注できないか**: `recordOfferCandidateOrder`は`clientInterviewPassed`以外を全て拒否（proposed/partnerInterviewPassed/failed/declined、テスト済み）。UI側も`clientInterviewPassed`以外には受注ボタン自体を表示しない。
- **ordered後のsiblingsが残らないか**: `recordOfferCandidateOrder`は同一`_copyWith`呼び出しで全live siblingをdeclineする（Phase1a由来のロジック、無変更）。
- **Phase 1B composite session（`projectInterviewSessions`のcomposite key）を壊していないか**: 本Phaseは`projectInterviewSessions`に一切触れていない。既存テスト全件green。
- **replacement sales（`PublicDemoReplacementStage`）との無関係性**: 専用回帰テストで`offerCandidates`が一切読み書きされないことを確認。

### 検討したが実装しなかった項目（スコープ判断）

- **対話式Project Interview Gameplay（follow-up質問付きミニゲーム）を2件目以降の候補にも使う**ことは検討したが、`PublicDemoEngineerSales.stage`という単一state machineカーソルを別プロジェクトのために巻き戻す遷移が存在しないため、Phase 1B domain再設計（本タスクのScope外）なしには実現できないと判断した。2件目以降は既存のsafe building block（確定的評価式）で面談する設計とした——「新しい面談エンジンを作らない」というガードレールと、「Phase 1B domain再設計はしない」というガードレールの両方を同時に満たす、最小安全範囲の選択。

## Known limitations

- **2件目以降の候補の面談は、対話式follow-up質問ミニゲームではなく、既存の確定的評価式（`PublicDemoInterviewEvaluator`）による簡易面談。** 1件目（`matchingProposal`経由でMatching画面から提案された候補）は引き続き対話式ミニゲームを使う。UI体験としては非対称だが、両方とも実在するauthorityの再利用であり、捏造・二重評価ではない。
- **`PublicDemoProjectContextResolver`は`orderedOfferCandidateProjectIdFor`フォールバックを追加したのみ**——全画面のcandidate authority統一は本Phaseのスコープ外（タスク自身の指示どおり）。
- **候補数に上限を設けていない**——`salesCapacity`/月4回の制約が自然な抑制として働くが、明示的なUI上限は設計判断として見送った（Fresh Audit時点のUnresolvedで指摘されていた製品判断であり、本Phaseで確定させるものではない）。
- **`declined`候補を「取り消す」UIはない**——`declineOfferCandidate`（Phase1a由来）にはUI導線を追加していない。declineは既存仕様どおり終端。

## Next task

`docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`のexecution order（Monthly Hiyori Management Report、Project/order/assignment continuity、Recruitment lifecycle clarity等）を参照。Parallel Sales / Offer Selection（Issue #245 Finding #4）はPhase 1a→1b→1cを通じて実装完了。

## FINAL VERDICT

**READY.** `flutter analyze`clean、`flutter test test/game/public_demo`1015/1015 green、`flutter test test/ui/public_demo`747/747 green（フルスイート実行）、`git diff --check`clean。本セッションで発見した2件のP0級既存バグ（save codec のscore floor誤り、declined候補のrecord誤reject）は同セッション内で修正・回帰テスト追加済み。HOME/Finance/Payroll/Matching式/Interview outcome式/`ordered != assigned`/`salesCapacity` semanticsはいずれも無変更。Broad Review（Codex）は本タスクの指示によりこのセッションでは実施しない——PR作成後に別途1回だけ実施する。

## Final HEAD SHA / PR

- Base `origin/main` SHA: `e46efba0dcf969cbbad138632bc723d21a9ac73c`（PR #258マージコミット、本セッション開始時・PR作成時ともにdrift無し確認済み）。
- Branch: `claude/parallel-sales-phase-1c-501dpp`
- Implementation commit: `2437fb81a65e071d464a2e8d2b4883fb4f1804ac`（code/tests/docs一式。`flutter analyze`/`flutter test`/`git diff --check`はすべてこのcommitの内容に対して実行・記録したもの）。
- Final HEAD SHA: 本ファイルを含む、このブランチの最新commit（PR #260の最新HEAD, `git log -1`で確認可能）。本commit以降、実装内容への変更はない（PR URL/HEAD SHA追記のdocs-onlyフォローアップのみ）。
- PR: https://github.com/perusonao/smile_enjoy_story/pull/260
