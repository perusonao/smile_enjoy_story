# SES Issue #148 Phase 1A — 確定情報ベース資金予測SSOT 実装結果

## STATUS

Completed（Phase 1A スコープのみ。HOME表示・ひより文言・CTAは対象外）

## BASE / HEAD

- BASE: `origin/main` (`fcc6430a5e2a49dbb5cc0aea3c726c2ebec8498e`)
- 作業branch: `claude/issue-148-cash-forecast-uxf82u`
- HEAD: 本reportをコミットしたcommit（下記「commit SHA」参照）

## 実施内容

### 読んだ既存会計authority

Issue #148本体（HOME警告カード・ひより文言・Phase 2含む全体像）を読んだ上で、今回のタスク指示（Phase 1A: 予測SSOTのみ）に対応する既存の権威ロジックを次の順で確認した。

- `lib/game/public_demo/public_demo_state.dart` — `PublicDemoState`。`cash`／`pendingRevenue`（既存の固定30日回収ラグの売掛金）／`engineersAssigned`／`monthOpeningCash`／`summerBonusSelection`／`summerBonusPaid`／`isCloseBlocked`（倒産・年度完了ガード）のSSOT。
- `lib/game/public_demo/public_demo_revenue.dart` / `public_demo_revenue_payment.dart` — `PublicDemoRevenue.monthlyRevenueForAssignedCount`（参画エンジニア数からの月次売上計算）と`PublicDemoRevenuePayment.apply`（前月`pendingRevenue`を現金化し、今月分を新しい`pendingRevenue`として計上する30日サイト決済）。
- `lib/game/public_demo/public_demo_salary.dart` / `public_demo_salary_finance.dart` — `PublicDemoSalary.baselineMonthlyExpenses`（創業チーム給与＋固定費）と`PublicDemoSalaryFinance.monthlyExpenses`（baseline + 参画済み中途社員の給与、`month`指定で既存の確定済み昇給スケジュールを反映）。
- `lib/game/public_demo/public_demo_summer_bonus_payment.dart` / `public_demo_summer_bonus_plan.dart` — `PublicDemoSummerBonusPayment.calculateSummerBonus`（7月賞与額の計算）。実際の7月決算はこれに加えて支払可否（affordability）判定を持つが、予測は「このまま進めたら」の値を示すため可否判定は複製していない。
- `lib/game/public_demo/public_demo_monthly_close.dart` — 月次決算の共通entry point（`closeApril`/`closeMay`/`closeJune`/`closeJuly`/`closeOrdinaryMonth`）。売上決済→月次遷移→cash-flowサマリ記録の順序と、各月`monthlyExpenses`が「給与＋固定費」の合算で渡される契約を確認。
- `lib/game/public_demo/public_demo_financial_status.dart` — 倒産・資金ショート猶予・年度末失敗の状態遷移（今回変更なし。予測は`financialStatus`の遷移規則を再現せず、単純な「決算結果現金 < 0」だけを見る）。
- `lib/game/models/accounts_receivable.dart` / `lib/game/engine/finance_engine.dart` — 個別支払サイト付き売掛金モデルが存在するが、これはPublic Demoとは別の（`game_state.dart`/`game_engine.dart`側の）会計系統であり、`lib/main.dart`が起動するPublic Demo 0.1では未使用と確認。Public Demo 0.1の売掛金は`PublicDemoState.pendingRevenue`（単一値・固定1か月ラグ）がSSOTであり、本タスクはそちらを対象にした。

### 予測モデルの入力・出力・予測範囲

新規ファイル `lib/game/public_demo/public_demo_cash_forecast.dart` に `PublicDemoCashForecast.forecast(...)` を追加した。

**入力**

- `state: PublicDemoState` — 現在のゲーム状態（cash・pendingRevenue・engineersAssigned・summerBonusSelection・summerBonusPaid・isCloseBlockedを読む）。
- `workflow: PublicDemoWorkflowState` — authoritativeなworkflow全体。予測内部で`workflow.joinedApplicants`を導出する（Follow-up以降。詳細は「Follow-up: joinedApplicants authority統一」参照）。
- `monthsAhead`（既定値3）— 予測する決算回数。

**出力（`PublicDemoCashForecastResult`）**

- `months: List<PublicDemoCashForecastMonth>` — 予測した各回の決算結果（`month`／`openingCash`／`cashReceived`／`revenueRecognized`／`monthlyExpenses`／`bonusPaid`／`closingCash`）。
- `firstShortageMonth: int?` — 予測期間内で最初に`closingCash < 0`になった月（内部月番号4-15）。無ければ`null`。
- `hasShortage` / `isSafe` — `firstShortageMonth`の有無から導出される真偽値。
- `basis: PublicDemoCashForecastBasis`（現状`confirmedOnly`のみ）— 後続UIが「確定情報ベース」であることを表示できるようにするための明示マーカー。

