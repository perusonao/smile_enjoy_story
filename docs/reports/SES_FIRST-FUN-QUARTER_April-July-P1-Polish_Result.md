# SES First Fun Quarter — April–July P1 Polish (Result Report)

Status: **Implemented, self-hardened, focused + full public_demo regression suites green.**

## Base main SHA

`git fetch origin` was run at session start. `origin/main`（`refs/heads/main`）was
**`f683b7e38270978fd2a263e62f6a350da8d3bef4`**（PR #260 "Parallel Sales Phase 1C" のマージコミット）—
指定された期待SHAと完全一致（drift無し）。作業ブランチ
`claude/ses-first-fun-quarter-p1-fqw6ca` はこの `origin/main` から新規作成した。

## Final HEAD SHA

`2b220aac65ec5f0cc54f9e5c8e74a539f760510a`（実装コミット。本PR: https://github.com/perusonao/smile_enjoy_story/pull/261）

## Fresh Audit（今回の判断根拠）

Audit #1（56/100・Verdict B、commit `e46efba` 時点）以降、PR #260 Phase1C が
main にマージ済み。旧Audit #1のFindingをそのまま再実装せず、**最新main
（`f683b7e3`）の実装をコードレベルで再監査**した。監査は4本の独立した読み取り専用調査
（社員数/役割、入社前候補可視化、研修CTA、面談フロー）として実施し、结果は下記の
Before/After節にまとめた。

## Audit #1 各P1の Before / After

### 1. 初期社員・社員数の理解

**Before（Fresh Audit確認事項）**
- HOMEの「社員」KPI（`HomeDashboardDisplayData.totalEmployeeCount`）は
  `engineerCount + adminCount`（技術者2名＋総務1名＝3名）を表示する一方、
  社員タブの`_employeeRosterSection`は`workflow.engineers`（技術者のみ）の
  `合計`行を表示していた（2名）。**同じ「社員」という言葉の下で異なる数字が
  出る根本原因**は、総務担当（HOMEナビゲーターの佐倉ひより）が
  ロースター上の1カードとしては一切表示されないこと（Issue #122で
  既に文書化済みの既知の設計上の理由）。
- 佐藤健（eng-01）・鈴木葵（eng-02）はどちらも一般の`PublicDemoEngineerSales`
  として定義され、「創業社員である」ことを示すUI文言は皆無だった。
- 技術者/総務を区別するdomainのenum/roleフィールドは存在しない
  （総務は`PublicDemoState.adminCount`という素のint、技術者は
  `PublicDemoEngineerSales`という別クラス — 混同させる余地は元々ない構造だが、
  数字の整合性だけが取れていなかった）。
- 「営業可能 N名／研修が必要 N名」の要約行は存在しなかったが、
  同じ判定を行う`PublicDemoEmployeeStatusResolver`/`isReadyForFieldSales`
  は既存で、社員一覧の各行バッジも同じ関数から描画されていた。

**After（実装内容）**
- 社員タブの技術者合計行を「技術者: 待機N・参画中N・合計N」に改名し、
  その直下にHOMEの「社員」数との内訳を明記する新しい説明行を追加
  （`HOMEの「社員 N名」には、上の技術者N名に加えて総務の佐倉 ひより（1名）が
  含まれます。総務はこの一覧には表示されません。`）。データauthorityは
  一切増やしていない（`s.adminCount`と`HomeNavigatorIdentity.name`という
  既存の値をそのまま参照）。
- 社員一覧の各カード（`_employeeRosterCard`）に、`publicDemoInitialEngineers`
  （既存の創業エンジニア定数配列）のid一致で「創業社員・技術者」ラベルを追加。
  新しいdomainフィールドなし、既存の定数配列を参照するのみ。
- 社員一覧セクションに「営業可能 N名 ／ 研修が必要 N名」の要約行を追加。
  各カードのバッジと**同じ**`_employeeStatusDisplayFor(e).label`を数えているため、
  カードの表示と要約が食い違うことは構造的にありえない。

