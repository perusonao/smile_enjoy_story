# SES Public Demo 0.1 — TR-0 社内/社外研修 調査・設計レポート

作成日: 2026-08-22
対象ブランチ: `claude/training-investigation-design-63zj0s`（`main` を fast-forward merge済み、コード変更なし）
前提コミット: `main` HEAD `b1762f8f` （指示書の期待値と一致を確認済み）

本レポートは指示書「S.E.S. Public Demo 0.1 — TR-0 社内/社外研修 調査・実装計画」に基づく調査結果である。
**コード変更・commit（本レポート以外）・push・PR作成は行っていない。** 研修機能そのものは実装していない。

---

## 1. 調査した実装/資料

### 実コード（`lib/game/public_demo/`）

| ファイル | 役割 |
|---|---|
| `public_demo_engineer_runtime.dart` | 社員ごとの「実体の能力値」を保持する ground-truth データ。SkillSheet/営業表示とは分離されている。 |
| `public_demo_growth_engine.dart` | `PublicDemoGrowthSource`（`assignment`/`waiting`/`internalTraining`/`externalTraining`）を入力に、純粋関数で成長量を計算する。 |
| `public_demo_monthly_growth.dart` | 1ヶ月分の成長結果を保存・表示用に軽量化したスナップショット。 |
| `public_demo_state.dart` | Public Demo 0.1 の中核状態（月・現金・人数・`engineerRuntimes`・`latestGrowthResults` 等）。`applyMonthlyGrowth()` が唯一の成長適用口。 |
| `public_demo_assignment.dart` | 案件参画の状態（次月発注可否・リプレイス進行等）。 |
| `public_demo_sales.dart` | 営業パイプラインの状態機械（`PublicDemoSalesStage`：`waiting`〜`ordered`）。 |
| `public_demo_employee_condition.dart` | モチベーション/信頼を定性ラベル化するだけの薄いユーティリティ。 |
| `public_demo_salary_finance.dart` | 給与オファーと基準経費から月次経費を算出。 |
| `public_demo_monthly_record.dart` | 月末スナップショットの永続表現（**現状、進行フローには未接続**、コメントで明記）。 |
| `public_demo_recruitment.dart` / `public_demo_interview.dart` / `public_demo_raise.dart` | 採用・面談・昇給の各ドメイン。 |

### UI（`lib/ui/public_demo/`）

`public_demo_01_placeholder_screen.dart`（1026行、全読了）が実質的に Public Demo 0.1 の唯一の画面。`engineers`/`applicants`/`assignments` は **`PublicDemoState` ではなくこの `StatefulWidget` のローカル `State` フィールド**として保持されている（後述§9で詳述）。

### 永続化

`lib/game/persistence/save_service.dart`、`lib/app/main.dart`、`lib/app/app_entry.dart` を確認。

### 既存テスト（`test/game/public_demo/`, `test/ui/public_demo/`）全13ファイルを一覧・主要ファイルを全読了。

### 資料

- `docs/DEVELOPMENT_PLAN.md`（780行、全読了）— Development（本編）向けのロードマップ。Public Demo 0.1 固有の記述は §3.9 の一部（Phase 3C の給与要求）のみで、研修専用の章は存在しない。
- `AGENTS.md`（27行、全読了）。
- リポジトリ全体を `研修|教育|Learning Ability|福利厚生|internalTraining|externalTraining` で grep → **Markdown資料内に一致なし**。
- `training`/`Training` を `lib/`, `test/` 全体で grep → **`public_demo_growth_engine.dart` の enum 値以外に一致なし**（Development本編側にも研修概念は存在しない）。

### Git履歴

`public_demo_growth_engine.dart` を追加したコミット `5ac5cb5`（`feat(public-demo): add engineer growth engine`）と、それを状態に接続したコミット `c703932`（`feat(public-demo): apply engineer growth on month advance`）を確認。コミットメッセージ・PR説明に "EG-1〜EG-4" という段階名の直接的な記載は見当たらず、指示書側で使われている呼称と推測される。ソースコード上のコメントには "EG-2 only computes results... deferred to EG-3" 等の記述があり、実装順序の履歴的整合は取れている。

---

## 2. 現在のGrowth Engineとの接続点

`PublicDemoGrowthSource`（`public_demo_growth_engine.dart:11-15`）:

```dart
enum PublicDemoGrowthSource {
  assignment,
  waiting,
  internalTraining,
  externalTraining,
}
```

`_capabilityDelta()`（同ファイル `:150-181`）は **4値すべてに対応する基礎倍率をすでに定義済み**:

```dart
final sourceBase = switch (request.source) {
  PublicDemoGrowthSource.assignment => 2.0,
  PublicDemoGrowthSource.waiting => 0.45,
  PublicDemoGrowthSource.internalTraining => 1.2,
  PublicDemoGrowthSource.externalTraining => 1.4,
};
```

この倍率に `growthPotential`（隠しパラメータ 1-5）由来の `potentialMultiplier`、`fastLearner`（`EmployeeAbility`）由来の `fastLearnerMultiplier`、`morale` 由来の `moraleMultiplier`、スキル上限に近づくほど弱まる `diminishingMultiplier` が乗算される。**この計算式自体は internalTraining/externalTraining に対してすでに完全に動作する状態**であり、テストのみ存在しない。