**予測範囲**

「当月末から次の3回の月次精算」を、`state.month`を起点に`state.month, state.month+1, state.month+2`の3決算としてカバー（`monthsAhead`で変更可）。年度末（内部月15＝3月）を超える回はtruncateし、`state.isCloseBlocked`（倒産済み・年度完了済み）の場合は空の予測（安全側）を返す。

### 予測ロジックの設計判断（確定情報のみを使う）

- **参画エンジニア数（売上の元）は予測期間中一定**として扱う。将来の採用成功・案件通過による増減は「不確実な将来成功」であり混ぜない。これにより`PublicDemoRevenue.monthlyRevenueForAssignedCount`は毎回同じ値を返し、既存の30日サイト（`pendingRevenue`を1か月ずらして現金化）だけをそのまま繰り返し適用する。
- **給与・固定費**は`PublicDemoSalaryFinance.monthlyExpenses(baselineExpenses: PublicDemoSalary.baselineMonthlyExpenses, hires: joinedApplicants, month: closedMonth)`をそのまま呼び出す。既存の`hires`引数に渡す社員も「現時点で参画済み」のみとし、将来の内定・入社は含めない。`month`は各予測月をそのまま渡すため、参画済み社員の既に確定している昇給スケジュール（`applicant.salaryForMonth`）は正しく反映される。
- **7月賞与**は、予測が7月に到達し、かつ`state.summerBonusPaid`がまだ`false`の場合のみ、`state.summerBonusSelection`（現在選択中のプラン。既定`none`）を`PublicDemoSummerBonusPayment.calculateSummerBonus`にそのまま渡して計算する。実際の7月決算が持つ「支払不能なプランは決算ごと拒否する」という可否判定は、予測では意図的に複製していない — 予測の目的は「このまま進めたら資金がどうなるか」を示すことであり、実際の決算が持つブロック挙動を先取りして隠すと、むしろ危険を見せられなくなるため。
- **現金マイナス判定**は`PublicDemoFinancialStatus`の資金ショート猶予・倒産・年度末失敗の状態遷移を再現せず、単純に各予測月の`closingCash < 0`だけを見る。Phase 1Aの指示「「注意」「危険」など恣意的な閾値は増やさない」に沿い、猶予期間などの解釈を追加しない生の事実のみを返す。

### 実際の月次精算との一致方法

新規計算式は一切書いていない。既存の3つの純粋関数をそのまま呼び出すだけで構成した。

- `PublicDemoRevenue.monthlyRevenueForAssignedCount` — 売上認識。
- `PublicDemoSalaryFinance.monthlyExpenses` — 給与＋固定費（`PublicDemoMonthlyClose`の各`closeXxx`が受け取る`monthlyExpenses`と同じ計算）。
- `PublicDemoSummerBonusPayment.calculateSummerBonus` — 7月賞与額。

テストでは、上記の値が実際の`PublicDemoMonthlyClose.closeApril`/`closeOrdinaryMonth`の結果と一致することを直接比較している（後述）。UI側の会計計算は追加していない（UI Widgetでの独自計算はゼロ）。

## 変更ファイル

- 追加: `lib/game/public_demo/public_demo_cash_forecast.dart`（新規、純粋モデルのみ。既存ファイルへの変更なし）
- 追加: `test/game/public_demo/public_demo_cash_forecast_test.dart`（focused test。Follow-upで18ケースに拡張）
- 追加: 本report `docs/reports/SES_ISSUE-148A_Cash-Forecast_Result.md`

既存ファイル（`PublicDemoState`／`PublicDemoMonthlyClose`／`PublicDemoRevenuePayment`／`PublicDemoSalaryFinance`／`PublicDemoSummerBonusPayment`／`PublicDemoWorkflowState`／save schema／PR #136関連）は一切変更していない。Follow-upも`public_demo_cash_forecast.dart`と対応するテストのみを変更している。

## テスト結果

### 新規 focused test（`test/game/public_demo/public_demo_cash_forecast_test.dart`）

`flutter test test/game/public_demo/public_demo_cash_forecast_test.dart` — **15/15 pass**

対応するケース（Testsセクションの最低要件との対応）：

1. 売掛金の回収が支払サイトどおり予測へ反映される
   → 「AR collection」グループ：今月`cashReceived`が前月`pendingRevenue`、来月`cashReceived`が今月`revenueRecognized`と一致することを確認。
2. 給与・固定費・既存の賞与予定が、実際の月次精算と同じ月へ反映される
   → 「matches the real monthly close」グループ：予測の`monthlyExpenses`/`closingCash`が`PublicDemoMonthlyClose.closeApril`/`closeOrdinaryMonth`の実結果と一致すること、参画済み中途社員の給与が反映されること、7月賞与が選択プラン通りに7月枠にのみ計上され、支払済みなら二重計上されないことを確認。
