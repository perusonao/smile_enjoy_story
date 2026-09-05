# SES FIRST-FUN-YEAR-LATE-GAME-1 / Issue #167 Phase 1 — 実装パラメータ確定（READ-ONLY）

Status: **READY WITH CONDITIONS**（詳細は I. 最終判定）

## 監査対象 SHA

- `origin/main` を fetch して監査した。
- **Audited SHA: `63d79bec203acdd46d01405454faa17a4e3b30bd`**（2026-09-05 15:37:33 +0900）

## 参照資料の可用性について（重要な前提）

指示された下記2点は、現在のセッションのファイルシステム・`git log --all` のいずれにも存在せず、
`perusonao/smile_enjoy_story` の履歴上に痕跡がない（コミットされたことがない）。

- `docs/reports/SES_FIRST-FUN-YEAR_LATE-GAME-1_Phase1_PreImplementation_Final.md`
- `docs/reports/SES_FIRST-FUN-YEAR_Post-176_Priority_Audit.md`

これは本タスク自身の指示（production/tests/workflow 変更禁止、commit/push/PR 不要）と同様に、
過去の READ-ONLY 監査セッションもこれらのレポートをコミットしていなかったためと考えられる
（セッションのコンテナ終了とともに消えた可能性が高い）。

代わりに以下を一次情報として本レポートを作成した。

- Issue #167 本文 + コメント（`design audit complete` コメント、2026-09-04 時点の暫定結論を含む）
- Issue #129
- Issue #166 / #147 / #168（#167 が依存すると明記している3件。**いずれも `open` のまま**）
- `docs/reports/SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md`（origin/main に実在。Issue #167 が
  根拠とする「8月〜2月が単調」という一次証拠そのもの）
- `origin/main` の実コード（`lib/game/public_demo/**`, `lib/domain/models/engineer.dart` 等）

`SES_FIRST-FUN-YEAR_Post-176_Priority_Audit.md` は実在しないため、そこに記載されていたという
「鈴木の営業機会は4月だけ」という記述を本レポートの根拠として一切使用していない。ただし同趣旨の
事実（創業社員 鈴木葵 eng-02 が初期実力52で4月の営業実力60に届かず、以後その年度は営業不可）は
`SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md` の実プレイ記録の脚注として独立に確認できる。
これは Finding B 監査の専用テーマであり、本タスクでも Finding B のルール変更は行っていない
（本レポートは鈴木のようなFinding B対象社員をPhase 1の対象に含めない、という別経路の結論のみ使う）。

---

## A. 確定パラメータ表

| # | 項目 | 確定値 |
|---|---|---|
| A-1 | 対象社員集合 | **入社済み応募者（`PublicDemoApplicant`, `employeeMorale`/`employeeCompanyTrust` が non-null）かつ判定月時点で `assignedEngineerIds` に含まれる者のみ**。創業社員（`PublicDemoEngineerSales` ベースの `engineers`）は対象外（詳細 E） |
| A-2 | 発生方式 | **社員ごとの one-shot**（当該社員について生涯1回。cooldown/条件反復は不採用 — 詳細 B） |
| A-3 | 発生ウィンドウ | internal month **8〜14**（暦: 8月〜翌2月、`advanceToNextOrdinaryMonth` の対象範囲と完全一致） |
| A-4 | 発生条件 | 対象社員が (a) 入社済み (b) ウィンドウ内の月で参画中 (c) まだこの決定をしていない、の3条件を満たす最初の月にカードが出現し続ける（強制モーダルではなく、`employeeConditionCard` 内の常設ボタンとして — 昇給要求ボタンと同じ提示方式） |
| A-5 | 選択肢1: 様子を見る | cash 0円、moraleDelta 0、trustDelta 0 |
| A-6 | 選択肢2: フォロー | cash **¥15,000（対象1名あたり）**、moraleDelta **+5**、trustDelta **+3** |
| A-7 | 選択肢3: 追加投資 | cash **¥45,000（対象1名あたり）**、moraleDelta **+12**、trustDelta **+6** |
| A-8 | Finance制限時の挙動 | `PublicDemoState.isFinanciallyRestricted`（cashShortage or terminal）の間、"様子を見る" 以外の2択は既存の内定承諾/研修/賞与と同じ扱いで拒否。cash不足時（`state.cash < cost`）も同様に拒否 |
| A-9 | 一度きり性の保存方法 | `PublicDemoApplicant` に nullable な `followUpDecision`（enum）+ `followUpDecisionMonth`（int?）を追加。既存の `raiseDecision`/`raiseEffectiveMonth` と同型パターン |
| A-10 | Growth Engine 側の変更 | **なし**。`PublicDemoGrowthEngine._capabilityDelta` の `moraleMultiplier`（<30→0.75 / 30-75→1.0 / >75→1.10）は現状のまま利用するのみで、閾値・倍率いずれも変更しない |
| A-11 | Trustの扱い | 上昇はするが、**現状のゲーム結果に対する入力としては使われていない**ため、UIコピー上も「主要な効果」として謳わない（詳細 B/E） |

