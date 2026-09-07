# SES_TAB-UI_REFERENCE_2026-09-05 — source manifest

このディレクトリの7枚のPNGは、`docs/design/references/SES_UI_Audit_References.zip`
（既にmainに存在、2026-09-05付）に含まれていた7枚のPNGをそのまま抽出・改名したもの。
ピクセル内容は変更していない（sha256一致、再エンコードなし）。

このディレクトリの7枚が **SES NON-HOME UI Visual Complete の Canonical Visual Reference**
である。詳細な使い方・優先順位は `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md` を参照。

## ファイル対応表（zip内の元ファイル名 → このディレクトリでの正式名）

| # | 正式ファイル名 | 対象タブ / 内容 | zip内の元ファイル名 | sha256 |
|---|---|---|---|---|
| 1 | `01_Employee_LayoutDraft.png` | 社員タブ — 改善レイアウト（案） | `a_clean_infographic_ui_mockup_image_of_a_japanese.png` | `caf537e3fc37a1da6d40c86695b808bb5938a8985d7aa2a99505a64f9938c201` |
| 2 | `02_FiveTabs_LayoutOverview.png` | 5タブ（ホーム/社員/営業/会計/メニュー）— 各タブ改善レイアウトイメージ（完成案） | `a_clean_ui_design_mockup_infographic_app_screens.png` | `35159f8d075b2322505ada5ecdc5fec4cdcce01fa8e70fd9abe7061ea01146a2` |
| 3 | `03_Employee_DetailedLayout.png` | 社員タブ — 詳細レイアウト（完成イメージ案） | `a_clean_ui_concept_poster_with_multiple_mobile_app.png` | `3a053ef27fa44f33b8e7a6e48a7ef972ba6a15b585f6fb7eb72694c84d755759` |
| 4 | `04_Sales_DetailedLayout.png` | 営業タブ — 詳細レイアウト（完成イメージ案） | `a_wide_clean_ui_ux_design_mockup_poster_for_a_mob.png` | `70fc4ebf0102d675baa856911d0a004988ab5eb3e5587ca9243e3db2c1c7ad4a` |
| 5 | `05_Sales_ScreenFlow.png` | 営業タブ — 画面遷移イメージ（完成案） | `a_wide_clean_ui_ux_design_presentation_poster_in.png` | `929de435a82845d3d00a8a3b4c6e3408c73ce07cae0f6900022a1dce151c8748` |
| 6 | `06_Accounting_DetailedLayout.png` | 会計タブ — 詳細レイアウト（完成イメージ案） | `wide_infographic_style_ui_mockup_image_on_a_light.png` | `96cc7feee4f2c2f7d9e816960064e8a53f64409bc92a8f8caca99b0964997898` |
| 7 | `07_Menu_DetailedLayout.png` | メニュータブ — 詳細レイアウト（完成イメージ案） | `a_wide_clean_ui_ux_concept_poster_image_for_a_mob.png` | `8589892168279ac04bd7f7ac1aa9f5fd20d4f4f75b7a3c2c0cf10eda562b40b1` |

## IMPORTANT — これらの画像の使い方

この7枚は **Visual / layout / hierarchy / navigation target の正**である。

画像内に描かれている架空の社員名・案件名・単価・金額・数値・機能（例:
「ECサイト開発支援」「佐藤健」「320万円」等）は **gameplay仕様の正ではない**。
実装時は既存の authoritative game state / domain実装が優先し、画像にある
架空データや画像にしか存在しない機能を新規実装してはならない。

この7枚のPNG（2026-09-05付）が正式なCanonical Visual Referenceであり、
これ以外の単独の後発JPEG/PNG（例: 個別タスクのpre/post比較用に追加された
一時的なターゲット画像）をCanonical Referenceとして扱わない。
