# SES FIRST-FUN-YEAR Partner Interview — Phase B (B1+B2) Result Report

**Issue:** #245 (Finding #3 / #10 中心), Phase A は PR #246 で main へマージ済み
**Audited explicit main SHA:** `0b90d556b74746c2f82ac0e9111a95e93bd564b6`（`git fetch origin` 後の `origin/main` — Issue本文の期待SHAと完全一致。これが最新でもあることを確認済み）
**Branch:** `claude/ses-partner-interview-phase-b-dz4g42`
**Final HEAD SHA:** `67271b8492c9e4bc5b7f735094e06aa21d0bcc00`
**PR URL:** https://github.com/perusonao/smile_enjoy_story/pull/247

---

## 0. Method

- `git fetch origin` を実施し、repository default branchではなく明示的に `origin/main` を使用。取得したSHAは `0b90d556b74746c2f82ac0e9111a95e93bd564b6` で、Issue #245記載の期待値と完全一致（Phase Aの broad Codex review は再実行せず）。
- ブランチ `claude/ses-partner-interview-phase-b-dz4g42` は当初 `main` から大きく乖離した古い起点（コミット `f4ca78f`, 未マージ作業なし）だったため、`origin/main` から作り直した（`git checkout -B` — 破棄した作業なし、事前に確認済み）。
- 未マージのFresh Audit（`docs/reports/SES_FIRST-FUN-YEAR_Human-Replay-UX-Findings_Fresh-Audit.md`, ブランチ `claude/issue-245-fresh-audit-3600u9` に存在, commit `2bb9a11`）を読み込み、Finding #3/#9/#10のroot causeと該当コード位置を把握した上で、現在の `main` 上のコードを実際に再読して裏取りした。

---

## 1. Root cause（Fresh Auditの再確認）

Finding #3/#9/#10 の実体は1つ:

**「上位会社面談」（`ei(i, PublicDemoInterviewType.partner)`）は、ボタンを1回タップした瞬間に `PublicDemoAggregate.recordEngineerInterviewResult` が同期的にコミットされ、結果モーダルは「すでに確定した結果を表示するだけ」の非interactiveな画面だった。** 一方、`客先面談`（Issue #219以降、実在する `PublicDemoMatchingProposal` がある場合）は既に本物のinteractiveなミニゲーム（`PublicDemoProjectInterviewDialog`, Phase 6）を持っている。同じ「面談」という語で、片方だけ実質「選択の余地がない演出」になっていた。

加えて、結果モーダル（`PublicDemoInterviewResultDialog`）は生スコア（`$score点`）と「基準点60点をクリア/に届かず」という hidden threshold をそのまま表示していた（HIDDEN-PARAMS-1違反）。

`案件紹介`（`_introduceProject`, Issue #219のPhase 2フィックス）は、通常プレイで **必ず** 実在プロジェクトへの `PublicDemoMatchingProposal` を先に作ってから `stage: introduced` に遷移する。つまり `上位会社面談` に到達する時点で、`客先面談` が使っているのと同じ実在の `(engineer, project)` ペアが既に手元にある——Fresh Auditが示唆した「既存 `ClientInterviewEngine`/`ProjectInterviewDialog` を再利用できる」という仮説は、実装前調査で確認が取れた。

---

## 2. 再利用した既存authority/engine（新score/schemaを作らない）

- **`ClientInterviewEngine`/`ProjectInterviewEngine`**（`lib/game/engine/`）— 質問生成・フォローアップ評価・最終合否roll。新しい計算式を一切追加していない。
- **`PublicDemoProjectInterview`**（`lib/game/public_demo/public_demo_project_interview.dart`）— Phase 6が既に持つ、上記エンジンへのアダプタ。`start`/`chooseFollowUp`/`conclude`/`failureReasons` をそのまま呼ぶ。
- **`ClientInterviewSession`** モデルと **`PublicDemoWorkflowState.projectInterviewSessions`** リスト — Phase 6が使っている既存の永続化済みリストをそのまま共用（新しいリスト/新しいJSONキーを追加していない）。
- **`PublicDemoProjectInterviewDialog`**（UI） — Phase 6のダイアログをパラメータ化して再利用（新規ダイアログを作らない）。

新しく足したのは「同じ仕組みを `introduced` ステージでも使えるようにするための薄い配線」のみ:

