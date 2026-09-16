# SES First Fun Quarter — AI Replay Audit Fix (Result Report)

Status: **Implemented, self-hardened, focused + full public_demo regression suites green, web build green. Codex Broad Review round 1 (P1/P2/P3) addressed in the same PR.**

## Base main SHA

`git fetch origin main` was run at session start. `origin/main`（`refs/heads/main`）は
**`af90479e966a17d752337921f34a2475d9559d1a`**（PR #268 "SES Phase 4 Document
Screening" のマージコミット）— タスクで指定された監査対象SHAと完全一致（drift無し）。

作業ブランチ `claude/ai-replay-audit-fix-l64sdg` はローカルに古い無関係の内容
（"Phase 0A/0B: SES domain models and random generators" — 現在のmain系譜には
存在しない、無関係な過去のスキャフォールド）が残っていたため、`origin/main`から
作り直した（`git checkout -B claude/ai-replay-audit-fix-l64sdg origin/main`）。

## Final HEAD SHA

`02c1f1a75bfbae171ca8bcd71e9e0923bdce33dc`（初回実装は`0bdfe7c1a3c0cc3c28fdfc3e585835c359646825`。
下記「Codex Broad Review Round 1 対応」節が今回の追加コミット分）

## 根拠となったResult Report

`SES_FIRST-FUN-QUARTER_AI-REPLAY-AUDIT-2_Result.md` はリポジトリ内・git履歴内の
どこにも見つからなかった（`docs/reports/`配下はもちろん、全コミットのadd履歴を
検索しても該当ファイル名は存在しない）。近い名前の既存コミット
（`fix: SES First Fun Quarter AI Replay Audit #2 — Final P1 Fix` /
`fix: SES First Fun Quarter AI Replay Audit #3 P1`）はどちらも既にmainへ
マージ済みで、内容も本タスクの指摘（technicalExperience識別子の露出、
SkillSheet編集Missionの詰み）とは別の既存修正だった。

指示に従い監査自体は再実施せず、タスク本文に列挙されたFinding（P1-1/P1-2/
P2-1/P2-3/P3-1/P3-2）の記述を実装根拠として採用し、対応するコード箇所を
Freshに確認した上で実装した。各Findingの「監査で確認されたroot cause」は
すべて現在のコードで実際に再現・確認できた（下記Before/After参照）。

## Findingごとの修正内容

### P1-1（必須修正）: technicalExperience識別子の露出

**Before（コード確認）**

`lib/game/engine/client_interview_engine.dart`の`_target()`:

```dart
static String _target(ClientInterviewQuestionCategory c, Project p) =>
    c == ClientInterviewQuestionCategory.technicalExperience &&
            p.requiredLanguages.isNotEmpty
        ? p.requiredLanguages.first.name
        : c.name;
```

`requiredLanguages`が空の案件では`technicalExperience`カテゴリの質問の
`target`が生の`c.name`（`"technicalExperience"`という内部enum識別子文字列）
になり、`answer()`内の日本語テンプレート
（`'${q.target}を使った開発で...'`、及び曖昧回答時の
`'${q.target}の案件には参加しています...'`）へそのまま埋め込まれていた。
`ClientInterviewEngine`は`game_engine.dart`の`upperCompanyInterview`/
`clientInterview`両ステップから同一インスタンスとして呼ばれる共有エンジンの
ため、上位会社面談・客先面談の両方で再現する。

さらに調査の結果、この関数は`technicalExperience`以外の全カテゴリ
（industryExperience/leadership/roleExperience/communication/teamwork/
troubleHandling/workStyle）についても常に`c.name`を返す実装になっており、
`requiredLanguages`の状態に関わらず、曖昧回答時（`vague`、`mismatch>=2 ||
quality<45`で発生）には他カテゴリでも同種の識別子露出が起こり得た。

**After（実装内容）**

各カテゴリに人間可読な日本語ラベルを対応させる`_categoryTargetLabels`
定数マップを追加し、`_target()`のフォールバックをそこから引くよう変更。
`technicalExperience`かつ`requiredLanguages`が非空の場合のみ、既存の
`languageName()`ヘルパー（先頭大文字化）で言語名を返す（従来の生の
`.name`小文字値から統一）。

