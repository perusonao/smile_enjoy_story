# SES FIRST-FUN-YEAR — Month-start Status / Recommended Action Fresh Audit

## Recommended AI
Claude Code Sonnet

## Goal
First Fun Year の次P1として、月が変わった直後にプレイヤーが数秒で以下を理解できる状態へ進めるため、まず最新mainをREAD-ONLYでFresh Auditする。

- 今月の会社状態はどうなっているか
- 先月の結果から何が変わったか
- 今月まず何をすべきか
- 誰を研修・営業・案件進行すべきか
- 資金不足や待機リスクがある場合、どの行動が回復につながるか

新しい経営システムや独自authorityを作らず、既存 Finance / Payroll / Assignment / Employee Status / Project Context / Recruitment / Monthly Management Report / HOME Recommended Action のauthorityを再利用する前提で監査する。

## Base / Freshness — MUST
作業開始時に `git fetch origin`。repository default branchは禁止。明示的に最新 `origin/main` を基準にする。

Issue #241 / PR #242 merge main at task creation:
`245a4d430901fc93245c1d95c8e858e3dcfda5c3`

main post-merge Fast CI #642 が実行中でもFresh Auditは並行可。ただしproduction implementation開始前に最新mainとCIを再確認する。

## Fresh Audit — READ ONLY
production codeは変更しない。以下をtraceする。

1. 月末close後から次月HOME表示までの遷移順序
2. Monthly Management Report dismiss後に何がHOMEへ引き継がれるか
3. HOMEの会社状態/KPI/資金警告/総務案内/Recommended Actionの現authority
4. Recommended Action候補の生成・優先順位・CTA先
5. Employee Status（研修が必要 / 営業可能 / 待機 / 営業中 / 参画予定 / 参画中）との接続
6. Project / Order / Assignment Contextとの接続
7. Recruitment / confirmed next-month join / joined applicantとの接続
8. Cash shortage / waiting employee / assignment shortage時の回復導線
9. April opening contextとMay以降の月初体験の差
10. July bonus / year-end / bankruptcy等、通常月と異なる月境界
11. save/reload直後に月初状態や推奨行動がtruthfulか
12. stale / duplicate / impossible CTAが残る条件
13. 360x800 / 390x844で追加情報を1画面HOME要件を壊さず提示できる余地

## Required state matrix
最低限、以下で「表示される状態」「Recommended Action」「CTA先」「authority」を表にする。

- Fresh April
- May after no recruitment
- waiting employee + sales-ready
- waiting employee + training-required
- active sales pipeline
- ordered but not assigned
- assigned engineer
- recruitment applicant pending
- confirmed next-month join
- newly joined employee
- cash warning / recovery-needed
- July bonus boundary
- March / year-end
- bankruptcy/terminal where applicable
- reload immediately after month transition

## Authority rules
- UI独自の資金・給与・参画・営業可能・入社時期計算は禁止
- fake status / fake project / fake next action禁止
- ordered != assigned を維持
- joined applicantをpre-entryへ戻さない
- replacement ordered時に旧projectを新projectとして表示しない
- Finance/Payroll/Matching/Assignment balance式変更禁止
- save schema変更禁止（必要性を発見した場合は実装せず報告）
- HOME大規模redesign禁止
- Monthly Management Reportを二重close/seen-state代用に使わない

## Audit questions
特に以下を判定する。

A. 月初専用の新しいpersistent stateは本当に必要か。それとも既存aggregateからread-only derive可能か。
B. 「会社状態」と「次の一手」を1つのpresentation resolverへ集約できるか。
C. Recommended Actionの既存候補/優先順位にstale・impossible・情報確認CTA優先の問題があるか。
D. 先月結果→今月行動の理解ループを、Monthly ReportとHOMEの既存情報だけで接続できるか。
E. First Fun Year Human Replay #225を再開する前に実装すべき最小scopeは何か。

## Output / Verdict
`GO / GO WITH MINOR DESIGN CHANGES / NO-GO` を出す。

GOの場合は、production実装をまだ開始せず、2〜3時間以内のClaude Code実装単位に切った具体的implementation planを提示する。

必須:
- audited main SHA
- authority trace
- state matrix
- root causes / gaps
- proposed minimal presentation architecture
- changed-file候補（まだ変更しない）
- test matrix
- persistence/schema impact
- known limitations
- Human Replay #225再開条件

## Result Report — REQUIRED
`docs/reports/SES_FIRST-FUN-YEAR_Month-Start-Status-Recommended-Action_Fresh-Audit.md`

監査レポートをrepositoryへcommitし、Claude Code最終回答にも添付/uploadしてiPhoneから直接取得可能にする。ローカルpathだけは禁止。

## Progress reporting — REQUIRED
各節目で以下を報告:
`Current status / Next action / Actual elapsed time / Revised ETA`

## Estimated processing time
Fresh Audit: 30〜60分。

## Review policy for later implementation
実装 → Claude self-hardening → focused verification → Codex broad review 1回 → P0/P1とFirst Fun Year直結P2をまとめて修正 → focused verification → CI → exact-head merge。Broad Reviewを再帰的に繰り返さない。
