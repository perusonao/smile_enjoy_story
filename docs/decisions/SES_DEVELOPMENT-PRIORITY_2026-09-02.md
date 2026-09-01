# SES Development Priority (2026-09-02)

Status: **Accepted — current governing decision**

Base commit: `523a65892ed8c87f5457f3048899dada884a2f9d`
(main HEAD at time of writing — merge commit for PR #139
"feat(public-demo): add late-year recovery loop")

This document is the current single source of truth for **how development is
prioritized and run** on S.E.S. (process/priority level). It does not replace
`docs/DEVELOPMENT_PLAN.md`, which remains the source of truth for **what
phase/feature work is next** (Phase 3B/3C/3D, Phase 4+, etc.). Read this
document first to understand *why* a given phase or issue is or isn't being
worked on right now; read `DEVELOPMENT_PLAN.md` for the phase detail itself.

If a future decision changes this policy, update this file in place (or
supersede it with a new dated decision file that says so explicitly) rather
than leaving two contradictory "current" policies in the repository.

---

## Primary Goal

現在の最優先目標は100人テストではない。

まず開発者本人がPublic Demoを

4月 → 翌年3月

まで1年度通して実際にプレイし、

- 「面白かった」
- 「もう1年遊びたい」
- 「別の経営戦略を試したい」

と思える状態 = **First Fun Year** を作る。

機能追加・UX改善・バランス調整・テスト改善の優先順位は、
原則としてこの目標への寄与で判断する。

## Development AI

当面のメイン実装AIは Claude Code とする。

ChatGPTは主に、

- 開発優先順位判断
- Claude Code用プロンプト作成
- Issue / PR整理
- 独立レビュー
- 実装結果の評価

に使用する。

Codexは必須ではなく、独立監査や難しい問題のセカンドオピニオンなど、
必要性がある場合に使用する。

## Model Selection

Claude Codeへ作業を依頼するときは、その作業を安全に完遂できる
「必要最低限のモデル」を選ぶ。

高性能モデルを常用しない。上位モデルが必要になる明確な理由がある場合のみ
切り替える。

## Result Report

Claude Codeへ実装・調査・設計などを依頼する際は、原則として結果報告
Markdownを出力する。

保存先の基本形:

```
docs/reports/
```

報告には最低限、以下を記録する。

- STATUS
- BASE / HEAD
- 実施内容
- 変更ファイル
- テスト結果
- 未解決事項 / Known Issues
- commit SHA（commitした場合）
- PR / Merge Readiness（該当する場合）

## E2E Policy

E2E完全Greenを、すべてのゲーム開発を開始するための条件にはしない。

E2E問題を次の2種類に分類する。

### Blocking

以下は原則として開発を止めて優先修正する。

- アプリが起動できない
- 通常操作で進行不能になる
- セーブデータを破壊する
- 4月→翌3月の年度完走を妨げる
- 主要ゲームフローそのものが成立しない
- productionの重大なregressionを示している

### Non-blocking

以下はIssue / Known Issueとして記録したうえで、
First Fun Year開発を継続してよい。

- 特定viewportだけのE2E不安定
- browser / CI環境固有の問題
- accessibility tree等、テスト環境由来と根拠を持って判断できる問題
- 特殊条件だけのテスト失敗で通常プレイを阻害しないもの
- flaky test

ただし、テストを削除・skip・retry増加・timeout増加などで
単にGreenへ見せかけてはならない。

## Current State

PR #139 Recovery Loop Phase 1 はmainへマージ済み。

Merge commit:

```
523a65892ed8c87f5457f3048899dada884a2f9d
```

Recovery Loopを待つフェーズは終了した。

次の優先事項は、

1. First Fun Yearを阻害する進行不能問題を解消
2. Issue #133（July bonus / July progression）の現在状態を確認
3. 4月→翌3月を実際に通しプレイ
4. 各月について
   - 退屈だった
   - 判断に意味を感じなかった
   - 何をすべきか分からなかった
   - 結果のフィードバックが弱かった
   - 達成感がなかった

   箇所を記録
5. その実プレイ結果を根拠に次の改修を選ぶ

Issue番号順に機械的に実装しない。「First Fun Yearを最も改善するもの」を
優先する。

---

## Relationship to existing documents

- `AGENTS.md` — unchanged by this decision. It still points to
  `docs/DEVELOPMENT_PLAN.md` as mandatory pre-work reading; that pointer is
  sufficient to reach this document (see the short cross-reference added to
  `DEVELOPMENT_PLAN.md`'s top section).
- `docs/DEVELOPMENT_PLAN.md` — remains the source of truth for phase/feature
  sequencing. This decision governs *how* that plan gets prioritized and
  reported on, not its phase content.
- `docs/ai-knowledge/INDEX.md` — remains the router for evidenced
  incidents/patterns/decisions (`SES-XXX-NNN` entries). This document is a
  standing product/process decision rather than a technical
  incident/pattern, so it lives in `docs/decisions/` instead of being forced
  into that ID scheme; a one-line pointer was added to the index's routing
  notes so it is still discoverable from there.