```dart
static const _categoryTargetLabels = <ClientInterviewQuestionCategory, String>{
  technicalExperience: '今回必要な技術領域',
  industryExperience: '業界知識',
  leadership: 'リーダー経験',
  roleExperience: '担当領域',
  communication: '顧客対応',
  teamwork: 'チームでの役割',
  troubleHandling: 'トラブル対応',
  workStyle: '働き方',
};
```

これにより`target`が内部enum識別子を返すパスは存在しなくなった（全8
カテゴリを一度に検証する回帰テストで確認 — 下記Tests参照）。

**Authorityへの影響**: なし。`target`は表示用文字列のみで、`quality`/
`vague`/`mismatch`/面談の合否判定には一切使われていない。

### P1-2（必須修正）: SkillSheet編集Missionの詰み

**Before（コード確認）**

`lib/ui/public_demo/public_demo_01_placeholder_screen.dart`の
`_employeeNextActionsSection`が`ec(i)`（SkillSheet編集ボタンを含むカード）
を描画する3箇所の条件をすべて確認した:

- 4月（`s.month == 4`）: 全エンジニアに対し無条件で描画
- 5月・6月（`s.month == 5 || 6`）: `stage != ordered && !assignedである`
  エンジニアのみ
- 7月〜2月（RECOVERY-LOOP-1、`s.month >= 7 && <= 14`）:
  `!assignedEngineerIds(month).contains(...)`のエンジニアのみ

参画（`assignedEngineerIds`への算入）は`受注`月の翌月の月次締め処理
（`assignOrderedForMay`/Recovery系）で発生するため、4月中に
`SkillSheet確認→営業開始→案件紹介→上位会社面談→客先面談→受注`まで
一気に進めた技術者は、4月時点ではまだ`stage == ordered`かつ未参画
（`ec(i)`は4月ブロックで既に描画済み）だが、その技術者が一度も
「スキルシートを編集」を押さないまま5月へ月次を進めると、5月以降は
`ec(i)`の3描画箇所すべてから除外される。以後、参画が解除されない限り
（Public Demo 0.1の範囲では通常発生しない）二度と`ec(i)`のSkillSheet
編集ボタンに到達できなくなる。

Mission 2（`PublicDemoMissionId.editSkillSheet`）の完了条件
（`lib/game/public_demo/public_demo_mission_resolver.dart`）は
`anyEngineer((e) => e.salesProfileEditConfirmed)`のままで、この
authority自体は正しく実装されている（cancel時は`salesProfileEditConfirmed`
が立たない、same-value saveでも「保存した事実」だけで完了する — 既存の
`public_demo_mission_resolver_test.dart`が既にこれらを検証済み）。
問題は**そこへ到達するUI導線が参画後に消滅する**ことだった。

**After（実装内容）**

`activeProjectStatusCard`（Section 3「参画中案件」— 参画中の技術者が
必ず1枚持つカード）に、`ec(i)`が持つのと全く同じ「スキルシートを編集」
ボタンを追加した。呼び出し先は既存の`_openSkillSheetEdit(engineer)`
そのもの（同一コマンド、同一authority）:

```dart
if (_engineerById(a.engineerId) case final engineer?)
  Padding(
    padding: const EdgeInsets.only(top: 8),
    child: OutlinedButton.icon(
      key: Key('public-demo-skill-sheet-edit-open-active-${a.engineerId}'),
      onPressed: () => unawaited(_openSkillSheetEdit(engineer)),
      icon: const Icon(Icons.edit_outlined),
      label: const Text('スキルシートを編集'),
    ),
  ),
```

`ec(i)`の3描画箇所は「未参画」を条件に持ち、`activeProjectStatusCard`は
`assignedEngineerIds(month).contains(...)`（=参画中）を条件に持つため、
同一エンジニア・同一月でこの2つのボタンが同時に存在することはない
（構造的に排他）— 表示条件の変更は最小限（新しい描画箇所を1つ追加した
だけ）で、既存の`ec(i)`側のロジックは一切変更していない。

