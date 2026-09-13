# SES First Fun Quarter — Visual Polish（April→July）Result Report

Status: **Implemented, self-hardened, focused + full public_demo regression suites green.**

## Base main SHA

`git fetch origin main` をセッション開始時に実行。`origin/main`（`refs/heads/main`）は
**`51b6e0f21fc48ab5c823764d23472dbf0343af18`**（PR #261 "SES First Fun Quarter —
April-July P1 Polish" のマージコミット）— 指定された期待SHAと完全一致（drift無し）。
作業ブランチ `claude/first-fun-quarter-visual-polish-a04l7f` はこの `origin/main` から
新規作成した。

## 前提: 既存asset棚卸し

実装前に `assets/images/{characters,events,locations,navigator}/` を全数確認した。

| ディレクトリ | ファイル | コード内での使用状況（実装前） |
|---|---|---|
| events | `client_interview.jpg` | `ei()`/`_openProjectInterview`/`pi()`/`ci()` の**全4系統**が共有（上位会社面談・客先面談の区別なし） |
| events | `order_decision.jpg` | **破損（後述）**。`Image.asset`が常にdecode失敗しフォールバックiconを表示 |
| events | `company_management.jpg` / `recruitment_application.jpg` / `first_assignment.jpg` / `client_contact.jpg` / `system_incident.jpg` | それぞれ専用イベントで正常使用中 |
| locations | `meeting_room.jpg` / `cafe_meeting.jpg` | **`AssetPaths`に定義されているが実装ではどこからも参照されていない**（未使用） |
| characters | `sales_male.jpg` / `sales_female.jpg` / `client_contact_person.jpg` / `recruiter.jpg` / `applicant_engineer.jpg` | `AssetPaths`に定義されているが**実装ではどこからも参照されていない**（未使用） |
| characters | `engineer_junior/midlevel/veteran.jpg` | 社員/応募者カード等で広く再利用済み（`homeOfficeStagePortraitFor`） |

**新規画像は一切作成せず**、上記の「定義済みだが未使用」の高品質assetをP1-A/P1-Cで
再利用する形で全ての実装を行った。P1-D/P1-Eは既存の進捗バー・iconの語彙を再利用した
UI追加のみで、画像は不要だった（詳細は各節）。

## Fresh Findings（今回のAudit独自の発見）

### 🔴 `order_decision.jpg` は物理的に破損していた（未検出のP0級バグ）

手動でJPEGマーカーを解析した結果、`order_decision.jpg`（14,450 bytes）は
**SOF（Start Of Frame）マーカーが存在しない**不完全なJPEGだった
（`FFD8`→`APP0`→`DQT`×2→`DHT`×2→**SOFなしでいきなり`SOS`**）。Pillow
（Python画像ライブラリ）でも `UnidentifiedImageError` となり、画像として認識不能。

このため、**PR #261で実装された「案件を獲得した」受注成功演出は、実プレイでは
一度も正しい画像を表示できていなかった**——`GameEventModal`の`errorBuilder`が
発火し、常に汎用の🔔ベルアイコン（`Icons.notifications_active_outlined`）
+グレー背景にフォールバックしていた。

このバグは`test/ui/asset_paths_test.dart`の既存スモークテストでは検出不能
だった（バイト数が0より大きいことしか確認しておらず、decode可否は見ていない）。
コード内のコメント（`_precacheEventImage`のdoc）は「`order_decision.jpg`のような
破損assetでも`onError`で確実にフォールバックする」ことを説明しており、**開発者は
このファイルが壊れている可能性を認識しつつ、根本原因（ファイル自体の破損）は
未調査のままだった**ことが伺える。

P1-B（受注成功演出）の最優先事項をこの修正に充てた。

## P1-A: 上位会社面談 と 客先面談 の視覚的区別