---

## B. 各値のauthority/根拠

### B-1. Morale効果量 — 現行Growth Engineの実際の閾値・倍率

authority: `lib/game/public_demo/public_demo_growth_engine.dart`（`PublicDemoGrowthEngine._capabilityDelta`）

```dart
final moraleMultiplier = request.morale < 30
    ? 0.75
    : request.morale > 75
    ? 1.10
    : 1.0;
```

- 実際の閾値は **<30 で 0.75倍、>75 で 1.10倍、それ以外（30〜75）は 1.0倍**。
- この `request.morale` は `PublicDemoState.applyMonthlyGrowth` が
  `PublicDemoWorkflowState.moraleByEngineerId`（入社済み応募者は `employeeMorale`、
  創業社員は `PublicDemoEngineerSales.motivation` = `interviewProfile.morale`）から都度渡す値であり、
  **参画中社員について現状これ以外に morale が影響するゲーム結果は存在しない**（B-3で詳述）。
- 初期値: `defaultEmployeeMorale = 65`（`lib/domain/models/engineer.dart:13`）。

**重要な限定事実（過大な期待を避けるための開示）**:
`_capabilityDelta` は `sourceBase(2.0 for assignment) * potentialMultiplier * fastLearnerMultiplier
* moraleMultiplier * diminishingMultiplier` を `floor()` してから使う。`potentialMultiplier =
0.70 + growthPotential*0.15`（`growthPotential` は 1〜5, `lib/domain/models/hidden_parameters.dart`）
は応募者ごとの非公開パラメータであり、この値と fastLearner 有無・現在スキル帯（diminishing）の
組み合わせによっては **floor() の丸めにより 30〜75 → >75 の変化が月あたりの整数デルタを
まったく変えないケースがある**。例えば `growthPotential=3`（初期値相当）・fastLearner なし・
skill<70 の社員では、moraleMultiplier 1.0 と 1.10 のどちらでも月次デルタは floor(2.3)=2 と
floor(2.53)=2 で同じになる。一方 **morale<30 に落ちた場合は floor(1.725)=1 と、常に -1/月の
実害が発生する**。つまり実データ上、Growth Engine の morale 効果は
「**75超えを狙う上振れは対象社員のパラメータ次第で無効化されうるが、
30未満に落とすことの下振れは常に効く**」という非対称性がある。これは今回の3択の設計
（B-2）にそのまま反映した。

### B-2. 3択が異なる結果を生む設計、および「追加投資が常に最適ではない」ことの根拠