| 層 | 新規メソッド | 役割 |
|---|---|---|
| `PublicDemoEngineerSales`（domain） | `applyPartnerProjectInterviewResult` | `introduced` → `partnerInterviewPassed`/`partnerInterviewFailed`。`applyProjectInterviewResult`（Phase 6, 1段階後）を一段手前にミラーしたもの。**`interviewRecord`（クライアント面談合格の unforgeable proof）は絶対に発行しない** — 既存の `evaluateInterview` のpartner分岐と全く同じ契約を守る。 |
| `PublicDemoWorkflowState`（domain） | `concludePartnerProjectInterview` | `concludeProjectInterview` を一段手前（`introduced` 要求）にミラー。既存の `startProjectInterviewSession`/`updateProjectInterviewSession`/`projectInterviewSessionFor` はステージ非依存のため **無改修のまま両リーグ（partner/client）で共有**。 |
| `PublicDemoAggregate`（domain） | `startPartnerInterview`, `concludePartnerInterview` | UI向けの薄いラッパー。`startProjectInterview`/`concludeProjectInterview` の一段手前ミラー。`chooseProjectInterviewFollowUp`/`projectInterviewChoicesFor`/`projectInterviewFailureReasonsFor`/`projectInterviewCandidateFor` は**無改修のまま partner/client 両方で共有**（これらはステージを見ていないため）。 |
| `PublicDemoProjectInterviewDialog`（UI） | `type: PublicDemoInterviewType` パラメータ | `client`（既定, 無変更）/`partner` を切り替え。partnerリーグ専用のwidget key prefix（`public-demo-partner-interview-*`）を使い、既存clientリーグのkey/挙動は一切変更していない。 |

---

## 3. Phase B1 — truthful UX

- `PublicDemoInterviewResultDialog.score` を `int?` に変更し、`null` の場合は生スコア行を表示しない。
- 既存の**フォールバック経路**（`ei()` — 実在するMatching proposalが無い場合。通常プレイでは `案件紹介` が必ず先にproposeするため、月内候補プールが空など稀なケースのみ到達）で、`score: r.score` の受け渡しと「基準点60点をクリア/に届かず」という hidden threshold の文言を削除し、「総合的な適性が評価されました/基準に届きませんでした」という定性的な表現に置き換えた（`r.passed` という既存authorityの判定結果自体は変えていない — 表示だけを変更）。
- 「上位会社面談」「客先面談」はB2実装後、実際にinteractiveなミニゲームとして分離され、タイトル・ダイアログ内ラベル（`_interviewLabel`）で明確に区別される。

---

## 4. Phase B2 — interactive Partner Interview

`上位会社面談` ボタンは、実在する `PublicDemoMatchingProposal`（＝実質ほぼ常に存在— `案件紹介` が必ず先に作る）がある場合、`PublicDemoProjectInterviewDialog(type: partner)` を開くようになった:

- **modalを開いただけでは結果をcommitしない** — `initState` は `startPartnerInterview` を呼ぶだけで、これは「セッションを作る/再開する」だけの操作。合否は一切決まらない。
- **選択肢を選んだだけでも未確定状態を維持** — `chooseFollowUp` は次の質問へ進める、または最終問なら「結論を出す準備完了」にするだけ。
- **明示的な面談実行/回答確定でのみcommit** — 全問に回答すると自動的に `concludePartnerInterview` が呼ばれ、そこで初めて `ClientInterviewEngine.finalRate` + `ProjectInterviewEngine.roll` による実際の合否roll が行われる。
- **X / OS back / dismissで結果をcommitしない** — close(×)ボタン・システムバックジェスチャーは共に単なる `Navigator.pop()`。セッションの `completed`/`result` は一切変更されない。
- **reopenできる** — 未完了セッションは `employeeId`（+`projectId`+`startedWeek`）で一意に保持され、閉じて再度開くと同じセッションが再開する。
- **double tapで二重commitしない** — 既存の `_projectInterviewLaunchInProgress` ガード（Phase 6 Codex P2-2フィックス）を partner/client 両リーグで共有。フォローアップの二重送信は `PublicDemoProjectInterview.chooseFollowUp` の既存 questionIndex 一致チェックで拒否される（Phase 6と同じ仕組み）。
- **save/reloadでstate integrityを壊さない** — `projectInterviewSessions` の既存永続化スキーマをそのまま再利用。`PublicDemoSaveCodec` の既存クロスチェック（`interviewRecordProjectId` 系）は全て genuine CLIENT passにのみ紐づいており、partnerのみの合否（`interviewRecord` 非発行）には一切触れないことをコードレビューと専用の save/reload テストの両方で確認済み。
- **成功/失敗後に理由を表示** — 合格時は「〜への提案が上位会社に評価されました。次は客先面談へ進みます。」、不合格時は `ProjectInterviewEngine.failureReasons`（Phase 6と同じ、`MatchingEngine`のfit breakdownに基づく truthful な理由）を表示。生のrate/scoreは一切表示しない（HIDDEN-PARAMS-1）。
- **次のClient Interview/営業flowへ自然につなぐ** — 合格すると `partnerInterviewPassed` になり、既存の `客先面談` ボタン（Phase 6のまま）がそのまま次のステップとして現れる。同一プロジェクトに対する新しい `客先面談` セッションは、`startProjectInterviewSession` の既存の「completedなら置き換える」規則により自動的に開始される。

