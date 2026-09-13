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

### Codex Review Follow-upで追加変更されたファイル（既出3指摘対応）

- `lib/ui/public_demo/public_demo_offer_comparison_screen.dart`（変更）— Finding 1（`setState`によるrebuild修正）、Finding 3（`hasGenuineInterviewRecord`ベースの表示修正）。
- `lib/game/public_demo/public_demo_aggregate.dart`（変更）— Finding 2（`canProposeAdditionalOfferCandidate`のhistorical candidateチェック削除）。
- `lib/game/persistence/public_demo_save_codec.dart`（変更）— Finding 2関連で発見した追加バグの修正（`ordered`候補のengineer-stage cross-checkがhistorical candidateを誤ってreject）。
- `test/game/public_demo/public_demo_parallel_sales_phase1c_test.dart`（変更）— Finding 2の回帰テスト追加。
- `test/game/public_demo/public_demo_parallel_sales_phase1b_test.dart`（変更）— Finding 2関連の既存テスト1件を、新しい正しい期待値へ更新。
- `test/ui/public_demo/public_demo_offer_comparison_screen_test.dart`（変更）— Finding 1の回帰テスト追加、Finding 3のアサーション更新。

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

- **2件目以降の候補の面談は、対話式follow-up質問ミニゲームではなく、既存の確定的評価式（`PublicDemoInterviewEvaluator`）による簡易面談。** 1件目（`matchingProposal`経由でMatching画面から提案された候補）は引き続き対話式ミニゲームを使う。UI体験としては非対称だが、両方とも実在するauthorityの再利用であり、捏造・二重評価ではない。**（Codex Broad Reviewの指摘を受けた今回のフォローアップでも、この制約は変更していない——意図的に維持している。）**
- **`PublicDemoProjectContextResolver`は`orderedOfferCandidateProjectIdFor`フォールバックを追加したのみ**——全画面のcandidate authority統一は本Phaseのスコープ外（タスク自身の指示どおり）。
- **候補数に上限を設けていない**——`salesCapacity`/月4回の制約が自然な抑制として働くが、明示的なUI上限は設計判断として見送った（Fresh Audit時点のUnresolvedで指摘されていた製品判断であり、本Phaseで確定させるものではない）。
- **`declined`候補を「取り消す」UIはない**——`declineOfferCandidate`（Phase1a由来）にはUI導線を追加していない。declineは既存仕様どおり終端。

## Codex Review Follow-up（PR #260, 既出3指摘への対応）

Codex Broad Reviewは本フォローアップより前に既に1回完了済み。本フォローアップはその3指摘への修正・focused verificationのみを行い、**新しいBroad Reviewは要求していない**。

### Finding 1 — P1（必須）: 比較画面が面談実行後にrebuildされない

- **Severity**: P1
- **Root cause**: `public_demo_offer_comparison_screen.dart`の`_OfferCandidateCard`へ渡す`onInterviewPartner`/`onInterviewClient`コールバックが、親画面（`_openOfferComparison`）の`_commitAggregate`を呼ぶだけで、比較画面自身の`State`に対する`setState`を一切呼んでいなかった。`build()`は`widget.candidatesFor()`を毎回再読するため、外部から`setState`されない限り再描画されず、stage表示・次アクションのCTA（客先面談ボタン・受注ボタン）が古いままになり、再タップすると完了済みのtransitionを無害だが無意味に再実行していた。
- **Fix**: `_PublicDemoOfferComparisonScreenState`に`_runInterviewPartner`/`_runInterviewClient`を追加し、`widget.onInterviewPartner`/`onInterviewClient`を呼んだ直後に`if (mounted) setState(() {})`する。既存の`_confirmOrder`（受注確定後に`setState`する実装）と同じ規約に統一。両呼び出しは現状同期的だが、将来非同期化されても安全なよう`mounted`チェックを維持。
- **Tests**: `test/ui/public_demo/public_demo_offer_comparison_screen_test.dart`に新規テスト追加（パートナー面談実行→画面を閉じずに客先面談CTA出現を確認→客先面談実行→画面を閉じずに受注CTA出現を確認→受注CTAへの二重タップで確認ダイアログが1つだけ開くことを確認）。
- **RESOLVED**

