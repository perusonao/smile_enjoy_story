# SES NON-HOME UI Visual SSOT

Status: **Accepted — current governing Visual reference for Employee / Sales / Accounting / Menu**

このドキュメントは、HOME以外のタブ（Employee / Sales / Accounting / Menu）の
**Visual（見た目）/ layout / 情報階層 / navigation target** についての
単一の正本（Single Source of Truth）である。

## Canonical Visual Reference

`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` 配下の **7枚のPNG** を、
Employee / Sales / Accounting / Menu の Canonical Visual Reference とする。

| # | ファイル | 対象タブ | 内容 |
|---|---|---|---|
| 1 | `01_Employee_LayoutDraft.png` | 社員 | 改善レイアウト（案） |
| 2 | `02_FiveTabs_LayoutOverview.png` | 社員/営業/会計/メニュー（+ホーム） | 各タブ改善レイアウトイメージ（完成案）— 5タブ横断の全体像 |
| 3 | `03_Employee_DetailedLayout.png` | 社員 | 詳細レイアウト（完成イメージ案）— 一覧/詳細モーダル/スキルシート/案件詳細 |
| 4 | `04_Sales_DetailedLayout.png` | 営業 | 詳細レイアウト（完成イメージ案）— 案件一覧〜提案確認〜進捗の5画面 |
| 5 | `05_Sales_ScreenFlow.png` | 営業 | 画面遷移イメージ（完成案） |
| 6 | `06_Accounting_DetailedLayout.png` | 会計 | 詳細レイアウト（完成イメージ案）— サマリー/収支内訳/入金予定/予測/アラート |
| 7 | `07_Menu_DetailedLayout.png` | メニュー | 詳細レイアウト（完成イメージ案）— メニュー/セーブロード/設定/チュートリアル/初期化 |

元ファイルの由来・sha256による同一性証跡は
`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/README.md` を参照。

この7枚が正式版であり、単独の後発JPEG/PNG（個別タスクのpre/post比較用に
追加された一時的なターゲット画像等）をCanonical Referenceに昇格させない。

## Scope

- **対象**: Employee（社員）タブ / Sales（営業）タブ / Accounting（会計）タブ / Menu（メニュー）タブ。
- **対象外（Freeze維持）**: HOME。HOMEは既存のHOME Visual SSOT
  （`docs/reports/SES_HOME-FINAL-TOUCH_Result.md`「SES HOME Visual SSOT Exact
  Layout Match」節、および実装済みスクリーンショット
  `docs/reports/screenshots/SES_HOME-VISUAL-SSOT-EXACT_AFTER_360x800.png` /
  `..._390x844.png`）を優先し、HOME Freeze
  （`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`「HOME
  Freeze（2026-09-06）」節）を維持する。本SSOTの7枚にHOME向けの構図・要素が
  含まれていても、HOME実装への反映・先取りは行わない。

## 優先順位 — Reference と Authoritative State の関係

1. **Authoritative game state / 既存specification が常に最優先。**
   ゲーム上の状態・数値・可否判定（eligibility）・計算結果・実際に画面へ
   表示すべき事実データは、既存の authoritative な実装（domain / workflow /
   save state 等）が正であり、本Visual Referenceはそれを変更する根拠にならない。
2. **Visual Reference（この7枚）が正とするのは、layout / 情報階層 /
   visual treatment（配色・カード形状・アイコン・タイポグラフィ等）/
   navigation target（画面遷移先・タブ構成）に限る。**

つまり、Referenceに描かれていても現行のauthoritative stateに存在しない
データや機能（例: 画像内の架空の社員名・案件名・クライアント名・金額・
グラフの具体数値・存在しない画面遷移機能など）を、Referenceを根拠に
新規実装してはならない。実装時は必ず既存の authoritative
フィールド・ロジックから表示可能な値だけを使う。

## 必須ルール

- **fake data禁止**: 架空の人物名・案件名・金額・数値をproduction UIに
  一切表示しない。Referenceに描かれた具体値はレイアウトの参考例に過ぎない。
- **対応viewport**: 360×800 / 390×844 の両方で確認する。
- **TextScaler 1.3 / 2.0**: いずれの倍率でも horizontal overflow を起こさない。
- **タップ領域**: practical tap target は 48px 以上を確保する。
- **情報階層**: 各タブは「current state（現在の状態）→ next action（次に
  やるべき行動）→ detail（詳細）」の順で構成する。
- **スクロール**: excessive scrolling を避け、主要情報をできる限り
  1画面相当の密度でまとめる。

## Relationship to existing documents

- `docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md` — 開発優先順位の
  正本。NON-HOME Visual Fresh Audit以降の実行順序はこちらを参照。
- `docs/reports/SES_NON-HOME-UI_EMPLOYEE_Phase1_Implementation_Result.md` /
  `docs/reports/SES_NON-HOME-UI_SALES_Phase1_Implementation_Result.md` —
  Employee/Sales UI Phase 1（情報階層＝IA再設計）の実装結果。この2つは
  **information architecture complete であり、本SSOTが定義するVisual
  Completeではない**。Visual Complete化（配色・カード形状・アイコン・
  タイポグラフィ等をこの7枚に整合させる作業）は別タスクとして今後実施する。
- `docs/reports/SES_HOME-FINAL-TOUCH_Result.md` — HOME側のVisual SSOT
  運用実績（本SSOTのHOME Freeze節が参照する既存事例）。

## Update history

### 2026-09-07（Canonicalization）

- `docs/design/references/SES_UI_Audit_References.zip`（既存, main）に
  含まれていた7枚のPNG（2026-09-05付）を
  `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/` へ抽出・改名し、
  Employee / Sales / Accounting / Menu の Canonical Visual Reference として
  本SSOTを新規作成した。