**Before**: `ei()`（社員面談）・`pi()`（入社前上位会社面談）・`ci()`（入社前客先面談）・
`_openProjectInterview`（対話式面談）の**全経路**が`AssetPaths.eventClientInterview`
（ビジネスマン2人の握手写真）を無条件に共有。対話式面談ダイアログ
（`PublicDemoProjectInterviewDialog`）に至っては画像自体が一切なく、
`Icons.badge_outlined`の汎用iconのみだった。

**After**:
- 既存の未使用location asset `locations/meeting_room.jpg`（会議室・フォーマル）を
  **上位会社面談**、`locations/cafe_meeting.jpg`（ラウンジ・カジュアル）を
  **客先面談**に割り当てる`_interviewSceneAsset(bool partner)`ヘルパーを
  `public_demo_01_placeholder_screen.dart`に追加。
- `PublicDemoInterviewResultDialog`（`ei`/`pi`/`ci`が使う結果ダイアログ）に
  `imageAsset`/`fallbackIcon`パラメータを追加し、面談種別に応じた画像を渡すよう
  全呼び出し元を更新。
- `PublicDemoProjectInterviewDialog`（対話式面談。実プレイで主に使われる経路）
  に新規`_InterviewLocationBanner`（高さ72dp、角丸10、`BoxFit.cover`）を追加し、
  タイトルバー直下に面談種別ごとの背景写真を表示。
- 両経路とも同じ`meeting_room.jpg`/`cafe_meeting.jpg`を参照しているため、
  セーブの進み方（旧経路 or 新Phase 6経路）に関わらず同じ面談は同じ画像になる。

**画像内容の妥当性**: `meeting_room.jpg`＝革張りチェア・大型モニター付き会議室
（フォーマルな上位会社との商談に自然）、`cafe_meeting.jpg`＝観葉植物・窓辺の
ラウンジ（客先訪問時の柔らかい対人接触を示唆）。どちらも既存UI（イベント画像の
イラスト調・青系トーン）と統一感がある。

## P1-B: 受注成功演出

**Before**: 破損した`order_decision.jpg`により、`_recordEngineerOrder`
（単一候補案件からの受注）・`_recordOfferCandidateOrder`（PR #261の候補案件比較
経由の受注）・`_recordApplicantJuneOrder`（6月受注）の**全3経路**で常に
フォールバックiconしか表示されていなかった。

**After**:
- `AssetPaths.eventOrderDecision`を、P1-Aで面談専用画像に切り替えたことで役目を
  終えた`client_interview.jpg`（握手写真）に再割り当て。「握手＝契約成立」は
  「受注成功」の表現として直感的に強く、かつP1-Aの変更により面談画像との
  重複が完全になくなったため、受注成功の瞬間にのみ表示される専用画像になった。
- 破損していた`assets/images/events/order_decision.jpg`は削除（`git rm`）。
- ドメイン/受注authorityは無変更。コピー・余白・表示サイズ（`GameEventModal`の
  共通`imageHeight: 180`）はP1-B単体のために変更していない——既に他の全event
  dialogと統一されたレイアウトであり、個別に変えると他イベントとの一貫性が
  崩れるため。

**達成感の評価**: 「案件を受注しました」というタイトル＋握手写真＋
「〇〇さんの案件を受注しました。」という本文は、既存の他イベント（入社・初参画等）
と同じ強度のフィードバックになった。実写真が表示されるようになったこと自体が
最大の改善であり、追加のコピー変更は行っていない。

## P1-C: 採用イベント

**Before**: `ApplicantPersonaHeader`/`_PersonaAvatar`
（`lib/ui/recruitment/recruitment_interview_widgets.dart`。Public Demo・本編
どちらの面談画面でも共有）は、候補者idのhashで色を選んだ円＋反応emoji
のみで、実在の人物感が薄かった。一方、面談対象と同じ`PublicDemoApplicant`は、
採用タブの候補者カード（`ac(i)`）では既に`homeOfficeStagePortraitFor(a.id)`
（`engineer_junior/midlevel/veteran.jpg`をid別に確定的に割り当てる既存関数）で
実写ポートレートを表示していた——**面談画面だけ**顔が消える不整合があった。