### 2. 入社決定済み・入社前候補の可視化

**Before（Fresh Audit確認事項）**
- 内定承諾済みの応募者は`workflow.applicants`から一切消えない
  （新規のcandidate/employee二重authorityは元から存在しない）。採用/営業タブの
  `_salesApplicantProgressCards`は既に`_applicantLifecycleBucket`で
  「結果待ち・入社予定」という見出しの下に、まだ入社していない・
  かつ次に打てるアクションが無い応募者（未経験入社者の`offerAccepted`、
  `juneOrdered`、`preEntryPartnerFailed`/`preEntryClientFailed`）を
  グループ化して表示していた（Issue #245 Finding #13で実装済み）。
  つまり「消える」バグ自体は存在しなかった。
- ただし、この可視化は**採用/営業タブの中の一見出し**に限定されており、
  「今、会社にいる/入る人は誰か」を確認する最も自然な場所である
  **社員タブには一切表示されない**——初見プレイヤーが社員タブだけを見ると、
  「内定を出したのに、この人はどこに行った？」となる導線の欠落があった。
  また「○月入社予定」という具体的な月表示は無かった（月次レポートの
  事後通知「来月は○○が入社予定です」はあったが、事前の常時表示ではない）。

**After（実装内容）**
- 社員タブに新セクション「入社予定」（`_pendingJoinRosterSection`）を追加。
  `workflow.applicants`のうち`!hasJoined && _applicantLifecycleBucket(a) ==
  awaitingJoin`を満たす応募者を、既存の採用タブと**まったく同じbucket判定**で
  読み出して表示する——新しいcandidate/employeeレコードは一切作らず、
  既存の`PublicDemoApplicant`をもう一箇所で読むだけ（二重authority禁止を厳守）。
  各カードに氏名・概要・「○月入社予定」バッジ（`publicDemoMonthLabel(s.month
  + 1)`、既存のmonth-labelヘルパーを再利用）を表示。
- 入社は既存の`PublicDemoWorkflowState.joinAcceptedForFiscalClose`
  （毎月の月次締めで呼ばれる）でのみ発生するため、この新セクションは
  社員一覧セクションと矛盾しない：入社した瞬間にこのセクションから消え、
  社員一覧に現れる。
- save/reload（`toJson`/`fromJson`往復）、月境界（closeMay前後）、
  重複締め（closeMayを2回呼んでも二重入社しない）を新規テストで確認済み
  （後述）。

### 3. 研修CTAの説明

**Before（Fresh Audit確認事項）**
- 「skillFitが営業可能基準未満だと研修ボタンが消える」という仮説を
  コードレベルで検証した結果、**そのような結合は存在しなかった**——
  `PublicDemoInternalTrainingTransaction`にskillFit/actualCapabilityの
  チェックは一切なく、研修カードの表示条件（`assigned`/`isCloseBlocked`/
  `selected`）とスキルフィット閾値（`isReadyForFieldSales`、
  営業開始ロックバナー用）は完全に独立した別々のコードパスだった。
  プレイヤーが感じた「消えた」体験は、実際には「案件に参画した」
  （カードごと非表示になる、正当な仕様）か「今月すでに研修を選択済み」
  （ボタンが文言に置き換わる、正当な仕様、かつ既に説明文あり）の
  いずれかだったと推測される。
- ただし監査の過程で、**別の実在するギャップ**を発見した：
  `internalTrainingCard`の`showAction`ゲートは`s.isCloseBlocked`のみを見ており、
  `s.isFinanciallyRestricted`（資金繰り悪化のcashShortage猶予期間）を
  見ていなかった。一方`PublicDemoInternalTrainingTransaction.execute`は
  既にこの状態を`blockedByFinancialShortage`として拒否する
  （FINANCE-FAILURE-1A+1B §13/16）。`PublicDemoAggregate
  .selectInternalTraining`はこの拒否に対して**意図的に無言のno-op**
  （このクラスの他のコマンドと同じ設計）を返すため、資金繰り悪化中に
  「研修する」を押しても**何の説明もなく何も起きない**という、
  ユーザーが報告した症状と一致する挙動が実在した。