一方、`PublicDemoGrowthRequest`（実際に `PublicDemoGrowthEngine.calculate` へ渡される入力）を生成しているのは `PublicDemoState.applyMonthlyGrowth()`（`public_demo_state.dart:126-165`）ただ1箇所のみで、そこでの `source` 決定ロジックは：

```dart
final source = assignedEngineerIds.contains(runtime.engineerId)
    ? PublicDemoGrowthSource.assignment
    : PublicDemoGrowthSource.waiting;
```

**`internalTraining`/`externalTraining` を選択する分岐は存在しない。** つまり2値（`assignment` / `waiting`）のみが実際に生成され、`internalTraining`/`externalTraining` は Growth Engine 内で計算可能な状態のまま、呼び出し側から一度も渡されることのない未接続コードである。UI・状態・save/loadのどこにも「研修」という概念自体が存在しない。

---

## 3. 既存仕様（実コード/資料で確認できたもの）

- `PublicDemoGrowthSource.internalTraining` / `externalTraining` という列挙値と、それぞれの基礎成長倍率 `1.2` / `1.4` はすでに定義済み（§2）。`assignment=2.0`、`waiting=0.45` との相対関係（`waiting < internalTraining < externalTraining < assignment`）も既存コードの数値として確定している。
- Growth Engine の成長式は `sourceBase × potentialMultiplier × fastLearnerMultiplier × moraleMultiplier × diminishingMultiplier` で、`source` 以外の4項は全ソース共通。研修を追加してもこの式自体を変更する必要はない。
- `practicalExperience`（実務経験月数）は現状 `source == assignment` のときのみ `1`、それ以外（`waiting` を含む）は `0`。`industryExperience` も `practicalExperience > 0` かつ `industry != null` の場合のみ加算される（`public_demo_growth_engine.dart:89-92`）。**`internalTraining`/`externalTraining` を新たに `source` として渡しても、この既存条件分岐だけで自動的に「実務経験・業界経験は増えない」を満たす**——追加のガードコードは不要。
- `PublicDemoState.applyMonthlyGrowth()` は `growthAppliedMonths` により当月の重複適用を防止済み（`if (growthAppliedMonths.contains(month)) return this;`）。この既存ガードは研修導入後も再利用できる。
- 「Learning Ability」という名称のパラメータは**存在しない**。最も近いのは `HiddenParameters.growthPotential`（1-5、隠しパラメータ、UI非表示）と `EmployeeAbility.fastLearner`（性質フラグ）の組み合わせであり、Growth Engine はすでにこの2つを個人差として利用している。「福利厚生」に関する仕組みはコード上に存在しない。
- **Public Demo 0.1 には現状、動作する save/load 経路が存在しない。** `PublicDemo01PlaceholderScreen` は `main.dart`/`app_entry.dart` から `GameController`/`SaveService` を経由せず直接 `PhoneFrame(child: PublicDemo01PlaceholderScreen())` として生成される単純な `StatefulWidget` で、`s`/`engineers`/`applicants`/`assignments` はすべて起動のたびに初期値へリセットされるローカル `State` フィールドである。`SaveService.forExperience(AppExperience.publicDemo01)` というキー（`ses_public_demo_01_save_v1`）は存在するが、これを呼び出す箇所はコード中に一つもない。`PublicDemoState.toJson`/`fromJson` は `test/game/public_demo/public_demo_engineer_runtime_test.dart` でラウンドトリップ・旧セーブ互換のテストがされている「将来の接続に備えた」実装であり、現在の実プレイでは使われていない。
- **社員の「参画中/待機中」という所属は `PublicDemoState` ではなく UI（`_S` State）側の `engineers`（`PublicDemoSalesStage`）と `assignments`（`PublicDemoAssignment` のリスト）が真実の情報源であり、月末処理のたびにその場で `Set<String>` へ変換されて `_closeGrowth()` に渡されている**（例: `may()` 内 `engineers.where((e) => e.stage == ordered).map((e) => e.id).toSet()`）。`PublicDemoState.engineersAssigned`/`engineersWaiting` は人数のみを保持する派生値であり、個々の社員IDの所属集合そのものは保持していない。
- `PublicDemoGrowthResultCard`（UI）は現状 `assignment` か否かの2値でしか文言を出し分けていない（`assigned ? '案件参画を通じて成長' : '待機中の自己学習'`）。研修ソースの文言は未実装。
- `docs/DEVELOPMENT_PLAN.md` は Development（本編）向けのロードマップであり、Public Demo 0.1 の研修機能について直接規定していない。

---

## 4. 追加案（過去構想・未確定として存在するもの）

`docs/DEVELOPMENT_PLAN.md` に、研修そのものではないが関連する **本編（Development）向けの将来構想**が存在する。これらは Public Demo 0.1 の既存仕様ではなく、着想の参考情報として区別して扱う。