**After**:
- `_PersonaAvatar`を、`homeOfficeStagePortraitFor(seed)`
  （`seed`=`applicant.id`、候補者カードと**完全に同じ**関数・同じ結果）で
  実写ポートレートを表示するよう変更。
- 画像のdecode失敗時は、従来通りの色付き円＋emojiにフォールバック
  （既存の安全設計を踏襲）。
- 反応emoji自体は削除せず、ポートレート右下の小さな丸バッジとして残した——
  「今の反応」という、静止画のポートレートでは表現できない情報だったため。
- 結果: 採用面談で見た顔 → 内定承諾 → 「入社予定」カード（既存の
  `homeOfficeStagePortraitFor`使用箇所）→ 入社後の社員一覧、で**一貫して
  同じ顔**が表示されるようになり、「仲間が増えた」感覚が強化された。
- `PublicDemoRecruitmentInterviewDialog`（Public Demo）・本編の
  `recruitment_interview_screen.dart`/`prologue_interview_screen.dart`の
  3画面すべてがこの共有widgetを使うため、変更は全経路に一律で反映される
  （HOME/経済/saveスキーマは無変更）。

## P1-D: 研修

**Before**: `internalTrainingCard`（研修選択カード）は文言のみ。研修結果の
確認場所である`PublicDemoGrowthResultCard`（月次成長サマリー、「今月の成長」
セクション）も`"Java 78 → 80  (+2)"`という**数値テキストのみ**で、成長を
視覚的に実感できる要素が皆無だった。一方、社員一覧の各カードには
`PublicDemoEmployeeSkillBar`という進捗バーが既に存在していた
（`beforeCapability`受け取り可能だが、スクロールしないと見えない位置）。

**After**:
- `PublicDemoGrowthResultCard`（月次成長サマリー、月末に真っ先に目に入る場所）
  に、既存テキスト行は変更せず**追加**する形で`_CapabilityGrowthBar`
  （新規、この1ファイル内のprivate widget）を実装。0-100スケールの
  fill barの上に、研修前レベルを示す薄い縦マーカーを重ねることで
  「ここからここまで伸びた」ことが数値を読まなくても一目で分かるようにした。
  `delta == 0`（変化なしの月）ではバーを出さず、既存の「今月は大きな変化なし」
  テキストのみ——伸びていないのに伸びたように見せるバーを描かないため。
- 既存の`PublicDemoEmployeeSkillBar`（社員一覧側）は**変更していない**
  （scope最小化。テキスト/バー両方が二重に変わることによる予期せぬ差分を避けた）。
- PR #261で追加された資金不足時の研修不可説明文（`s.isFinanciallyRestricted`
  ブロック）はテキスト・条件とも無変更。research domain rule（コスト・効果）も
  無変更。

**画像不足の判断**: 「研修」を表す専用シーン画像は既存assetに存在しない
（`events/`ディレクトリに該当するものなし）。今回はUI要素（進捗バー）のみで
「成長が視覚的に分かる」という目的を達成できたため、genericなプレースホルダー
画像は作成していない。より強い演出（研修シーンの挿絵）が今後必要な場合の仕様は
本レポート末尾「画像が不足している一覧」に記載。

## P1-E: 7月賞与

**Before**: `PublicDemoSummerBonusDialog`（賞与額の選択）は3つの選択肢が
文言のみで視覚的に無差別（アイコンなし）。決定後（`decideSummerBonus()`）は
`_commitAggregate`のみでUIフィードバックが皆無——プレイヤーは
`_accountingDecisionSection`カードの文言が「未決定」→「選択済み」に
変わったことに自分で気付く必要があった。

**After**:
- `PublicDemoSummerBonusDialog`の3択それぞれに、金額規模に対応する既存
  Material icon（なし=`money_off_outlined`、0.5か月=`paid_outlined`、
  1か月=`card_giftcard_outlined`）を追加し、タイトルにも
  `card_giftcard_outlined`（既存の`_accountingDecisionSection`エントリー
  カードと同一icon、新規iconではなく既存語彙の再利用）を追加。