- この`blockedByFinancialShortage`ルール自体には、domain層の直接テストが
  1件も存在しなかった（before今回）。

**After（実装内容）**
- `showAction`に`!s.isFinanciallyRestricted`を追加（研修ルール自体は一切
  変更していない——既存のdomain rule にUIゲートを一致させただけ）。
- 資金繰り悪化中はボタンを非表示にし、代わりに理由と回復条件を明記する
  説明文を追加：「資金繰りが悪化しているため、今月は社内研修を利用できません。
  現預金が回復すると再び利用できます。」（既存の求人媒体の
  `blockedByFinancialShortage`メッセージと同じ言い回しパターンを踏襲）。
- domain層に`blockedByFinancialShortage`の直接テストを新規追加、
  UI層に「カード自体は消えない・ボタンだけ消える・理由が出る」の
  widgetテストを新規追加（後述）。

### 4. 面談フローの理解改善

**Before（Fresh Audit確認事項）**
- 1件目の対話式面談（`PublicDemoProjectInterviewDialog`、質問→フォロー
  アップの本格ミニゲーム）と、Phase1cの「候補案件を比較」画面から
  2件目以降に実施する面談（`PublicDemoAggregate
  .evaluatePartnerInterviewForCandidate`/`evaluateClientInterviewForCandidate`、
  `PublicDemoInterviewEvaluator`による確定的な再評価、ダイアログ無し）は、
  Phase1C自身のResult Reportが明記する通り**意図的な設計上の制約**
  （対話式ミニゲームは単一カーソルの`PublicDemoEngineerSales.stage`上に
  構築されており、Main Game統合なし・大規模domain再設計なしという
  ガードレール内では複線化が構造的に不可能）——今回のP1範囲でも
  この制約は変わらないため、**統一しない**という判断は妥当と確認した。
- ただしラベル文言を比較した結果：
  - 客先面談側は「客先面談」の語幹は共通だが、比較画面は
    「客先面談を実施/再実施」と動詞が付く。
  - パートナー面談側は**語自体が違う**——対話式は「上位会社面談」、
    比較画面は「パートナー面談」——同じ処理を指す2つの用語が併存していた
    （リポジトリ全体を検索した結果、「上位会社面談」はUI/ドメイン/テスト
    47ファイルに登場する既存の標準用語、「パートナー面談」は比較画面
    本体とそのテストの2ファイルのみで使われる新しい用語だった）。
  - 比較画面には、面談合格/不合格後の「次に何をすべきか」を説明する文が
    **一切無かった**（対話式は「次は客先面談へ進みます」等を都度表示する）。
    ステータスバッジとボタンの切り替えのみで、文章での説明はゼロ。
  - なぜ2件目以降が簡易判定になるのかを説明する文言も皆無だった。

**After（実装内容）**
- 比較画面のラベルを「パートナー面談」→「上位会社面談」に統一
  （バッジ・面談結果表示・ボタン文言のすべて）——**大規模domain再設計を伴わない、
  UI文言のみの統一**。挙動（確定的評価 vs 対話式）自体は変更していない。
- 比較画面の先頭に、なぜここでの面談が対話形式でないかを説明する
  一度きりの案内文を追加。
- 各候補カードに、面談結果に応じた「何が起きたか→次に何をすべきか」の
  一文（`_nextStepCaption`）を追加——対話式画面が既に行っている説明と
  同じ情報を、確定的評価パスにも初めて提供する。
- 大規模domain再設計は行っていない（新しい面談評価式・新しいstageは
  一切追加していない）。

### 5. PR #260 Phase1Cとの整合 + 画像