3. 待機が続く既知シナリオで、資金不足になる最初の月を返す
   → 「shortage detection」グループの該当ケースで`firstShortageMonth`が正しい月（5月）を返すことを確認。
4. 確定済みの回収があるシナリオで、資金不足判定が誤って出ない
   → 同グループの該当ケースで`hasShortage`が`false`、全月`closingCash >= 0`を確認。
5. 予測処理がゲーム状態を変更しない
   → 「purity」グループで`state.toJson()`が呼び出し前後で不変であること、同一入力に対する決定性を確認。
6. 既存の倒産判定・月末処理・save schemaに回帰がない
   → 下記の既存 focused test を再実行し、全件green。

追加で、close-blocked（倒産済み・年度完了済み）状態からの空・安全な予測、年度末（3月）でのwindow truncationも確認済み。

### 既存 focused test（回帰確認）

`flutter test` で以下13ファイルを実行 — **133/133 pass**

- `public_demo_revenue_payment_test.dart`
- `public_demo_salary_finance_test.dart`
- `public_demo_salary_test.dart`
- `public_demo_summer_bonus_payment_test.dart`
- `public_demo_monthly_close_test.dart`
- `public_demo_monthly_close_ordinary_month_test.dart`
- `public_demo_monthly_close_revenue_test.dart`
- `public_demo_financial_status_test.dart`（倒産・資金ショート猶予・年度末失敗の全契約含む）
- `public_demo_state_test.dart`
- `public_demo_save_codec_test.dart`
- `public_demo_fiscal_year_completion_lock_test.dart`
- `public_demo_fiscal_year_save_test.dart`
- `public_demo_save_service_test.dart`（save分離を含む）

### flutter analyze

`flutter analyze` — **No issues found!**（14.2s）

### 実行環境について

セッション初期状態にFlutter SDKが存在しなかったため、Flutter公式リポジトリから`3.44.9`（CI: `.github/workflows/*.yml`が指定するバージョンと同一）をshallow cloneして`/opt/flutter-sdk`にセットアップした上で上記を実行した。フルテスト・PlaywrightはPR CIへ一任し、本セッションでは実行していない。

## 未解決事項 / Known Issues

- 本モデルはPhase 1Aのスコープ通り、HOMEへの警告カード表示・ひよりの文言/CTA・Phase 2（案件Fit詳細、面談選択肢の狙い表示等）を一切含まない。後続PRでこの`PublicDemoCashForecast`を消費するUI層を実装する必要がある。
- 7月賞与の予測値は、実際の決算が持つ「支払不能なら決算自体を拒否する」というブロック挙動を再現していない（意図的な設計判断。上記「予測ロジックの設計判断」参照）。後続UIで「このプランのままだと資金不足になる」という警告と、「実際にはその決算はブロックされる」という違いを混同しないよう文言設計が必要（Phase 1B/2の課題）。
- `monthsAhead`が3を超える場合の年度末truncation・close-blocked時の空予測はテスト済みだが、将来UIがどの`monthsAhead`を使うかは未確定（Issue #148本文は「最低でも3回」とだけ指定）。
- `lib/game/models/accounts_receivable.dart`（`AccountsReceivable`/`ArStatus`、支払サイト別売掛金）はPublic Demo 0.1では未使用の別系統（`game_engine.dart`/`finance_engine.dart`側）であることを確認済みだが、リポジトリ内に両方の会計系統が併存している事実は今回の変更範囲外として現状のまま残した。（Follow-up時点でも未解決）

## Follow-up: joinedApplicants authority統一

### authority不一致の内容

初回実装の`PublicDemoCashForecast.forecast`は`joinedApplicants: Iterable<PublicDemoApplicant>`を外部から直接受け取っていた。これは同じ「入社済み中途社員一覧」を渡す既存の`PublicDemoSummerBonusPayment`/`PublicDemoMonthlyClose.closeJuly`とは異なり、`PublicDemoMonthlyClose.closeMay`が採用しているauthority方針（呼び出し側に`joinedApplicants`という生の subset 選択肢を与えず、authoritativeな`PublicDemoWorkflowState`全体を受け取ってその内部で`workflow.joinedApplicants`を導出する）とズレていた。

このズレにより、呼び出し側が

- 入社済み社員の一部だけを渡す
- 空配列を渡す
- 古いスナップショットを渡す

のいずれも型システム上可能で、実際の月次決算（`workflow.joinedApplicants`を必ず使う）と予測給与が乖離しうる状態だった。

### 修正方法