- `decideSummerBonus()`に、決定直後の`SnackBar`確認
  （「夏季賞与を「1か月」に決定しました（支給総額 ¥XXX）。」）を追加。
  金額は`PublicDemoSummerBonusDialog`自身が使う`PublicDemoMonthlyClose
  .previewJuly`を**同じ引数で再計算**しており、二重の金額ロジックは存在しない
  （commit前の`s`/`workflow`から算出、bonus計算ロジック自体は無変更）。
- 8月開始時の「夏季賞与 ¥XXX / なし」という結果表示（既存、
  `_accountingMonthlyResultSection`の`hasAugustResult`分岐）はテキスト・
  条件とも無変更——「7月に決めたことと結果が視覚的に分かる」という
  P1-Eの要求は、決定直後のSnackBar＋既存の結果表示の組み合わせで満たしている。

## Result: 検証

### flutter analyze / git diff --check

- Flutter SDKはこのセッションに存在しなかったため、CI
  （`.github/workflows/*.yml`の`subosito/flutter-action@v2`、`3.44.9`固定）
  と同一の**Flutter 3.44.9 (stable)**をダウンロード・展開して使用。
- `flutter analyze`: **No issues found**（リポジトリ全体、複数回実行して確認）。
- `git diff --check`: 差分ホワイトスペース問題なし。

### 360x800 / 390x844 の overflow

- `public_demo_project_interview_dialog_test.dart` /
  `public_demo_partner_interview_dialog_test.dart`
  （新規`_InterviewLocationBanner`込みで360x800・390x844・textScale
  1.0/1.3/2.0の全組み合わせを検証）: **green**。
- `public_demo_offer_comparison_screen_test.dart`（360x800/390x844の
  overflowテスト含む）: **green**。
- `public_demo_growth_result_card_test.dart`（360px/390px、新規growth bar込み）:
  **green**。
- `public_demo_recruitment_interview_visual_test.dart` /
  `public_demo_seeded_recruitment_visual_test.dart`（新ポートレート込みの
  面談ダイアログを360x800/390x844・textScale最大2.0で検証、スクリーンショット
  含む）: **green**。

### dialog/modal内でCTAが画面外に追い出されないか

`_InterviewLocationBanner`は固定高72dpのみを消費し、質問/結果本文は
引き続き`SingleChildScrollView`内にあるため、決定ボタン（`続ける`等）は
常にダイアログ下部の非スクロール領域に固定されたまま——上記の overflow
テスト group が同時にこれを検証している。

### 既存flowを壊していないか（回帰）

- Focused（今回変更したファイルに対応するテスト）:
  `public_demo_interview_result_dialog_test.dart`（imageAsset必須化に伴い
  既存2テストを更新）、`public_demo_project_interview_dialog_test.dart`、
  `public_demo_partner_interview_dialog_test.dart`、
  `public_demo_growth_result_card_test.dart`、
  `public_demo_summer_bonus_dialog_test.dart`、
  `public_demo_recruitment_interview_visual_test.dart`、
  `public_demo_seeded_recruitment_visual_test.dart`、
  `recruitment_interview_ux_test.dart`、`prologue_widget_test.dart`、
  `text_quality_widget_test.dart`、`asset_paths_test.dart`: **全green**。
- `test/game/public_demo` + `test/ui/public_demo`
  （157ファイル、1764+テスト、CI相当のフルスイート）:
  1回目の実行で`public_demo_offer_comparison_screen_test.dart`の1件のみ失敗
  → 根本原因を特定・修正（下記「Fresh Findings 2」参照）→ 再実行で**全green
  （exit code 0）**。
- `git diff --check`: 上記の通り問題なし。

### 🟡 Fresh Findings 2（テスト環境の潜在バグを発見・修正）

