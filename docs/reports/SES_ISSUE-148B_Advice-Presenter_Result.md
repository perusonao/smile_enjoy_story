# SES Issue #148 Phase 1B.1 + 1B.2 — 資金状態Presenter／ひより助言候補 実装結果

## STATUS

Completed（Phase 1B.1 + 1B.2 スコープのみ。HOME Widget・文言表示・CTA遷移・Phase 2は対象外）

## PRECONDITION確認

- `origin/main` に PR #153（Issue #148 Phase 1A: 確定情報ベース資金予測SSOT）がマージ済みであることを、GitHub上のPR #153（`state: closed`, `merged: true`, `merged_at: 2026-09-03T04:42:42Z`）を直接確認して検証した。
- `PublicDemoCashForecast`（`lib/game/public_demo/public_demo_cash_forecast.dart`）の現在のAPIと、対応する `test/game/public_demo/public_demo_cash_forecast_test.dart`（22ケース）を読んだ。
- 作業branch（`claude/phase-1b-cash-advice-logic-zyxvi9`）はセッション開始時点でPhase 0の古いcommit上に作られていたため、`origin/main`最新HEAD（`e60dbe3`＝PR #153マージ後）へ`git checkout -B`で作り直した。

## BASE / HEAD

- BASE: `origin/main` (`e60dbe38c0eee05d12ba34a241373d3a9dfd1731`、PR #153マージ後の最新HEAD)
- 作業branch: `claude/phase-1b-cash-advice-logic-zyxvi9`
- HEAD: 本reportをコミットしたcommit（下記「commit SHA」参照）

## 実施内容

### 1B.1: 資金状態Presenter

新規ファイル `lib/game/public_demo/public_demo_cash_status_presentation.dart` に、`PublicDemoCashForecastResult`（Phase 1A・変更なし）を入力とする純粋mapper `PublicDemoCashStatusPresentation.fromForecast(...)` を追加した。

**状態は指示通り3値のみ**（`PublicDemoCashStatus` enum）:

- `safe` — `forecast.months`が空でなく、かつ`forecast.hasShortage == false`（予測期間内に現金マイナスなし）。
- `shortage` — `forecast.hasShortage == true`（`firstShortageMonth`がある）。
- `unavailable` — `forecast.months.isEmpty`（決算停止・年度完了など、予測月が空）。判定順序は`months.isEmpty`を最優先で見ることで、close-blocked状態が誤って`safe`に分類されないようにしている。

**不足月の扱い**: `shortage`のときだけ`shortageMonth`フィールドに`forecast.firstShortageMonth`をそのまま保持する（再計算・調整なし）。`safe`と`unavailable`では常に`shortageMonth == null`。

**独自閾値なし**: 「注意」「危険」等の閾値・状態は追加していない。`PublicDemoCashForecastResult.isNegative`（現金マイナスの事実）以外の判定基準を導入していない。

**日本語表示文言なし**: `PublicDemoCashStatusPresentation`は`status`（enum）と`shortageMonth`（int?）の2フィールドのみを持ち、日本語文言・アイコン・色などの表示情報は一切持たない。

### 1B.2: ひより助言候補の選定

新規ファイル `lib/game/public_demo/public_demo_cash_advice_selector.dart` に、純粋selector `PublicDemoCashAdviceSelector.select(...)` を追加した。

**入力**: `cashStatus: PublicDemoCashStatusPresentation`（1B.1の出力）、`workflow: PublicDemoWorkflowState`、`state: PublicDemoState`（読み取り専用。書き込みは一切行わない）。

**出力**: `PublicDemoCashAdviceCandidate?`（最大1件、または`null`）。候補は以下の4フィールドのみを持つ。

- `employeeId: String` — 対象社員ID（`PublicDemoEngineerSales.id`）。
- `actionType: PublicDemoAdviceActionType` — 推奨アクション種別（後述の3値のみ）。
- `shortageMonth: int` — `cashStatus.shortageMonth`をそのまま保持（再計算なし）。
- `reason: PublicDemoAdviceReason` — なぜこの助言を出すかの理由コード。

**shortageのときだけ動作**: `cashStatus.status != PublicDemoCashStatus.shortage`（`safe`／`unavailable`）では常に`null`を返す。

**既存workflow APIとステージ定義の確認**: `lib/game/public_demo/public_demo_workflow_state.dart`（`PublicDemoWorkflowState`の全域）と`lib/game/public_demo/public_demo_sales.dart`（`PublicDemoSalesStage` enum: `waiting → skillSheet → selling → introduced → partnerInterviewPassed/Failed → clientInterviewPassed/Failed → ordered`）を読み、既に存在する遷移メソッド（`startSkillSheetReview`／`beginSelling`）とその`from`ステージ集合だけを根拠にした。新しい画面・新しいアクションは一切追加していない。

**優先順の実装**（`workflow.engineers`のリスト順を1回だけ走査。決定的）:

1. **待機社員の既存次アクション** — `stage == waiting`の社員のうち、リスト順で最初に見つかった1名に対して:
   - `state.engineerRuntimes`から対応するruntimeを引き、`PublicDemoEngineerRuntime.isReadyForFieldSales`（既存の実在フラグ。`actualCapability >= fieldSalesCapabilityRequirement`）が`false`かつ`state.trainingSelections`に未登録なら、`actionType = startInternalTraining`（既存の`PublicDemoInternalTrainingTransaction`が既に提供する選択可能なアクション）、`reason = waitingBelowFieldSalesReadiness`。
   - それ以外（既にfield-sales ready、または既に研修選択済み）なら、`actionType = confirmSkillSheet`（既存の`PublicDemoWorkflowState.startSkillSheetReview`）、`reason = waitingReadyForSkillSheet`。
2. **営業開始可能だが未営業の社員** — 1で誰も見つからなかった場合のみ、`stage == skillSheet`（SkillSheet確認済み・一度も営業していない）の社員のうち、リスト順で最初の1名に対して`actionType = beginSelling`（既存の`PublicDemoWorkflowState.beginSelling`）、`reason = skillSheetReadyToBeginSelling`。
3. **それ以外は`null`** — `selling`／`introduced`／`partnerInterviewPassed`／`clientInterviewPassed`／`ordered`（既に営業中・選考中・参画済み）の社員は候補として一切選ばない。さらに`partnerInterviewFailed`／`clientInterviewFailed`（一度営業を試みて失敗した社員）も、`beginSelling`の`from`ステージ集合に技術的には含まれるが、「未営業」ではなく「再挑戦」にあたるため、意図的に候補から除外した（下記「既知の制約」参照）。1にも2にも該当する社員がいなければ`select`は`null`を返す。

**「もう一度営業開始」として選ばない**: 上記の通り、`selling`／`introduced`／面談結果待ち／`ordered`の社員はいかなる優先順でも候補にならない。

**必勝手順・成功率・将来収益の推定なし**: `select`が返すのは既存ステージ・既存runtime capability・既存training選択状況という、すべて既に確定した事実のみであり、将来の営業成功率や採用成功を一切参照・推定していない。

**決定的な選定順**: 優先順1・2ともに`workflow.engineers`（既存workflowが保持する社員順）をそのまま走査するため、同一入力に対して常に同じ候補を返す。

## 変更しない範囲の遵守

- `PublicDemoState`／`PublicDemoWorkflowState`／月次決算／財務計算／倒産・猶予判定：**読み取りのみ**。フィールド追加・メソッド変更は一切行っていない。
- save schema／workflowの状態遷移／採用・営業・面談の成功率：無変更。
- HOME Widget／Navigator／画面遷移／E2E／Playwright：無変更（触れていない）。
- Phase 2の案件Fit・面談理由・不合格理由：無変更（触れていない）。
- PR #136および無関係なファイル：無変更。

## 変更ファイル

- 追加: `lib/game/public_demo/public_demo_cash_status_presentation.dart`（Phase 1B.1、新規pure mapper）
- 追加: `lib/game/public_demo/public_demo_cash_advice_selector.dart`（Phase 1B.2、新規pure selector）
- 追加: `test/game/public_demo/public_demo_cash_status_presentation_test.dart`（focused test、6ケース）
- 追加: `test/game/public_demo/public_demo_cash_advice_selector_test.dart`（focused test、17ケース）
- 追加: 本report `docs/reports/SES_ISSUE-148B_Advice-Presenter_Result.md`

既存ファイルは一切変更していない。

## テスト結果

### 新規 focused test

`flutter test test/game/public_demo/public_demo_cash_status_presentation_test.dart test/game/public_demo/public_demo_cash_advice_selector_test.dart` — **23/23 pass**

対応するケース（Testsセクションの最低要件との対応）:

1. 予測が安全なら`safe`、不足月があれば`shortage`、空なら`unavailable`になる
   → `public_demo_cash_status_presentation_test.dart`の3ケースで確認。
2. `shortage`の不足月が改変されず渡る
   → 同ファイルで`presentation.shortageMonth`が`forecast.firstShortageMonth`と一致すること、直接構築した`PublicDemoCashForecastResult`でも改変されないことを確認。
3. 研修またはSkillSheet確認が必要な待機社員を、既存ステージに沿って選べる
   → `public_demo_cash_advice_selector_test.dart`「waiting employees before sales」グループで、`eng-02`（既定runtime capability 52 < 60閾値）は`startInternalTraining`、`eng-01`（既定capability 78）は`confirmSkillSheet`を選ぶことを確認。既に研修選択済みの`eng-02`は`confirmSkillSheet`へ切り替わることも確認。
4. 営業開始可能な未営業社員を選べる
   → 「sales-ready-but-unsold employee」グループで、`stage == skillSheet`の社員が`beginSelling`候補になることを確認。待機社員が同時にいる場合はそちらが優先されることも確認。
5. 営業中・選考中・参画済み社員を不適切な再営業候補にしない
   → 「no unsafe re-selling candidate」グループで、`selling`／`introduced`／`partnerInterviewFailed`／`partnerInterviewPassed`／`clientInterviewFailed`／`clientInterviewPassed`／`ordered`の7ステージすべてで`null`になることを個別に確認。
6. 安全・停止済み状態で助言候補を返さない
   → 「safe/unavailable」グループで、`safe`・`unavailable`いずれの`cashStatus`でも常に`null`を確認。
7. 同一入力で常に同じ候補になる
   → 「determinism and purity」グループで2回連続呼び出しの結果が一致することを確認。
8. mapper／選定処理が`state`と`workflow`を変更しない
   → 同グループで、呼び出し前後の`workflow.toJson()`/`state.toJson()`が不変であることを確認。

### Phase 1Aの資金予測テストと関連workflowテスト（回帰確認）

`flutter test` で以下9ファイルを実行 — **98/98 pass**（新規23件を含む）

- `public_demo_cash_status_presentation_test.dart`（新規）
- `public_demo_cash_advice_selector_test.dart`（新規）
- `public_demo_cash_forecast_test.dart`（Phase 1A、22ケース、無変更）
- `public_demo_workflow_state_test.dart`
- `public_demo_workflow_snapshot_test.dart`
- `public_demo_engineer_runtime_test.dart`（`isReadyForFieldSales`を利用したため）
- `public_demo_training_state_test.dart`（`trainingSelections`を利用したため）
- `public_demo_internal_training_transaction_test.dart`（`startInternalTraining`が指す既存transaction）
- `public_demo_growth_engine_test.dart`

さらに広く `test/game/public_demo/` ディレクトリ全体（55ファイル）を実行 — **496/496 pass**（回帰なし）。

### dart format

`dart format`（変更対象4ファイル）— 2ファイルを自動整形（生成時点でのフォーマット差分）、以降差分なし。

### flutter analyze

`flutter analyze` — **No issues found!**（17.2s）

### 実行環境について

セッション初期状態にFlutter SDKが存在しなかったため、Flutter公式リポジトリから`stable`チャンネル（取得時点の最新: `3.47.2`。CI（`.github/workflows/*.yml`）は`3.44.9`を固定指定）をshallow cloneして`/tmp/flutter_sdk`にセットアップした上で上記を実行した。`flutter pub get`実行時に`pubspec.lock`が本セッションのFlutterバージョン差分で書き換わったため、`git checkout -- pubspec.lock`で元に戻し、`pubspec.lock`は変更ファイルに含めていない。フルテスト・PlaywrightはPR CIへ一任し、本セッションでは実行していない。

## 判断根拠（設計上の主要な判断）

- **1B.1の状態判定順序**: `months.isEmpty`を`hasShortage`より先に判定することで、close-blocked状態（fiscal year completed／倒産等）が`unavailable`として`safe`と区別される。指示の「予測月が空（決算停止・年度完了など）」を文字通り満たす。
- **1B.2の対象社員の範囲**: `workflow.engineers`（創業社員＋入社済み中途社員が合流する既存の営業パイプライン、`PublicDemoSalesStage`）のみを対象とした。`workflow.applicants`が持つ入社前の別パイプライン（`PublicDemoApplicantStage`: `offerAccepted → preEntrySkillSheet → ... → juneOrdered`）は、まだ入社していない候補者向けの並行した仕組みであり、「社員」への助言としてはスコープ外と判断し、対象に含めていない（下記「既知の制約」参照）。
- **研修 vs SkillSheet確認の分岐根拠**: 指示文が「研修開始・SkillSheet確認など」を並記していたため、待機社員1名に対してどちらを推すか区別する既存の実在事実が必要だった。`PublicDemoEngineerRuntime.isReadyForFieldSales`（`state.engineerRuntimes`が既に保持する、既存のfield-sales閾値判定）を用いることで、将来予測を一切行わずに区別できると判断した。これは`PublicDemoState`の読み取りであり、変更禁止範囲（`PublicDemoState`の変更）には抵触しない。
- **`partnerInterviewFailed`/`clientInterviewFailed`を候補から除外した理由**: `PublicDemoWorkflowState.beginSelling`の`from`ステージ集合には技術的にこの2つも含まれる（再挑戦は既存の正規遷移）。しかし優先順2の指示文言「営業開始可能だが**未営業**の社員」は文字通り一度も営業していない社員を指し、再挑戦はこれに該当しない。また「必勝手順・成功率の推定を返さない」という指示の趣旨に鑑み、失敗済みの再挑戦を積極的に推すことは「次はうまくいく」という暗黙の期待を伴いかねないため、安全側に倒してこの2ステージも候補から除外し、`null`側（③既に営業・選考中で安全な直接アクションを選べない扱い）に含めた。

## 既知の制約 / Known Issues

- **入社前applicantパイプラインは対象外**: `PublicDemoWorkflowState.applicants`が持つ入社前セールスパイプライン（`preEntrySkillSheet`／`preEntrySelling`等）の候補者は、本Phaseの助言選定対象に含めていない。将来これらも対象にする場合は、`workflow.engineers`と`workflow.applicants`をどう優先順で合流させるかの追加設計が必要になる。
- **`partnerInterviewFailed`/`clientInterviewFailed`は常に候補外**: 上記の通り意図的な設計判断だが、結果として「面談に失敗した社員への次アクション」はこのPhaseでは一切助言されない（`null`になる）。再挑戦を安全に助言する設計は本Phaseのスコープ外として持ち越した。
- **HOME Widget・文言・CTA連携は未実装**: 指示通り、本PRは`PublicDemoCashStatusPresentation`／`PublicDemoCashAdviceCandidate`という純粋モデルの追加までであり、これらを消費するUI層・日本語文言・CTA遷移は後続PRの対象。
- **`monthsAhead`が既定の3以外の場合の助言優先順は未検証**: 1B.2のテストはPhase 1Aの既定`shortageMonth`値をそのまま使っているが、より長い予測窓での優先順の妥当性は本Phaseでは検証していない（Phase 1A自体の制約を引き継ぐのみで、1B側で新たな制約を追加してはいない）。

## commit SHA

- Phase 1B.1 + 1B.2 実装（コード＋テスト＋report、単一commit）: `6d514203dbb2cbd2ab775355526d034ec941312f`

## PR URL

https://github.com/perusonao/smile_enjoy_story/pull/154

## Merge Readiness

- 変更はPhase 1B.1 + 1B.2のスコープ内（純粋モデル2件＋テストのみ）に収まっており、`PublicDemoState`／`PublicDemoWorkflowState`／save schema／HOME Widget／Navigator／E2E／Phase 2／PR #136には一切触れていない。
- `flutter analyze`・新規focused test（23件）・関連回帰テスト（`public_demo`ディレクトリ全体496件）がすべてgreenであることを確認済み。
- フルテスト・PlaywrightはPR CIでの実行に委ねる。
- **本PRはmergeしない**（ユーザー指示）。HOME Widget・文言表示・CTA遷移・Phase 2は本PRの対象外で、後続PRの課題として残る。