- `PublicDemoCashForecast.forecast`のシグネチャから`joinedApplicants`パラメータを廃止し、代わりに`workflow: PublicDemoWorkflowState`を必須paramとして受け取るよう変更（`lib/game/public_demo/public_demo_cash_forecast.dart`）。
- 予測処理内部で`workflow.joinedApplicants`（`PublicDemoWorkflowState`が公開する既存の導出getter、`applicants.where((a) => a.hasJoined)`）を1回だけ取得し、それを`PublicDemoSalaryFinance.monthlyExpenses`と`PublicDemoSummerBonusPayment.calculateSummerBonus`双方へそのまま渡す。
- `PublicDemoMonthlyClose.closeMay`と同じ形（「対象社員のsubsetを呼び出し側が選べない」API）になり、呼び出し側がpayrollに含める社員を個別に選ぶ手段はAPI上存在しない。
- クラスdocコメントに、`closeMay`と同じauthority契約であることと、その理由（stale/空/部分集合を渡す余地を型で塞ぐこと）を明記。
- 予測モデルの計算式・予測期間・UI・ひより文言・CTA・ゲームバランスは変更していない。PR #136も変更していない。

### 追加・更新したテスト

`test/game/public_demo/public_demo_cash_forecast_test.dart`を更新（既存15ケースを新API`workflow:`へ移行、全て維持）した上で、次の3ケースを追加した（計18ケース）。

1. **入社済み中途社員の給与が必ず予測へ入る** — `PublicDemoWorkflowState(applicants: [2名の入社済applicant], engineers: [])`を渡し、両名の給与が`monthlyExpenses`合計に含まれることを確認（「every joined mid-career employee ... is always included, with no way to pass a subset」）。
2. **呼び出し側が入社済み社員を省略する余地がAPI上なくなっている** — 上記1のケース自体が、`workflow`という単一の authoritative な入力からしか給与を取得できないこと（部分集合を渡す独立したパラメータが存在しないこと）を実証する。加えて、内定承諾済みだが未入社（`hasJoined == false`）のapplicantと、面談すら受けていない`applied`ステージのみのapplicantをそれぞれworkflowに含めても、その給与が予測へ一切混入しないことを確認（「a pre-join applicant ... is excluded」「an applicant with no interview/offer/join at all ... never contributes」）。
3. **実際の月次決算と、同じworkflowを使う予測の給与・賞与・closingCashが一致する** — 入社済みapplicant1名を含む`workflow`から`workflow.joinedApplicants`を`PublicDemoMonthlyClose.closeJuly`へ渡した実決算と、同じ`workflow`を渡した予測の7月分の給与・賞与・closingCashが一致することを確認（「the July forecast, including a joined engineer bonus-eligible salary, matches PublicDemoMonthlyClose.closeJuly exactly」）。既存の`closeApril`/`closeOrdinaryMonth`との一致テスト2件もそのまま維持。

既存15件は全てAPI呼び出し部分（`joinedApplicants: [...]` → `workflow: PublicDemoWorkflowState(applicants: [...], engineers: [])`）のみ更新し、期待値・アサーションは変更していない。

### 検証結果

- `flutter analyze` — **No issues found!**
- `flutter test test/game/public_demo/public_demo_cash_forecast_test.dart` — **18/18 pass**
- 既存 focused test 14ファイル（前回13ファイル＋`public_demo_workflow_state_test.dart`を追加）— **134/134 pass**（`public_demo_revenue_payment_test.dart`／`public_demo_salary_finance_test.dart`／`public_demo_salary_test.dart`／`public_demo_summer_bonus_payment_test.dart`／`public_demo_monthly_close_test.dart`／`public_demo_monthly_close_ordinary_month_test.dart`／`public_demo_monthly_close_revenue_test.dart`／`public_demo_financial_status_test.dart`／`public_demo_state_test.dart`／`public_demo_save_codec_test.dart`／`public_demo_fiscal_year_completion_lock_test.dart`／`public_demo_fiscal_year_save_test.dart`／`public_demo_workflow_state_test.dart`／`public_demo_save_service_test.dart`）
- フルテスト・PlaywrightはPR CIへ一任（本セッションでは未実行）。

`PublicDemoCashForecast`は本Follow-up時点でもまだUI層から消費されていない（`grep`で確認済み）ため、この破壊的シグネチャ変更が既存の呼び出し元へ与える影響はない。

## commit SHA

（コミット後に追記）

## PR / Merge Readiness

- 変更はPhase 1Aのスコープ内（純粋モデル＋テストのみ）に収まっており、既存の会計・save schema・PR #136・採用/営業/面談成功率には一切触れていない。
- `flutter analyze`・関連focused test（新規18件＋既存134件）が全てgreenであることを確認済み。
- フルテスト・PlaywrightはPR CIでの実行に委ねる。
- HOME UI・ひより連携・Phase 2は本PRの対象外であり、Merge可能と判断する（CI green確認後）。
