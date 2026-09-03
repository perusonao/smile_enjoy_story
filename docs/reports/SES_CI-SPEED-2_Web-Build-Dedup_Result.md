# SES-CI-SPEED-2 — Web Build Dedup（main→Pages deploy 高速化）— Result

## Objective

`.github/workflows/e2e.yml` の Fast CI（main push 経路）では、`flutter build
web` が **2回** 実行されている:

1. `validate` ジョブ: `flutter build web --release --no-web-resources-cdn`
   （base-href なし＝デフォルト `/`）— `smoke-e2e` のローカル静的サーバ用
2. `build` ジョブ（Pages 用）: `flutter build web --release --base-href
   "/${{ repository.name }}/" --no-web-resources-cdn` — GitHub Pages 配信用

`build` の `flutter analyze`/`flutter test` 重複は PR #151（Issue #149）で
既に削除済み。本タスクの主対象は残った `flutter build web` の重複そのもの。
PR #151 の結果報告（`SES_TEST-STRATEGY-1_CI-Optimization_Result.md`
「未解決事項」）でも、この重複は base-href 差異のため「安全に統合するには
E2E ローカル配信側の変更が必要で別Issue化を推奨する」と明記されており、
本タスクはその follow-up にあたる。

## BASE SHA

`e60dbe38c0eee05d12ba34a241373d3a9dfd1731`
（`Issue #148 Phase 1A: 確定情報ベース資金予測SSOT`, origin/main の実際の tip
と一致することを `git rev-parse origin/main` で確認済み — タスク記載の
CURRENT EXPECTED MAIN と同一）

作業ブランチ `claude/web-build-dedup-ci-svlywe` は元々
`f4ca78f`（Phase 0A/0B, SES domain models）という stale なコミットを指して
いたが、`git log origin/main..HEAD` が空（= このコミットは既に origin/main
の祖先として merge 済み）であることを確認したうえで、
`git checkout -B claude/web-build-dedup-ci-svlywe origin/main` により
最新 main から作り直した。ブランチ固有の未 merge コミットは存在しなかった
ため、破棄した作業はない。

## Slice A — 監査結果

### 現在の job dependency

```
pull_request / push(main) / workflow_dispatch
  └─ validate      : pub get → analyze → test
                      → build web --release --no-web-resources-cdn
                        (base-href なし = "/")
                      → upload artifact "build-web"
                      → npm ci → replay unit tests
       └─ smoke-e2e : "build-web" artifact を download → build/web に展開
                      → Playwright (mobile-chromium, curated smoke spec)
             ├─ replay-package (push限定, if: always())
             └─ check-latest    (push/workflow_dispatch限定, stale-SHA guard)
                   └─ build      : checkout target_sha
                                    → pub get
                                    → build web --release
                                      --base-href "/${{ repository.name }}/"
                                      --no-web-resources-cdn   ← 重複②
                                    → e2e-replay-package を fold-in
                                    → upload-pages-artifact
                         └─ deploy : check-latest を再実行 → deploy-pages
```

`build` は `needs: [smoke-e2e, check-latest]` かつ
`check-latest.outputs.is_latest == 'true'` のときのみ実行され、
`check-latest` は `target_sha`(= 本 run の `github.sha`) が
`origin/main` の実際の tip と一致する場合のみ `true` を返す
（`e2e/scripts/check-latest-main.mjs`、単純な文字列比較、値の書き換えなし）。
つまり `build` が checkout する SHA は、`validate`/`smoke-e2e` が検証した
SHA と常に同一であることが保証されている。この stale-SHA guard の構造は
本タスクで一切変更しない。

### 問い:「validateで1回だけ生成したWeb artifactを、smoke E2EとGitHub
Pages deployの両方で安全に再利用できるか？」

**base-href の差異を確認した:**

- `validate` の build: `--base-href` 未指定 → `web/index.html` の
  `<base href="$FLUTTER_BASE_HREF">` は `/` に置換される
- `build`（Pages）の build: `--base-href "/smile_enjoy_story/"` →
  同プレースホルダは `/smile_enjoy_story/` に置換される
- `web/index.html` を確認したところ、`flutter_bootstrap.js` /
  `manifest.json` / `favicon.png` / `icons/Icon-192.png` へのリンクは
  すべて相対パス（先頭 `/` なし）であり、ブラウザは `<base href>` を基準に
  解決する。Flutter Web の bootstrap（`flutter_bootstrap.js` /
  `flutter_service_worker.js` 等）が持つ資産一覧も相対キーであり、
  実行時に `document.baseURI`（= `<base>` タグ）を基準に解決される。
  よって **`index.html` 内の `<base href>` 文字列以外に base-href が
  焼き込まれる箇所はない**（本セッションには Flutter SDK が存在せず実ビルド
  比較はできていないため、この結論はソースコード調査ベースであり、
  Slice D の CI 実行結果で最終確認する）。
- `e2e/playwright.config.ts` の `webServer` は
  `node scripts/static-server.js <port> <build/web dir>` を起動し、
  `baseURL` は `http://localhost:<port>`（サブパスなし）。
  `e2e/scripts/static-server.js` はリクエストパスをそのまま
  `build/web` 配下のファイルパスとして解釈するのみで、サブパス
  (`/smile_enjoy_story/...`) 配信には対応していない。
- `e2e/tests/*.spec.ts` は全て `page.goto('/?e2e=1...')` のように
  **先頭 `/` の絶対パス** で遷移している。Playwright の URL 解決規則上、
  先頭 `/` のパスは `baseURL` のオリジンに対して解決される（パス部分は
  無視される）ため、`baseURL` にサブパスを足すだけでは
  `page.goto('/...')` は依然オリジン直下にアクセスする。

**結論:** `validate` の build（base-href `/`）と Pages 用 build
（base-href `/smile_enjoy_story/`）は **`index.html` 1ファイルの内容のみ
が異なり**、それ以外の `build/web` 配下のファイル構成・内容は同一である
（相対パス方式のため）。1回の artifact を両方に安全に使い回すには:

- `validate` 側の build を Pages と同じ base-href
  (`/${{ github.event.repository.name }}/`) で実行するよう変更し、
- `smoke-e2e` が使うローカル静的サーバ側を、`<base href>` が指す
  `/smile_enjoy_story/` サブパス配下でも資産を配信できるよう対応させる
  （`page.goto('/...')` はそのままルート `/` の index.html を返し、
  ブラウザがその後 `<base href>` に従って発行する `main.dart.js` 等の
  サブパス付きリクエストだけをサーバ側で吸収する）

という Slice B の方針で、ゲームコードやテストの assertion には一切触れず
安全に統合できる。

### 判定: **A. 安全に1回化可能**

根拠:
- 差分は `index.html` の `<base href>` 1箇所のみ（相対パス方式のため）
- stale-SHA guard・smoke E2E の spec 内容・Pages deploy の安全確認ステップ
  はいずれも変更不要（`validate`/`build` job の "何を build するか" のみ
  変更し、"いつ deploy するか" の判定ロジックには触れない）
- 変更対象は CI インフラ（workflow YAML + `e2e/scripts/static-server.js` +
  `e2e/playwright.config.ts`）に閉じ、`lib/`（ゲームコード）は一切変更不要

Slice B へ進む。

## 変更ファイル（想定, Slice B/C時点で更新）

- `.github/workflows/e2e.yml`
- `e2e/scripts/static-server.js`
- `e2e/playwright.config.ts`
- 本レポート

## commit SHA（Slice A）

（このコミットで記録）
