# SES Issue #132 SkillSheet UX Design Report

- Issue: #132 SKILLSHEET-UX-2A — redesign SkillSheet modal layout and define career/profile parameters
- Base: `origin/main` @ `7488ff1` (Merge pull request #131)
- Branch: `claude/skillsheet-ux-design-issue-132-vzm2az`
- Scope: **調査・設計のみ。プロダクションコードの実装は行っていない。**
- Parallel work: Issue #133 (Codex) — 7月夏季賞与デッドロック / 4月リスタート

## 凡例 (Evidence Tags)

| Tag | 意味 |
|---|---|
| **FACT** | 本リポジトリの現コードから確認した事実。file path / class / member を併記 |
| **DESIGN** | 本Issueでの設計提案（未実装） |
| **FUTURE** | Issue #132より後の候補。今回は境界だけ残す |
| **UNKNOWN** | authority未確認・現時点で権威データが存在しない |

---

## Executive Summary

1. **FACT** — PR #131 が入れた Public Demo の SkillSheet は、`lib/ui/public_demo/public_demo_01_placeholder_screen.dart:403` の `_S._openSkillSheetReview()` という **単一の `AlertDialog`** であり、表示しているのは `PublicDemoEngineerSales.name` / `.summary` の2つと `PublicDemoInterviewProfile` の4整数だけ。SES営業資料としての情報設計はまだ存在しない。
2. **FACT** — 一方で Public Demo は既に、**永続化済み・成長エンジン接続済みの実力データ** を `PublicDemoEngineerRuntime` に持っている（`primaryLanguage` / `languageSkills` / `techSkills` / `abilities` / `industryExperience` / `careerHistory`）。SkillSheetダイアログはこれを**一切読んでいない**。→ Phase A は「新規Domainデータ無し」で情報量を大幅に増やせる。
3. **FACT** — actual vs sales-facing の境界は **すでにデータ上に存在する**。`LanguageSkill` は `actualExperienceMonths` と `displayedExperienceMonths` を別々に持ち、`PublicDemoGrowthEngine.calculate()`（`public_demo_growth_engine.dart:101`）は `actualExperienceMonths` だけを +1 し、`displayedExperienceMonths` を意図的に据え置く（コード内コメント: *"SkillSheet-facing displayed experience intentionally remains intact."*）。つまり佐藤は参画月を重ねると **実経験37ヶ月 / 記載36ヶ月** に自然に乖離する。
4. **FACT** — 本編（main game）には `SkillSheet` クラス（`lib/domain/models/sales_profile.dart:9`）、盛りリスク判定（`SalesEngine.riskFor/inflationPoints/clampSheet`）、編集UI（`engineer_detail_screen.dart:246 _editSkillSheet`）が **すでに実装済み**。Issue #132 は「新設計」ではなく「本編の既存境界を Public Demo に読み取り専用で持ち込む」問題として扱うのが正しい。
5. **DESIGN** — 推奨は3フェーズ分割。**Phase A（既存authorityのみでUI再設計 / 新規永続フィールドゼロ）** → **Phase B（`careerHistory` / `certifications` / 工程 / 業界の権威データ投入）** → **Phase C（actual vs sales-facing の編集ゲーム性）**。Phase A だけで「5〜10秒で何ができる人か分かる」というIssueの中心要求は満たせる。
6. **FACT / RISK** — Public Demo のセーブは `PublicDemoSaveCodec`（`schemaVersion = 1`）で **厳密round-trip一致検証**（`public_demo_save_codec.dart:58` の `_canonicalJson(json) != _canonicalJson(toJson(aggregate))`）を行う。永続フィールドを1つ足すだけで**旧セーブが全滅（decode→null→新規セッション）**する。これが #133 との最大の衝突面であり、Phase A が永続フィールドを足さない最大の理由。
7. **CONFLICT RISK WITH #133: LOW**（Phase A に限る）。Phase B 以降は persistence schema を触るため MEDIUM に上がる。

---

## Current Implementation

### 1. Current SkillSheet structure（Public Demo / PR #131）

**FACT** — `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`

| 要素 | 実装 |
|---|---|
| エントリポイント1 | HOME Recommended Action CTA — L1469 `() => unawaited(_openSkillSheetReview(e))` |
| エントリポイント2 | 社員カード内 `FilledButton('SkillSheet確認')` — L1849-1850 |
| 表示 | `showDialog` + `AlertDialog`（`key: public-demo-skill-sheet-<id>`, L407） |
| タイトル | `'${engineer.name}\n営業用SkillSheet'` |
| 本文 | `SingleChildScrollView > Column`（L409〜） |
| 本文 - 導入文 | 「取引先へ提示する営業用プロフィールです。…」 |
| 本文 - 見出し1 | `経歴・スキル要約` → `Text(engineer.summary)`（例: `Java / SQL・開発経験3年`） |
| 本文 - 見出し2 | `営業・面談プロフィール` → `_dialogRow` ×4（L430-433） |
| 本文 - 注記 | 「Public Demoでは現在の営業用情報を閲覧します。実経歴との差分編集や盛りリスク判定は本編のSkillSheet機能で扱います。」 |
| アクション | `TextButton('戻る')`（key `...-cancel-<id>`, L444） / `FilledButton('内容を確認')`（key `...-confirm-<id>`, L449） |
| 確定処理 | L456-457 `if (!mounted || confirmed != true) return; _startSkillSheetReview(engineer.id);` |
| Domain権威 | `PublicDemoAggregate.startSkillSheetReview()`（`public_demo_aggregate.dart:373`）→ `PublicDemoWorkflowState.startSkillSheetReview()` |

**FACT** — 表示している値は合計 **6項目のみ**（name, summary, skillFit, humanity, morale, clientTrust）。SES SkillSheetとしての言語・工程・業界・案件履歴・資格・希望条件は **1項目も無い**。

### 2. 本編（main game）側の SkillSheet 実装

**FACT**

| 要素 | 場所 |
|---|---|
| モデル | `lib/domain/models/sales_profile.dart:9` `class SkillSheet` — `displayedLanguageExperience: Map<ProgrammingLanguage,int>` / `displayedDatabase/Network/Infrastructure/Frontend/Backend/Leader/Manager` / `displayedIndustryExperience: Map<Industry,int>` / `displayedRoles: List<String>` / `updatedWeek` |
| 盛り上限 | `SkillSheet.maxExperienceInflationMonths = 36` / `SkillSheet.maxSkillInflation = 2` |
| 生成 | `SkillSheet.fromActual()` — actual値から初期化 |
| 保管 | `GameState.skillSheets: List<SkillSheet>`（`game_state.dart:68`）/ `GameState.skillSheetFor(id)`（L208） |
| 盛りリスク | `SalesEngine.riskFor / inflationPoints / inflationDetails / clampSheet`（`lib/game/engine/sales_engine.dart:9-70`）、`enum SkillSheetRisk { honest, moderate, aggressive, extreme }` |
| 案件マッチ | `SalesEngine.skillSheetMatch(SkillSheet, Project)` — **記載値**でマッチングし、`generateOffers()` の面談枠数もリスク段階で 1/2/3 に変わる |
| 編集UI | `lib/ui/engineers/engineer_detail_screen.dart:246 _editSkillSheet()` — 言語年数/Backend/Leader を増減、リスクラベル・社員反応・二段階確認あり |
| 表示UI | 同 L284 `_SkillSheetSalesCard` — 「実際 X / 記載 Y」の対比行 |
| 投影 | `lib/presentation/engineers/engineer_detail_display_data.dart:53 EngineerSkillSheetDisplay`（`sheet` は **nullable**。旧セーブ時は「再生成せず unavailable を出す」ルール） |
| 候補者モーダル | `lib/ui/prologue/prologue_screen.dart:526 showCandidateSkillSheetDialog()` — 年齢/希望年収/経験年数/言語/DB等/業界経験/役割経験の**セクション分割済みモーダル**（Public Demo 版より情報設計が進んでいる先行実装） |

**DESIGN** — Public Demo の SkillSheet UI は、この `showCandidateSkillSheetDialog` の情報構造を継承しつつ、モバイル（360px）向けにアコーディオン化するのが最も整合的。

---

## Current Data Authority

### Public Demo が現在保持している権威データ

**FACT** — `lib/game/public_demo/public_demo_sales.dart` `class PublicDemoEngineerSales`

| field | 型 | 初期値(eng-01 佐藤 健 / eng-02 鈴木 葵) | 永続化 | 現UI消費者 |
|---|---|---|---|---|
| `id` | String | `eng-01` / `eng-02` | ○ | Widget key |
| `name` | String | 佐藤 健 / 鈴木 葵 | ○ | ダイアログtitle・カード |
| `summary` | String | `Java / SQL・開発経験3年` / `JavaScript / Flutter・開発経験2年` | ○ | ダイアログ `経歴・スキル要約`、カード |
| `interviewProfile.skillFit` | int | 78 / 52 | ○ | ダイアログ `案件スキル適合` |
| `interviewProfile.humanity` | int | 70 / 66 | ○ | ダイアログ `ヒューマンスキル` |
| `interviewProfile.morale` | int | 72 / 64 | ○ | ダイアログ `モチベーション` |
| `interviewProfile.clientTrust` | int | 60 / 55 | ○ | ダイアログ `取引先からの信頼` |
| `stage` | enum | `waiting` | ○ | カードボタン / `PublicDemoSalesProgress` |
| `lastInterviewScore` | int? | null | ○ | 面談結果ダイアログ |
| `interviewRecord` | 値オブジェクト | null | ○(id) | 非表示（真正性証明） |
| `mental` | int | 50 | ○ | **per-engineer表示なし**。`PublicDemoCompanySnapshot.averageMental` に集計されるのみ |
| `trust` | int | 50 | ○ | 同上 `averageTrust` |

**FACT** — `lib/game/public_demo/public_demo_engineer_runtime.dart` `class PublicDemoEngineerRuntime`（`publicDemoInitialEngineerRuntimes`, L180-）

| field | 型 | eng-01 佐藤 健 | eng-02 鈴木 葵 | 永続化 | 現UI消費者 |
|---|---|---|---|---|---|
| `primaryLanguage` | `ProgrammingLanguage` | `java` | `javascript` | ○ | 成長結果カードのみ |
| `languageSkills[lang].displayedExperienceMonths` | int | **36** | **24** | ○ | **なし** |
| `languageSkills[lang].actualExperienceMonths` | int | 36（参画月ごとに+1） | 24（同） | ○ | **なし** |
| `languageSkills[lang].actualSkill` | int(0-100) | 78 | 52 | ○ | `capabilityFor()`（L370）→ 営業ロック文言 |
| `techSkills.database` | int(0-5) | 3 | 1 | ○ | **なし** |
| `techSkills.network` | int(0-5) | 1 | 1 | ○ | **なし** |
| `techSkills.infrastructure` | int(0-5) | 1 | 1 | ○ | **なし** |
| `techSkills.frontend` | int(0-5) | 1 | **3** | ○ | **なし** |
| `techSkills.backend` | int(0-5) | **3** | 1 | ○ | **なし** |
| `techSkills.leader` | int(0-5) | 1 | 0 | ○ | **なし** |
| `techSkills.manager` | int(0-5) | 0 | 0 | ○ | **なし** |
| `hidden` | `HiddenParameters` | growthPotential 3 等 | growthPotential 4 等 | ○ | **表示禁止**（`public_demo_growth_result_card.dart:10` に「Growth potential… remain private」と明記） |
| `abilities` | `Set<EmployeeAbility>` | `{}` | `{}` | ○ | なし（入社者のみ `fastLearner` が付くことがある） |
| `industryExperience` | `Map<Industry,int>` | `{}` | `{}` | ○ | なし |
| `careerHistory` | `List<CareerHistoryEntry>` | `[]` | `[]` | ○ | なし |

**FACT（重要な否定）** — `industryExperience` は Public Demo では **絶対に増えない**。`PublicDemoState`（L664-668）が `PublicDemoGrowthRequest(source:..., morale:...)` を **`industry:` 無し**で構築するため、`PublicDemoGrowthEngine.calculate()` 内の `industryExperience = practicalExperience > 0 && request.industry != null ? 1 : 0` が常に 0 になる。よって業界経験は現状 **常に空**。

**FACT（重要な否定）** — `careerHistory` は Public Demo の全コードパスで **一度も書き込まれない**（`grep -rn careerHistory lib` の結果、`public_demo_engineer_runtime.dart` の宣言/copyWith/JSONのみ）。よって **常に空**。

### 案件（Assignment）側の権威データ

**FACT** — `lib/game/public_demo/public_demo_assignment.dart`

| field | eng-01 | eng-02 | 備考 |
|---|---|---|---|
| `projectName` | `販売管理システム開発` | `業務アプリ改修` | `publicDemoInitialAssignments`（L115-）。新規受注時は `forOrderedEngineer()` で一律 `新規開発支援`（L109） |
| `deliveryPressure` | 45 | 72 | 現場側の内部指標 |
| `budgetHealth` | 75 | 48 | 同上 |
| `humanity` | 70 | 66 | 同上 |
| `fieldEvaluation` | 50 | 50 | 現場評価 |
| `nextOrderStatus` / `replacementStage` | enum | enum | 継続/交代フロー |

**FACT** — Assignment に `industry` / `startMonth` / `endMonth` / `role` / `teamSize` / 使用技術 は **存在しない**。案件履歴カードに必要な項目の大半がここに無い。

### 本編Domainにあるが Public Demo では未使用のモデル

**FACT**

| モデル | 場所 | Public Demo での使用 |
|---|---|---|
| `SkillSheet`（displayed*） | `sales_profile.dart:9` | **未使用**（`GameState.skillSheets` 経由でのみ生きる） |
| `CareerHistoryEntry` | `career_history_entry.dart` | 型はimport済み・**中身は常に空** |
| `EngineerCertification` / `EngineerCertificationCategory` | `engineer_certification.dart` | **未使用**（runtimeにフィールドすら無い） |
| `Engineer.certifications` | `engineer.dart:63` | Public Demoは `Engineer` を使わない |
| `Applicant.qualifications: List<String>` | `applicant.dart:32` | `PublicDemoApplicant` に該当フィールド無し |
| `EmployeePreference`（希望軸） | `employee_preference.dart` | **未使用** |
| `Industry` enum | `sales_profile.dart:5` | 型は使えるが値が入らない |
| `EmployeeAbility` | `sales_profile.dart:7` | runtimeにあるが初期社員は空 |
| `Education` / `Major` / `age` / `japaneseLevel` / `englishLevel` / `jobChangeCount` / `totalItExperienceMonths` | `applicant.dart` | `PublicDemoApplicant` に存在しない → **Public Demo の年齢・学歴は UNKNOWN** |

---

## Data Classification

Issue §3 の A/B/C/D 分類。**「Public Demoの営業用SkillSheetに載せる」観点**での分類。

### A — 現在すでに authoritative data が存在する（Phase Aで即表示可）

| 項目 | authority |
|---|---|
| 氏名 | `PublicDemoEngineerSales.name` |
| 経歴サマリ | `PublicDemoEngineerSales.summary` |
| 営業ステージ / 参画状態 | `PublicDemoEngineerSales.stage`（`PublicDemoSalesStage`） |
| 現在案件名 | `PublicDemoAssignment.projectName`（参画中のみ） |
| 主言語 | `PublicDemoEngineerRuntime.primaryLanguage` |
| 主言語の**記載**経験月数 | `LanguageSkill.displayedExperienceMonths` |
| 主言語の**実**経験月数 | `LanguageSkill.actualExperienceMonths` |
| 技術スキル7軸(0-5) | `TechSkillLevels` (database/network/infrastructure/frontend/backend/leader/manager) |
| 案件スキル適合 / ヒューマン / モチベーション / 取引先信頼 | `PublicDemoInterviewProfile` |
| 営業可否ライン | `PublicDemoEngineerRuntime.fieldSalesCapabilityRequirement = 60` と `actualCapability` |
| 保有アビリティ | `PublicDemoEngineerRuntime.abilities`（入社者のみ非空になりうる） |

### B — Domain modelには存在するが Public Demoでは未使用（Phase Bで接続）

| 項目 | 未使用の理由 |
|---|---|
| 業界経験 | `runtime.industryExperience` は存在するが `PublicDemoGrowthRequest` に `industry` が渡らず常に空 |
| 案件履歴 | `runtime.careerHistory` は存在するが書き込みパスが無い |
| 資格 | `EngineerCertification` は domain にあるが runtime にフィールドが無い |
| sales-facing SkillSheet 本体 | `SkillSheet` クラスは本編専用。Public Demo は `displayedExperienceMonths` を代替に使っている |
| 希望条件 | `EmployeePreference` は本編 `Engineer` のみ |

### C — 新しい Domain data が必要（Phase B / C）

| 項目 | 必要な追加 |
|---|---|
| 担当工程（要件定義〜運用保守） | **enum が存在しない**。`CareerHistoryEntry.processes: List<String>` は自由文字列で、どこにも値が無い。`DevelopmentProcess` enum の新設が必要 |
| Framework / DB製品 / Cloud / OS / Tools の個別記載 | `TechSkillLevels` は0-5のレベルのみ。製品名（Spring / Oracle / AWS / Linux / Git 等）を持つ器が無い |
| 案件ごとの期間・役割・チーム規模・案件規模 | `PublicDemoAssignment` に無い。`CareerHistoryEntry` の該当フィールドに値を入れる仕組みが必要 |
| 案件の業界 | `PublicDemoAssignment.industry` が無い |
| 学習中 / 研修 / 自己学習 | 器が無い（`internalTraining` は月次成長の選択でしかなく履歴を残さない） |
| 希望技術/工程/役割/業界/働き方 | Public Demo に希望条件モデルが無い |
| SkillSheet 記載値の独立保持（盛り） | Public Demo に `SkillSheet` 相当の永続オブジェクトが無い |

### D — 表示すべきでない / authority不明

| 項目 | 理由 |
|---|---|
| `HiddenParameters`（growthPotential / stressTolerance / retention / projectInterviewSkill / turnoverIntent） | **明示的に private**。`public_demo_growth_result_card.dart:10` が「remain private」と宣言 |
| `PublicDemoEngineerSales.mental` / `.trust` | 社内HR指標。取引先提示資料に載せる性質のものではない。現状も per-engineer 表示はしていない |
| `PublicDemoApplicant.interviewScore` / `acceptanceScore` | 採用側の内部評価 |
| 給与 / `requestedMonthlySalary` / `acceptedMonthlySalary` | 営業SkillSheetに載せない（単価とは別物） |
| `interviewRecord` / `joinRecord` / `bindingOffer` | 真正性証明の内部値オブジェクト |
| **年齢** | **UNKNOWN** — Public Demo に年齢フィールドが存在しない。Issue §4 の「年齢等（authorityがある場合のみ）」に従い **表示しない** |
| **学歴 / 最終学歴 / 国籍 / 語学レベル** | **UNKNOWN** — `PublicDemoApplicant` に存在しない |
| `deliveryPressure` / `budgetHealth` / `fieldEvaluation` | 現場側の内部指標。取引先提示用ではない（社内向けタブなら FUTURE で検討可） |

---

## Recommended Information Architecture

**DESIGN** — 「最初の5〜10秒で何ができる人か分かる」を最優先に、**Above the fold に要約、以下はアコーディオン**という構造にする。

### Section hierarchy（優先度順）

```
[0] Sticky Header (compact, 常時表示)
    氏名 ／ ステージバッジ ／ 主言語+経験年数
[1] Summary Band (open, 折りたたみ不可)  ← 5秒で分かる層
    ・強み chips 最大3（例: Java 3年 / Backend Lv.3 / DB Lv.3）
    ・営業準備インジケータ（実力 78 / 必要 60）
    ・現在の状態（待機中 / 参画中: 販売管理システム開発）
[2] スキル・経験        (accordion, 既定=open)   ← A
[3] 営業・面談プロフィール (accordion, 既定=closed) ← A（PR #131の既存4項目を格納）
[4] 担当工程            (accordion, 既定=closed)   ← C（Phase Bまで「未設定」空状態）
[5] 業界経験            (accordion, 既定=closed)   ← B（Phase Bまで空状態）
[6] 案件履歴            (accordion, 既定=closed)   ← B/C（Phase Bまで空状態）
[7] 資格・学習          (accordion, 既定=closed)   ← C（Phase Bまで空状態）
[8] 希望条件・キャリア    (accordion, 既定=closed)   ← C（Phase Cまで空状態）
[9] Sticky Bottom CTA (常時表示)
    [戻る]              [内容を確認]
```

**DESIGN原則**
- **[1] Summary Band は折りたためない。** ここだけで「何ができる人か」が閉じる。
- **[2]〜[8] は同時に1つだけ開く（single-expand accordion）**とし、モーダル内スクロール量を抑える。
- **authorityが無いセクションはセクションごと非表示にせず、「未登録」の空状態を出す。** 理由：SES SkillSheetとして「工程欄が無い」より「工程欄が空」の方が現実に近く、Phase Bで埋まることを予告できる。ただし **架空の値は絶対に入れない**（Issue §11）。
- **[3] を Summary より下に置く**理由：`skillFit/humanity/morale/clientTrust` はゲーム内部スコアであり、SES SkillSheetの一次情報ではない。ただし PR #131 の既存表示・既存テスト（`public_demo_01_skill_sheet_flow_test.dart` が4ラベル全てを `findsOneWidget` で検証）を壊さないため **必ず残す**。

### 各セクションの表示内容（Phase A時点）

**[1] Summary Band** — **FACT ベースのみ**
| 表示 | source |
|---|---|
| `Java 3年` chip | `languageLabels[runtime.primaryLanguage]` + `formatExperience(displayedExperienceMonths)` |
| `Backend Lv.3` chip | `runtime.techSkills.backend`（0のものは出さない） |
| `DB Lv.3` chip | `runtime.techSkills.database` |
| 実力メータ | `runtime.actualCapability` / `fieldSalesCapabilityRequirement` |
| 状態 | `PublicDemoSalesStage` + `PublicDemoAssignment.projectName`（あれば） |

**[2] スキル・経験**
| 行 | source | 表記 |
|---|---|---|
| 言語 | `runtime.languageSkills` | `Java ／ 記載 3年`（実力 `★★★★☆` は `actualSkill/20`） |
| DB / Network / Infrastructure / Frontend / Backend | `runtime.techSkills` | `★★★☆☆` 形式（本編 `prologue_screen.dart:531 stars()` と同一表記） |
| 役割経験 | `techSkills.leader` / `.manager` | `リーダー経験 ★☆☆☆☆` |

**DESIGN** — Framework / Cloud / OS / Tools は **Phase A では行ごと出さない**。0-5レベルしか無い状態で「AWS」等のラベルを出すと、存在しない権威をUIが捏造することになる（Issue §11違反）。Phase B で製品名モデルが入ってから追加する。

---

## Mobile Layout

対象: **360px portrait** / **390px portrait**。

### 共通仕様（DESIGN）

| 項目 | 値 | 理由 |
|---|---|---|
| 表示形式 | `showModalBottomSheet(isScrollControlled: true)` + `DraggableScrollableSheet` | `AlertDialog` は `insetPadding` の都合で360pxだと実効幅が約280pxまで落ち、chip行が2〜3行に割れる |
| 初期高さ | `initialChildSize: 0.85` | Header+Summary+開いた1セクションが収まる |
| 最大高さ | `maxChildSize: 0.95` | 上端に背景を残し「モーダルである」ことを維持 |
| 最小高さ | `minChildSize: 0.5` | 下方向スワイプで閉じられる（= 戻る操作） |
| スクロール | **モーダル本体の1本だけ**。各アコーディオン内部は `shrinkWrap` で自前スクロールを持たない | nested scroll 回避（Issue §6） |
| 案件履歴 | `Column` に展開（`ListView` を入れ子にしない） | 同上。かつ `public_demo_01_placeholder_screen.dart:2038` に記録済みの **SliverList未マウント問題** の再発回避 |
| Header | `pinned`（`SliverPersistentHeader` 相当 or Sheet上部固定Container） | Issue §6 compact header |
| CTA | 下端固定 `SafeArea` + `Row`（戻る / 内容を確認） | スクロール位置に関わらず確認操作に到達可能 |
| 戻る操作 | ①下端CTAの「戻る」 ②シート下スワイプ ③Androidバック ④バリアタップ — **全て `confirmed != true` 経路** | PR #131 の `if (!mounted || confirmed != true) return;`（L456）がそのまま全経路を吸収する |

### 360px portrait レイアウト提案

```
┌──────────────────────────────── 360px ─┐
│ ═══ (drag handle)                       │  8
├─────────────────────────────────────────┤
│ 佐藤 健              [営業準備OK]        │ 32  ← pinned header
│ Java 3年 ・ 待機中                       │ 20
├─────────────────────────────────────────┤
│ ┌─ SUMMARY ────────────────────────────┐│
│ │ [Java 3年][Backend Lv.3][DB Lv.3]    ││ 30  ← Wrap, 1行に3chip
│ │ 実力 78 ／ 営業ライン 60              ││ 18
│ │ ▓▓▓▓▓▓▓▓▓▓▓▓▓▓▓░░░░  78             ││ 10
│ │ 現在: 待機中（未参画）                 ││ 18
│ └──────────────────────────────────────┘│
├─────────────────────────────────────────┤
│ ▼ スキル・経験                    (開) │ 44  ← tap target 44px
│    Java          記載 3年 ／ ★★★★☆    │ 24
│    DB            ★★★☆☆                │ 24
│    Backend       ★★★☆☆                │ 24
│    Frontend      ★☆☆☆☆                │ 24
│    Network       ★☆☆☆☆                │ 24
│    Infrastructure★☆☆☆☆                │ 24
│    リーダー経験    ★☆☆☆☆                │ 24
├─────────────────────────────────────────┤
│ ▶ 営業・面談プロフィール           (閉) │ 44
│ ▶ 担当工程                    未登録   │ 44
│ ▶ 業界経験                    未登録   │ 44
│ ▶ 案件履歴                    未登録   │ 44
│ ▶ 資格・学習                  未登録   │ 44
│ ▶ 希望条件・キャリア            未登録   │ 44
├─────────────────────────────────────────┤
│  [    戻る    ] [   内容を確認   ]      │ 56  ← sticky bottom
└─────────────────────────────────────────┘
```

- **横padding 16px** → 実効コンテンツ幅 **328px**。
- chip は `SkillChipRow`（`lib/ui/widgets/skill_chip.dart:38`、`Wrap(spacing:6, runSpacing:6)`）を再利用。`[Java 3年]` ≈ 84px、`[Backend Lv.3]` ≈ 108px、`[DB Lv.3]` ≈ 76px → 6px×2 の spacing 込みで 280px。**328pxに1行で収まる**。4個目以降は自動で2行目に折り返す。
- 折りたたみヘッダは **44px タップターゲット**（Material最小48pxにやや満たないが、既存 `_dialogRow` の密度と整合。48pxに上げても下記の高さ計算に収まる）。
- 上記構成の全高 ≒ 8+52+76+44+168+264+56 = **668px**。360×800端末で `initialChildSize: 0.85` = 680px に **ちょうど収まる**（＝スクロール無しで全セクション見出しが見える）。これが single-expand accordion を採る根拠。

### 390px portrait レイアウト提案

**DESIGN** — 別レイアウトを作らず、**同一ウィジェットのまま余白と密度だけ広げる**（分岐は `LayoutBuilder` の1箇所）。

| 差分 | 360px | 390px |
|---|---|---|
| 横padding | 16 | 20（実効 350px） |
| Summary chips | 3個/行 | 3個/行（余白増、4個目も入る場合あり） |
| スキル行ラベル幅 | 96px 固定（`_SheetRow` 準拠） | 112px |
| スキル行 | ラベル + 星 | ラベル + 星 + 補助テキスト（`実力 78` 等）を同一行に |
| アコーディオン見出し | 44px | 48px |
| 案件履歴カード | 縦積み | 縦積み（`期間`と`役割`を1行2カラム化可） |
| 全高 | ≒668px | ≒700px（390×844の 0.85 = 717px に収まる） |

**DESIGN** — 分岐しきい値は `constraints.maxWidth >= 380`。360と390で**セクション数・順序・キー・CTAは同一**にする（E2Eが両解像度で同じセレクタを使えるようにするため）。

---

## Project History Design

**FACT** — 現在 Public Demo に案件履歴データは無い（`runtime.careerHistory` は常に空、`PublicDemoAssignment` に期間/業界/役割/規模が無い）。

**DESIGN** — 案件履歴カード（1案件 = 1カード、モバイルで縦積み）

```
┌─────────────────────────────────────────┐
│ 販売管理システム開発            [金融]   │ ← projectName + industry chip
│ 2024/04 〜 2025/03 （12ヶ月）            │ ← startWeek/endWeek → 月表記
│ ─────────────────────────────────────── │
│ 役割  PG        規模  10名 / 30名       │ ← role, teamSize / projectScale
│ 工程  [実装][単体][結合]                 │ ← processes chips
│ 技術  [Java][Spring][Oracle]            │ ← languages + technologies chips
│                              [詳細 ▾]   │ ← detail expansion（summary/実績）
└─────────────────────────────────────────┘
```

- **折りたたみ既定**: カードは常に上記5行まで表示、`summary`（案件概要）と `実績` は `[詳細 ▾]` で展開。→ 5案件あってもモーダル内スクロール1画面強に収まる。
- **必要フィールドと現状**

| UI項目 | `CareerHistoryEntry` の受け皿 | 現状 |
|---|---|---|
| 案件名 | `projectName` | **FACT: フィールド有り / 値なし** |
| 期間 | `startWeek` / `endWeek` / `experienceMonths` | **FACT: フィールド有り / 値なし** |
| 業界 | `industry: Industry?` | **FACT: フィールド有り / 値なし** |
| 案件概要 | `summary` | **FACT: フィールド有り / 値なし** |
| 担当工程 | `processes: List<String>` | **FACT: フィールド有り（自由文字列）/ 値なし** — **C: enum化が必要** |
| 言語 | `languages: List<ProgrammingLanguage>` | **FACT: フィールド有り / 値なし** |
| Framework / DB / Cloud / Tool | `technologies: List<String>` | **FACT: フィールド有り（自由文字列）/ 値なし** — **C: カテゴリ分けが必要** |
| 役割 | `role: String` | **FACT: フィールド有り / 値なし** |
| チーム規模 | `teamSize: int` | **FACT: フィールド有り / 値なし** |
| 案件規模 | — | **C: 新規フィールド必要**（`projectScaleBand`） |
| 実績 | — | **C: 新規フィールド必要**、または `summary` に含める |

**DESIGN** — `technologies: List<String>` を `Framework / Database / Cloud / OS / Tool` に分けたい場合、**`CareerHistoryEntry` を破壊せず** `List<TechnologyTag>`（`{category, key, displayName}`）を **追加フィールド**として足すのが後方互換的。`docs/design/SES_EMPLOYEE-DATA-1_Expansion_Design.md` §3 が明示する「`CareerHistoryEntry` を後方互換で拡張せよ」「`projectHistory` という第2のリストを作るな」という既存決定に従うこと。

**DESIGN（履歴の作られ方 / Phase B）** — `SES_EMPLOYEE-DATA-1` §3 EMPLOYEE-DATA-1C に従い、**参画が実際に終了した時点で不変の1エントリを追記**する。Public Demo では「第1期終了（`month == 15`）」または交代成立時が終了点。表示名は **参画時点のスナップショット**を保存し、後からマスタが変わっても履歴が変わらないようにする。

---

## Skills / Experience Design

**DESIGN**

| カテゴリ | Phase A で出すか | source / 判断 |
|---|---|---|
| 言語 | **出す** | `runtime.languageSkills` — 記載月数を主表示、`actualSkill` を★で補助 |
| 各経験年数 | **出す** | `formatExperience(displayedExperienceMonths)`（`labels.dart:186`） |
| Database | **出す** | `techSkills.database`（0-5 → ★） |
| Cloud | **出さない** | **C**: `TechSkillLevels` に cloud 軸が無い。`infrastructure` を "Cloud" と表示するのは authority の捏造 |
| OS | **出さない** | **C**: 器が無い |
| Framework | **出さない** | **C**: 器が無い（`technologies` は空） |
| Tools | **出さない** | **C**: 器が無い |
| その他技術 | **出さない** | 同上 |
| Network / Infrastructure / Frontend / Backend | **出す** | `TechSkillLevels` にそのまま存在 |
| Leader / Manager | **出す（役割経験として）** | `techSkills.leader/.manager` |

**DESIGN — 表記の統一**
- レベル表記は本編と同じ **★×level + ☆×(5-level)**（`prologue_screen.dart:531`）。
- 経験月数は **`formatExperience()`**（`3 年` / `1 年 6 ヶ月` / `8 ヶ月`）。
- 0レベルの軸は **行ごと省かず「—」を出す**。SES SkillSheetは「空欄であること」自体が情報。

**FUTURE** — Cloud/OS/Framework/Tools を入れる場合、`TechSkillLevels` に軸を足すのではなく **`TechnologyTag` リスト**を新設するのが良い。理由：`TechSkillLevels` は `SalesEngine.skillSheetMatch()` と `Project.required*` に1対1で対応しており、軸を足すと **本編のマッチング計算とバランスに波及する**（Issue §11「案件提案確率変更」禁止に抵触）。

---

## Certifications / Learning Design

**FACT** — Public Demo に資格データは **一切無い**。`PublicDemoEngineerRuntime` に `certifications` フィールドが無く、`PublicDemoApplicant` に `qualifications` も無い。

**FACT** — 本編には2系統の権威が既に定義され、**混同禁止**が明文化されている（`SES_EMPLOYEE-DATA-1_Expansion_Design.md` §5）:
- `Applicant.qualifications: List<String>` — **応募者自己申告**（sales-facing / claimed provenance）。ゲームロジックが書き換えない。
- `Engineer.certifications: List<EngineerCertification>` — **会社が確認した実績**（verified provenance）。
- **「自己申告を検証済みへ自動昇格させてはならない」**。

**DESIGN**（Phase B）

```
▼ 資格・学習
  ── 保有資格（会社確認済み） ──
  [基本情報技術者]  2023年 取得    ← EngineerCertification.displayName / acquiredWeek
  [AWS SAA]        2024年 取得
  ── 申告資格（本人申告） ──         ← 別グループ・別ラベルで表示（統合・重複排除しない）
  [Oracle Bronze]
  ── 学習中 ──                      ← C: 新規
  [TypeScript] 社内研修 2ヶ月目
```

- **DESIGN** — Public Demo に載せるには `PublicDemoEngineerRuntime.certifications: List<EngineerCertification>` の追加が必要（**Cに分類**）。追加は後方互換（`json['certifications'] ?? const []`）で可能だが、**`PublicDemoSaveCodec` の厳密round-trip検証により旧セーブが失効する**（後述）。
- **DESIGN** — 初期社員 eng-01/eng-02 の資格は **空のまま**にする。架空の資格を付与するのは Issue §11 違反。「未登録」空状態を出す。
- **FUTURE** — 学習中/研修/自己学習は、既存の `internalTraining`（`PublicDemoInternalTrainingTransaction` / `trainingSelections`）が既に「今月この社員は研修」という情報を持っている。これを履歴として残す `trainingHistory` を Phase B/C で足せば、自然な学習履歴になる。**今回は実装しない。**

---

## Preferences / Career Design

**FACT** — Public Demo に希望条件モデルは無い。本編には `EmployeePreference`（social / privateLife / compensation / growth / stability、日本語ラベル付き）と `Applicant.desiredWorkStyle: WorkStyle`（常駐/ハイブリッド/フルリモート希望）、`desiredMonthlySalary` があるが、**`PublicDemoApplicant` / `PublicDemoEngineerSales` / `PublicDemoEngineerRuntime` のいずれにも無い**。

**DESIGN**（Phase C）— 希望条件は **SkillSheetの中で唯一「取引先向けでない」ブロック**なので、扱いを分ける。

| 項目 | 提案 | 分類 |
|---|---|---|
| 希望技術 / 希望工程 / 希望役割 / 希望業界 | `EmployeeCareerWish` を新設（enum集合） | C |
| キャリア希望 | `EmployeePreference` を Public Demo に持ち込む（既存enum再利用） | B |
| 働き方 | `WorkStyle` を持ち込む（既存enum再利用） | B |
| その他条件 | 自由文字列1つ | C |

**DESIGN** — UI上は「希望条件・キャリア」セクションに **`社内向け` バッジ**を付け、取引先提示ブロック（スキル/工程/業界/案件履歴/資格）と視覚的に分離する。SES実務でも希望条件は営業側の内部情報であり、これがゲーム上の「営業に出す/出さない」判断材料になる。

---

## Actual vs Sales-Facing Boundary

### 現在の境界（FACT）

**境界はすでに存在し、Public Demo でも機能している。**

| レイヤ | 保持者 | フィールド | 性質 |
|---|---|---|---|
| ACTUAL（実績） | `PublicDemoEngineerRuntime.languageSkills[l]` | `actualExperienceMonths`, `actualSkill` | 成長エンジンが書き換える |
| SALES-FACING（記載） | 同上 | `displayedExperienceMonths` | **成長エンジンが意図的に触らない** |
| ACTUAL（実績・本編） | `Engineer.profile.languageSkills[l].actualExperienceMonths`, `Engineer.profile.techSkills` | — | 真の実力 |
| SALES-FACING（記載・本編） | `SkillSheet.displayed*`（`GameState.skillSheets`） | — | 盛れる。`SalesEngine.clampSheet` で上限クランプ |
| ACTUAL（経歴事実） | `Engineer.careerHistory` / `runtime.careerHistory` | — | クラスdoc: *"career history records the facts, while SkillSheet records the sales-facing representation of them."* |
| 資格 claimed | `Applicant.qualifications` | — | 自己申告 |
| 資格 verified | `Engineer.certifications` | — | 会社確認 |

**FACT — 根拠コード**
- `lib/game/public_demo/public_demo_growth_engine.dart:101-106`
  ```dart
  final languageAfter = languageBefore.copyWith(
    // SkillSheet-facing displayed experience intentionally remains intact.
    actualExperienceMonths: languageBefore.actualExperienceMonths + practicalExperience,
    actualSkill: afterSkill,
  );
  ```
  → 佐藤（初期 actual 36 / displayed 36）は参画月を1回経るごとに **actual 37 / displayed 36** となり、**Issue §2 が例示する「実経験 3年 / 記載 4年」の逆向きの乖離が自然発生する**。
- `lib/domain/models/language_skill.dart:12-19` — `displayedExperienceMonths` / `actualExperienceMonths` の二重保持が **設計意図として明記済み**。
- `lib/domain/models/career_history_entry.dart:5-8` — career history と SkillSheet の分離が **クラスdocに明記済み**。

### 推奨する境界（DESIGN）

**既存構造をそのまま採用する。新しい二重化は作らない。**

```
PublicDemoEngineerRuntime          ← ACTUAL EMPLOYEE FACTS（唯一の実績権威）
 ├ languageSkills[*].actualExperienceMonths / actualSkill
 ├ techSkills
 ├ industryExperience     (Phase B で書き込み開始)
 ├ careerHistory          (Phase B で書き込み開始)
 └ certifications         (Phase B で追加)

PublicDemoSkillSheet (新設 / Phase C) ← SALES-FACING REPRESENTATION
 ├ employeeId
 ├ displayedLanguageExperience: Map<ProgrammingLanguage,int>
 ├ displayedTechSkills
 ├ displayedIndustryExperience
 ├ displayedProcesses
 ├ displayedCareerEntryIds  (どの実績を載せるか)
 └ updatedMonth
```

**DESIGN — Phase A/B での暫定境界**

Phase A では `PublicDemoSkillSheet` を**作らない**。代わりに:

> **presentation projection `PublicDemoSkillSheetDisplay` を1つ作り、「今の記載値 = `displayedExperienceMonths` / `techSkills`」という写像をそこ1箇所に閉じる。**

こうすると Phase C で `PublicDemoSkillSheet` を導入するとき、**projection の入力を差し替えるだけ**でウィジェットは無改造で済む。UI側にDomain権威を複製しない（Issue §11）ための唯一の受け皿。

**重要（Issue §11遵守）** — Phase A/B では:
- 盛り編集UIを出さない
- `SkillSheetRisk` / `SalesEngine.inflationPoints` を Public Demo から呼ばない
- Company Trust への影響を作らない
- `PublicDemoInterviewEvaluator.evaluate()` の入力（`actualCapability`）を変えない — 現在 `public_demo_aggregate.dart:441` が `runtimeForOrNull(id)?.actualCapability` を渡しており、これは **記載値ではなく実力**。ここを記載値に変えると面談成功率が変わる（禁止事項）。

---

## Future Editability

**DESIGN — Phase C で「盛り」を入れるときの境界**

| 判断 | 提案 | 根拠 |
|---|---|---|
| 盛り値を持つ場所 | **`PublicDemoState.skillSheets: List<PublicDemoSkillSheet>` を新設**（`engineerRuntimes` と同じ並びで） | `GameState.skillSheets`（`game_state.dart:68`）と対称。runtimeに `displayed*` を増やすと「実績オブジェクトの中に営業表現がある」という現在の綺麗な分離が崩れる |
| 実力の権威 | `PublicDemoEngineerRuntime` のまま **不変** | 成長エンジンの唯一の入出力であり、#133 が触る月次進行とも接続済み |
| 盛り上限 | `SkillSheet.maxExperienceInflationMonths = 36` / `maxSkillInflation = 2` を **再利用** | 本編とバランス値を二重管理しない |
| リスク判定 | `SalesEngine.riskFor` 相当を **Public Demo用に別実装せず**、`Engineer` 依存を外した純関数へ抽出 | 現 `SalesEngine.riskFor(Engineer, SkillSheet)` は `Engineer` を要求するが、Public Demo は `Engineer` を使わない。`riskFor(actual: {...}, displayed: {...})` へシグネチャを一般化するのが最小変更 |
| 面談への影響 | `PublicDemoInterviewEvaluator.evaluate(actualCapability:)` に **記載値を渡さない**。代わりに「記載と実力の乖離」を別パラメータで受ける | 既存の面談成功率を変えずに、乖離ペナルティだけを加算できる |
| 発覚イベント / Company Trust | `PublicDemoEngineerSales.trust` が既に存在し `averageTrust` に集計されている → **書き込み口だけ後から足せる** | 新モデル不要 |

**FUTURE（Issue #132 では実装しない）**
- 盛り編集UI（スライダー/ステッパー）
- `SkillSheetRisk` バッジと社員反応セリフ
- Company Trust 低下
- 案件提案率 / 面談成功率への反映
- 客先での発覚イベント
- バランス調整

**DESIGN — 今回残しておくべき「境界だけ」**
1. presentation projection `PublicDemoSkillSheetDisplay` を作り、**ウィジェットが `runtime` を直接読まない**ようにする。
2. その projection のフィールド名を `displayed*` 系にしておく（`displayedLanguageExperienceMonths` 等）。Phase C で source が `runtime` → `PublicDemoSkillSheet` に変わっても名前が変わらない。
3. 実力由来の値（`actualCapability`、営業ラインメータ）は projection 上で **`actual*` という別名**にする。UI上も「実力」と「記載」を別ラベルにしておく。

---

## Data-to-UI Mapping

Phase A で実装可能な写像のみ（**新規Domainデータ不要**）。

| UI Section | UI要素 | Domain authority | file:member | 分類 |
|---|---|---|---|---|
| Header | 氏名 | `PublicDemoEngineerSales.name` | `public_demo_sales.dart:57` | A |
| Header | ステージバッジ | `PublicDemoEngineerSales.stage` | `public_demo_sales.dart:61` | A |
| Header | 主言語+年数 | `runtime.primaryLanguage` + `languageSkills[l].displayedExperienceMonths` | `public_demo_engineer_runtime.dart:31-32` | A |
| Summary | 強み chips | `runtime.techSkills` 上位2軸 + 主言語 | `tech_skill_levels.dart` | A |
| Summary | 実力メータ | `runtime.actualCapability` / `fieldSalesCapabilityRequirement` | `public_demo_engineer_runtime.dart:17,43` | A |
| Summary | 現在案件 | `PublicDemoAssignment.projectName` | `public_demo_assignment.dart:26` | A |
| Summary | 経歴サマリ文 | `PublicDemoEngineerSales.summary` | `public_demo_sales.dart:58` | A |
| スキル | 言語行 | `runtime.languageSkills[*]` | `language_skill.dart` | A |
| スキル | DB/NW/Infra/FE/BE 行 | `runtime.techSkills.*` | `tech_skill_levels.dart:3-9` | A |
| スキル | 役割経験行 | `runtime.techSkills.leader/.manager` | 同上 | A |
| スキル | アビリティ chips | `runtime.abilities` | `sales_profile.dart:7` | A |
| 営業・面談 | 案件スキル適合 | `interviewProfile.skillFit` | `public_demo_interview.dart:11` | A |
| 営業・面談 | ヒューマンスキル | `.humanity` | 同 L12 | A |
| 営業・面談 | モチベーション | `.morale` | 同 L13 | A |
| 営業・面談 | 取引先からの信頼 | `.clientTrust` | 同 L14 | A |
| 担当工程 | 工程 chips | **なし** | — | **C** |
| 業界経験 | 業界 chips + 月数 | `runtime.industryExperience`（常に空） | `public_demo_engineer_runtime.dart:36` | **B** |
| 案件履歴 | カード群 | `runtime.careerHistory`（常に空） | 同 L37 | **B** |
| 資格・学習 | 資格行 | **なし** | — | **C** |
| 希望条件 | 希望行 | **なし** | — | **C** |
| （非表示） | growthPotential 等 | `runtime.hidden` | `hidden_parameters.dart` | **D** |
| （非表示） | mental / trust | `PublicDemoEngineerSales.mental/.trust` | `public_demo_sales.dart:71-72` | **D** |
| （非表示） | 年齢 / 学歴 | — | — | **D / UNKNOWN** |

---

## Required Domain Changes

### Phase A — **Domain変更ゼロ**

**DESIGN** — Phase A は既存の永続データを読むだけ。`PublicDemoState` / `PublicDemoEngineerSales` / `PublicDemoEngineerRuntime` / `PublicDemoAssignment` の **toJson を1バイトも変えない**。→ `PublicDemoSaveCodec.schemaVersion` 据え置き、旧セーブ互換維持、#133 の persistence 作業と非衝突。

唯一の新規は **presentation層**:
- `lib/presentation/public_demo/public_demo_skill_sheet_display.dart`（新規）
  - `PublicDemoSkillSheetDisplay` — `header` / `summary` / `skills` / `salesProfile` / `emptySections`
  - `PublicDemoSkillSheetDisplayFactory.create(PublicDemoAggregate, String engineerId)`
  - `EngineerDetailDisplayFactory`（`engineer_detail_display_data.dart:80`）と同じ「見つからなければ null を返す」規約に揃える。

### Phase B — 権威データ投入（永続スキーマ変更あり）

| 変更 | 対象 | 影響 |
|---|---|---|
| `DevelopmentProcess` enum 新設（requirement / basicDesign / detailDesign / implementation / unitTest / integrationTest / systemTest / maintenance） | `lib/domain/models/development_process.dart`（新規） | 新規enumのみ。既存に影響なし |
| `CareerHistoryEntry.processes` を `List<String>` から `List<DevelopmentProcess>` へ… **しない** | — | **後方互換破壊。代わりに `processCodes: List<DevelopmentProcess>` を追加フィールドとして足す** |
| `CareerHistoryEntry` に `projectScaleBand` / `achievements` 追加 | `career_history_entry.dart` | `?? default` で後方互換 |
| `PublicDemoAssignment` に `industry` / `startMonth` 追加 | `public_demo_assignment.dart` | **toJson変更 → セーブ影響** |
| `PublicDemoEngineerRuntime.certifications` 追加 | `public_demo_engineer_runtime.dart` | **toJson変更 → セーブ影響** |
| `PublicDemoGrowthRequest` に `industry` を実際に渡す | `public_demo_state.dart:664` | **`industryExperience` が増え始める = 挙動変化**。#133の月次進行と同じ関数を触るため要調整 |
| 参画終了時に `careerHistory` へ1件追記 | `PublicDemoState` / `PublicDemoWorkflowState` | **月次進行に接続する = #133 と直接衝突しうる** |

**DESIGN — セーブ互換の扱い（重要）**
`PublicDemoSaveCodec.fromJson` は `_canonicalJson(json) != _canonicalJson(toJson(aggregate))` で厳密一致を要求する（`public_demo_save_codec.dart:58`）。したがって **フィールドを1つ足すだけで旧セーブは decode→null**（＝新規セッションへフォールバック）になる。Phase B では:
1. `schemaVersion` を **2 に上げる**、かつ
2. `schemaVersion == 1` の payload を **明示的に読める migration path** を足す、
のどちらかを**意図的に選択**すること。黙って壊さない。**この判断は #133 の persistence 作業が着地してから行う。**

### Phase C — actual vs sales-facing

| 変更 | 対象 |
|---|---|
| `PublicDemoSkillSheet` 新設 | `lib/game/public_demo/public_demo_skill_sheet.dart`（新規） |
| `PublicDemoState.skillSheets` 追加 | **セーブ影響大** |
| `SalesEngine.riskFor` の `Engineer` 依存を外す | `sales_engine.dart:9` — シグネチャ一般化 |
| 編集コマンドを `PublicDemoAggregate` に追加 | `public_demo_aggregate.dart` |

---

## Required UI Changes

### Phase A

| file | 変更 |
|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | `_openSkillSheetReview()`（L403-458）を、新ウィジェットを `showModalBottomSheet` で開く **10行程度の呼び出し**に置換。`_startSkillSheetReview` 呼び出し条件（`confirmed != true` で return）は **変更しない** |
| `lib/ui/public_demo/public_demo_skill_sheet_sheet.dart` | **新規**。`PublicDemoSkillSheetSheet`（`DraggableScrollableSheet` + pinned header + single-expand accordion + sticky CTA） |
| `lib/ui/public_demo/public_demo_skill_sheet_sections.dart` | **新規**。`_SummaryBand` / `_SkillSection` / `_SalesProfileSection` / `_EmptySection`（未登録表示） |
| `lib/presentation/public_demo/public_demo_skill_sheet_display.dart` | **新規**。projection（上記） |
| `lib/ui/widgets/labels.dart` | `industryLabels` を追加（`client_interview_content.dart:28` の private `_industry()` を昇格・共有化）。**Phase B で使う。Phase Aでは任意** |
| `lib/ui/widgets/skill_chip.dart` | **無改造で再利用** |

**維持必須（UX Flow / Issue §7）**
- Widget key: `public-demo-skill-sheet-<id>` / `public-demo-skill-sheet-cancel-<id>` / `public-demo-skill-sheet-confirm-<id>` — **3つとも維持**
- ボタンラベル: `戻る` / `内容を確認` — **維持**
- 見出しテキスト: `営業用SkillSheet` / `経歴・スキル要約` / `営業・面談プロフィール` / `案件スキル適合` / `ヒューマンスキル` / `モチベーション` / `取引先からの信頼` — **維持**（既存widget test と e2e が文字列一致で検証）
- カードボタン `SkillSheet確認` / HOME CTA `SkillSheetを確認` — **維持**（e2e が `exact: true` で参照）
- 「戻る = workflow進行しない / 確認 = workflow進行」— **維持**

**注意** — `営業・面談プロフィール` の4行をアコーディオン内（既定=閉）に入れると、`findsOneWidget` を使う既存テストが **閉じた状態では失敗する**。対策は次のいずれか（実装PRで選択）:
- (a) `営業・面談プロフィール` セクションを既定=open にする（最小リスク）
- (b) 既存テストに `ensureVisible` + 展開タップを追加する（テスト変更を伴う）

**DESIGN推奨: (a)**。Phase A では「スキル・経験」と「営業・面談プロフィール」の2つを既定openにし、残りを既定closedにする。360pxでの高さは ≒ 668 + 96 = **764px** となり `maxChildSize: 0.95`（760px @800）にほぼ収まる。1セクションぶんのスクロールは許容する。

### Phase B / C

- 案件履歴カード / 資格セクション / 希望条件セクション を空状態から実データ表示へ
- Phase C で編集UI（**Issue #132 では作らない**）

---

## Test Strategy

### 既存で壊してはいけないテスト（FACT）

| test | 検証内容 |
|---|---|
| `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart` | ダイアログkey、7つの日本語ラベル、`戻る`で `stage == waiting` 維持、再オープン可、`内容を確認`で `stage == skillSheet`、その後 `営業開始` |
| `test/ui/public_demo/public_demo_01_success_playthrough_test.dart` | 成功プレイスルー中の SkillSheet 確認ステップ |
| `test/ui/public_demo/public_demo_01_home_recommended_action_test.dart` | HOME CTA が SkillSheet を開き、確認で1段だけ進む |
| `test/ui/public_demo/public_demo_01_home_navigator_test.dart` | CTA が read-only であること |
| `test/ui/public_demo/public_demo_01_home_runtime_read_test.dart` | 確認前に mutation が無いこと |
| `test/ui/public_demo/public_demo_01_persistence_test.dart` | 永続化トラジェクトリ |
| `test/ui/public_demo/public_demo_01_assignment_carryforward_test.dart` / `_bankruptcy_ux_test` / `_completion_lock_ui_test` / `_fiscal_year_progression_test` / `_home_consolidation_test` / `_home_office_stage_test` / `_suzuki_sales_lock_test` | 実プレイスルー中に SkillSheet 確認を通る |
| `e2e/tests/public-demo-fresh-start.spec.ts:28-55` | `SkillSheetを確認` ボタン、`営業用SkillSheet` テキスト、cancel→再表示、confirm後の非terminal |

### Phase A で追加すべきテスト（DESIGN）

**Widget tests**（新規 `test/ui/public_demo/public_demo_01_skill_sheet_layout_test.dart`）
1. 360×800 で SkillSheet を開き、`Summary` band の chips が **表示される**
2. 360×800 で **横スクロールが発生しない**（`tester.takeException()` に overflow が無い / `RenderFlex overflowed` を出さない）
3. `スキル・経験` セクションが既定 open で、`Java` / `Backend` 行が見える
4. `担当工程` / `業界経験` / `案件履歴` / `資格・学習` が **「未登録」空状態**を出す（架空データを出さない回帰テスト）
5. 390×844 でも上記1〜4が同じ key で成立する
6. **アコーディオンを1つ開いても `戻る` / `内容を確認` が両方 hitTestable**（sticky CTA の到達性）
7. アコーディオンを全部開いても `内容を確認` が押せて `stage` が1段だけ進む
8. **`hidden` の値（growthPotential 等）が画面上のどこにも現れない**（`find.textContaining` による否定検証）
9. `mental` / `trust` の数値が per-engineer に現れない

**Presentation tests**（新規 `test/presentation/public_demo/public_demo_skill_sheet_display_test.dart`）
10. projection が `runtime` の値をそのまま返す（再計算しない）
11. `runtime` が無いengineerIdでは **null を返す**（`EngineerDetailDisplayFactory` と同規約）
12. `careerHistory` / `industryExperience` が空のとき、空リストを返す（**捏造しない**）
13. `displayedExperienceMonths` と `actualExperienceMonths` が乖離しているとき、`displayed*` を記載欄に、`actual*` を実力欄に **取り違えず**返す

**Domain tests**（変更なしの確認）
14. `PublicDemoSaveCodec` round-trip が Phase A 前後で **同一 JSON** を produce する（＝セーブ非破壊の回帰テスト）

**E2E**（`e2e/tests/public-demo-fresh-start.spec.ts` に追記）
15. 既存フロー（開く→戻る→再開→確認→営業開始）が **無改造で通る**
16. `SES_EMPLOYEE-DATA-1_Expansion_Design.md` §8 に従い、下方セクションのアサート前に **repositoryのportableスクロールヘルパ**を使う。**retries / sleep を増やさない**

### Phase B/C

- `careerHistory` 追記が参画終了時に **ちょうど1件**、月を進めても重複しない
- 旧 `schemaVersion` セーブの扱い（migration or 明示的拒否）を **意図した通り**に検証
- 資格の claimed / verified が **別グループでレンダリングされる**（統合されない）

---

## Files Likely to Change

### Phase A（実装時）

| file | 種別 | 変更量目安 |
|---|---|---|
| `lib/ui/public_demo/public_demo_01_placeholder_screen.dart` | 変更 | `_openSkillSheetReview` を約55行→約12行に置換 |
| `lib/ui/public_demo/public_demo_skill_sheet_sheet.dart` | **新規** | ~180行 |
| `lib/ui/public_demo/public_demo_skill_sheet_sections.dart` | **新規** | ~220行 |
| `lib/presentation/public_demo/public_demo_skill_sheet_display.dart` | **新規** | ~140行 |
| `test/ui/public_demo/public_demo_01_skill_sheet_layout_test.dart` | **新規** | ~200行 |
| `test/presentation/public_demo/public_demo_skill_sheet_display_test.dart` | **新規** | ~150行 |
| `test/ui/public_demo/public_demo_01_skill_sheet_flow_test.dart` | 変更（最小） | 開閉操作の追随のみ。**アサーションは弱めない** |
| `docs/reports/SES_ISSUE-132_SkillSheet_UX_Design_Report.md` | 本ファイル | — |

**変更しない（Phase A）**: `lib/game/public_demo/**` 全て、`lib/game/persistence/**` 全て、`lib/domain/**` 全て。

### Phase B

`lib/domain/models/development_process.dart`(新規) / `career_history_entry.dart` / `public_demo_engineer_runtime.dart` / `public_demo_assignment.dart` / `public_demo_state.dart` / `public_demo_save_codec.dart` / `lib/ui/widgets/labels.dart`

### Phase C

`lib/game/public_demo/public_demo_skill_sheet.dart`(新規) / `public_demo_state.dart` / `public_demo_aggregate.dart` / `lib/game/engine/sales_engine.dart`

---

## Conflict Risk with #133

Issue #133 = 「Public Demo 7月の夏季賞与デッドロック + 4月リスタート」。

### #133 が触ると想定されるファイル（FACT — 該当機能の所在）

| 領域 | file |
|---|---|
| 夏季賞与 | `lib/game/public_demo/public_demo_summer_bonus_plan.dart`, `public_demo_summer_bonus_payment.dart`, `lib/ui/public_demo/public_demo_summer_bonus_dialog.dart` |
| 月次進行 / 締め | `public_demo_monthly_close.dart`, `public_demo_monthly_record.dart`, `public_demo_monthly_cash_flow.dart`, `public_demo_month_label.dart`, `PublicDemoState.advanceToJune` 等 |
| Finance | `public_demo_financial_status.dart`, `public_demo_salary_finance.dart`, `public_demo_revenue*.dart` |
| persistence | `lib/game/persistence/public_demo_save_codec.dart`, `public_demo_save_service.dart` |
| restart | `public_demo_01_placeholder_screen.dart` の `_restartGame()`（L653-672）, `_isRestarting`（L85）, `Key('public-demo-restart-button')`（L639） |

### 衝突評価

| Phase | Risk | 理由 |
|---|---|---|
| **Phase A** | **LOW** | Domain / persistence / finance / month progression を **一切触らない**。唯一の共有ファイルは `public_demo_01_placeholder_screen.dart` |
| Phase B | **MEDIUM** | `PublicDemoState` の月次成長呼び出し（L664）と `PublicDemoSaveCodec.schemaVersion` に触れる。#133 も persistence/restart に触る |
| Phase C | **MEDIUM〜HIGH** | `PublicDemoState` に新リストを足すため codec が確実に衝突 |

### Phase A の唯一の共有ファイル対策（DESIGN）

`public_demo_01_placeholder_screen.dart` は 2421行あり、#133 は **L85 / L639 / L653-672 の restart 周辺**と、月次締めCTA周辺を触る見込み。Issue #132 Phase A が触るのは **L394-458 の SkillSheet ブロックのみ**。行が離れているため **Git の自動マージで解決可能な可能性が高い**。

さらにリスクを下げるため、**DESIGN推奨**:
1. SkillSheet UI 本体を **新規ファイル**（`public_demo_skill_sheet_sheet.dart`）に出し、`placeholder_screen` 側の diff を **`_openSkillSheetReview` 1メソッドの置換だけ**に圧縮する。
2. `_startSkillSheetReview`（L394-395）、`_commitAggregate`、`readyForFieldSales`、`capabilityFor` には **触らない**。
3. #133 が先にマージされたら、#132 は `origin/main` を取り込んでから push する。

**明示的に守る禁止事項（Issue §11）** — Finance / bonus / month progression / persistence authority / 案件提案確率 / 面談成功率 / timeout・retry・sleep・assertion の弱体化 を **一切変更しない**。

---

## Recommended Implementation Split

### Phase A — 既存authorityだけでUI再設計（**最優先・単独PR**）

- Scope: モーダルレイアウト刷新、Summary band、accordion、chips、sticky CTA、360/390対応、空状態
- Domain変更: **ゼロ**
- 永続変更: **ゼロ**
- 既存フロー: **完全維持**（key / ラベル / workflow遷移条件）
- 追加表示データ: `runtime.primaryLanguage` / `languageSkills` / `techSkills` / `abilities` / `assignment.projectName`（**全て既存の永続データ**）
- 見積: 中規模PR 1本（~900行、うちテスト~350行）
- **これだけで Issue #132 の中心要求（5〜10秒で理解できる情報設計 + モバイルレイアウト）は満たせる。**

### Phase B — career/project parameter model拡張

- `DevelopmentProcess` enum 新設
- `CareerHistoryEntry` の後方互換拡張（`processCodes` / `projectScaleBand` / `achievements` / `technologies` のカテゴリ化）
- `PublicDemoEngineerRuntime.certifications` 追加
- `PublicDemoAssignment.industry` / `startMonth` 追加
- `PublicDemoGrowthRequest(industry:)` を実際に渡す
- 参画終了時の `careerHistory` 追記
- **セーブスキーマ判断（version bump or migration）を明示的に行う**
- **#133 着地後に着手すること**
- 見積: 2〜3PR に分割推奨（①enum/model追加 ②書き込みパス ③セーブ移行）

### Phase C — actual vs sales-facing representation

- `PublicDemoSkillSheet` 新設 + `PublicDemoState.skillSheets`
- projection の入力差し替え（ウィジェット無改造）
- `SalesEngine.riskFor` の `Engineer` 依存除去
- **編集ゲームプレイ・盛りリスク・Company Trust・提案率・面談リスク・発覚イベントは Phase C の中でさらに別Issueへ分割**
- 見積: 3PR以上

### 推奨順序

```
#133 (Codex, 進行中)
   ↓ merge
Phase A  ← Issue #132 の実装スコープはここまでにするのが安全
   ↓
Phase B ①enum/model → ②書き込み → ③セーブ移行
   ↓
Phase C
```

---

## Implementation Readiness

**READY（Phase A のみ）**

- Phase A は **必要な権威データが全て既に存在し、永続化もされている**ことをコードで確認済み。設計上の未解決点は無い。
- 唯一の実装時判断は「`営業・面談プロフィール` を既定 open にするか、既存テストに展開操作を足すか」。本レポートは **既定 open（既存テスト無改造）** を推奨。

**NOT READY（Phase B / C）**

- `PublicDemoSaveCodec` の schema 方針（version bump / migration）が **#133 の persistence 作業の着地待ち**。
- 工程 / Framework / Cloud / OS / Tools の粒度（enum か自由文字列か、製品名マスタを持つか）は **プロダクト判断が必要** — 本レポートでは `TechnologyTag` を推奨するが未確定。

**検証上の制約（明示）** — 本セッションの環境に **Flutter SDK がインストールされていない**（`flutter: command not found`）。したがって本レポートは **静的コードリーディングのみに基づく**。テストの実行・ビルド・スクリーンショット取得は行っていない。上記の高さ計算（668px / 764px 等）は各ウィジェットの既定メトリクスからの **見積であり、実測値ではない**。実装PRでは 360×800 / 390×844 の widget test と実スクリーンショットで必ず検証すること。

---

## Recommended Implementation AI

**Claude Code**

理由: Phase A は「既存の大規模ファイル（2421行）の1メソッドを、既存キー・既存文字列・既存workflow遷移を厳密に維持したまま差し替える」作業であり、既存テスト14本以上の文字列アサーションとの整合が支配的。長い既存コンテキストの厳密保持が要求されるため。

## Recommended Implementation Model

**Claude Opus 4.1**（Issue指定）
**Fallback: 現在Claude Codeで利用可能な最新Opus**（本セッションの構成識別子: `claude-opus-5`。実際に応答したモデルは異なる場合がある）

Phase B のセーブ移行判断は、#133 の成果を読んだうえで再度 Opus クラスで実施することを推奨。

---

## Appendix: 検証コマンド

```bash
# 現在のSkillSheetダイアログ
sed -n 394,458p lib/ui/public_demo/public_demo_01_placeholder_screen.dart

# Public Demo が持つ実力データ（初期値）
sed -n 180,232p lib/game/public_demo/public_demo_engineer_runtime.dart

# actual と displayed の分離（成長エンジン）
sed -n 95,112p lib/game/public_demo/public_demo_growth_engine.dart

# 本編の SkillSheet / 盛りリスク
sed -n 1,70p lib/game/engine/sales_engine.dart

# セーブの厳密round-trip検証
sed -n 36,66p lib/game/persistence/public_demo_save_codec.dart

# industryExperience が増えないこと
sed -n 660,670p lib/game/public_demo/public_demo_state.dart

# careerHistory が書き込まれないこと
grep -rn "careerHistory" lib --include=*.dart | grep -v domain/models
```