- 様子を見る (¥0 / ±0): 現状 Public Demo には参画中社員の morale を自動的に減衰させる仕組みが
  一切ない（`MoraleEngine`/週次ドリフトは本編ゲーム専用で Public Demo からは呼ばれていない —
  `git grep` で `MoraleEngine` の import が public_demo 配下に存在しないことを確認済み）。
  したがって「様子を見る」を選んでも**この瞬間のリスクはゼロ**で、これは既存事実に忠実な設計であり
  捏造ではない。
- フォロー (¥15,000 / +5 / +3): 初期値65から+5=70。**75の閾値には届かない**ため、
  デフォルト状態の社員では moraleMultiplier を動かせない。ただし過去の給与交渉
  (`decideRaise` の `hold` は moraleDelta -4) 等で morale が下がっていた場合、
  30の閾値割れからの回復・予防に有効な安価な手当てになる。
- 追加投資 (¥45,000 / +12 / +6): 初期値65から+12=77で **75の閾値を明確に超える**。
  これは `growthPotential>=4` または fastLearner 持ちの社員では月次成長デルタを実際に
  +1/月押し上げる（B-1のfloor計算参照）。一方 `growthPotential=3` 相当の平均的な社員では
  floorの丸めにより体感できる差が出ないことがあり、**「常に追加投資が正解」にはならない**
  （高ポテンシャル社員に絞って投資する方が合理的という戦略差が生まれる）。
  さらに ¥45,000 はキャッシュの実コスト（C章で試算）であり、資金が逼迫している回では
  `isFinanciallyRestricted` により選択肢自体が拒否される（A-8）。

以上により、「追加投資が常に最適解にならないこと」「新しい成長ルールを勝手に追加しない
（=Growth EngineのmoraleMultiplier自体は変更しない）」という指示の両方を満たしている。

### B-3. Trust — 現状ゲーム結果への影響の有無

authority調査: `employeeCompanyTrust` の**読み取り側**を `git grep` で全探索した結果、

```
public_demo_raise.dart:91-92     … 書き込みのみ（このフィールド自体を書き込む処理）
public_demo_recruitment.dart     … フィールド定義・copyWith/toJson/fromJson
public_demo_01_placeholder_screen.dart:1856  … UI表示（ラベル化して見せるだけ）
```

**上記以外に `employeeCompanyTrust` を読み取ってゲーム結果（成長・営業・離職・売上等）の
入力に使っているコードは現状存在しない。** これは `docs/ai-knowledge/patterns/SES-MOR-001-morale-trust-independence.md`
（Morale と Trust は意図的に独立、の既存パターン）とも整合する事実であり、Trust に
入力としての効果があるように誤認させない設計とした（A-11）。UIコピーでは「信頼が上がる」ことを
副次的な演出として表示してよいが、"主要メリット" としては morale→growth の実効果のみを謳う。

### B-4. 対象社員 — employeeMorale / employeeCompanyTrust のauthority

authority: `lib/game/public_demo/public_demo_recruitment.dart`（`PublicDemoApplicant`）

- `employeeMorale`/`employeeCompanyTrust` は **入社済み応募者にのみ存在する nullable フィールド**
  （`PublicDemoJoinRecord` を介した `join()` でのみ非null化される — 直接 `copyWith` で捏造不可、
  コード内コメントで明言）。
- 一方、創業社員（`workflow.engineers`, 型 `PublicDemoEngineerSales`）は `mental`/`trust`
  （デフォルト50固定）のみを持ち、`employeeMorale`/`employeeCompanyTrust` 相当の可変フィールドを
  一切持たない。`PublicDemoEngineerSales.motivation` は `interviewProfile.morale` を返すgetterだが、
  これを事後的に変化させる仕組み（raise・follow-up 等）は現状存在しない。
- したがって **創業社員をPhase 1の対象に含めるには `PublicDemoEngineerSales` へ新規の可変
  morale/trust フィールドを追加する必要があり**、これは「創業社員を無理に対象化しない」
  という指示に反する（スコープ拡大になる）ため、**Phase 1では対象外**とした（E章）。

### B-5. 発生頻度の方式比較（one-shot / cooldown / 条件発生）