**表示条件変更 vs authority変更の判断**: タスクの指示通り、まずコード上の
authority（`PublicDemoMissionResolver`/`salesProfileEditConfirmed`/
`confirmSkillSheetEdit`）を確認し、authority自体には問題がないことを
確認した上で、最小の表示条件追加（新しい導線を1つ足すだけ）で解決できると
判断した。Mission側のコード（`public_demo_mission_resolver.dart`）は
一切変更していない。

**Authorityへの影響**: なし。呼び出しているコマンドも判定基準も既存のまま。
参画後でも「編集して保存した」という事実だけが引き続きMissionを完了させる
（fake completionではない — 下記Testsのウィジェットテストでcancel/実save
両方を検証）。

### P2-1（小規模改善）: 面談回答のバリエーション

**Before**: `answer()`内の回答文は3パターンしかなく、
`technicalExperience`以外の7カテゴリ（industryExperience/leadership/
roleExperience/communication/teamwork/troubleHandling/workStyle）は
非曖昧時にすべて同一の1文
（`'自分の担当を明確にし、関係者と合意を取りながら進めました。...'`）を
共有していた。上位会社面談・客先面談は同一エンジンを使うため、両方で
同じ文言が繰り返し表示されていた。

**After**: カテゴリごとに個別の自然な回答文を追加する`_answerText()`
ヘルパーを新設。`quality`/`vague`/`mismatch`の計算ロジックには一切
手を加えておらず、文言（表示のみ）を差し替えただけ。合否authority・
難易度・gameplay balanceへの影響はゼロ。

### P2-3（小規模改善）: 現金増減と純利益相当の乖離説明

**Before**: `PublicDemoMonthlyReportDialog`の「純利益相当」セクションは
数値のみを表示し、なぜ「現金」セクションの増減額と一致しないことがあるのか
説明がなかった（両者が乖離する理由自体は`PublicDemoMonthlyCashFlow
.netIncome`の既存docコメントに明記済みの既知の仕様）。

**After**: 既存の`data.revenue`/`data.cashReceived`（どちらも同じダイアログの
「売上・入金」セクションで既に表示されている値）が異なる場合にのみ、
`_ReportStatRow`の既存`caption`スロットへ短い説明文を追加。新しい会計計算・
新しいFinance authorityは一切追加していない（既存の2つの値を読んで文章化
しただけ、差分の再計算もしていない）。

### P3-1（小規模改善）: 求人媒体モーダルの金額表記統一

**Before**: `_RecruitmentMediaCard`/`_RecruitmentMediaSheet`/
`_RecruitmentMediumOption`内の4箇所が`'¥${value}'`という生の文字列補間を
使っており、カンマ区切りなしの`¥3170000`のような表示になっていた
（他の画面は既存の`formatYen()`で`¥3,170,000`形式に統一済み）。

**After**: 4箇所すべてを既存の`formatYen()`に置き換え。表示形式のみの変更で、
値そのもの（`state.cash`/`medium.cost`）は変更していない。

### P3-2（小規模改善）: 給与提示ダイアログの表記統一

**Before**: `PublicDemoSalaryOfferDialog`の説明文が英語混じり
（`"...入社後のMotivation / Trustにも影響します。"`）だった。

**After**: 既存の用語（`モチベーション`/`信頼` — `engineer_detail_screen.dart`
や`founding_dialogs.dart`などで既に使われている表記）に統一し、
`"...入社後のモチベーションや信頼にも影響します。"`に変更。

## 今回やらないと明記された項目（対応せず）

- P2-2（絵文字グリフ） — iPhone実機確認待ちのため未着手。
- 案件比較・受注選択UI — 別スコープのため未着手。
- 入社直後の昇給相談 — 仕様/バグ判定未完了のため未着手。
- HOMEレイアウト変更 — HOME Freeze維持、未着手。
- save schema bump — 発生させていない（後述のSave Compatibility参照）。
- workflow変更 — `.github/workflows/`配下は一切変更していない。

