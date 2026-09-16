# SES First Fun Quarter — AI Replay Audit Fix (Result Report)

Status: **Implemented, self-hardened, focused + full public_demo regression suites green, web build green.**

## Base main SHA

`git fetch origin main` was run at session start. `origin/main`（`refs/heads/main`）は
**`af90479e966a17d752337921f34a2475d9559d1a`**（PR #268 "SES Phase 4 Document
Screening" のマージコミット）— タスクで指定された監査対象SHAと完全一致（drift無し）。

作業ブランチ `claude/ai-replay-audit-fix-l64sdg` はローカルに古い無関係の内容
（"Phase 0A/0B: SES domain models and random generators" — 現在のmain系譜には
存在しない、無関係な過去のスキャフォールド）が残っていたため、`origin/main`から
作り直した（`git checkout -B claude/ai-replay-audit-fix-l64sdg origin/main`）。

## Final HEAD SHA

`0bdfe7c1a3c0cc3c28fdfc3e585835c359646825`

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
- legacy save: `target`の読み込み側（`fromJson`）は無変更のため、旧セーブに
  焼き込まれた文字列（内部識別子を含む可能性のあるもの含む）もそのまま
  読める。新規に生成される質問だけが新ラベルを使う。
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

## PR

https://github.com/perusonao/smile_enjoy_story/pull/269

## Actual Processing Time

セッション開始（`git fetch origin main`）からPR作成・本レポート作成完了まで、
約1時間40分（コード調査・実装・Flutter SDKのセットアップ・複数回のフル
テストスイート実行・flake切り分けのためのpristine main比較実行を含む）。