### 4a. サービス残数（sales slot）の消費

既存の `recordEngineerInterviewResult`（旧汎用パス）は partner タイプで `PublicDemoState.useSalesSlot()` を1回消費していた。この既存予算契約を壊さないよう、`startPartnerInterview` に同じ消費ロジックを追加した:

- **新規に本当に面談を開始した時のみ**消費（`workflow.startProjectInterviewSession` が実際に変化した場合 = `identical()` で判定）。
- **同じ未完了セッションの再開（reopen）では絶対に二重消費しない**。
- 既存の `s.salesRemaining > 0` ボタン有効化ガードと同じ条件で、残数が尽きていれば開始自体をno-opにする。

（実装当初、この消費ロジックを見落としており、既存UIテスト `public_demo_01_home_recommended_action_test.dart` の1件が real regression として検出された — §7参照。）

---

## 5. State transition（before / after）

**Before（PR #246時点のmain）:**

```
selling --[案件紹介]--> introduced --[上位会社面談タップ]--> (即座にcommit)
  --> partnerInterviewPassed / partnerInterviewFailed
       --[客先面談タップ]-->
         (実在proposalあり: interactive Phase 6 mini-game)
         (実在proposalなし: 即座にcommit、レガシー汎用ダイアログ)
```

**After（このPhase B実装後）:**

```
selling --[案件紹介 → 実在proposal自動作成]--> introduced
  --[上位会社面談タップ]-->
    実在proposalあり（通常プレイでは常に true）:
      interactive mini-game (PublicDemoProjectInterviewDialog, type: partner)
        開く → 質問に回答 → 全問回答で自動的に合否roll → 結果表示 → 続ける
        （close/back/reopenは結果を一切commitしない）
    実在proposalなし（稀な例外パス、月内候補プールが空等）:
      レガシー汎用ダイアログ（B1のtruthful UX適用済み: 生スコア非表示）
  --> partnerInterviewPassed / partnerInterviewFailed
       --[客先面談タップ]-->（Phase 6, 無改修）
```

`PublicDemoSalesStage` enum・その遷移条件（`_transitionEngineerStage` 等）・`recordOrder`/`assignOrderedForMay` の既存ガード（`hasGenuineInterviewRecord`）は一切変更していない。

---

## 6. Schema / domain impact

**save schemaの変更: なし。**

- 新しい永続化フィールド・新しいJSONキーを一切追加していない。`ClientInterviewSession`/`projectInterviewSessions` の既存スキーマをそのまま partner/client 両リーグで共用する設計にしたため、`PublicDemoSaveCodec` の変更は不要だった。
- `PublicDemoEngineerInterviewRecord`（クライアント面談合格の unforgeable proof）は一切変更していない。Partner passは絶対にこのrecordを発行しない — `assignOrderedForMay`/`recordOrder` の既存の「genuine client interview passのみが受注資格を持つ」というガードは無傷。
- `Matching outcome` の計算式（`ClientInterviewEngine.finalRate`/`ProjectInterviewEngine.roll`）は一切変更していない。UI都合での改変なし。
- `ordered != assigned`、`revenue != cash receipt` の既存区別は無関係（Finance/Payroll/Matching式に一切触れていない）。
- **B2で唯一の新規ドメインロジックは「サービス残数消費のタイミングをinteractive flowに合わせて移す」という一点**（§4a）。これは既存の `useSalesSlot()` 契約（partnerタイプは1消費、clientタイプは0消費）を厳密に維持しており、新しい予算/新しいカウンタは一切導入していない。