| 方式 | 概要 | 「毎月同じカードが出る」回避 | 「一度も出ない」回避 | 実装量 |
|---|---|---|---|---|
| **one-shot（採用）** | 社員ごとに生涯1回。8〜14月内で条件を満たす最初の月に出現し、選択後は二度と出ない | ◎ 構造的に不可能（1回のみ） | ○ 参画中の入社済み社員が1人以上いれば必ず初回月で成立。ゼロ人ルートのみ非発生（想定内の自然な結果） | 小（`raiseDecision` と同型） |
| cooldown | 例: 3ヶ月おきに再度出現可能 | △ 3回程度は出うる。効果を毎回変えないと"劣化コピー"になりやすい | ◎ | 中〜大（前回決定月の保存、毎回の効果再設計、既存パターンに前例なし） |
| 条件発生（morale閾値割れ等） | 例: morale<40等になったら出現 | ◎ | **× 現状Public Demoには参画中社員のmorale自然減衰が無いため、一度も条件を満たさないルートが普通に起こりうる**（B-2参照） | 小〜中だが不発生リスクが高い |

**選定: one-shot。** 理由: (1) 8〜14月の「7ヶ月間何も判断がない」という問題は、design principle
1（"at least one meaningful decision... does not need to be forced every month"）に照らせば
1回で十分に解消対象であり、Phase 1の最小スコープ制約と整合する。(2) 条件発生方式は現状の
authorityでは「一度も出ない」ルートを排除できない。(3) cooldownはPhase 1の「roughly 2-3h」枠を
超える設計・実装コストがかかる。既存の `PublicDemoRaiseDecision`（`raiseDecision` 一度きり）と
完全に同型のため、実装・レビューコストの見積り精度も高い。

**既知の限定**: 多くのプレイ経路で、入社済み社員は近い時期にまとめて参画するため、
one-shotの発生月は複数社員でも「8月」に集中しやすい（C章の再現例参照）。これは
「7ヶ月中1ヶ月だけ判断がある」状態に留まり、7ヶ月全体の退屈さを完全解消するものではない
— design audit コメント自身も "does not need to be a forced modal every month" と
Phase 1の役割を明記しており、残りの月の改善は将来フェーズの検討事項として切り離す。

### B-6. コスト額（¥15,000 / ¥45,000）の根拠

既存の類似コスト構造との整合性を確認した:

| 既存アクション | 単価 | authority |
|---|---|---|
| 社内研修（待機中社員のみ対象） | ¥30,000 | `PublicDemoInternalTrainingTransaction.cost` |
| 基本健診（会社一括） | ¥10,000/人 | `healthCheckConfigs[basic].costPerEmployee` |
| 人間ドック（会社一括） | ¥40,000/人 | `healthCheckConfigs[premium].costPerEmployee` |
| 日帰り旅行（会社一括） | ¥20,000/人 | `companyTripConfigs[dayTrip].costPerEmployee` |

¥15,000（フォロー）/ ¥45,000（追加投資）は上記のレンジ（¥10,000〜¥40,000）の外側にわずかに
はみ出す程度で、既存の「安い/高い」の相対関係（研修¥30,000を挟んで下と上）と整合する。
C章で実際のYear 1キャッシュフローに対する影響を試算する。

---

## C. プレイ例（8〜14月）

`SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md`（Issue #163 監査、origin/main 実在）が記録した
実プレイのAugust〜Februaryの実測値を土台に、Phase 1導入後の分岐を示す。

### 前提（監査記録から）

- 8月時点: 現預金 ¥1,660,000 / 社員3名（内2名参画中: 佐藤健=創業社員 eng-01, 高橋翔=入社済み
  応募者 app-01 / 1名待機: 鈴木葵=創業社員 eng-02）。
- 通常月の固定費差引: 約 -¥120,000/月（`advanceToNextOrdinaryMonth` 相当）。
- **対象社員は入社済みかつ参画中の高橋翔のみ**（佐藤健・鈴木葵は創業社員のため対象外 — B-4）。