- **§7.4 資格取得支援/社員育成（後続拡張）**：「会社が受験費用を負担 → 社員が学習 → 合否 → 資格取得 → 営業信頼性/モチベーション/社員成長が変化」という将来構想。「基礎となる資格・キャリア履歴モデルが安定するまで実装しない」と明記されている。
- **§7.5 EmployeeAbility 拡張候補**：`learning speed`（学習速度）が将来追加候補として挙げられている。現行の `fastLearner` とは別概念として言及されており、「キャリア履歴・資格は EmployeeAbility とは区別すべき」という原則も明記。
- **§3.9 Phase 3C（Public Demo限定の先行実装メモ）**：6月以降、社員が昇給要求を出せる（hold/small raise/requested raise）という記述はあるが、これは Public Demo の既存実装（`public_demo_raise.dart`）に対応するものであり研修とは無関係。
- **§7.9 その他将来候補**：BP/パートナー会社、未経験者採用、資金調達等。研修と直接関係はしないが、指示書 §9 が挙げる「新人研修」「未経験者専用カリキュラム」の重複回避先として位置づけられる既存の将来トピック領域。

上記はいずれも **Development本編向け**であり、Public Demo 0.1 の仕様として確定しているものではない。矛盾があるわけではなく、単に「Public Demo 0.1 の研修」を直接規定する資料が存在しないことの確認である。

---

## 5. 推奨案（今回提案するもの）

指示書 §4 の最小案をベースに、実装調査で判明した以下の点を反映して微調整する。

1. `internalTraining`/`externalTraining` の基礎倍率（1.2 / 1.4）はすでに定義済みのため、**新しい倍率を重複定義せず、そのまま利用する**（指示書の明示条件どおり）。
2. `practicalExperience`/`industryExperience` が0のままになる条件は既存コードの分岐だけで自動的に満たされるため、**研修側に特別なゼロ化ロジックを書く必要はない**——ソース種別を渡すだけでよい。
3. Public Demo 0.1 は save/load が実際には未接続という事実を踏まえ、TR-1〜TR-4 では「将来の接続に備えて `PublicDemoState` のシリアライズ整合性は保つが、UIからの実際の保存/復元経路は変更しない（既存のまま = 未接続のまま）」を明示的なスコープとする。
4. 「案件参画」の所属情報が `PublicDemoState` ではなく UI ローカル状態にあるという既存アーキテクチャの非対称性は、研修選択にも同様のパターンを踏襲するか、`PublicDemoState` 側に寄せるかの判断が必要（§9で比較・結論）。

---

## 6. 社内研修設計

| 論点 | 推奨内容 | 根拠 |
|---|---|---|
| 対象 | 待機中の社員のみ（`PublicDemoSalesStage.waiting` 等、案件に参画していない社員） | 指示書の最小案どおり。案件参画中の社員は `assignment` ソースが優先されるべきで、研修と二重取りさせない。 |
| 案件参画中でも可否 | 不可（排他） | 「実務経験を積んでいる社員が同時に研修も受ける」という二重成長を避ける。既存の `assignedEngineerIds` 判定と一貫させる。 |
| 頻度 | 1ヶ月単位（月初〜月末の意思決定サイクルに合わせる） | 既存の月送り粒度（4月→5月等）と一致させ、新しい時間軸を作らない。 |
| 費用 | ¥0（無料） | 「低コストまたは無料」の指示に対し、実装・テストの単純化（現金減算ロジック不要）を優先し、無料を採用。 |
| Growth接続 | `PublicDemoGrowthSource.internalTraining` | 既存 enum をそのまま使用。 |
| Moraleへの影響 | なし（変更しない） | 現状 Public Demo にモチベーションを能動的に変化させる仕組みが存在しないため、根拠のない新規仕様を作らない。 |
| 実務経験 | 増えない（0のまま） | §3の既存分岐により自動的に満たされる。 |
| 業界経験 | 増えない（0のまま） | 同上。 |
| Learning Ability等との関係 | 既存の `growthPotential`/`fastLearner` 乗数がそのまま適用される | Growth Engine 側の式を変更しないため自動的に成立。 |
| 同一社員への連続実行 | 制限しない | スキル上限に近づくほど `diminishingMultiplier` が効くため、連続実行の旨味は自然に減衰する。追加の制限ロジックは不要。 |
| 月内の回数制限 | 1人につき当月1回（研修ソースは1つしか選べない、後述§9の排他制御） | 「内部研修と外部研修を同月に二重取り」を防ぐための最低限の制約。 |
| UI導線 | 待機中社員カード内にボタンを追加 | 既存の「SkillSheet確認」等と同じ場所に配置し、新しい画面遷移を作らない。 |
| プレイヤーへの提示 | 費用（¥0）・期待効果を定性的に一言（「待機よりも早く成長」）のみ | 内部倍率・growthPotential は非表示のまま。 |

---

## 7. 社外研修設計

