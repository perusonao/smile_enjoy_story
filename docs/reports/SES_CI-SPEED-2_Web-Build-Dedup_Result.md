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

## Slice B — 実装結果

### changed files

- `e2e/scripts/static-server.js` — 4番目の任意引数（CLI）/
  `SES_E2E_BASE_PATH`（env）で `basePath`（例:
  `/smile_enjoy_story/`）を受け取れるようにした。リクエストパスを
  まず `root` 直下にそのまま解決し、見つからず `basePath` prefix と一致する
  場合のみ prefix を除いた相対パスで再解決、それでも見つからなければ従来
  通り `index.html` へ SPA fallback する。`basePath` 未指定（デフォルト
  `''`）時は解決ロジックが従来の「直接 stat → 見つからなければ
  index.html」と完全に同じ経路を通るため、ローカル開発フロー
  （`flutter build web` を base-href なしで実行するケース）は無変更。
- `e2e/playwright.config.ts` — `SES_E2E_BASE_PATH` を読み取り、
  `static-server.js` の第3引数として渡すよう `webServer.command` を拡張。
  `baseURL` はルート (`http://localhost:<port>`) のまま変更していない
  （`page.goto('/...')` は先頭 `/` の絶対パスなので、`baseURL` に
  サブパスを足しても意味がないため — Slice A の監査結果通り）。
- `.github/workflows/e2e.yml`
  - `validate` ジョブの `flutter build web` に
    `--base-href "/${{ github.event.repository.name }}/"` を追加
    （Pages 用 `build` ジョブと同一の式）。これにより `validate` が
    upload する `build-web` artifact は Pages 配信用と同じ
    `<base href>` を持つ。
  - `smoke-e2e` ジョブの Playwright 実行ステップに
    `SES_E2E_BASE_PATH: "/${{ github.event.repository.name }}/"` を追加
    し、ローカル静的サーバがその base-href を解決できるようにした。
  - Slice C ではないため、Pages 用 `build` ジョブの `flutter build web`
    自体はまだ削除していない（次 Slice の対象）。

### implementation

Slice A で確認した通り、base-href の違いは `index.html` の
`<base href>` 文字列 1箇所のみで、他の参照は全て相対パスのためブラウザが
その `<base>` を基準に解決する。したがって:

- `validate` の build を Pages と同じ `--base-href` に揃えれば、
  `validate` が生成する1つの artifact が Pages 配信物と **同一内容**になる
- `smoke-e2e` 側は、`page.goto('/...')`（先頭 `/` の絶対パス）で常に
  サーバルートの `index.html` を取得し、その `<base href>` に従って
  ブラウザが発行する後続リクエスト（`main.dart.js` 等）だけが
  サブパス付きになる。ローカル静的サーバがそのサブパスを認識して
  同じファイルを返せれば、ゲーム側コード・テストの assertion には
  一切触れずに base-href 差異を吸収できる

この設計により、production routing（Pages の実際の配信）や
gameplay テストの内容は変更していない。`static-server.js` の変更は
「見つからなければ prefix を1回だけ剥がして再試行」という E2E harness
専用の追加ロジックであり、GitHub Pages 専用 hack をゲームコード
（`lib/`, `web/index.html` 含む）へ入れる形にはなっていない
（`web/index.html` は無変更）。

### verification（focused）

このセッションには Flutter SDK が存在しないため、実際の
`flutter build web --base-href ...` は実行できていない（Slice D の
実 CI 実行で最終確認する）。Flutter に依存しない範囲で以下を実施した:

- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/e2e.yml'))"`
  — YAML構文の妥当性、既存6ジョブ
  (`validate/smoke-e2e/replay-package/check-latest/build/deploy`) が
  変更後も揃っていることを確認
- `cd e2e && npx tsc --noEmit -p tsconfig.json` — `playwright.config.ts`
  の型チェックが通ることを確認
- `cd e2e && npm run test:replay-unit` — 112件全て pass
  （`check-latest-main.mjs` 等 stale-SHA guard 関連のユニットテストを
  含む。本 Slice ではこのスクリプトを変更していないため無影響である
  ことの再確認）