### Finding 2 — P2: historical ordered candidateが新sales cycleの追加提案を永久にブロック

- **Severity**: P2
- **Root cause**: `PublicDemoAggregate.canProposeAdditionalOfferCandidate`が`engineer.stage`チェックに加え、`offerCandidatesForEngineer(engineerId).any(stage==ordered)`という冗長かつ誤った追加チェックを持っていた。`offerCandidates`は履歴を削除しない設計のため、一度でも受注→assignment→`endAssignment`でreleaseされたengineerは、新しいsales cycleへ進んでも過去のhistorical ordered candidateがこのチェックに引っかかり、`canProposeAdditionalOfferCandidate`が永久にfalseになっていた。
- **Fix**: 当該チェックを削除。`engineer.stage`（`recordOrder`/`recordOfferCandidateOrder`が候補の受注と同一`_copyWith`で同期し、`releaseFromAssignment`が解放時に`waiting`へ確実にリセットする、既存の正しい authority）のみで判定するよう変更。履歴データ自体は一切削除・変更していない。
  - **追加で発見した関連バグ（save codec）**: 上記修正の検証（save/reloadを途中に挟むケース）で、`PublicDemoSaveCodec._hasConsistentAuthorityFacts`の別チェック（「candidateが`ordered`ならOWN engineerも現在`ordered`でなければならない」）が、まさにこの正当なhistorical candidateシナリオ（release後は`waiting`に戻る）を**save全体rejectとして誤検出**することを発見した。この2つのチェックはFinding 2の同じ根本原因（historical ordered candidateの認識不足）に由来するため、あわせて修正した。この経緯は既存テスト`public_demo_parallel_sales_phase1b_test.dart`の1件（「a raw save asserting stage: ordered...is rejected」）の前提と矛盾するため、当該テストを「rejectされない・かつengineer.stage gateにより実害が出ない（inert）ことを確認する」内容へ更新した——テストを削除して問題を隠してはいない。
- **Save compatibility**: 維持。schema変更なし、migration不要（両チェックとも既存フィールドの検証ロジックの変更のみ）。`ordered != assigned`は無変更（`assignOrderedForMay`/`recoverLateYearAssignment`は自身の`engineer.stage == ordered`という第一条件を無変更で維持しており、historical candidateだけでは絶対にassignmentを作れない）。Replacement salesは無変更（`PublicDemoReplacementStage`/`public_demo_assignment.dart`にdiff無し）。
- **Tests**: `test/game/public_demo/public_demo_parallel_sales_phase1c_test.dart`に新規テスト追加——`propose→partner+client合格→受注→closeApril/closeMay→closeJune/closeJuly（month 8まで）→7月分「発注なし」決定→endAssignment release→新sales cycleの最初の提案→追加提案可能`を実際の本番コマンドで再現し、save/reloadを途中に挟んでも成立することを確認。`public_demo_parallel_sales_phase1b_test.dart`の既存テスト1件を上記のとおり更新。
- **RESOLVED**

### Finding 3 — P2: declined siblingの客先面談結果を「不合格」と偽表示

- **Severity**: P2
- **Root cause**: `_OfferCandidateCard`の客先面談結果表示が`candidate.stage == clientInterviewPassed || candidate.stage == ordered`で「合格」判定していた。`decline()`は`interviewRecord`を一切clearしないため、`clientInterviewPassed`から直接（他候補の受注により）自動declineされたcandidateは、真にgenuine interviewRecordを保持したまま`stage`だけが`declined`になる——このcandidateは上記の条件式では「不合格」表示になり、実際には合格していたという事実を偽って伝えていた。
- **Fix**: 判定を`candidate.hasGenuineInterviewRecord`（stage非依存の、unforgeableな authority）へ変更。あわせて`declined`状態の説明文を、`hasGenuineInterviewRecord`の有無で分岐: 合格していた場合は「客先面談に合格していましたが、他の案件を受注したため見送りになりました。」、合格していなかった場合は既存の「見送り済みのため、この案件は受注できません。」のまま。パートナー面談側の表示ロジックは、現行のUI配線（自動declineは`proposed`/`partnerInterviewPassed`/`clientInterviewPassed`の3つのliveステージのみが対象で、手動declineのUI導線が存在しない）の下では既に正しいことを確認し、変更していない。
- **Tests**: 既存テスト（`test/ui/public_demo/public_demo_offer_comparison_screen_test.dart`の受注確認フロー）のアサーションを、declined siblingが正しく「客先面談：合格」+「客先面談に合格していましたが...」を表示し、「不合格」という文字列がどこにも現れないことを確認する内容へ更新。
- **RESOLVED**