| 論点 | 推奨内容 | 根拠 |
|---|---|---|
| 社内研修との差 | 費用あり・成長効率が高い（`externalTraining` 基礎倍率1.4 > `internalTraining` 1.2） | 既存倍率をそのまま利用。 |
| 現金コスト | ¥200,000 / 社員 / 月（詳細は§8） | 既存の経済バランス（月次基準経費 ¥800,000、給与レンジ ¥280,000〜¥360,000）に対して過大にならない水準。 |
| 研修期間 | 1ヶ月固定 | 指示書§9で「研修期間2〜3か月」は明示的に対象外（将来仕様）としているため、Demo 0.1では単月固定。 |
| 案件参画との排他 | 排他（社内研修と同じ扱い） | §6と同じ理由。 |
| Moraleへの影響 | なし（変更しない） | §6と同じ理由。既存に無い仕組みを勝手に作らない。 |
| Learning Ability等による個人差 | 既存の `growthPotential`/`fastLearner` 乗数がそのまま適用される | 式変更なしで自動的に成立。 |
| 実務/業界経験との区別 | 増えない（0のまま） | §3と同じ既存分岐により自動的に満たされる。 |
| 連続利用制限 | 制限しない（現金が続く限り毎月選択可） | 現金という自然な制約が既に機能するため、追加ロジック不要。 |
| UI導線 | 待機中社員カード内、社内研修ボタンの隣に配置。現金不足時はボタンを disabled にする（`s.salesRemaining > 0 ? ... : null` と同じ既存パターンを踏襲） | 既存コードの一貫したUIパターンを再利用。 |

---

## 8. 推奨パラメータ

既存の経済バランス（`aprilStart()`: 現金 ¥3,000,000、月次基準経費 ¥800,000、応募者希望給与 ¥280,000〜¥360,000/月）を壊さない値として、以下を推奨する。

| パラメータ | 推奨値 | 理由 |
|---|---|---|
| 社内研修費 | ¥0 | 既存倍率(1.2)は待機(0.45)より十分高く、無料でも選ぶ動機が成立する。現金減算ロジック・不足時テストが不要になり実装/テストが単純化する。 |
| 社外研修費 | ¥200,000/人/月 | 月次基準経費(¥800,000)の約1/4、最低給与水準(¥280,000)より低い。初期現金¥3,000,000に対し、待機社員2〜3名が同時に選んでも即座に資金ショートしない範囲。 |
| internalTraining成長倍率 | **既存値 `1.2` をそのまま使用**（新規定義しない） | 指示書の明示条件（既存倍率の重複定義禁止）。 |
| externalTraining成長倍率 | **既存値 `1.4` をそのまま使用**（新規定義しない） | 同上。 |
| Morale変化 | なし（±0固定） | 既存にMoraleを能動変化させる仕組みが存在しないため新設しない。 |
| 利用条件 | 待機中のみ、当月1ソースまで選択可 | §6/§7。 |
| 1か月に選べる人数 | 上限なし（待機人数が自然な上限） | Demo 0.1 の社員数（2〜3名程度）では過大な影響を及ぼさないため、人為的な上限は設けない。 |
| 同一社員の連続研修可否 | 可（制限なし） | 逓減乗数が自然にブレーキになる。 |
| cash不足時の挙動 | 選択ボタンを disabled にし、選択自体をブロックする（現金がマイナスになる状態を作らない） | 既存の「営業残0のとき面談ボタンを無効化」パターンと一貫。 |
| 研修中社員を営業/案件提案可能にするか | 不可（研修選択中は営業系ボタンを非表示/無効化） | 案件参画との排他と同じ理由——同月に研修と営業活動を同時に進めると`assignment`/`training`の二重ソースになりかねない。 |
| 月途中キャンセルの有無 | 可（月末処理の直前まで無料でキャンセル可能） | まだ現金を引いていない段階でのキャンセルなので払い戻し処理が不要——実装がシンプルになる。 |
| 研修選択後、月送りまでの表示 | 社員カードのバッジを「待機」→「研修中（社内）」/「研修中（社外）」に変更するのみ。数値の内部倍率は表示しない | 指示書§8の「growthPotentialや詳細な内部倍率は原則表示しない」に準拠。 |

---

## 9. 状態モデル比較と採用案

前提として、**現状 `PublicDemoState` は「案件参画中かどうか」という個々の社員IDの所属集合そのものを保持していない**（人数の集計値のみ）。所属の実体は UI（`_S` State）の `engineers`/`assignments` ローカルリストにあり、月末処理の瞬間に `Set<String>` へ変換されて `PublicDemoState.applyMonthlyGrowth()` に渡される、という非対称なアーキテクチャがすでに存在する（§3）。この事実を踏まえて4案を比較する。