## Save Compatibility

- 新しい永続化フィールドは追加していない。`ClientInterviewQuestion.target`
  はこれまで通り`String`として`toJson()`/`fromJson()`される（型・キー名は
  不変）。既存セーブに保存済みの`target`文字列（仮に旧バグの影響で内部
  識別子が焼き込まれていたとしても）はそのまま読み込まれ、新規に生成される
  質問だけが新しいラベルを使う — 後方互換に問題なし。
- `PublicDemoEngineerSales.salesProfileEditConfirmed`のスキーマ・意味は
  無変更。
- `PublicDemoMissionResolver`の判定ロジック・`publicDemoAprilMissionChain`
  の順序は無変更（P1-2はUI導線の追加のみ）。
- `save schema bump`は発生していない。

## Changed Files

```
lib/game/engine/client_interview_engine.dart
lib/ui/public_demo/public_demo_01_placeholder_screen.dart
lib/ui/public_demo/public_demo_monthly_report_dialog.dart
lib/ui/public_demo/public_demo_salary_offer_dialog.dart
test/game/client_interview_04b_test.dart
test/ui/public_demo/public_demo_01_playthrough_test.dart
test/ui/public_demo/public_demo_active_project_visibility_test.dart
test/ui/public_demo/public_demo_skill_sheet_edit_after_assignment_test.dart (new)
docs/reports/SES_FIRST-FUN-QUARTER_AI-REPLAY-FIX_Result.md (new, this file)
```

## Tests

- `flutter analyze`: **No issues found.**（プロジェクト全体）
- `flutter test test/game/public_demo test/ui/public_demo`:
  **1910/1910 pass**（自分のブランチ、最終コミット時点）。
  - 比較として`origin/main`（pristine）で同一コマンドを実行し
    **1908/1908 pass**（差分の2件は本PRで追加した新規テスト分）。
  - 実装途中に一度だけ`test/ui/public_demo/public_demo_01_playthrough_test.dart`
    の"recruitment media adds applicants through the existing flow"が
    フルスイート内で失敗したが、(1)単体実行では常にpass、(2)pristine
    origin/mainで同一の組み合わせ実行をしても再現せず、(3)本PRの全修正を
    適用した状態での再実行では2回連続でpassしたため、環境負荷起因の
    一過性flakeと判断し、コード上の対応は行っていない。
  - `test/ui/public_demo/public_demo_active_project_visibility_test.dart`は
    P1-2で`activeProjectStatusCard`にText要素を1つ追加した影響で
    既存の「Text要素はちょうど7個」という厳密カウントの回帰テストが
    赤くなったため、8個への更新とコメント追記を行った（fieldEvaluationを
    表示しないという既存の不変条件はテストの意図通り維持）。
- `test/game/client_interview_04b_test.dart`に追加した回帰テストは、
  修正前のコード（`_target()`のフォールバックを`c.name`に戻したもの）に
  対して実際に失敗することを確認済み（テストの有効性を検証した上で
  修正版に戻して再度green化）。
- `git diff --check`: 問題なし。
- `flutter build web --release`: **成功**（Public Demo full suiteの一部として）。

## Self-Hardening Findings

タスク指定の確認observableすべてを実施:

- requiredLanguages empty: `client_interview_04b_test.dart`の新規テストで
  全8カテゴリを一度に検証、内部enum文字列の漏れなし。
- SkillSheet edit before sales: 既存挙動不変（`ec(i)`の`stage != waiting`
  ガードは無変更）。
- SkillSheet edit after order（参画前）: 既存の`ec(i)`導線で引き続き到達可能
  （既存テスト`public_demo_01_skill_sheet_flow_test.dart`でカバー済み・
  無変更）。
- SkillSheet edit after assignment（参画後）: 新規ウィジェットテストで
  「編集せず参画→7/8で詰まる」ことをまず再現し、新しい導線での
  cancel（未完了のまま）→実save（8/8に到達）まで確認。
- cancel: 新規テストで「新しい導線からcancelしても
  `salesProfileEditConfirmed`は`false`のまま」を検証。