### 分岐例

| 月 | 状態 | プレイヤー行動 | 結果 |
|---|---|---|---|
| 8月 | 高橋のフォローアップ機会が初出現（`followUpDecision == null` かつ参画中かつ month∈[8,14]の最初の月） | ケースA: 様子を見る | cash変化なし。moraleは前月から不変（65のまま想定）。以後この社員には二度とこのカードは出ない |
| 8月 | 同上 | ケースB: フォロー ¥15,000 | cash -¥120,000-¥15,000=-¥135,000。morale 65→70（閾値75未満のまま、moraleMultiplierは1.0で不変） |
| 8月 | 同上 | ケースC: 追加投資 ¥45,000 | cash -¥120,000-¥45,000=-¥165,000。morale 65→77（**>75 に到達、moraleMultiplierが1.0→1.10へ**）。高橋のgrowthPotentialが4以上またはfastLearner持ちなら、9月以降の月次成長デルタが+1/月相当で上振れる |
| 9〜14月 | 高橋については決定済みのため以後カード非表示（成長効果はケースCのみ継続） | — | ケースCのみ、9〜14月の6ヶ月で最大+6スキルポイント程度の累積差（growthPotential等条件付き。B-1のfloor挙動により実際には条件次第でこれより小さくなりうる） |

### Year 1経済への影響試算（追加確認事項）

- ¥15,000（フォロー、1名）: 月次固定費 -¥120,000 の **約12.5%**（一時費用）。開始資金
  ¥4,000,000（`public_demo_state.dart:149` の `cash: 4000000`）の **約0.4%**。
- ¥45,000（追加投資、1名）: 月次固定費の **約37.5%**（一時費用）。開始資金の **約1.1%**。
  8月時点の実残高¥1,660,000に対しては **約2.7%**。
- 対象社員が複数名（例: 3名）いて全員に追加投資を選ぶと合計¥135,000となり、月次固定費の
  約1.1ヶ月分に相当する一時支出になる — 資金繰りが厳しい回では意味のある選択コストになる。
- 結論: **¥15,000は「ほぼ無視できる」、¥45,000は「単月では致命的ではないが、資金が
  タイトな回では他の選択（賞与「なし」を選ぶ等、実際に監査記録にある行動）と競合しうる
  意味のある金額」** で、Year 1経済上の差として機能する。

---

## D. #129との境界

Issue #167 の design audit コメント（2026-09-04）が既に明記している境界を、コード監査でも
追認した。

- #129（PUBLIC-DEMO-EMPLOYEE-1ON1-1A）は「対話型の1on1ミニゲーム」であり、プレイヤーの
  選択に対して個別の会話・キャラクターリアクションを伴う、新しいUIフロー（ミニゲーム画面）を
  要求する、より大きな機能。
- #167 Phase 1（本レポートの対象）は、既存の `employeeConditionCard` に**ボタン+3択ダイアログ
  を1つ追加するだけ**の「会社経営判断」であり、対話・ミニゲームUIを一切持たない
  （実装テンプレートは `PublicDemoRaiseDialog` と同型の `AlertDialog` + 3つの `FilledButton.tonal`）。
- 責務分離: #167 Phase 1 は「cashを使うか使わないか」という**経営レベルの判断**を1回だけ扱う。
  #129 が将来実装されても、#167 Phase 1 が追加する `followUpDecision` フィールドや
  `PublicDemoFollowUpTransaction` 相当のクラスをそのまま置き換える必要はない
  （#129は別レイヤーの追加UI導線として、既存authorityを消費する形になる見込み — design audit
  コメントの "reuse current authorities rather than inventing a parallel employee-state system"
  と同じ方針）。
- 明示的な非目標: 本Phase 1では対話文・キャラクター演出・複数ターンの会話フローを実装しない。

---

## E. 実装対象/非対象