| 案 | 内容 | SSOT | save/load | 月次処理 | UI | assignmentとの排他 | 将来拡張 |
|---|---|---|---|---|---|---|---|
| A. `PublicDemoEngineerRuntime` に training state を持つ | runtime自体に「今月の選択」フィールドを追加 | runtimeは月をまたいで永続する「実体能力」を表すクラスであり、月次で毎回リセットされる一時的な選択を持たせると意味が混在する（ファイル冒頭コメント「does not contain SkillSheet/sales values」の設計意図にも反する） | 毎月クリアが必要な一時フィールドをruntimeのtoJson/fromJsonに混ぜると、既存のラウンドトリップテスト（§1で確認した`public_demo_engineer_runtime_test.dart`）の意味が変わってしまう | runtimeのcopyWithで都度リセットが必要になり煩雑 | runtimeを経由してUIに伝える必要があり間接的 | 判定ロジックがruntime内外に分散する | 拡張時にruntimeの責務がさらに肥大化する |
| **B. `PublicDemoState` に月次training selectionを持つ（推奨）** | `PublicDemoState` に `Map<String, PublicDemoGrowthSource> trainingSelections`（値は`internalTraining`/`externalTraining`のみ）を追加し、`applyMonthlyGrowth()`適用後にクリア | 単一の型付きフィールドが唯一の情報源になる | `PublicDemoState.toJson/fromJson`は既にラウンドトリップ・旧セーブ互換テストの対象であり、同じパターンで追加すればテスト整合性を保ったまま将来のsave/load接続に自然に乗る | `applyMonthlyGrowth()`の中で`assignedEngineerIds`より優先度は下・`waiting`より優先度は上、という1箇所の判定に閉じる | `PublicDemoState`のメソッド（`selectInternalTraining`/`selectExternalTraining`/`cancelTraining`）をUIから呼ぶだけで完結 | `applyMonthlyGrowth()`内で`assignedEngineerIds`を優先させる1行のガードで表現できる | 既存の`growthAppliedMonths`/`latestGrowthResults`と同じ置き場所にあるため、将来の資格取得等の拡張時も同じパターンを踏襲しやすい |
| C. employee status自体（`PublicDemoSalesStage`）に training を追加 | `waiting`の代わりに`trainingInternal`/`trainingExternal`のようなstageを増やす | `PublicDemoSalesStage`は営業パイプラインの進行度（面談・紹介・受注）を表す列挙であり、「待機中に何をしているか」という直交する概念を混在させると意味が破綻する（例：`introduced`中の社員が研修も選べるのか、という不整合が生じる） | stageの意味が変わるため、既存の`engineerStep()`/`engineerStatus()`等の分岐網羅（switch式）を全て見直す必要があり影響範囲が広い | 既存のstage分岐コードに新規caseを追加する箇所が多岐にわたる | 既存の`engineerStatus()`のswitch式に手を入れる必要がある | 「待機中」という状態自体を研修が上書きしてしまうため、排他は表現しやすいが、逆に案件営業の再開時に元のstageへ戻す遷移を新設する必要がある | 将来的な営業ステージ拡張とバッティングしやすい |
| D. その他（UIローカル状態に、`assignedEngineerIds`と同じパターンで一時保持） | `_S`の`engineers`/`assignments`と同様、`Set<String> internalTrainingEngineerIds`等をwidgetのState fieldに持つ | 現状の「参画中/待機中」の真実の情報源と同じ置き場所になり、アーキテクチャ的な一貫性は最も高い | 現状Public Demo 0.1は実際にはsave/loadが未接続（§3）なので実害はないが、**将来persistenceが接続された瞬間に何もしないと研修選択だけ保存されないままになる**——Bと違い、後から明示的な追加作業が必要になる | `_closeGrowth()`呼び出し時に`trainingSelections`相当のパラメータを組み立てるだけで済み、Bとほぼ同等 | Bと同等 | Bと同等 | 将来の save/load 接続時に取りこぼしが起きやすい |

**採用案: B.** 理由:
- 現状の「所属がUIローカルにある」非対称性（Dの根拠）は今回の研修追加が原因で生まれたものではなく、既存の設計上の負債である。これを研修選択にまで広げて追認するより、`PublicDemoState`が既に備えているtoJson/fromJsonおよびラウンドトリップテストの枠組みに素直に乗せる方が、指示書が明示する評価軸（save/load・将来拡張）に対して優位。
- `applyMonthlyGrowth()`という単一の適用口に閉じ込められるため、二重適用防止も既存の`growthAppliedMonths`ガードをそのまま使い回せる（§10）。
- A・Cは責務混在・影響範囲の広さの点で明確に劣る。

---

## 10. 月次処理順

### 現在の実装順（例: `april()`, `may()`, `june()`, `july()` in `public_demo_01_placeholder_screen.dart`）

```
1. 当月中の意思決定を反映したローカル状態（engineers/applicants/assignments）を確定
2. （必要なら）イベントダイアログを await 表示
3. setState:
     s = _closeGrowth(assignedEngineerIds)   // PublicDemoState.applyMonthlyGrowth()
           .advanceToX(monthlyExpenses: ..., ...)  // 月送り + 固定経費の現金減算
```

`applyMonthlyGrowth()`は`growthAppliedMonths.contains(month)`により当月の重複適用を防止済み。`advanceToX`系は月送りと同時に**固定経費のみ**を現金から減算する。

### 研修を組み込んだ推奨順序

```
[月の途中、随時]
  待機中社員のカードで「社内研修」/「社外研修」ボタンを押す
    → PublicDemoState.selectInternalTraining(id) / selectExternalTraining(id)
    → setState のみ（現金・成長への反映はまだ行わない）
    → バッジ表示が即座に「研修中」に変わる（§8）
  「選択を取り消す」を押せば selectionをクリアして「待機」に戻す（コスト未発生なので払い戻し不要）

[月末ボタン押下時]
  1. 当月の意思決定を確定（既存どおり）
  2. イベントダイアログ（既存どおり）
  3. setState:
       s = _closeGrowth(assignedEngineerIds)
             .advanceToX(...)

     _closeGrowth() 内の applyMonthlyGrowth() を以下のように拡張する:
       a. growthAppliedMonths.contains(month) なら即return（既存ガードを再利用 = 二重適用防止）
       b. 各社員について、source を以下の優先順位で決定:
            assignedEngineerIds に含まれる → assignment
            trainingSelections にエントリがある → その値（internalTraining/externalTraining）
            それ以外 → waiting
          （assignment を最優先にすることで、万一UI側の選択解除漏れがあっても
            案件参画と研修が二重に成立することはない）
       c. 成長をGrowth Engineで計算・適用（既存ロジックをそのまま利用）
       d. 当月の trainingSelections のうち externalTraining の人数 × ¥200,000 を
          cash から一括減算（このステップも b と同じ関数内で行うことで、
          「growthAppliedMonthsガードが一度しか通らない」という既存の保証を
          そのまま現金減算の二重課金防止にも転用する）
       e. trainingSelections を空 {} にクリアして返す（翌月は選択なしから開始）
```