### Focused verification（本フォローアップ）

- Focused Phase1c domain tests（`public_demo_parallel_sales_phase1c_test.dart`）: 20/20 passed（Finding 2回帰テスト含む）。
- Focused Phase1c UI tests（`public_demo_offer_comparison_screen_test.dart`）: 7/7 passed（Finding 1回帰テスト含む、Finding 3のアサーション更新含む）。
- Focused save codec tests（`public_demo_save_codec_test.dart`/`public_demo_parallel_sales_phase1b_test.dart`/`public_demo_offer_candidate_test.dart`/`public_demo_parallel_sales_session_composite_identity_test.dart`）: 168/168 passed（Finding 2関連のcodec修正・既存テスト更新含む）。
- `flutter analyze`（全体）: No issues found。
- `flutter test test/game/public_demo`: 1016/1016 passed（フルスイート、Finding 2の新規テスト1件を含む正味+1）。
- `flutter test test/ui/public_demo`: **748/748 passed**（フルスイート、Finding 1/3の新規・更新テスト含む）。
- `git diff --check`: clean。

## Next task

`docs/decisions/SES_FIRST-FUN-YEAR_NEXT-PRIORITIES_2026-09-10.md`のexecution order（Monthly Hiyori Management Report、Project/order/assignment continuity、Recruitment lifecycle clarity等）を参照。Parallel Sales / Offer Selection（Issue #245 Finding #4）はPhase 1a→1b→1cを通じて実装完了。

## FINAL VERDICT

**READY.** Codex Broad Review（PR #260）の既出3指摘（P1×1、P2×2）はすべてRESOLVED。`flutter analyze`clean、`flutter test test/game/public_demo`1016/1016 green（フルスイート）、`flutter test test/ui/public_demo`748/748 green（フルスイート）、`git diff --check`clean。本フォローアップ中に追加で発見したsave codecの関連バグ（historical ordered candidateを誤ってreject）も同セッション内で修正・回帰テスト追加済み。HOME/Finance/Payroll/Matching式/Interview outcome式/`ordered != assigned`/`salesCapacity` semanticsはいずれも無変更。**新しいBroad Reviewはこのフォローアップでは要求していない**（本タスクの指示どおり）。「2件目以降は簡易面談」というKnown Limitationは意図的に維持し、変更していない。

## Final HEAD SHA / PR

- Base `origin/main` SHA: `e46efba0dcf969cbbad138632bc723d21a9ac73c`（PR #258マージコミット、本セッション開始時・PR作成時ともにdrift無し確認済み）。
- Branch: `claude/parallel-sales-phase-1c-501dpp`
- Original Broad Review対象HEAD（本フォローアップ開始時点）: `0e4aa9492ae86dd8a8135d3203aaa322e544a446`
- Implementation commit（Phase 1C本体）: `2437fb81a65e071d464a2e8d2b4883fb4f1804ac`
- Codex Review Follow-up commit（本フォローアップの修正一式）: `8245f364d7358288a138820c7542d131642c5d27`
- Final HEAD SHA（本ファイルを含む、このブランチの最新commit）: 本行を含むcommit以降、実装内容への変更はない（PR URL/HEAD SHA記載のdocs-onlyフォローアップのみ）——`git log -1`で確認可能。
- PR: https://github.com/perusonao/smile_enjoy_story/pull/260