- same-value save: 既存の`public_demo_mission_resolver_test.dart`が
  既にカバー（本PRでは未変更のためリグレッションなしを確認するのみで
  十分と判断）。
- save/reload: `client_interview_04b_test.dart`の既存
  `GameState.fromJson(s.toJson()).toJson() == s.toJson()`ラウンドトリップ
  テストが引き続きpass。`target`のシリアライズ形式（String）は無変更。
- Mission completion: 新規ウィジェットテストで
  `PublicDemoMissionResolver.resolve()`が実際に8/8へ遷移することを確認
  （Mission側コード自体は無変更 — UI導線追加だけでauthorityの再評価が
  正しく反映されることを確認）。
- April Mission 8-step progression: 上記と同一テストで
  `publicDemoAprilMissionChain`の順序・要素数を変更していないことを確認
  （import元の定数をそのまま参照、書き換えなし）。
- legacy save: 初回実装時点では`target`の読み込み側（`fromJson`）が無変更
  だったため、旧セーブに焼き込まれた文字列（内部識別子を含む可能性のある
  もの）はそのまま残っていた。この残課題はCodex Broad Review Round 1の
  P1として指摘され、下記「Codex Broad Review Round 1 対応」節の通り
  修正済み（`ClientInterviewEngine.sanitizeLegacySessions`を`SaveService
  .load()`/`PublicDemoAggregate.fromJson()`にフックし、legacy active
  sessionもロード時にサニタイズされる）。
- malformed state: 本PRの変更範囲（表示文字列・UI導線の追加）は
  malformed-state耐性に影響する新しいパース/検証コードを含まないため、
  既存の防御（`_openSkillSheetEdit`のnullランタイム/スキルガードなど）を
  そのまま踏襲。
- month boundary: P1-2の新規テストは4月チェーン完走→8月まで月送りした
  状態で検証しており、月境界を跨いだ後の到達可能性を直接確認している。
- duplicate action: 新しい編集ボタンは`ec(i)`のものと同時に描画されない
  構造（参画済み/未参画で排他）であることをコード上確認済み（同時押下や
  二重送信の懸念なし — 呼び出し先の`_openSkillSheetEdit`自体も無変更）。

「Mission表示上は完了だがauthorityでは未完了」というfake completionは
作っていない — 新しいUI導線はすべて既存のauthorityコマンド
（`confirmSkillSheetEdit`）を素通しで呼ぶだけで、Mission側の判定ロジックは
一切変更していない。

## Intentionally Deferred Items

- 本Findingリストの「今回やらない」節に列挙された4項目（上記参照）。
- `ec(i)`側で「参画後は編集不要」という設計意図自体を見直すこと（今回は
  導線を1つ追加するだけの最小修正で解決したため、`ec(i)`自体の描画条件は
  変更していない）。

## Codex Broad Review Round 1 対応（追加コミット）

### Codex Broad Review result

PR #269に対する初回Broad Review（`chatgpt-codex-connector[bot]`、reviewed
commit `0bdfe7c1a3`）: **CHANGES REQUESTED**。

- P0: 0件
- P1: 1件
- P2: 1件
- P3: 1件

GitHub上のインラインレビューコメント（review thread）として実際に確認
できたのはP2の1件（`lib/ui/public_demo/public_demo_monthly_report_dialog.dart:226`、
"Handle zero-sided revenue differences separately"）のみ。P1/P3は
タスク本文で詳細に記述された内容を根拠とし、Broad Reviewの再実行は
行っていない（指示通り）。3件とも本PR内で対応し、確認できたP2の
review threadはresolve済み。

### P1（必須修正）: legacy saveの面談質問で内部enum名が引き続き漏れる

**Codexの指摘**: 初回実装の`_target()`修正は「新規に生成される質問」しか
直しておらず、旧版（`requiredLanguages`が空の面談でtarget=
`"technicalExperience"`を書き込んでいた版）で開始・保存済みの
**active session**は、PR版へアップデートしてリロードしても
`ClientInterviewSession.fromJson`が保存済みのtarget/answer textをそのまま
復元するため、内部enum名が漏れ続ける。