**費用をいつ引くか**: 研修「選択」時ではなく、**月末の `applyMonthlyGrowth()` 内、成長適用と同じ状態遷移の中で**引く。理由:
- 選択時に即座に引いてしまうと、月途中キャンセル時の払い戻し処理が別途必要になり、二重課金・返金漏れのリスクが増える。
- 月末の1回の状態遷移に集約することで、既存の `growthAppliedMonths` ガード1つだけで「二重課金・二重Growth」の両方を同時に防止できる（新しいガード変数を増やさない）。

---

## 11. UI/UX

スマホ縦画面・情報過多回避を前提に、既存パターンを踏襲する。

- **研修入口**: 待機中社員一覧（`ec()`カード）の中。社員詳細を別途新設せず、既存の「SkillSheet確認」「営業開始」ボタン群と同じ場所に「社内研修」「社外研修」ボタンを追加する（新規画面遷移を作らない）。
- **社内/社外の比較**: 2つのボタンを並べ、各ボタン直下に一言ずつ定性テキスト（例: 社内＝「無料・待機よりも早く成長」、社外＝「¥200,000・社内研修よりもさらに高い効果」）を表示。数値の内部倍率・growthPotentialは非表示。
- **費用表示**: 社外研修のみ金額を明示。社内研修は「無料」とだけ表示。
- **期待効果**: 「実務経験・業界経験は増えません」の一言を両方に共通表示し、案件参画との違いを明確にする。
- **選択済み表示**: 社員カードのバッジを既存の`badge()`ウィジェットで「研修中（社内）」/「研修中（社外）」に変更。
- **キャンセル**: 「選択を取り消す」ボタンを研修中バッジの下に表示。月末処理前ならいつでも無料で取り消し可能。
- **月次結果への表示**: `PublicDemoGrowthResultCard`（既存）の `assigned ? '案件参画を通じて成長' : '待機中の自己学習'` を3値以上のswitchに拡張し、`internalTraining`→「社内研修を通じて成長」、`externalTraining`→「社外研修を通じて成長」を追加。既存の成長数値表示（`before → after (+delta)`）はそのまま流用。

---

## 12. save互換

- **現状、Public Demo 0.1 は実際のsave/load経路を持たない**（§3）。したがって「既存セーブとの互換性を壊す」というリスクは実プレイ上は発生しない。
- ただし `PublicDemoState.toJson/fromJson` は独立してテスト対象（`public_demo_engineer_runtime_test.dart`）になっており、将来のsave/load接続を見越して正しさを保っておくべき既存の契約である。
- 採用案（§9 案B）に従い `trainingSelections` を追加する場合、既存の `industryExperience`/`abilities`（`PublicDemoEngineerRuntime.fromJson`）や `growthAppliedMonths`（`PublicDemoState.fromJson`）と同じ**「キーが無ければ空のデフォルトにフォールバックする」パターン**（`json['trainingSelections'] as Map<String, dynamic>? ?? {}`）を踏襲すれば、旧形式のJSON（研修導入前に生成された）を読み込んでもクラッシュせず「研修選択なし」として復元できる。
- 新しいテストとして、`public_demo_engineer_runtime_test.dart`の既存パターン（`state.toJson()..remove('engineerRuntimes')`）と同型の「`trainingSelections`キーを取り除いた旧JSONが読み込める」ケースをTR-1で追加する。

---

## 13. 既存仕様との矛盾

調査の結果、**指示書の最小案（§4記載）と実コード・資料の間に明確な矛盾は見つからなかった**。強いて挙げるべき差分は以下の1点のみ：

- 指示書は「既存コードにすでに倍率がある場合は、新しい倍率を重複定義しない」と明示しており、実際に `internalTraining=1.2`/`externalTraining=1.4` が既存コードに存在することを確認した。本レポートの推奨案（§8）はこれに完全準拠し、新しい倍率を提案していない。矛盾ではなく、指示の前提が正しかったことの確認である。

---

## 14. Public Demo 0.1最小範囲（今回実装する予定の範囲・TR-1以降の対象）

- 待機中社員に対する「社内研修」「社外研修」の選択・取り消し
- `PublicDemoGrowthSource.internalTraining`/`externalTraining` への接続（既存倍率をそのまま使用）
- 社外研修費用（¥200,000/人/月、月末に一括減算）
- 現金不足時のボタン無効化
- 案件参画との排他
- 月次結果表示（研修ソース別の文言）
- `PublicDemoState`のシリアライズ整合性維持（実際のUI経路の保存/復元は変更しない）

---

## 15. Demo 0.1では実装しない範囲（指示書§9のとおり明記・確定）