- `static-server.js` を実際に起動し、`flutter build web
  --base-href "/smile_enjoy_story/"` の出力を模した最小限のダミー
  `build/web`（`<base href="/smile_enjoy_story/">` を持つ `index.html`
  + 相対パス参照の JS/JSON/PNG）に対して手動 HTTP リクエストで検証:
  - `GET /` → ルートで `index.html`（ダミー実装が期待通りその base href
    を含む）を返す
  - `GET /smile_enjoy_story/flutter_bootstrap.js` →
    prefix を剥がして `root` 直下の同名ファイルを実体で返す
    （index.html への SPA fallback ではなく実際の JS 内容）
  - `GET /smile_enjoy_story/icons/Icon-192.png` → ネストした
    パスでも同様に解決
  - `GET /smile_enjoy_story/../../etc/passwd` → `root` 外への脱出は
    ブロックされ SPA fallback（`index.html`）が返る（既存の path
    traversal ガードが `basePath` 剥がし後の再解決にも適用されている
    ことを確認）
  - `basePath` 引数を省略した場合、`GET /manifest.json` や
    存在しないパスへの fallback がいずれも変更前と同じ挙動であることを
    確認（後方互換）

### remaining risk

- 実際の `flutter build web --base-href` 出力に、`index.html` 以外にも
  base-href が焼き込まれる箇所がないかは、ソースコード調査
  （`web/index.html` の相対参照、Flutter Web bootstrap の一般的挙動）
  ベースの結論であり、本セッションで実ビルドを比較検証してはいない。
  Slice D の実 CI 実行（`smoke-e2e` の GREEN/RED）で最終確認する
- `smoke-e2e` の 3 seed founding-first-assignment を含む実際の
  Playwright 実行そのものは、この環境に Flutter SDK も
  Playwright ブラウザバイナリの新規取得手段もないため未実施。
  Slice D の CI 実行に委ねる

### commit SHA（Slice B）

`6d8deb2`（`feat(ci): make one Pages-base-href Web build reusable by smoke-e2e (SES-CI-SPEED-2 Slice B)`）

## Slice C — 実装結果

### changed files

- `.github/workflows/e2e.yml`
  - `build` ジョブから `subosito/flutter-action@v2` / `flutter pub get` /
    `Build web (release)`（`flutter build web --release --base-href ...`）
    の3ステップを完全に削除した。
  - 代わりに `actions/download-artifact@v4`（`name: build-web`,
    `path: build/web`）を追加し、`validate` が同一 run 内でアップロード
    済みの `build-web` artifact（Slice B により Pages と同じ base-href で
    ビルド済み）をそのまま `build/web` へ展開する。
  - ジョブ冒頭のコメントブロック（jobs 一覧）と `build` ジョブ内の
    インラインコメントを、実際の構造（Flutter build 自体が無くなった）に
    合わせて更新した。
  - `build` ジョブの `permissions`（`contents: read` /
    `pages: write` / `actions: read`）・`needs`
    (`[smoke-e2e, check-latest]`)・`if` 条件・`concurrency` 設定は
    無変更。Replay Viewer の fold-in（`e2e-replay-package` の
    download → `build/web/e2e-replays/` への組み込み）と
    `actions/configure-pages@v5` / `actions/upload-pages-artifact@v3` も
    無変更。

### implementation

Slice B で `validate` の build は Pages と同一の `--base-href` を持つ
ようになったため、`check-latest` が保証する「`build` が使う SHA は
`validate` が検証した SHA と常に同一」という既存の安全性前提と組み合わせる
と、`build` ジョブは自前で `flutter build web` を再実行する必要が完全に
なくなる。`build` ジョブは `checkout`（`ref:
needs.check-latest.outputs.target_sha`、`e2e/replay-viewer/` ソースの
fold-in に必要なため維持）の直後に `build-web` artifact を download する
だけになった。