P1-Bの`order_decision.jpg`修正（破損ファイル→正常な画像）を適用した直後、
`public_demo_offer_comparison_screen_test.dart`の1テストが失敗した。原因を
特定するため、`git stash`でbaselineに戻して同テストを再実行（pass）→
`AssetPaths.eventOrderDecision`だけを様々な有効ファイルに変更して再検証
（すべてfail）→ 最小再現テストで`precacheImage()`が実画像に対して
`tester.pump()`だけでは解決しないことを確認（`tester.runAsync()`でのみ解決）
——という手順で切り分けた。

判明した根本原因: **このFlutter SDK環境では、`MultiFrameImageStreamCompleter`
は実時間（wall-clock）でしか解決せず、`tester.pump()`/`pumpAndSettle()`の
フェイクタイムでは進まない**（これは本リポジトリの
`public_demo_01_playthrough_test.dart`の`tapAndSettle`ヘルパー自身が既に
コメントで明記している既知の制約）。破損した`order_decision.jpg`は
decodeが即座に失敗（エラー）していたため偶然この制約を回避できていたが、
`public_demo_offer_comparison_screen_test.dart`はこの`runAsync`回避策を
使っておらず、**「正しい画像に直すと露呈する」既存の潜在的なテストの脆さ**
だった。

対処: 同テストファイルに`tapAndSettle`と同じ`runAsync`実時間待機パターン
（`_awaitRealImageDecode`）を追加し、confirm-yesタップ直後に適用。
ゲームロジック・受注authorityは一切変更していない——純粋にテストの
待ち方の修正。

## 画像が不足している一覧（今後の追加素材候補）

以下は「なくても実装は完成しているが、より強い演出のために画像があると
良い」候補。**現時点でこれらは作成していない**——生成AIでの作成が
必要なため、仕様のみここに記載する。

### 候補1: `training_session.jpg`（研修シーン、P1-D）

- **使用イベント**: 社内研修選択カード（`internalTrainingCard`）の上部バナー
- **推奨サイズ/アspect比**: 251×117px相当（`locations/meeting_room.jpg`と
  同じ比率、約2.14:1）を推奨。将来的な高解像度端末対応のため、実データは
  502×234px程度で書き出し、表示側で縮小
- **画像内容**: オフィスの一角で、若手エンジニア1名がノートPCとモニター2台に
  向かい、画面には成長を示唆するグラフ/コードが表示されている。デスクには
  技術書が数冊積まれている
- **キャラクター**: 既存の`engineer_junior.jpg`のトーン（黒髪・シャツ、
  20代）に寄せた人物1名。特定の社員個人ではなく「研修中の誰か」を表す
  ジェネリックな人物
- **背景**: 明るいオフィス、大きな窓、観葉植物（`locations/office_day.jpg`
  と同系統のトーン）
- **構図**: 横長バナー、人物は画面中央やや左、右側に空間を残してテキスト
  オーバーレイの余地を作る
- **画風**: 既存UI素材と同じ「セミリアル・イラスト調、青〜暖色系の
  やわらかい配色」（`client_interview.jpg`/`company_management.jpg`と統一）
- **画像内テキスト**: なし（ラベルはFlutter側で描画）
- **Flutterでの配置**: `internalTrainingCard`のCard内、既存テキストの
  上部に`ClipRRect`+`AspectRatio`で追加
- **BoxFit**: `BoxFit.cover`
- **mobile表示サイズ**: 360px幅で高さ約168px、390px幅で高さ約182px
  （アスペクト比2.14:1を維持）

**画像生成AI向け日本語プロンプト**:
> オフィスの明るいデスクで、20代の若手男性エンジニアがノートPCと外部モニター
> 2台に向かってプログラミングをしている横長のイラスト。画面には成長曲線の
> グラフが薄く見える。デスクには技術書が数冊積まれている。背景は大きな窓と
> 観葉植物のある明るいオフィス。セミリアルなアニメ調イラスト、青と暖色の
> やわらかい配色、シャープすぎない輪郭線。アスペクト比2.14:1の横長バナー
> 構図、人物は中央やや左寄り、右側に余白を残す。テキストは一切含めない。