- 複数研修コース
- 資格取得
- Java/Python/AWS等の個別講座
- 外部研修会社（取引先の選択等）
- 研修期間2〜3か月（Demo 0.1は単月固定）
- 研修成功/失敗イベント（Demo 0.1は必ず成長が発生する決定論的モデル）
- 助成金
- 教育担当社員
- 新人研修
- 未経験者専用カリキュラム

これらは `docs/DEVELOPMENT_PLAN.md` §7.4（資格取得支援/社員育成）や §7.9（未経験者採用等）の将来領域と重複しうるため、後工程で改めて設計する。

---

## 16. 必要test（TR-1以降で追加する想定）

指示書§10の列挙に対応させ、既存テストファイルの配置パターンに沿って分類する。

**`test/game/public_demo/public_demo_state_test.dart` または新設 `public_demo_training_test.dart`**
- waiting → internalTraining（`applyMonthlyGrowth`が正しいsourceを使う）
- waiting → externalTraining（同上）
- assignmentとの排他（`assignedEngineerIds`に含まれる社員はtrainingSelectionsがあっても`assignment`が優先される）
- 実務経験が増えない（`actualExperienceMonthsDelta == 0`）
- industry経験が増えない（`industryExperienceMonthsDelta == 0`）
- cash deduction（externalTraining選択者数 × ¥200,000がcashから引かれる）
- insufficient cash（現金不足時に選択自体が失敗する/UIでブロックされることをドメイン層のヘルパーで検証）
- 二重課金防止（`applyMonthlyGrowth`を同月に2回呼んでもcashが1回分しか減らない = 既存`growthAppliedMonths`ガードの再利用を検証）
- 二重Growth防止（同上、成長も1回分しか適用されない）
- save/load（`trainingSelections`を含むJSONのラウンドトリップ、および旧JSON=キー無しからの読み込み）

**`test/game/public_demo/public_demo_growth_engine_test.dart`（既存ファイルへの追加）**
- internal/externalのGrowth差（`internalTraining`の成長量 < `externalTraining`の成長量、既存の`assignment vs waiting`テストと同型）
- Learning Ability等（growthPotential/fastLearner）の個人差が研修ソースでも維持される（既存テストパターンの`source`パラメータを研修値に差し替えるだけで書ける）

**`test/ui/public_demo/`（既存ウィジェットテスト群への追加）**
- 待機中社員カードに研修ボタンが表示される
- 研修選択でバッジが変わる／取り消しで「待機」に戻る
- 現金不足時に社外研修ボタンがdisabledになる
- 月次結果表示（`PublicDemoGrowthResultCard`）が研修ソースに応じた文言を出す
- 既存の360/390幅のレイアウト崩れがないこと（既存の同種テストの踏襲）

**回帰確認**
- 既存assignment/waiting Growthのテスト（`public_demo_growth_engine_test.dart`の既存9ケース）が変更なく通ること
- 会計回帰（`public_demo_monthly_loop_test.dart`, `public_demo_salary_finance_test.dart`の既存ケースが変更なく通ること、特に `cashAfter - cashBefore` の内訳に研修費が正しく追加されるだけで既存の固定経費ロジックが壊れていないこと）

---

## 17. 実装順序/commit分割

指示書§11の例をベースに、実コードの構造に合わせて確定する。

### TR-1: training state/domain + save互換
- **変更対象**: `public_demo_state.dart`（`trainingSelections`フィールド、`selectInternalTraining`/`selectExternalTraining`/`cancelTraining`メソッド、`toJson`/`fromJson`拡張）
- **完了条件**: 新規フィールドがコンパイル・既存の`toJson`/`fromJson`テストが無変更で通る。UI・Growth Engineへの接続はまだ行わない（このメソッド群はまだどこからも呼ばれない状態でよい）。
- **必須test**: §16の「save/load」項目、選択/取り消しの状態遷移単体テスト
- **commit境界**: `public_demo_state.dart` + 対応テストのみ。UIファイル・Growth Engineファイルは触らない。

### TR-2: 月次Growth/費用接続
- **変更対象**: `public_demo_state.dart`の`applyMonthlyGrowth()`（source決定ロジック拡張、cash減算追加）。Growth Engine自体（倍率定義）は変更しない。
- **完了条件**: `trainingSelections`に基づき正しい`PublicDemoGrowthSource`が渡り、成長・現金減算が月末に1回だけ発生する。UIはまだ接続しない（`applyMonthlyGrowth`の呼び出しシグネチャ変更があればUI側の呼び出しは追随させる必要があるため、その最小限の配線のみ許容）。
- **必須test**: §16の「waiting → internalTraining/externalTraining」「assignmentとの排他」「実務/industry経験ゼロ」「cash deduction」「insufficient cash」「二重課金/二重Growth防止」「internal/externalのGrowth差」「個人差維持」
- **commit境界**: `public_demo_state.dart` + `public_demo_growth_engine_test.dart`への追加 + 新設ドメインテストのみ。

### TR-3: training selection UI + 月次結果
- **変更対象**: `public_demo_01_placeholder_screen.dart`（研修ボタン・バッジ・キャンセルボタン）、`public_demo_growth_result_card.dart`（文言分岐）
- **完了条件**: 実際にボタン操作で選択・取り消しができ、月末に正しい成長・費用が反映され、結果カードに研修文言が出る。
- **必須test**: §16の「UI」項目全て（研修ボタン表示、バッジ切替、cash不足disabled、月次結果文言、360/390レイアウト）
- **commit境界**: UIファイル + 対応ウィジェットテストのみ。TR-1/TR-2で追加した状態/ドメインAPIを呼び出すだけで、状態モデル自体は変更しない。