**Freshコード確認で確認した事実**:
- `ClientInterviewQuestion.fromJson`/`ClientInterviewAnswer.fromJson`
  （`lib/game/models/client_interview.dart`）はJSONの`target`/`text`
  文字列をそのまま復元するだけで、サニタイズは一切行わない。
- `target`が汚染されたまま保存されている場合、`ClientInterviewEngine
  .answer()`（`lib/game/engine/client_interview_engine.dart`）が
  **新しく**回答を計算する際（次の質問へ進む、follow-upを選ぶ等）にも
  `q.target`をそのまま埋め込むため、「次の質問の回答」も新たに汚染される
  — 過去の回答文字列だけでなく、再開後に計算される回答も影響を受ける。
- `target`は`(category, project)`だけから決まる純粋関数の結果であり、
  `category`/`mismatch`/`quality`/`vague`などのauthorityフィールドとは
  完全に独立している（`lib/game/engine/game_engine.dart`の
  `finalRate`/`evaluate`はどちらも`target`/`text`を一切参照しない）。

**実装したmigration方法**:
`ClientInterviewEngine`に2つの新しい純粋関数を追加（
`lib/game/engine/client_interview_engine.dart`）:

```dart
static ClientInterviewSession sanitized(ClientInterviewSession session, Project project) {
  // 各questionのtargetを (category, project) から再導出し、
  // 各answerのtextを (category, 新target, 保存済みvague) から再生成。
  // category/mismatch/quality/vague/completed/result は一切変更しない。
}

static List<ClientInterviewSession> sanitizeLegacySessions(
  List<ClientInterviewSession> sessions,
  List<ProjectProposal> proposals,
) { ... } // Main Game: applicationId → ProjectProposal.project で解決
```

`sanitized()`は「新規生成されたセッションに対して実行しても値が変わらない
（idempotent）」ため、legacy/非legacyを判定するロジックは不要 — **常に**
実行して安全。

呼び出し箇所（authority/displayの境界を明確にするため、Main Game/Public
Demoそれぞれの「実際にセーブをロードする唯一の本番経路」にのみフック）:

- **Main Game**: `lib/game/persistence/save_service.dart`の
  `SaveService.load()`（Main Gameで`GameState.fromJson`が呼ばれる唯一の
  本番経路）。Projectは`state.proposals`から`session.applicationId`で
  解決（`GameEngine.startClientInterview`が元々セッションを紐付けるのと
  同じキー）。`lib/game/models/*`（純粋データ層）は`lib/game/engine/*`に
  依存しない既存の層構造を守るため、`models/game_state.dart`自体は
  変更せず、`persistence`層（既に`public_demo_save_codec.dart`が
  `engine/`に依存している前例あり）にサニタイズを置いた。
- **Public Demo**: `lib/game/public_demo/public_demo_aggregate.dart`の
  `PublicDemoAggregate.fromJson()`（`state.runSeed`と`workflow`の両方を
  同時に持つ唯一の場所）。Projectは`PublicDemoSeededProjectGenerator
  .regenerate(runSeed, projectId)`で解決 — Public Demoの他のPhase 6
  読み取りコード（`projectInterviewCandidateFor`等）が既に使っている、
  セーブデータに依存しない同じ決定的解決方法。新しい公開メソッド
  `PublicDemoWorkflowState.withSanitizedProjectInterviewSessions
  ({required int runSeed})`を追加。

`ClientInterviewSession.copyWith`に`questions`パラメータを追加（
既存呼び出し元は全て省略時に`this.questions`を使うため、既存の
挙動は一切変わらない）。

**Authorityへの影響**: なし。`category`/`mismatch`/`quality`/`vague`/
`completed`/`result`はすべて元の値のまま。`finalRate`/`evaluate`は
`target`/`text`を読まないため、score/pass-fail判定は無変更。

**Save Compatibility**: 新しい永続化フィールドは追加していない
（`copyWith`へのパラメータ追加はDartのAPI変更であり、JSON形式には
影響しない）。旧セーブは読み込み時に自動的にサニタイズされ、
その後の保存では既にクリーンな値が書き込まれる（べき等なので
何度保存/読み込みしても安定）。