**Fresh Auditが懸念していた「B2に本当にschema/domain redesignが必要なら…」というガードレール:** 実装前調査の結果、既存の `projectInterviewSessions` リストと `PublicDemoSaveCodec` の全クロスチェックロジック（`_hasConsistentAuthorityFacts`, `_hasConsistentProjectInterviewEvaluations`）を読み込み、それらが全て `interviewRecordProjectId`（＝genuine CLIENT passのみが持つ）を起点にしていることを確認した上で、redesignなしで安全に実装できると判断した。専用のsave/reloadテスト（partner-pass、partner-fail、in-progress、いずれも byte-identical round-trip）で実証済み。

---

## 7. Tests

### 7a. 新規テスト

- `test/game/public_demo/public_demo_partner_interview_test.dart`（17 tests, 385行）
  - `startPartnerInterview`: introducedでない場合のno-op、実在proposalなしでのno-op、セッション開始、resume、**サービス残数の消費（新規1回のみ・resumeでは非消費）**、**残数枯渇時のno-op**
  - `concludePartnerInterview`: genuine pass（`interviewRecord`は絶対に発行されない）、proposalなしでの未結論no-op、未回答での未結論no-op
  - Phase 6再利用の確認: partner合格後、`startProjectInterview`（client）が完了済みpartnerセッションを同一プロジェクトの新規clientセッションで置き換える、end-to-end（introduced→partner合格→client合格→受注→`assignOrderedForMay`が実プロジェクトに紐づくassignmentを生成）
  - month boundary: セッション開始月と異なる月では結論を出さない（既存の月固定ガードと同じ規則）
  - save/reload: 進行中セッション、partner合格（`interviewRecord`非発行の確認込み）、partner不合格（`beginSelling`で再挑戦できることの確認込み）
  - double tap: フォローアップの重複送信拒否、結論の二重呼び出しの安全性
- `test/ui/public_demo/public_demo_partner_interview_dialog_test.dart`（9 tests, 301行）
  - 質問/フォローアップフロー描画、生スコア非表示の確認
  - **dismiss never commits**（Issue #245 Finding #9）: X close、OS back、X連打の3パターン
  - viewport/TextScaler安全性: 360×800・390×844 × TextScaler 1.0/1.3

### 7b. 既存テストの更新（regression防止）

`案件紹介` が実在proposalを自動生成する既存挙動（Issue #219）により、`上位会社面談` ボタンも通常プレイでは常にinteractiveダイアログを開くようになった。これに伴い、以下を実施:

- `test/ui/public_demo/public_demo_project_interview_test_helpers.dart` に `dismissPartnerInterview` ヘルパーを追加（既存の `dismissClientInterview` と全く同じ形— interactiveダイアログが開いていればフォローアップを進めて `続ける` で閉じ、そうでなければレガシー `確認` ボタンをタップする）。
- 12件の既存UIテストファイル（`上位会社面談` タップ後に旧汎用ダイアログの `確認` ボタンを期待していた箇所）を `dismissPartnerInterview` を使うよう更新: `public_demo_01_assignment_carryforward_test`, `public_demo_01_completion_lock_ui_test`, `public_demo_01_fiscal_year_progression_test`, `public_demo_01_home_cash_forecast_advice_test`, `public_demo_01_home_consolidation_test`, `public_demo_01_home_office_stage_test`, `public_demo_01_home_recommended_action_test`（3箇所、うち1箇所はCTA/legacy button parityの検証内容を新ダイアログのkey検証へ更新）, `public_demo_01_home_runtime_read_test`, `public_demo_01_issue_124_screen_verification_test`, `public_demo_01_recovery_ui_test`（2箇所）, `public_demo_01_suzuki_sales_reentry_test`, `public_demo_01_suzuki_sales_yearend_boundary_test`（2箇所）。
- `public_demo_01_success_playthrough_test.dart` に `drivePartnerInterviewMiniGameToContinue` ヘルパーを追加し、既存の成功プレイスルーが新しいinteractive partner interviewを正しく駆動することを確認。
- 応募者（pre-entry applicant）向けの `pi()`/`ci()` フローは**意図的に無改修**（別パイプライン、Phase Bのスコープ外 — §9参照）。