### TR-4: tests/Chromium/デプロイMilestone
- **変更対象**: なし（コード変更なし）。既存のPlaywright（Chromium blocking / WebKit non-blocking、指示書の絶対条件どおりWebKit helper/specは変更しない）を含めたフルリグレッションの実行と結果確認。
- **完了条件**: `flutter test`全体・関連Playwrightが通り、既存の`public-demo-validation`ワークフローで問題がないことを確認。
- **必須test**: 既存の全回帰スイート（§16の回帰確認を含む）
- **commit境界**: なし（テスト実行のみ、必要であれば軽微なCI/ドキュメント更新に限定）。

---

## 18. リスク

- **バランスリスク**: 社外研修費(¥200,000)は現状の社員数（2〜3名）を前提にした値であり、将来Public Demoの社員数が増えた場合は同時選択による現金消費ペースを再検証する必要がある。
- **倍率の独自解釈リスク**: `internalTraining=1.2`/`externalTraining=1.4`は先行実装者（EG-2相当のコミット）が根拠ドキュメントなしに定義した値であり、TR-1〜TR-4はこれを**変更せずそのまま使う**ことが前提。もしプレイテストの結果チューニングが必要になった場合は、Growth Engineの既存値を上書きする明示的な別タスクとして扱い、今回のレポートの推奨値（§8）と黙示的に矛盾させない。
- **アーキテクチャ負債の温存**: §9で明らかになった「案件参画の所属がPublicDemoStateではなくUIローカル状態にある」という既存の非対称性は、今回のスコープでは是正しない（指示書の絶対条件「研修機能を実装しない」の範囲外）。将来、この非対称性自体を解消するタスクが発生した場合、`trainingSelections`の設計（案B）もあわせて見直しが必要になる可能性がある。
- **save/load未接続の見落としリスク**: 実プレイでsave/loadが機能していないため、TR-1〜TR-3の実装者が「セーブ経路がある」という前提で作業しないよう、本レポートの§3・§12の事実確認を必ず共有する。

---

## 19. TR-1へ渡す具体的実装ポイント

- `public_demo_state.dart`に追加するフィールド案:
  ```dart
  final Map<String, PublicDemoGrowthSource> trainingSelections; // 値は internalTraining/externalTraining のみ
  ```
  デフォルトは`const {}`。
- 追加メソッド案:
  - `PublicDemoState selectInternalTraining(String engineerId)`
  - `PublicDemoState selectExternalTraining(String engineerId)`
  - `PublicDemoState cancelTraining(String engineerId)`
  いずれも`trainingSelections`の`copyWith`のみを行う純粋な状態遷移とし、cashやgrowthには一切触れない（§10の「選択時にはコストを引かない」設計を反映）。
- `applyMonthlyGrowth()`のsource決定を以下の優先順位に変更:
  ```
  assignedEngineerIds.contains(id) → assignment
  else trainingSelections[id] があれば → その値
  else → waiting
  ```
- 外部研修費用の定数は`public_demo_state.dart`か新設の軽量定数クラス（例: `PublicDemoTrainingCost`）に`¥200,000`として1箇所だけ定義し、UIとドメインの両方から同じ定数を参照する（金額の二重管理を避ける）。
- `toJson`/`fromJson`は既存の`industryExperience`/`growthAppliedMonths`と同じ「欠損時は空へフォールバック」パターンを踏襲。
- Growth Engine（`public_demo_growth_engine.dart`）自体は**一切変更しない**——倍率もロジックも既存のまま利用可能であることをTR-2着手前に再確認すること。

---

## 20. Git状態（コード変更なし確認）

```
$ git log --oneline -3
b1762f8 Merge pull request #48 from perusonao/agent/e2e-webkit-navigation-stabilization
3b06b47 Merge remote-tracking branch 'origin/main' into agent/e2e-webkit-navigation-stabilization
6ad91c8 Merge pull request #50 from perusonao/ci/webkit-nonblocking-policy

$ git status
On branch claude/training-investigation-design-63zj0s
（このレポートファイル追加のみ、コード側の変更なし）
```

- 作業ブランチ `claude/training-investigation-design-63zj0s` は当初 `main` から派生していない孤立コミット（`f4ca78f`, Phase 0A/0B）のみを含んでいたが、そのコミットは既に `origin/main` の祖先であることを確認した上で `git merge --ff-only origin/main` によりブランチを `main` HEAD `b1762f8f` まで進めた（`git reset --hard`は環境のポリシーでブロックされたため、履歴を書き換えない fast-forward merge を使用）。
- `lib/`, `test/`, `.github/`, WebKit関連ファイル（`e2e/`）は一切編集していない。
- `stash@{0}`/`stash@{1}` は操作していない（そもそも本セッションでstashは使用していない）。
- 既存の未追跡ログ/画像/docxファイルには触れていない。
- 本レポート (`docs/SES_TR-0_Internal_External_Training_Investigation_Report.md`) の追加のみが本セッションの成果物であり、これから別途commitする。