### P2（必須修正）: 3月締めでも「来月入金予定」と表示してしまう

**Codexの指摘**: `revenue != cashReceived`の場合、`revenue`または
`cashReceived`のどちらかが`0`でも両方の説明文を無条件に表示していた
ため、「今月の入金¥0は先月分の売上」のような、実際には発生していない
取引を説明する不自然な文が出ていた。また3月（年度末）は翌月が
存在しないため、「来月入金予定」という保証できない予測を書いていた。

**修正内容**（`lib/ui/public_demo/public_demo_monthly_report_dialog.dart`
の`_cashDivergenceCaption`）: `data.revenue > 0`のときだけ売上側の説明を、
`data.cashReceived > 0`のときだけ入金側の説明を、それぞれ独立に追加する
よう分岐。3月（`closedMonth == 15`）は「年度末時点で未収」という、
未来を約束しない表現に変更。`revenue == cashReceived`（0円同士を含む）
の場合は引き続きcaption自体を出さない。新しい会計計算・新しいFinance
authorityは追加していない（読むのは既存の`data.revenue`/
`data.cashReceived`のみ）。

### P3（必須修正）: 新caption表示時に360×800でOne-Screen基準を4px超える

**Codexの指摘**: 360×800・TextScaler 1.0・revenue=¥800,000・
cashReceived=¥0・次アクションありの組み合わせで、`maxScrollExtent
== 4.0`（4pxだけスクロールが必要）になっていた。

**修正内容**: P2の文言修正で不要な文言（存在しない取引の説明）を削った
上で、`PublicDemoMonthlyReportDialog`の`insetPadding`/`titlePadding`/
`contentPadding`/`actionsPadding`と`_ReportSectionHeader`の上部paddingを
それぞれ数px単位でさらに詰めた（既存のISSUE-250 One-Screen対応が確立した
可読性/タップ領域の下限は維持）。情報は一切削っていない（純利益相当の
説明文はP2の分岐後も内容として保持）。

### Regression tests

- `test/game/client_interview_04b_test.dart`（Main Game）: legacy save
  （target="technicalExperience"、旧answer textにも同文字列を含む）を
  `SaveService`経由でロードし、(1)過去/現在/次の回答すべてに内部enum名が
  残らないこと、(2)quality/vague/mismatch/categoryが元の値と完全一致
  すること、(3)そのまま面談を完走した際のresult/accumulatedEvaluationが
  「汚染前のコントロール」と完全一致すること（score/pass-fail authority
  不変の証明）、(4)save→reloadが安定（idempotent）であることを検証。
  修正前のコード（サニタイズ呼び出しを外した状態）に対して実際に失敗
  することを確認済み。
- `test/game/public_demo/public_demo_project_interview_test.dart`
  （Public Demo）: 同内容を`PublicDemoAggregate.fromJson`経由で検証。
  こちらも修正前のコードに対して実際に失敗することを確認済み。
- `test/ui/public_demo/public_demo_monthly_report_dialog_test.dart`:
  - 新規group「5. 現金増減 vs 純利益相当 divergence caption」:
    通常月revenue>0/cashReceived>0（不一致）、revenue>0/cashReceived==0、
    revenue==0/cashReceived>0、3月でrevenue!=cashReceived、
    revenue==cashReceived（0円同士含む）でcaption非表示、の5パターン。
  - 既存group「4. One-Screen」に、Codex再現ケース（revenue=¥800,000、
    cashReceived=¥0、次アクションあり）を360×800/390×844 ×
    TextScaler 1.0/1.3の全4通りでoverflowなしを確認するテストと、
    360×800・TextScaler 1.0での`maxScrollExtent == 0`（スクロール不要）
    を確認するテストを追加。

### Self-hardening（今回分）