### 候補2: `bonus_handover.jpg`（賞与支給シーン、P1-E）

- **使用イベント**: `PublicDemoSummerBonusDialog`のタイトル部、または
  8月開始時の支給結果表示
- **推奨サイズ/アスペクト比**: 199×177px相当（`events/client_interview.jpg`
  と同じ比率）
- **画像内容**: 経営者（プレイヤー役）らしきスーツ姿の人物が、賞与袋/封筒を
  笑顔で差し出している、または複数の社員が笑顔で受け取っている様子
- **キャラクター**: `sales_male.jpg`/`sales_female.jpg`（既存・未使用の
  経営陣風ポートレート）のトーンに合わせた人物
- **背景**: オフィス内、既存`office_day.jpg`と同系統
- **構図**: バストアップ、封筒/賞与袋が手前に見える
- **画風**: 既存イベント画像と統一（`recruitment_application.jpg`の
  「封筒＋書類」的な小物の描き方を踏襲すると統一感が出る）
- **画像内テキスト**: なし
- **Flutterでの配置**: `PublicDemoSummerBonusDialog`の`AlertDialog`
  タイトル上部（新規`ClipRRect`バナー、高さ80dp程度）
- **BoxFit**: `BoxFit.cover`
- **mobile表示サイズ**: 360px幅で高さ約90px、390px幅で高さ約97px

**画像生成AI向け日本語プロンプト**:
> スーツ姿の経営者らしき人物が、賞与袋（のし袋風の白い封筒）を笑顔で
> 両手で差し出しているバストアップイラスト。背景は明るいオフィス。
> セミリアルなアニメ調イラスト、青と暖色のやわらかい配色、既存のSESゲームUI
> 素材と統一感のあるタッチ。アスペクト比199:177の縦長に近い正方形構図。
> テキストは一切含めない。

### 候補3（低優先）: `client_office_meeting.jpg`（客先面談の代替）

`cafe_meeting.jpg`は「客先面談」の代替として視覚的な区別には十分機能するが、
厳密には「客先訪問」というより「休憩ラウンジ」に近い内装のため、将来的に
より明確な「取引先オフィスの応接室」画像に差し替える余地がある。現状の
`cafe_meeting.jpg`流用は area/tone として既存UIと矛盾しないため、優先度は
低い任意改善として記載するに留める。

## Current status

実装・self-hardening（テスト環境固有の潜在バグの特定・修正含む）・
focusedテスト・flutter analyze・git diff --check・full public_demo regression
suite（157ファイル、1764+テスト、全green）完了。Result Reportをcommitし、
`claude/first-fun-quarter-visual-polish-a04l7f`へpush、mainへのPRを作成した。

## Next action

- ユーザー/レビュアーがResult ReportとPRを確認。
- 「画像が不足している一覧」の3候補（特に候補1・2）について、画像生成の
  要否をユーザー側で判断し、必要であれば添付の日本語プロンプトで生成。
- 次回のApril→July AI Replay Audit #2で、今回のP1-A〜P1-Eの体感を評価。
- 今回はCodex Broad Reviewは未実行（指示通り）。

## Unresolved items

- 研修・賞与支給シーンの専用イラストは未作成（画像生成AIでのみ対応可能な
  ため。仕様は本レポート記載、必要なら次セッションで生成・組み込み）。
- `cafe_meeting.jpg`の客先面談への流用は暫定解——将来より適切な「取引先
  応接室」画像に差し替える余地あり（優先度低）。
- Main Game（本編）側の`recruitment_interview_widgets.dart`共有widgetの
  ポートレート化は本編プロローグ/面談画面にも影響するが、既存テスト
  （`prologue_widget_test.dart`等）は全green——ただし本タスクの主眼は
  Public Demoであり、本編側の実プレイでの見え方は別途確認推奨。
- Aug〜Feb / Year-end領域は指示通り完全に無変更。
