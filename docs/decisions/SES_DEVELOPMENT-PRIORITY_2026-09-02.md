# SES Development Priority (2026-09-02)

Status: **Accepted — current governing decision / living source of truth**

This document is the current single source of truth for **how development is prioritized and run** on S.E.S. It is a living plan: when task status, priority, estimate, product direction, or persistent execution policy changes, update this document rather than leaving the change only in chat or a result report.

`docs/DEVELOPMENT_PLAN.md` remains the source of truth for detailed phase/feature design. Read this document first for current priority, then `DEVELOPMENT_PLAN.md` for phase detail.

---

## Primary Goal — First Fun Year

現在の最優先目標は100人テストではない。

まず開発者本人がPublic Demoを **4月 → 翌年3月** まで1年度通して実際にプレイし、

- 「面白かった」
- 「もう1年遊びたい」
- 「別の経営戦略を試したい」

と思える状態 = **First Fun Year** を作る。

機能追加・UX改善・バランス調整・テスト改善の優先順位は、この目標への寄与で判断する。

### First Fun Year completion criteria

1. 4月から翌3月まで通常プレイで完走できる。
2. 進行不能、月送り不能、セーブ破壊、重大な二重処理がない。
3. 毎月、判断・変化・結果のいずれかを感じられる。
4. 9月〜2月が単なる週送り期間にならない。
5. 会社が成長している実感がある。
6. 月次結果から「なぜ良くなった／悪くなったか」を理解できる。
7. 年度末に一年間の成果を振り返れる。
8. 終了時に別の戦略でもう1年遊びたいと思える。

---

## Current execution order

**HOME完成 → 年間通しプレイ → Blocker修正 → 後半強化 → 成長実感 → 月次結果 → 年度末 → 戦略性 → バランス → Public Demo仕上げ**

Issue番号順に機械的に実装しない。実プレイ結果を根拠に、First Fun Yearを最も改善するものを選ぶ。

### Prioritized backlog and AI processing-time budget

処理時間は調査・実装・関連テスト・結果報告作成を含む概算。CI待ち時間は含めない。

| Priority | Task | Claude Code / Codex目安 | Outcome |
|---|---|---:|---|
| P0 | 進行中HOME UI改修を完成 | 残り1〜3h | HOMEで会社状況・推奨行動・KPI・次の行動を理解できる |
| P0 | 4月→翌3月 First Fun Year通しプレイ | 1〜2h | 年間完走可否、退屈な期間、重大問題を実プレイで特定 |
| P0 | 年間進行Blocker修正 | 1件0.5〜3h | 月送り不能、二重処理、セーブ破壊等を除去 |
| P1 | 9月〜2月コンテンツ強化 | 4〜8h / 分割必須 | 年度後半にも判断・イベント・変化が発生 |
| P1 | 会社の成長実感強化 | 3〜6h | 社員・売上・資金・オフィス等から成長を実感 |
| P1 | 月次結果・経営フィードバック改善 | 2〜4h | 前月比・収支理由・危険要因が次の判断につながる |
| P1 | 年度末結果・年間評価強化 | 2〜4h | 一年間の成果を振り返り、年度完走に意味が生まれる |
| P2 | 経営判断のリスク/リターン強化 | 5〜10h / 分割必須 | 安全策・成長策など経営方針によるプレイ差が生まれる |
| P2 | 採用・社員マネジメント強化 | 5〜10h / 分割必須 | 採用・給与・昇給・定着が一連の経営判断になる |
| P2 | 営業・案件選択の戦略性強化 | 4〜8h | 適性・成功率・Trust等を考えて案件を選べる |
| P2 | 資金繰り表示改善 | 2〜4h | 将来入金・支出・資金ショートを予測しやすくなる |
| P2 | ナビゲーター支援強化 | 2〜5h | 状況別の危険・チャンス・推奨行動を案内 |
| P3 | 年間バランス調整 | 4〜10h / 反復 | 難易度と戦略ごとの生存・成長バランスを改善 |
| P3 | 重要イベント演出強化 | 2〜5h | 初契約・黒字化・社員増加等に達成感が生まれる |
| P3 | Public Demo UX仕上げ | 3〜6h | 初見でも基本ループを理解できる |
| P3 | 重大経路E2E整備 | 3〜8h | First Fun Yearを壊す重大Regressionを自動検出 |
| P4 | リファラル採用 | 4〜8h | 社員紹介という採用ルートを追加 |
| P4 | 雇用形態拡張 | 8〜16h | 正社員・契約社員・個人事業主等を使い分ける |
| P4 | 部署・役職システム | 8〜16h | 成長に応じて組織・役職を構築 |
| P4 | 労務・制度コンテンツ | 10〜20h+ | 社保・36協定・休職・退職代行・士業等を経営要素化 |
| P4 | SNS/HP/ISMS/Pマーク等 | 5〜10h | ブランド・認証投資を営業・採用へ接続 |

P4の拡張仕様はFirst Fun Yearの基本ループが成立するまで原則着手しない。

---

## AI task sizing / usage-window policy

5時間制限で実装途中のまま停止することを避けるため、AI作業量そのものを計画単位として扱う。

- **〜2h:** 1タスクで実行可能。
- **2〜3h:** 推奨サイズ。Claude Code / Codexの標準実装単位。
- **3〜5h:** 原則2タスクへ分割を検討。
- **5h超:** 必ずPhase分割する。設計・Domain・UI・テスト等に分ける。
- **10h超:** 独立Issue/PR単位まで分割する。

利用枠が少ない時は新規大型実装を開始せず、監査・設計・レビュー・タスク分割を優先する。

---

## Development AI

当面のメイン実装AIは **Claude Code** とする。