### 7c. 実行結果

```
flutter analyze                              → No issues found!
flutter test test/game/public_demo           → 878/878 passed
flutter test test/ui/public_demo             → 692/692 passed
git diff --check                             → クリーン（whitespace error無し）
```

（`test/game/public_demo/public_demo_partner_interview_test.dart` 単体で17件、`test/ui/public_demo/public_demo_partner_interview_dialog_test.dart` 単体で9件、いずれもfocused実行で先に確認済み。既存の `public_demo_project_interview_test.dart`/`public_demo_project_interview_dialog_test.dart`（客先面談、Phase 6）は無改修かつ全pass — B2実装が既存のClient Interviewを壊していないことを確認。）

---

## 8. Viewport verification

`test/ui/public_demo/public_demo_partner_interview_dialog_test.dart` の `viewport / TextScaler safety` グループで以下を確認（全pass, overflow例外なし）:

| Viewport | TextScaler 1.0 | TextScaler 1.3 |
|---|---|---|
| 360×800 | ✅ | ✅ |
| 390×844 | ✅ | ✅ |

質問カード・面接官/回答テキスト・フォローアップ選択肢の描画は、Phase 6の `PublicDemoProjectInterviewDialog` が既に採用している `SingleChildScrollView`（TextScaler拡大時は下方向スクロール、overflowしない設計）をそのまま再利用しているため、主要CTA（フォローアップ選択肢・「続ける」ボタン）がスクロール不能な形で画面外に押し出されることはない。

---

## 9. Known limitations / unresolved items

- **応募者（pre-entry applicant）向けの上位会社面談（`pi(i)`）は今回のスコープ外**。`preEntryIntroduced` ステージの応募者は、実在Matching proposalの概念を持たないPhase 6以前の別パイプラインを使っており、生スコア表示（`PublicDemoInterviewResultDialog` 経由）も未変更。将来Phase候補として残る。
- **assignment replacement pipeline（`PublicDemoReplacementStage`, 月7-14の再配属フロー）の `上位会社面談（1枠）`/`客先面談（0枠）` ボタンも今回のスコープ外**。これも別のenum/別のUI関数（`replacementPartner`/`replacementClient`）を使っており、Fresh AuditのFinding #3/#10は主にguided per-engineer flowを指しているため今回は触れていない。
- **B1のtruthful UX修正（生スコア非表示・定性表現化）は、実質使われなくなったレガシーフォールバック経路（`ei()`, 実在proposalが無い稀なケース）にのみ適用**。B2実装によりこの経路はほぼ到達不能になったが、完全に削除はしていない（月内候補プールが空になるケースなど、既存の防御的フォールバックとして残す判断）。
- Parallel Sales（Finding #4）、Trade Flow（Finding #7）は指示通り未実装。

---

## 10. Issue #245 remaining findings（Fresh Audit記載の13件中）

Fresh Auditの提案するPhase分けに沿うと、今回のPhase Bで対応したのは **Finding #3（上位会社面談の意味/理由の真実性 + interactive化）と Finding #9（dismiss=面談済という誤解の根本原因）**、および付随して **Finding #10（面談モーダルの1画面収まり — Phase 6のスクロール設計を再利用したため新規対応不要と確認）**。

未対応（Fresh Audit Phase A/C/Dに整理済み、範囲外）:

- Finding #1, #2, #8, #11 — Phase A（PR #246）で対応済み。
- Finding #4（並行営業/複数案件比較） — 設計のみ、schema変更を要するため別Phase。
- Finding #6, #12, #13 — Phase C相当（#239のresolverと協調予定）、未着手。
- Finding #7（紹介会社/商流） — authorityが存在しないため設計のみ、未着手。

---

## Final HEAD SHA

`67271b8492c9e4bc5b7f735094e06aa21d0bcc00`

## PR URL

https://github.com/perusonao/smile_enjoy_story/pull/247