- Interview: new session / legacy active session / requiredLanguages
  empty・non-empty / technicalExperience・communication・workStyle
  各カテゴリ / past・current・next answer / save/reload / quality /
  vague / score / pass-fail — 上記regression testsで直接検証済み。
  Main Game・Public Demo双方の共有経路（`ClientInterviewEngine`）を
  それぞれ個別のテストファイルで確認。
  - 補足: "motivation"という単語自体はP1-1/Codex Round 1のいずれの
    findingにも登場せず、`ClientInterviewQuestionCategory`にも該当する
    値は存在しない（最も近いのは`workStyle`で、これは既存
    テストでカバー済み）。
- Monthly report: April（通常のrevenue==cashReceived経路、既存
  テストで確認）/ normal month / March / revenue 0 / cashReceived 0 /
  equal / diverged / 360×800 / 390×844 / TextScaler 1.0 / 1.3 —
  すべて新規テストで直接カバー。
- P1-2 regression（今回のP1/P2/P3では`activeProjectStatusCard`/
  Mission関連コードに変更なし）: edit after assignment・cancel・
  same-value save・Mission 8/8のテストは無変更のまま
  `test/ui/public_demo/public_demo_skill_sheet_edit_after_assignment_test.dart`
  に残っており、今回のフルスイート実行（1945/1945 pass）で
  再確認済み。

### Changed files（今回分）

```
lib/game/engine/client_interview_engine.dart
lib/game/models/client_interview.dart
lib/game/persistence/save_service.dart
lib/game/public_demo/public_demo_aggregate.dart
lib/game/public_demo/public_demo_workflow_state.dart
lib/ui/public_demo/public_demo_monthly_report_dialog.dart
test/game/client_interview_04b_test.dart
test/game/public_demo/public_demo_project_interview_test.dart
test/ui/public_demo/public_demo_monthly_report_dialog_test.dart
docs/reports/SES_FIRST-FUN-QUARTER_AI-REPLAY-FIX_Result.md（本ファイル）
```

### Tests（今回分）

- `flutter analyze`: プロジェクト全体で問題なし。
- `flutter test test/game/public_demo test/ui/public_demo
  test/game/client_interview_04b_test.dart
  test/game/save_service_isolation_test.dart
  test/game/project_interview_test.dart test/game/matching_test.dart`:
  **1945/1945 pass**。
- 新規テストはそれぞれ、対応する修正を一時的に外した状態で実際に
  失敗することを確認してから修正版に戻して再度green化（P1: Main
  Game/Public Demo双方、P3: 360×800レイアウトテスト）。
- `git diff --check`: 問題なし。
- `flutter build web --release`: 成功。

### Unresolved items（今回分）

- GitHub上でインラインコメントとして実際に確認できたCodex findingは
  P2の1件のみ（`resolve_review_thread`でresolve済み）。P1/P3は
  タスク本文の記述を根拠に対応したため、対応するGitHub review thread
  は見つからず、resolveも行っていない（存在しないthreadをresolveする
  ことはできない）。
- 「March actual authoritative DisplayData経路」の追加テストは、
  `PublicDemoMonthlyReportDisplayData.fromSnapshot()`を通した完全な
  実プレイスルー由来のfixtureではなく、同クラスの通常コンストラクタで
  `closedMonth: 15`を直接指定したfixtureで代替した（3月かつrevenue!=
  cashReceivedを実プレイで安定再現するには、Recovery割当ウィンドウ
  （7〜14月）の制約上、3月自体を初回請求月にする経路が存在せず、
  エンジニアリングコストに見合わないと判断）。ダイアログの実ウィジェット
  ・実`AlertDialog`構造を経由したテストである点は変えていない。
- Broad Reviewは指示通り再実行していない。

## PR

https://github.com/perusonao/smile_enjoy_story/pull/269

## Actual Processing Time

初回実装（セッション開始からPR #269作成まで）: 約1時間。

Codex Broad Review Round 1対応（本追記分、GitHub実状態確認から
追加commit push・review thread resolve・本レポート更新まで）:
約1時間20分（P1のmigration設計・Main Game/Public Demo双方への実装・
各修正の有効性検証（一時無効化→再現確認→復元）・レイアウト調整の
反復・フルテストスイート再実行を含む）。