### 対象

- `PublicDemoApplicant`（`lib/game/public_demo/public_demo_recruitment.dart`）のうち
  `employeeMorale`/`employeeCompanyTrust` が non-null（=入社済み）、かつ判定月時点で
  `PublicDemoWorkflowState.assignedEngineerIds(month:)` に含まれる社員。

### 非対象（明文化）

1. **創業社員**（`workflow.engineers`, `PublicDemoEngineerSales`）— B-4の理由により対象外。
   将来対象化する場合は `PublicDemoEngineerSales` への可変morale/trustフィールド追加という
   スコープ拡大が必要であり、それ自体を別Issueとして扱うべき。
2. **待機中の入社済み社員** — 既に `internalTrainingCard`（¥30,000、待機中のみ）でカバーされて
   おり、対象を重ねると「同じ社員に同時に2つの投資UIが出る」曖昧さが生まれるため対象外。
3. **7月以前・3月（15月）** — 7月は夏季賞与固有のクローズ処理（`advanceToAugust`）、
   3月（15月）は年度末クローズ（`completeFiscalYear`）であり、`advanceToNextOrdinaryMonth`
   （8〜14月専用）の対象月ではないため、Phase 1のウィンドウから明示的に除外。
4. **Finding B（鈴木のような「初期実力不足で当年は永久に営業不可」の創業社員）のルール変更** —
   本タスクでは一切行わない（指示どおり）。

---

## F. 推定変更ファイル

### 新規

| ファイル | 役割 | 参考にした既存前例 |
|---|---|---|
| `lib/game/public_demo/public_demo_follow_up.dart` | 3択・cost/moraleDelta/trustDelta の純粋モデル | `public_demo_raise.dart`（96行） |
| `lib/game/public_demo/public_demo_follow_up_transaction.dart` | cash差引・`isFinanciallyRestricted`/残高チェックを伴う実行 | `public_demo_internal_training_transaction.dart`（123行） |
| `lib/ui/public_demo/public_demo_follow_up_dialog.dart` | 3択ダイアログUI | `public_demo_raise_dialog.dart`（40行） |
| `test/game/public_demo/public_demo_follow_up_test.dart` | モデル単体テスト | `public_demo_raise_test.dart`（99行） |
| `test/game/public_demo/public_demo_follow_up_transaction_test.dart` | 実行系テスト（cash不足/Finance制限/一度きり性） | `public_demo_internal_training_transaction_test.dart`（176行） |
| `test/ui/public_demo/public_demo_follow_up_dialog_test.dart` | ダイアログUIテスト | `public_demo_raise_dialog_test.dart`（36行） |

### 変更

| ファイル | 変更内容 |
|---|---|
| `lib/game/public_demo/public_demo_recruitment.dart` | `PublicDemoApplicant` に `followUpDecision`（enum, nullable）+ `followUpDecisionMonth`（int?）を追加。`copyWith`/`toJson`/`fromJson` 更新。`canDecideFollowUpIn(month)` 相当のヘルパー追加 |
| `lib/game/public_demo/public_demo_workflow_state.dart` | `decideFollowUp(...)` の追加（`decideRaise` と同型の `withApplicant` 経由更新） |
| `lib/game/public_demo/public_demo_aggregate.dart` | `decideFollowUp(...)` の薄いpassthroughメソッド追加 |
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `employeeConditionCard` 内にフォローアップ起動ボタンを追加（既存の昇給ボタンと同列） |
| `lib/game/persistence/public_demo_save_codec.dart` | 影響は軽微と推定（`PublicDemoApplicant.toJson`/`fromJson` に委譲していれば無変更で済む可能性が高いが、実装時に明示フィールド列挙の有無を確認すること） |

**save schemaへの影響**: 新規フィールドは全て nullable かつ `fromJson` で `json['x'] as T?` の
デフォルトnullフォールバックを踏襲すれば、既存セーブの読み込みに対して後方互換
（`raiseDecision`/`raisedMonthlySalary` と同じパターン）。スキーマ破壊的変更は不要。

