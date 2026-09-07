# SES TAB UI Visual Reference — Canonicalization Result

STATUS: **DONE（docs-only）**

## BASE / HEAD

- BASE SHA: `8387e9369389665bc38525f54430fb8930cd3808`（origin/main、PR #191マージ後）
- ブランチ: `claude/ses-tab-ui-visual-reference-pgxknt`（既存ブランチはmainから
  約1か月遅れの`f4ca78f`で停止・PR未作成だったため、`origin/main`から作り直した）
- HEAD SHA: 本ドキュメントのcommit時点のHEADを参照（コミットログ参照）

## 実施内容

### 1. 添付ZIPの代替確認

当初添付されるはずだった`SES_TAB-UI_REFERENCE_2026-09-05(1).zip`は本セッションから
直接アクセスできなかったが、ユーザー指示により**既にmainに存在する
`docs/design/references/SES_UI_Audit_References.zip`**を確認した。

このzip内に、日付2026-09-05付の7枚のPNGが実在することを確認した
（`unzip -l`のタイムスタンプで確認）。7枚それぞれを目視確認し、内容が
以下の通りEmployee/Sales/Accounting/Menuの4タブを対象とするUIモックアップ
であることを確認済み:

1. 社員タブ — 改善レイアウト（案）
2. 5タブ横断 — 各タブ改善レイアウトイメージ（完成案）
3. 社員タブ — 詳細レイアウト（完成イメージ案）
4. 営業タブ — 詳細レイアウト（完成イメージ案）
5. 営業タブ — 画面遷移イメージ（完成案）
6. 会計タブ — 詳細レイアウト（完成イメージ案）
7. メニュータブ — 詳細レイアウト（完成イメージ案）

新たな添付・アップロードは不要と判断し、これら7枚をCanonical Visual
Referenceとして続行した。

### 2. Canonical Visual Referenceの保存

`docs/design/references/SES_UI_Audit_References.zip`から7枚のPNGを抽出し、
`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`へ、内容が分かる
ファイル名へ改名して保存した（ピクセル内容は無変更、sha256一致を確認済み）。
zip内の元ファイル名との対応表とsha256は同ディレクトリの`README.md`に記録した。

### 3. Visual SSOTの新規作成

`docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`を新規作成し、以下を明記した:

- 上記7枚をEmployee / Sales / Accounting / MenuのCanonical Visual Referenceとする
- HOMEは既存HOME Visual SSOT（`docs/reports/SES_HOME-FINAL-TOUCH_Result.md`
  「SES HOME Visual SSOT Exact Layout Match」節）を優先しFreeze維持
- Referenceが正とするのはVisual/layout/情報階層/navigation targetのみ
- game state / eligibility / calculations / 表示する事実データは既存
  authoritative実装が正（Referenceに描かれた架空データ・機能を実装根拠にしない）
- fake data禁止
- 360×800 / 390×844
- TextScaler 1.3 / 2.0でのhorizontal overflow禁止
- practical tap target 48px以上
- current state → next action → detailの情報階層
- excessive scrolling回避

### 4. 開発計画SSOTの更新

`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`を更新し、
「Current execution order」・「次順序」リスト・Prioritized backlog table・
Update historyに以下の計画順を反映した:

1. Accounting UI Phase 1
2. NON-HOME Visual Fresh Audit
3. Employee Visual Complete
4. Sales Visual Complete
5. Accounting Visual Complete
6. Menu Visual Complete
7. 5-tab Visual Review
8. April→March Human Replay

あわせて、Employee UI Phase 1 / Sales UI Phase 1が
**「information architecture complete」であり「Visual Complete」ではない**
ことをbacklog table・次順序リスト双方に明記した。

## 変更ファイル

```
docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md                          (modified)
docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md                                     (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/01_Employee_LayoutDraft.png       (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/02_FiveTabs_LayoutOverview.png     (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/03_Employee_DetailedLayout.png     (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/04_Sales_DetailedLayout.png        (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/05_Sales_ScreenFlow.png            (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/06_Accounting_DetailedLayout.png   (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/07_Menu_DetailedLayout.png         (new)
docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/README.md                          (new)
docs/reports/SES_TAB-UI_REFERENCE_Canonicalization_Result.md                   (new, this file)
```

production code（Flutter/Dart, `lib/`配下）・save/finance/balance/month
authority・HOME実装は一切変更していない。docs-onlyの変更。

## 検証結果

- **7 PNGがrepository内に存在**: `docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`配下に7枚のPNG（+README.md）を確認済み。
- **SSOTからCanonical Referenceへ到達可能**: `docs/design/SES_NON-HOME-UI_VISUAL-SSOT.md`から`docs/design/references/SES_TAB-UI_REFERENCE_2026-09-05/`への相対パス参照、および逆方向（README→SSOT）の相互参照を確認済み。`docs/decisions/SES_DEVELOPMENT-PRIORITY_2026-09-02.md`からもVisual SSOTへの参照を追加済み。
- **`git diff --check`**: ステージ済み変更に対して実行し、warning/errorなし（exit code 0）。

## 未解決事項 / Known Issues

- 7枚のPNGはAI生成のモックアップ画像であり、画像内の社員名・案件名・金額等の
  具体数値はすべてサンプルであることを`SES_NON-HOME-UI_VISUAL-SSOT.md`と
  同ディレクトリの`README.md`双方で明記済み。実装時はこの点を再確認すること。
- 本タスクではAccounting UI Phase 1のproduction実装には一切着手していない
  （指示通り）。次のP0はSSOT更新後の計画順に従う。
- NON-HOME Visual Fresh Audit以降（Employee/Sales/Accounting/Menu Visual
  Complete、5-tab Visual Review）は本タスクの範囲外であり、別タスクとして
  今後実施する。

## Merge Readiness

docs-onlyの追加・変更のみで、production code / gameplay / domain / save /
finance / balance / month authorityへの影響なし。AUTO-MERGEは行わない
（ユーザー指示通り、レビュー後の人手マージを想定）。