stale-SHA guard（`check-latest`/`deploy` 直前の再検証）・`needs`/`if` の
依存関係・Replay Viewer 組み込みロジック・`upload-pages-artifact` の呼び出し
方はいずれも変更していない。ゲームコード（`lib/`, `web/`）・テストの
assertion にも触れていない。

### verification（focused）

- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/e2e.yml'))"`
  — YAML構文の妥当性、既存6ジョブが変更後も揃っていることを再確認
- 変更後の `build` ジョブの `needs`/`steps`/`permissions` を Python 経由で
  抽出し、`checkout → Download build/web → Download e2e-replay-package →
  Assemble Replay Viewer → configure-pages → upload-pages-artifact` の順に
  Flutter 関連ステップが一切存在しないこと、`permissions` が無変更である
  ことを直接確認した
- `mkdir -p build/web/e2e-replays`（Replay Viewer 組み込みステップ）は
  `build/web` が既に存在する前提だったが、artifact download 後も
  `build/web` は同じディレクトリ構造で存在するため、この後続ステップの
  ロジックは変更不要であることをコードレビューで確認した
- Flutter SDK が本環境に存在しないため、`build-web` artifact の実際の
  download → `upload-pages-artifact` までの結合動作は Slice D の実 CI 実行
  （`build`/`deploy` ジョブの GREEN）で最終確認する

### remaining risk

- `actions/download-artifact@v4` が同一 workflow run 内の `validate` の
  artifact を正しく取得できることは、既存の `smoke-e2e`/`replay-package`
  ジョブの同パターンから安全であると判断しているが、`build` ジョブでの
  実際の download 成功は Slice D の実 CI で確認する
- base-href 以外に build 成果物の差異が無いという Slice A/B の結論
  （ソースコード調査ベース）が実際の Pages 配信で問題ないかは、Slice D の
  Pages deploy 実行結果（配信URLでの実アクセス確認は本タスクの範囲外だが、
  `build`/`deploy` ジョブ自体のGREEN化で構造的な健全性は確認できる）で
  引き続き検証する

### commit SHA（Slice C）

`56880aa`（`perf(ci): drop second Flutter web build from Pages deploy job (SES-CI-SPEED-2 Slice C)`）

## 変更ファイル（累計, Slice C時点）

- `.github/workflows/e2e.yml`
- `e2e/scripts/static-server.js`
- `e2e/playwright.config.ts`
- 本レポート

## Slice D — PR / CI verification

### PR URL