**Before（Fresh Audit確認事項）**
- 「候補案件を比較」→面談→受注選択のフローは、コードレベル・テストレベル
  ともに正しく最新mainに繋がっていることを確認した（既存の
  `public_demo_offer_comparison_screen_test.dart`の6テストは変更前から
  全てgreen）。旧Audit #1が指摘した「案件比較UIが未接続」は完全に
  解消済みであることを確認し、**再実装は一切行っていない**。
- 一方、画像面で**実在するギャップ**を発見した：受注（`受注`）は
  この作品で最重要のお祝いモーメントであり、既存の単一候補向け
  「受注」ボタン（`_recordEngineerOrder`/`_recordApplicantJuneOrder`）は
  `order_decision.jpg`を使った`PublicDemoEventDialog`のお祝い演出を
  必ず表示する。しかし**Phase1cの「候補案件を比較」画面経由の受注
  （`recordOfferCandidateOrder`）だけは、この演出が一切無く**、
  アグリゲートを無言でコミットするだけだった——ゲーム内で唯一
  「受注成功」の視覚的お祝いが無い受注経路になっていた。

**After（実装内容）**
- Phase1c経由の受注にも、既存の`order_decision.jpg`と
  `PublicDemoEventDialog`をそのまま再利用したお祝い演出を追加
  （`_recordOfferCandidateOrder`、新しい画像アセットは一切生成/追加していない）。
  `PublicDemoOfferComparisonScreen.onOrder`のコールバック型を`void`から
  `Future<void>`に変更し、親画面のダイアログ表示完了を`await`できるように
  した——ドメインのorder authority自体は無変更。
- 360x800/390x844のoverflow確認は既存テストが継続green（後述）。

## PR #260によって既に解消済みだった項目（旧Audit #1 Findingのうち再実装しなかったもの）

- 「案件比較UIが未接続」（旧Audit #1の指摘）: PR #260 Phase1Cで
  `PublicDemoOfferComparisonScreen`として実装済み・配線済み。今回のFresh
  Auditで再確認し、再実装は行っていない。
- 「候補案件ごとの受注選択」: `recordOfferCandidateOrder`
  （候補ごとのproject指定型order authority）としてPhase1Cで実装済み。無変更
  （画像演出の追加のみ、authority自体は無変更）。

## 実装内容（変更ファイル）

- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
  - `_employeeRosterSection`: 技術者合計行のラベル変更＋HOME社員数との
    内訳説明行を追加＋営業可能/研修が必要サマリー行を追加。
  - `_employeeRosterCard`: 創業社員ラベルを追加。
  - `_pendingJoinRosterSection`/`_pendingJoinCard`（新規）: 「入社予定」
    セクション。
  - `internalTrainingCard`: `isFinanciallyRestricted`ゲート追加＋説明文追加。
  - `_recordOfferCandidateOrder`（新規）: Phase1c受注に受注成功演出を追加。
- `lib/ui/public_demo/public_demo_offer_comparison_screen.dart`
  - `onOrder`コールバック型を`Future<void> Function`に変更。
  - 「パートナー面談」→「上位会社面談」へ用語統一。
  - 比較画面冒頭の説明文、各カードの`_nextStepCaption`（次に何をすべきか）
    を追加。
- `test/game/public_demo/public_demo_internal_training_transaction_test.dart`
  （変更）: `blockedByFinancialShortage`の直接テストを追加。
- `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` /
  `public_demo_employee_visual_complete_test.dart`（変更）: ロースターの
  合計行ラベル変更に伴う期待値更新（`技術者: 待機...`、実際のカウント値は無変更）。
- `test/ui/public_demo/public_demo_offer_comparison_screen_test.dart`
  （変更）: 受注成功演出の表示・解除を組み込んだ回帰テスト追加。
- `test/ui/public_demo/public_demo_employee_pending_join_test.dart`（新規）:
  「入社予定」セクションのUIテスト（表示、月境界、重複締め、save/reload、
  360/390pxオーバーフロー）。