---

## G. 推定LOC

| 区分 | 推定行数 |
|---|---|
| 新規ドメインモデル（`public_demo_follow_up.dart`） | 90〜110 |
| 新規トランザクション（`public_demo_follow_up_transaction.dart`） | 90〜120 |
| 新規UI（`public_demo_follow_up_dialog.dart`） | 60〜80 |
| 既存ファイル変更（recruitment/workflow_state/aggregate/screen 合計） | 90〜120 |
| **production合計** | **約330〜430行** |
| テスト（モデル+トランザクション+ダイアログ） | 約220〜280行 |
| **総合計** | **約550〜700行** |

比較対象: 同型の既存機能一式（`public_demo_raise.dart` 96行 + `_transaction.dart` 65行 +
`_dialog.dart` 40行 + test 99行 + dialog test 36行 = 336行）よりやや大きい。理由は
cash差引・`isFinanciallyRestricted`連携（raiseには無い要素で、`internal_training_transaction`
相当の複雑さが加わるため）。

---

## H. Claude Code実装時間

**推定 3〜4時間。**

Issue #167 自身が示す目安「roughly 2-3 hours」に対しては、cashトランザクション + Finance制限
連携がある分やや上振れると見積もった。内訳目安:

- ドメインモデル+トランザクション実装: 60〜75分
- 既存ファイルへの配線（recruitment/workflow_state/aggregate/screen）: 45〜60分
- UI（ダイアログ+カードへのボタン追加）: 30〜45分
- テスト作成・`flutter analyze`/`flutter test` 通し: 45〜75分
- 想定外の配線調整・save_codec確認等のバッファ: 15〜30分

厳密に2〜3hに収めたい場合は、UIダイアログテストまたはtransaction testの一部
（cash不足ケースなど境界値のみ）を最小限に削る調整余地がある旨、実装時の判断材料として明記する。

---

## I. 最終判定

## READY WITH CONDITIONS

パラメータ自体は本レポートでClaude Codeがそのまま実装できる粒度まで確定した
（A章の確定パラメータ表 + F章のファイル一覧 + 既存前例への1:1対応）。ただし以下の条件が
残っているため、無条件の READY とはしない。

1. **依存Issueが未解決**: Issue #167 自身が明記する実行順序
   `#166 → #147 + deployed Screen Verification → #168 → #167 Phase 1 → 4月→3月人間プレイテスト`
   のうち、**#166・#147・#168 は本監査時点ですべて `open`** で、いずれも完了していない
   （2026-09-04時点のdesign auditコメントの条件がそのまま現在も有効）。本番実装は
   これらのマージ後、fresh `origin/main` での再監査を経てから着手すること。
2. **#129との重複実装防止**: 実装時点で #129 が着手されていないか再確認し、対話型1on1側で
   `employeeMorale`/`employeeCompanyTrust` を独自に操作するコードが割り込んでいないことを
   確認する。
3. **Trustの謳い方**: UIコピーで「信頼が上がる」を主要効果として書かない（B-3）。
4. **対象社員の明記**: 創業社員は対象外である旨を、必要であればUI上でも
   （少なくとも実装コメントで）明記し、将来「なぜ佐藤さんにはこのボタンが出ないのか」という
   問い合わせに耐える説明を残す。
5. Post-176 Priority Audit文書は本レポート作成時点で入手不能であり、本レポートの結論はそれに
   一切依拠していない。もし当該文書が別途復元・提示された場合、Finding B関連の記述が本レポートの
   E章「非対象」の理由付けと矛盾しないか再確認すること。

これらの条件は「設計をやり直す（REDESIGN）」レベルの疑義ではなく、実装着手前のゲーティング
条件（既存の依存関係順序の遵守）と実装時の注意事項であるため、**READY WITH CONDITIONS** とした。