[#155](https://github.com/perusonao/smile_enjoy_story/pull/155)
（base: `main`、head: `claude/web-build-dedup-ci-svlywe`, `mergeable_state:
clean`）

### base の追従について

PR作成後、`origin/main` が `e60dbe38`（本タスクの CURRENT EXPECTED MAIN）
から `8d510e6a`（Issue #148 Phase 1B.1 + 1B.2, 本タスクの DO NOT 対象）へ
進んだことを確認した。差分は `docs/` 配下の別レポートと
`lib/game/public_demo/` 関連のみで、本 PR が変更する
`.github/workflows/e2e.yml` / `e2e/scripts/static-server.js` /
`e2e/playwright.config.ts` / 本レポートとはファイルの重なりが一切なく
（`git diff --stat e60dbe38..origin/main -- <本PRの変更ファイル>` が空）、
GitHub 側も `mergeable_state: "clean"` を報告しているため、コンフリクト
解消のための追加 merge commit は行っていない。Issue #148 Phase 1B の内容
自体には一切触れていない。

### CI結果（実測、GitHub Actions run #398 / id 33721434923, event:
pull_request, head_sha `2f4a59bb`）

| job | conclusion | 所要時間 |
|---|---|---|
| `validate` | ✅ success | 10m46s（06:02:50 → 06:13:36） |
| `smoke-e2e` | ✅ success | 2m04s（06:13:39 → 06:15:43） |
| `check-latest` | skipped | — |
| `build` | skipped | — |
| `deploy` | skipped | — |
| `replay-package` | skipped | — |

`check-latest`/`build`/`deploy`/`replay-package` の skip は
`e2e.yml` の設計通り（`pull_request` イベントでは
`validate`/`smoke-e2e` のみ実行し、Pages deploy 経路は push/
workflow_dispatch 限定 — ワークフロー冒頭のコメント参照）であり、
異常ではない。PR run 全体の wall-clock は 13m12s（created_at 06:02:32 →
updated_at 06:15:44）。

**`smoke-e2e` が GREEN だったことが Slice B/C 設計全体の最重要な実地検証**
である: `validate` が Pages と同じ base-href
(`/smile_enjoy_story/`) でビルドした artifact を、base-href 対応させた
`e2e/scripts/static-server.js` 経由で実際に Playwright
(`founding-first-assignment.spec.ts` 3-seed サンプル,
`public-demo-fresh-start.spec.ts`, 各種 harness fixture spec) が
問題なく操作できることを実 CI 上で確認できた。ゲームコード・テストの
assertion は無変更のまま成功している。

`build`/`deploy`（Slice C が変更した第2 Flutter build 削除の直接検証）は、
`check-latest`/`build`/`deploy` が push/workflow_dispatch 限定という
既存ワークフロー設計上、pull_request イベントの CI では実行できない
（`check-latest` の stale-SHA guard は「対象 SHA が origin/main の実際の
tip であること」を要求するため、main 未 merge のコミットに対して
workflow_dispatch を手動実行しても `is_latest=false` となり同様に
skip される — これは意図された安全機構であり、本 PR 固有の問題ではない。
PR #151 の結果報告でも同様の制約が記録されている）。したがって
`build`/`deploy` ジョブの実行結果は、実際に `main` へ merge された後の
push トリガー run でのみ確認できる。本タスクでは「mainへの直接
commit禁止・自動merge禁止」のため、この最終確認は merge 後のフォロー
アップとして未確定のまま記録する（下記 remaining risk / unresolved
items 参照）。

## PERFORMANCE REPORT（実測値のみ）

### Before（直前の main push run, 本PRの変更を含まない旧ワークフロー）

参考として、本PR作成の直前（同日）に発生した最新の main push run
（GitHub Actions run #396, id `33719460784`, head_sha `8d510e6a`,
`Issue #148 Phase 1B.1 + 1B.2`）の実測値を「before」として採用した
（過去の参考値 #381 約24分54秒・#385 約15分07秒より新しく、同一リポジトリ・
同日の実行環境という条件が近いため、より公正な比較値と判断した）。

| job | 所要時間 | 内訳（旧ワークフロー） |
|---|---|---|
| `validate` | 10m57s（05:35:00→05:45:57） | flutter-action setup 59s + pub get 8s + analyze 11s + **test 8m45s** + build web 37s + upload/replay unit ~7s |
| `smoke-e2e` | 2m07s（05:45:57→05:48:04） | |
| `check-latest` | 8s（05:48:04→05:48:12） | |
| `replay-package` | 41s（05:48:04→05:48:45） | `build`と並行実行 |
| `build`（Pages, 旧＝2回目のFlutter build含む） | 1m48s（05:48:13→05:50:01） | flutter-action setup 59s + pub get 6s + **build web 35s** + replay fold-in/pages artifact ~8s |
| `deploy` | 17s（05:50:02→05:50:19） | |
| **push→deploy wall-clock** | **15m20s**（created_at 05:34:59 → deploy completed_at 05:50:19） | |

`build` ジョブが2回目の `flutter build web` のために費やしていた時間
（`flutter-action` セットアップ 59s + `pub get` 6s + `flutter build web`
35s = **1m40s**）が、Slice C により `build` ジョブの critical path から
削除される対象である。これは実測値（旧ワークフローの実行ログ）に基づく
「削除したステップの実測所要時間」であり、削減後の合計を推測して書いた
値ではない。

### After（本PR, pull_requestイベントで検証できた範囲の実測値）

| job | 所要時間 |
|---|---|
| `validate`（Pages base-hrefでのbuild込み） | 10m46s（06:02:50→06:13:36） |
| `smoke-e2e`（base-href対応static server経由） | 2m04s（06:13:39→06:15:43） |

`validate` に `--base-href` を追加したことによる所要時間の悪化は
確認されなかった（旧 10m57s → 新 10m46s、誤差の範囲内）。

### merge後に確定する値（未実測）

`build`/`deploy`（実際に第2 Flutter buildを省いた状態でのPages配信経路）
は、本PRが実際に `main` へ merge され push トリガーの run が実行される
まで実測できない。merge 後の同一構造の run で `build` ジョブの所要時間を
再測定し、上記 before の `build` 1m48s と比較することで、実際の
削減時間・削減率を確定する（見込みとしては、上記「削除対象の実測 1m40s」
がほぼそのまま `build` ジョブから、ひいては push→deploy wall-clock から
減る計算になるが、これは実測ではなく上記実測値からの算術であるため、
確定した「削減時間/削減率」としては merge 後に再測定するまで報告しない）。

## commit SHA（Slice A）

`dd590b8`（`docs(ci): audit Fast CI Web build duplication (SES-CI-SPEED-2 Slice A)`）

## FINAL REPORT

### BASE SHA

`e60dbe38c0eee05d12ba34a241373d3a9dfd1731`（タスク記載の CURRENT EXPECTED
MAIN と一致、`git rev-parse origin/main` で確認済み）

### FINAL HEAD SHA

`2f4a59bb00e2e5a26c355f7268df6d2a6ac442d4`（PR #155 head, このレポート更新
コミット自体は別途追記する）

### branch

`claude/web-build-dedup-ci-svlywe`

### Slice A/B/C/D の結果

- **Slice A（監査）**: 判定 A「安全に1回化可能」。base-href の差異は
  `web/index.html` の `<base href>` 1箇所のみで、他は全て相対パス参照。
  commit `dd590b8`。
- **Slice B（共有artifact化）**: `validate` の build を Pages と同じ
  `--base-href` に統一し、`e2e/scripts/static-server.js` を base-href
  対応化。commit `6d8deb2`。focused verification（YAML構文・tsc・
  replay-unit 112件）はローカルで完了、実 CI 検証は Slice D 実施。
- **Slice C（第2 build削除）**: `build`（Pages）ジョブから
  `flutter pub get`/`flutter build web` を削除し、`validate` の
  `build-web` artifact を download して再利用する構成に変更。
  commit `56880aa`。
- **Slice D（PR/CI検証）**: PR [#155](https://github.com/perusonao/smile_enjoy_story/pull/155)
  を作成し購読。`validate`/`smoke-e2e` は実 CI で GREEN
  （実測 10m46s / 2m04s）。`check-latest`/`build`/`deploy` は
  ワークフロー設計上 pull_request イベントでは実行されず（push/
  workflow_dispatch 限定 かつ stale-SHA guard の意図的な安全機構）、
  Slice C の直接的な実行検証（`build` ジョブの GREEN）は merge 後の
  push run でのみ確認できる状態のまま残っている。

### changed files

- `.github/workflows/e2e.yml`
- `e2e/scripts/static-server.js`
- `e2e/playwright.config.ts`
- `docs/reports/SES_CI-SPEED-2_Web-Build-Dedup_Result.md`（本レポート）

ゲームコード（`lib/`）・`web/index.html` を含む production 資産・save
schema・PR #136・Issue #148 Phase 1B には一切触れていない。

### before/after CI構造

```
[before]
push(main)
  validate  : analyze/test/build web(base-href "/")
    smoke-e2e
      check-latest
        build : pub get → build web(base-href "/repo/") ← 2回目のFlutter build
          deploy

[after]
push(main)
  validate  : analyze/test/build web(base-href "/repo/", Pages と共通)
    smoke-e2e (base-href対応 static server 経由でこのartifactをそのまま検証)
      check-latest
        build : validateのbuild-web artifactをdownloadして再利用（Flutter build なし）
          deploy
```

### tests / verification

- ローカル（Flutter SDK非搭載環境）: YAML構文チェック（python3 yaml）、
  `npx tsc --noEmit`、`npm run test:replay-unit`（112/112 pass）、
  `static-server.js` の base-path fallback / path-traversal / 後方互換を
  ダミー build dir に対する手動 HTTP リクエストで確認
- 実CI（PR #155, pull_request event, run #398）: `validate`
  （analyze/test/build web with Pages base-href）GREEN、`smoke-e2e`
  （3-seed founding-first-assignment 含む curated spec 一式、base-href
  対応 static server 経由）GREEN

### CI結果

- PR #155 run #398（head `2f4a59bb`）: `validate` success (10m46s) /
  `smoke-e2e` success (2m04s) / `check-latest`・`build`・`deploy`・
  `replay-package` は設計通り skipped（pull_request イベントのため）
- `build`/`deploy`（Slice C の直接検証）は merge 後の main push run で
  確認が必要（未実施・未実測。DO NOT: 自動merge禁止のため本セッションでは
  実施していない）

### performance実測

- Before（直前の main push run #396, head `8d510e6a`, 旧ワークフロー）:
  push→deploy wall-clock **15m20s**（`validate` 10m57s / `smoke-e2e`
  2m07s / `check-latest` 8s / `build` 1m48s(うち2回目のFlutter build
  関連ステップ実測 1m40s) / `deploy` 17s）
- After（PR #155, pull_requestイベントで検証できた範囲）: `validate`
  10m46s / `smoke-e2e` 2m04s（`validate`へのbase-href追加による有意な
  遅化なし）
- `build`/`deploy` を含む push→deploy 全体の after wall-clock、および
  削減時間・削減率の確定値: **未測定**（merge後のpush run待ち。推測値は
  本レポートに記載しない）
- 参考値（#381 約24分54秒、#385 約15分07秒）との比較: 直前の同日 main
  push run（#396, 15m20s）の方がより公正な比較対象と判断し、そちらを
  beforeとして採用した

### unresolved items

- `build`/`deploy` ジョブの実際の push-triggered GREEN 実行、および
  push→deploy wall-clock の削減時間・削減率の実測確定は merge 後の
  フォローアップとして残っている
- `e2e-heavy.yml`（週次フルリグレッション・WebKit）は本タスクの対象外で
  無変更のまま
- Issue #149 本文にある「テスト分類ごとの計測」「Tier運用ルール明文化」等は
  引き続き未着手（本タスクのスコープ外）

### rollback方法

`.github/workflows/e2e.yml` / `e2e/scripts/static-server.js` /
`e2e/playwright.config.ts` の3ファイルを、Slice B開始前のコミット
（`dd590b8`、Slice A完了時点）の内容に戻せば、変更前の「2回build」構成に
即座に復元できる。stale-SHA guard・Replay Viewer組み込み・
`e2e-heavy.yml`・ゲームコードはいずれの Slice でも変更していないため、
このrevertはCI構造のみに閉じる。GitHub操作としては本PRのrevert commit、
またはこの3ファイルのみを対象にした個別revertのいずれでも可能。

### PR URL

[https://github.com/perusonao/smile_enjoy_story/pull/155](https://github.com/perusonao/smile_enjoy_story/pull/155)

### MERGE READINESS

**B. READY WITH MINOR FOLLOW-UP**

理由: コード変更自体は安全性の前提（stale-SHA guard・base-href差異の範囲・
既存テストassertion無変更）を保った設計であり、PRで検証可能な範囲
（`validate`/`smoke-e2e`）は実CIでGREENを確認済み。ただし本タスクが
対象とする「第2 Flutter build削除」そのものの実行確認（`build`ジョブの
実CI GREEN）と、それに伴う実際の削減時間・削減率の実測は、ワークフローの
設計上 merge後のpush runでしか行えず、本セッションでは（自動merge禁止の
ため）未実施のまま残っている。これはコードの欠陥ではなく確認の未完了で
あり、"minor follow-up" として記録する。