- `test/ui/public_demo/public_demo_internal_training_financial_restriction_test.dart`
  （新規）: 研修CTAの資金繰り悪化時挙動のUIテスト。
- `docs/reports/SES_FIRST-FUN-QUARTER_April-July-P1-Polish_Result.md`
  （新規、本ファイル）。

他のproduction/testファイルは無変更。save schema・既存authority・
Main Game・Aug-Feb late-game・Year-end関連ファイルへの変更は一切なし。

## 画像 GOOD/WEAK/MISSING一覧（April–July範囲、public demoビルドのみ）

範囲は`lib/ui/public_demo/`・`lib/game/public_demo/`から到達可能な
画面/イベントに限定し、Main Game（`lib/presentation/home/home_shell_page.dart`
経由の別モジュール）・Aug-Feb Late-game（`eventCompanyManagement`＝
Founder Follow-up、Issue #167）は対象外とした。

### GOOD（配線済み・用途に適合）

| asset | 使用画面/イベント | 備考 |
|---|---|---|
| `events/order_decision.jpg` | 受注成功（単一候補経路＋今回Phase1c経路の両方） | 最優先項目。**今回のPRで両経路に統一配線**。再生成不要、既存アセットで十分機能する。 |
| `events/recruitment_application.jpg` | 4月締め→5月への遷移（「採用は求人媒体から始まります」） | 適切。 |
| `events/first_assignment.jpg` | 初回参画（入社・案件参画開始） | 適切。 |
| `navigator/navigator_normal.webp` / `navigator_caution.webp` / `navigator_home_compact.webp` | HOMEナビゲーター（佐倉ひより） | 全月常時表示、適切。 |
| `characters/engineer_midlevel.jpg`（eng-01佐藤）/ `engineer_junior.jpg`（eng-02鈴木）/ `engineer_veteran.jpg`（汎用プール） | HOME Office Stage・社員一覧アバター | 適切。 |
| `locations/office_day_home_banner.jpg` | HOME Office Stageの背景バナー | 適切。 |

### WEAK（配線済みだが視覚的に弱い/差別化不足）

| asset | 使用画面 | 課題 |
|---|---|---|
| `events/client_interview.jpg` | パートナー面談結果・客先面談結果の**両方**（4箇所） | 同じ写真が「上位会社面談」「客先面談」という異なる2つの面談種別に無差別に再利用されている。機能上は正しいが、プレイヤーがどちらの面談の結果を見ているか視覚的に区別できない。 |

### MISSING（今回のPRで修正済みの実在ギャップ）

| 症状 | 修正 |
|---|---|
| Phase1c（候補案件を比較）経由の受注に`order_decision.jpg`のお祝い演出が一切無かった | 本PRで`order_decision.jpg`を再利用して修正済み（新規アセット不要）。 |

### 未使用アセット（現状ではApril–July範囲のどの画面にも一切参照されていない）

以下はコードベース全体を検索した結果、**April–Julyのpublic demoフロー
からは一切参照されていない**（Main Game向け、あるいは将来のAug-Feb機能向けに
確保されている可能性がある）。今回は「不足」として扱わず、現状維持とした
（新機能追加は本タスクの禁止事項）：
`characters/sales_male.jpg`, `sales_female.jpg`, `client_contact_person.jpg`,
`recruiter.jpg`, `applicant_engineer.jpg`, `events/system_incident.jpg`,
`events/client_contact.jpg`（Main Game `event_image_mapper.dart`が使用）,
`locations/meeting_room.jpg`, `office_night.jpg`, `cafe_meeting.jpg`,
`locations/office_day.jpg`（Main Game `office_stage_section.dart`が使用）。

## 追加で画像生成が必要なasset仕様/prompt（提案・任意）

Claude Code側では高品質な新規画像を生成できないため、以下は**実装せず
仕様のみ**を記載する。優先度は「WEAK」項目の解消（面談種別の視覚的差別化）
一件のみ——他はApril–July範囲で緊急性なしと判断した。