ChatGPTは主に開発優先順位判断、Claude Code用プロンプト作成、Issue/PR整理、独立レビュー、実装結果評価に使用する。

Codexは独立監査、難しい原因調査、重要設計判断、必要に応じた実装に使う。同じproductionファイルをClaude CodeとCodexで同時変更しない。

## Model Selection

Claude Code / Codexへ作業を依頼するときは、その作業を安全に完遂できる**必要最低限のモデル**を選ぶ。高性能モデルを常用しない。

## Result Report

実装・調査・設計を依頼する際は、原則として結果報告Markdownを `docs/reports/` に出力する。

最低限記録するもの:

- STATUS
- BASE / HEAD
- 実施内容
- 変更ファイル
- テスト結果
- 未解決事項 / Known Issues
- commit SHA（commitした場合）
- PR / Merge Readiness（該当する場合）

---

## E2E Policy

E2E完全Greenを、すべてのゲーム開発を開始する条件にはしない。

### Blocking — 開発を止めて優先修正

- アプリが起動できない
- 通常操作で進行不能になる
- セーブデータを破壊する
- 4月→翌3月の年度完走を妨げる
- 主要ゲームフローそのものが成立しない
- productionの重大なregression

### Non-blocking — 記録してFirst Fun Year開発を継続

- 特定viewportだけのE2E不安定
- browser / CI環境固有の問題
- accessibility tree等、テスト環境由来と根拠を持って判断できる問題
- 特殊条件だけのテスト失敗で通常プレイを阻害しないもの
- flaky test

テスト削除・skip・retry増加・timeout増加だけでGreenへ見せかけない。

---


### Routine delivery gate

通常のPRからPagesデプロイまでを待たせないため、Fast CIは次の独立した必須ゲートを並列実行する。

- `flutter-validate`: `flutter analyze`、全Flutter test、Pagesと同一条件のWeb build
- `replay-unit`: lockfileを使うReplay ViewerのNode unit test
- `smoke-e2e`: 上記2ゲート後のChromium主要導線確認

Node依存はlockfileを維持したままnpmキャッシュ優先で取得する。失敗をskip/retry/timeout延長で隠さず、各ゲートは引き続きPages deployを止める。WebKit・年間通し・Recovery・多viewportはHeavy E2Eに分離する。

## Plan maintenance rule

この文書は会話時点のメモではなく、継続更新する正本である。

以下が起きたら更新する:

- タスク完了・中止・Block
- 優先順位変更
- AI処理時間見積りが大きく変化
- 新しいBlockerや実プレイ上の問題を発見
- First Fun Yearの完成条件・方向性を変更
- AI使い分け、モデル選択、E2E方針などの永続ルールを変更

Result Reportは履歴・証拠であり、この文書の代わりにはしない。変更後に複数の「current」文書を作らず、この正本を更新するか、明示的にsupersedeする。

---

## Relationship to existing documents

- `AGENTS.md` — この文書と `docs/DEVELOPMENT_PLAN.md` を作業前必読として直接参照する。
- `docs/DEVELOPMENT_PLAN.md` — phase/feature詳細の正本。この文書の優先方針で実行順を判断する。
- `docs/ai-knowledge/INDEX.md` — 技術的incident/pattern/decisionの索引。現在の開発優先順位の正本ではない。
- `docs/reports/` — 実施結果と証拠。計画変更が必要なら結果報告だけで終わらせず、この文書も更新する。

## Update history

### 2026-09-04（続報）

- Issue #163: 最新main（SHA `39d6f40e0d43561766f5cbf2c33a26ccbf9fd6f1`）を
  基準に、4月→翌3月の通しプレイ監査を実施。**年度完走PASS**（連続プレイ中
  P0ゼロ、最終現預金+¥700,000、倒産・資金ショート失敗なし）。追加の
  リロード/復帰デューデリジェンスでP0相当の問題を発見: (1)
  ブラウザリロード時に誤った画面（Public Demoと無関係な初心者/自由モード
  選択画面）へ飛ばされる問題は最小修正・検証済み。(2) より深い
  「タブを閉じて再訪問した際、実在するセーブが`SharedPreferences`経由で
  確実に読めない」問題を発見したが根本原因を特定できず未解決 —
  次タスクとして切り出した。単調だった箇所（8月〜2月の7か月間、参画中の
  社員向け判断が皆無で同一の推奨アクションが居座り続ける）、年度末演出の
  薄さも記録。詳細:
  `docs/reports/SES_FIRST-FUN-YEAR_Full-Year_Playtest_Audit.md`。

### 2026-09-04

- First Fun Year P0「資金不足の表示が誤って回復を示唆する」を解消。既存の
  `PublicDemoCashForecast`の次回決算見込みを読み取り専用で用い、マイナスの
  ときは回復を示唆せず、次回決算後も資金不足であることと根拠数値を表示する。
  詳細: `docs/reports/SES_FIRST-FUN-YEAR_P0_Cash-Shortage-Truth_Result.md`。

- Fast CIをFlutter検証・Replay unit・Chromium smokeの並列必須ゲートへ再編。検証範囲を縮めず、Node lockfileキャッシュ優先で通常PRからデプロイまでの待機を短縮。

### 2026-09-02

- First Fun Yearを最優先目標として固定。
- 100人テストより年間プレイの面白さを優先。
- E2EをBlocking / Non-blockingに分類。
- Claude Codeを主実装ラインとする方針を設定。
- 優先タスク一覧とClaude Code/Codex処理時間見積りを追加。
- 原則2〜3時間/タスク、5時間超は分割するルールを追加。
- HOME完成→年間プレイ→Blocker→面白さ改善の実行順を明文化。
- 計画変更時にこの文書を都度更新するLiving Source of Truth運用を明文化。