### 提案1: `events/partner_interview.jpg`（新規、任意・低優先）

- **使用画面**: パートナー面談（上位会社面談）結果ダイアログのみ
  （`PublicDemoInterviewResultDialog`のパートナー面談分岐、
  `client_interview.jpg`との差し替え候補）。客先面談側は
  `client_interview.jpg`のまま維持。
- **推奨サイズ/aspect ratio**: 既存`client_interview.jpg`と同一
  （UI材料デザイン合成画像からの切り出し規約に合わせ、横長 16:9 相当、
  想定表示幅 ~360-390px論理ピクセル基準）。
- **構図**: 会議室で技術者と「上位会社（元請け）」の担当者が対面で
  名刺交換または着席商談している構図。既存`client_interview.jpg`が
  技術者×客先の対面構図であるのに対し、こちらは技術者×元請け営業担当
  という一段階手前の関係性が一目で分かる人数・距離感にする
  （例: スーツ姿の元請け担当者1名+技術者1名、名刺やノートPCを挟んだ
  やや事務的な距離感）。
- **キャラクター**: 技術者側は`characters/engineer_junior.jpg`/
  `engineer_midlevel.jpg`と同一トーンの人物（顔の作り込みは既存
  素材と統一、性別・年齢は問わない）。相手役は`characters/recruiter.jpg`
  （現在未使用）とは別の「元請け営業担当」という新規ロール、
  スーツ・落ち着いた表情。
- **背景**: 会議室（`locations/meeting_room.jpg`と同トーンで可、
  現在未使用のためこの用途への転用も検討可——ただし用途が
  「面談結果画像」と「ロケーション背景」で異なるため、まずは
  `meeting_room.jpg`をこの用途に流用できないか確認することを推奨
  （新規生成よりコストが低い）。
- **既存SES素材に合わせたstyle**: 既存17点のUI素材デザイン合成画像と
  同じイラストスタイル（人物比率・色調・光源）。ドキュメント
  `assets/images/README.md`が言及する提供元合成画像から切り出す
  ワークフローを踏襲。
- **画像生成用prompt（参考、実際の生成モデル/スタイルは既存素材の
  提供元に合わせて調整すること）**:
  > "A business illustration in the same flat corporate art style as an
  > existing Japanese SES (IT staffing) game's UI asset set: a young
  > Japanese IT engineer in business casual attire sitting across a
  > meeting room table from a senior sales representative from a
  > partner/prime contractor company, exchanging business cards, calm
  > professional atmosphere, muted office color palette, medium shot,
  > 16:9 aspect ratio, no text or UI elements baked into the image."

**再利用可否の結論**: 上記は任意の将来施策であり、まず
`locations/meeting_room.jpg`（既存・未使用）をそのまま
`events/eventClientInterview`のパートナー面談分岐に転用できないか
（新規生成ゼロで差別化できる）を次のAudit #2で検討することを推奨する。

## Tests

実行環境: Flutter 3.44.8 stable（CI `.github/workflows/public-demo-validation.yml`
と同一バージョン）をセッション内にダウンロード/展開して使用。

- `flutter analyze`: **No issues found**（リポジトリ全体）。
- `git diff --check`: 差分ホワイトスペース問題なし。
- 新規/変更テストファイル（focused）:
  - `test/ui/public_demo/public_demo_employee_pending_join_test.dart`（新規、
    6 tests）: 入社予定セクションの表示・月境界（closeMay前後）・重複締め
    （idempotent close）・save/reload・360x800/390x844オーバーフロー。**全green**。
  - `test/ui/public_demo/public_demo_internal_training_financial_restriction_test.dart`
    （新規、2 tests）: 資金繰り悪化中は研修ボタンが消えて理由が表示される／
    通常時は表示される。**全green**。
  - `test/game/public_demo/public_demo_internal_training_transaction_test.dart`
    （既存＋1件追加）: `blockedByFinancialShortage`の直接テスト。**全green**。
  - `test/ui/public_demo/public_demo_employee_ui_phase1_test.dart` /
    `public_demo_employee_visual_complete_test.dart`（既存、ラベル変更に伴う
    期待値更新1箇所ずつ）: **全green**（他の既存assertionは無変更のまま通過）。
  - `test/ui/public_demo/public_demo_offer_comparison_screen_test.dart`
    （既存、受注成功演出の回帰チェック追加）: 全6テスト**green**
    （360x800/390x844のoverflowテストを含む）。
- Full public_demo suite: `flutter test test/game/public_demo test/ui/public_demo`
  （157ファイル、domain+widgetテスト合計 **1764件**）: **全green（exit code 0）**。
  既存の`public_demo_offer_comparison_screen_test.dart`
  （Phase1C回帰）・`public_demo_employee_ui_phase1_test.dart`/
  `public_demo_employee_visual_complete_test.dart`（ロースター表示）・
  `public_demo_01_home3_integration_test.dart`（HOME 360/390px overflow）・
  `public_demo_01_month_start_status_recommended_action_test.dart`
  （月初推奨アクション）等、本PRの変更が触れる領域を含め regression なし。

## Unresolved items

- 面談種別（上位会社面談 vs 客先面談）を視覚的に差別化する専用画像は
  未実装（生成不可のため仕様のみ提案、上記参照）。
- `client_interview.jpg`の代替候補として`locations/meeting_room.jpg`
  （既存・未使用）を転用できるかは未検証——次セッションでの確認を推奨。
- Main Game/Aug-Feb Late-game/Year-endは本タスクの対象外のまま
  （指示通り無変更）。
- e2e（Playwright）スイートは対象外とした（本タスクのテスト要件は
  focused domain/UI tests + flutter analyze + 該当public_demo suitesであり、
  e2eは時間的制約から今回のスコープに含めていない）。

## AI Replay Audit #2で確認すべき項目

1. 初見プレイヤーが社員タブを開いた瞬間、HOMEの「社員3名」と
   技術者2名＋説明文の内訳が実際に「一致して理解できる」と感じるか
   （文言の分かりやすさは主観評価が必要）。
2. 「入社予定」セクションが採用/営業タブの「結果待ち・入社予定」と
   重複して見えて冗長に感じられないか、逆に発見しやすくなったと
   感じられるか。
3. 研修ボタンが資金繰り悪化で消えた際の新しい説明文が、実際に
   「なぜ今できないか・いつ再びできるか」を初見で理解できる文言に
   なっているか。
4. 「候補案件を比較」画面の新しい説明文・次ステップ文言が、
   対話式面談との違いを実際に納得感を持って説明できているか
   （「劣った面談」ではなく「既に紹介済みの技術者評価の再利用」という
   フレーミングが伝わるか）。
5. 受注成功演出（`order_decision.jpg`）がPhase1c経由でも表示されることを
   実プレイで確認。

## Current status

実装・self-hardening・focusedテスト・flutter analyze・git diff --check・
Full public_demo regression suite（157ファイル、1764テスト、全green）完了。
Result Reportをcommitし、`claude/ses-first-fun-quarter-p1-fqw6ca`へpush、
mainへのPR（#261）を作成した。

## Next action

- ユーザー/レビュアーがResult ReportとPRを確認。
- 上記「AI Replay Audit #2で確認すべき項目」に基づく次回Fresh Audit。
- 面談種別差別化画像（WEAK項目）の要否判断（`meeting_room.jpg`転用調査を含む）。

## Actual elapsed time / Revised ETA

- Actual elapsed time: 約40分（Fresh Audit調査・実装・Flutter SDKセットアップ・
  focused/full regressionテスト実行・Self-hardening・Result Report作成・
  commit/push/PR作成を含む、単一セッション）。
- Revised ETA: 本タスクは1セッションで完了。追加のP1事項は現時点で無し。
