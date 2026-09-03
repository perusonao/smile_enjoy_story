# SES-TEST-STRATEGY-1 — CI Optimization (merge→deploy 重複排除) — Implementation Result

## Objective

Issue #149 (TEST-STRATEGY-1) が指摘する「First Fun Year の開発速度を落とさない
テスト実行戦略」のうち、最優先事項として明示された具体例を対処した:

PR #150 merge 後の main Fast CI (`.github/workflows/e2e.yml`) で、`validate`
ジョブが `flutter analyze` / `flutter test` / `flutter build web --release`
を実施した**同一SHA**に対し、`build` ジョブ（Pages 用ビルド）が
`flutter analyze` / `flutter test` を**もう一度**実施していた。

この監査タスクは READ-ONLY な広範囲監査ではなく、Issue 本文が「最優先」と
明示した具体的重複（merge→deploy 経路の同一SHA重複実行）に絞った修正タスクと
して実施した。テスト件数そのものを削る変更は行っていない。

## Audited main SHA

`fec518aa556973733b5b867055d9b374adb981a7`
(`Merge pull request #150 from perusonao/claude/issue-147-home-ui-3a`)

作業ブランチ `claude/ses-ci-optimization-i4krdw` はこの SHA (origin/main の
最新 tip) から作成した。ブランチの旧内容はゲームコア初期実装
(`f4ca78f`, Phase 0A/0B) を指す stale なコミットで、main の祖先ではあったが
本タスクに必要な `.github/workflows/` や `AGENTS.md` を含んでいなかったため、
`git checkout -B claude/ses-ci-optimization-i4krdw origin/main` で最新化して
から着手した（ブランチ固有のコミットは存在しなかったため、作業の破棄は
発生していない）。

## 現在のCI/deploy構造（変更前）

リポジトリの `.github/workflows/` には5ファイルが存在する:

| ファイル | トリガー | 役割 |
|---|---|---|
| `e2e.yml` (Fast CI) | `pull_request`/`push(main)`/`workflow_dispatch` | PRの必須ゲート + main merge後のPages deploy |
| `e2e-heavy.yml` (Heavy E2E) | `workflow_dispatch` + 週次schedule | 全Playwrightスイート(WebKit込み)。deployには一切接続しない |
| `public-demo-validation.yml` | `pull_request(main)` かつ `lib/game/public_demo/**` 等のpath filter | Public Demo領域限定の追加検証 |
| `public-demo-preview.yml` | 同上 path filter | Public Demo単体プレビューbuildのartifact化 |
| `public-demo-ux3-order-assignment-patch.yml` | `workflow_dispatch` のみ、特定の旧ブランチ固定 | 過去の一回限りパッチ用途、通常のPR/mainフローには関与しない |

`e2e.yml` (Fast CI) のジョブ構成（変更前）:

```
pull_request / push(main) / workflow_dispatch
  └─ validate      : flutter pub get → analyze → test
                      → build web --release --no-web-resources-cdn (base-hrefなし)
                      → upload build-web artifact
                      → npm ci → replay unit tests
       └─ smoke-e2e : validate の build-web artifact を download
                      → Playwright (mobile-chromium, curated smoke spec)
             ├─ replay-package (push限定, if: always())
             └─ check-latest    (push/workflow_dispatch限定。origin/main の
                                  現在tipと github.sha を比較する
                                  stale-run guard。target_sha を output)
                   └─ build      : checkout target_sha
                                    → flutter pub get
                                    → flutter analyze          ← 重複①
                                    → flutter test              ← 重複②
                                    → build web --release --base-href "/repo/" (Pages用)
                                    → e2e-replay-package を fold-in
                                    → upload-pages-artifact
                         └─ deploy : check-latest を再実行 → deploy-pages
```

`build` は `needs: [smoke-e2e, check-latest]` であり、
`if: needs.check-latest.outputs.is_latest == 'true'` のときのみ実行される。
`check-latest` は `e2e/scripts/check-latest-main.mjs` で
`target_sha`(= このワークフロー実行の `github.sha`) と
`git ls-remote origin refs/heads/main` の実際の tip を比較し、
**一致した場合のみ** `target_sha` をそのまま返す(スクリプトは値を書き換えない、
`isLatestCommit` は単純な文字列比較)。つまり `build` が実行される時点で
`build` がcheckoutするSHAは、`validate`/`smoke-e2e` が検証したSHAと
**保証付きで同一** である。

## ボトルネック

`build` ジョブの `flutter analyze` と `flutter test` は、`validate` ジョブが
**同一コミット**に対してすでに実行し成功させた検証を、ジョブ依存チェーン
(`build` → `check-latest` → `smoke-e2e` → `validate`)を経てもう一度
実行しているだけで、追加のカバレッジを一切生んでいなかった。

`flutter build web --release` 自体は `validate` と `build` で
**意図的に異なる出力**（`validate`: base-hrefなし・smoke-e2eのローカル
静的サーバ用 / `build`: `--base-href "/${{ repository.name }}/"` の
Pages配信用）のため単純な重複ではなく、artifactをそのまま使い回すことは
できない（Flutter webのbase-hrefはビルド成果物内に焼き込まれ、
`index.html`/bootstrap JS等の書き換えが必要になり、`e2e/playwright.config.ts`
のローカルサーバも root 配信前提のため、安全に統合するには E2E ローカル
配信の仕組み自体を変更する必要があり、リスクとスコープが本タスクの
「安全で単純な改善」の範囲を超える）。したがって今回は
**analyze/testの重複除去のみ**を対象とし、buildの二重実行そのものは
意図的に残した（下記「未解決事項」参照）。

## 変更内容

`.github/workflows/e2e.yml` の `build` ジョブから `Analyze`
(`flutter analyze`) と `Test` (`flutter test`) の2ステップを削除した。
削除の安全性は次の事実で担保されている:

- `build` は `check-latest.outputs.is_latest == 'true'` のときのみ実行される
- `check-latest` は `target_sha`(= このrunのgithub.sha) が
  origin/mainの実際のtipと一致する場合のみ `is_latest=true` を返す
- `build` は `needs.check-latest.outputs.target_sha` をcheckoutする
- `build` は `needs: [smoke-e2e, check-latest]` であり、`smoke-e2e` は
  `needs: validate` — つまり `build` が走る時点で、**同一SHA**に対する
  `validate` の `flutter analyze`/`flutter test` はすでに成功している

このため `build` 内での再実行は、状態が異なる可能性のない
確定済み同一コミットへの検証再実行であり、除去しても検出できていた不具合が
見逃されるようになることはない。

ワークフロー冒頭のジョブ一覧コメントと、削除箇所には根拠を示すインライン
コメントを追加した。

## 削除した重複処理

- `build` ジョブ内 `flutter analyze`（`validate` ジョブと同一SHA・同一操作）
- `build` ジョブ内 `flutter test`（`validate` ジョブと同一SHA・同一操作、
  リポジトリ全体の `flutter test` フルスイート）

## 維持した安全gate

- `validate` ジョブの `flutter analyze` / `flutter test` / build / replay
  unit tests は変更なし（PR/mainの必須ゲートとしてそのまま維持）
- `smoke-e2e` の curated Playwright spec 一覧は変更なし
  （E2Eを「UI文言・レイアウト変更の普遍的gate」にする方向の変更は行っていない）
- `check-latest` の stale-run guard（`build` 直前・`deploy` 直前の
  二重チェック、SES-CI-002 が要求する構造）は無変更
- `build` の `flutter build web --release`（Pages用ビルド）自体は削除・
  簡略化していない。First Fun Year の進行不能検出テスト
  (`founding-first-assignment.spec.ts` 等)を含む `smoke-e2e` の内容も無変更
- `e2e-heavy.yml`（週次フルリグレッション・WebKit・年間ルート・Recovery）は
  無変更。replay viewer 関連 (`replay-package`/`build`ジョブの
  fold-in ロジック)も無変更

## 変更ファイル

- `.github/workflows/e2e.yml`（`build` ジョブから重複した
  analyze/testステップを削除し、根拠コメントを追加。ジョブ本数・トリガー・
  権限・concurrency設定は無変更）

ゲームロジック/UI/save/domainのファイルは一切変更していない。

## 実行した検証

- `python3 -c "import yaml; yaml.safe_load(open('.github/workflows/e2e.yml'))"`
  でYAML構文の妥当性を確認（パース成功、既存6ジョブ
  `validate/smoke-e2e/replay-package/check-latest/build/deploy` が
  変更後も揃っていることを確認）
- `build` ジョブのステップ列を変更後YAMLから抽出し、
  `checkout → flutter-action → pub get → Build web (release) →
  Download e2e-replay-package → ...` の順に `Analyze`/`Test` が
  存在しないことを直接確認
- `build`/`deploy`/`check-latest` の `needs`/`if` 条件、および
  `e2e/scripts/check-latest-main.mjs` の実装（`isLatestCommit` が
  文字列一致のみで target_sha を書き換えない）を読み、
  「`build` 実行時点のSHAは常に `validate` が検証したSHAと同一」という
  安全性の前提をコード上で確認した
- 本セッションの実行環境に Flutter SDK が存在しないため、
  `flutter analyze`/`flutter test` 自体のローカル再実行はできなかった。
  ただし本変更はワークフローYAMLのみでDart/テストコードに触れていないため、
  実際の analyze/test 結果への影響はなく、push後のFast CI実行（`validate`
  ジョブ、および `build` ジョブでの `flutter build web` 単体成功）で
  最終確認できる

## merge→deployの期待短縮効果

main への push（PR merge）1回あたり、`build` ジョブから
リポジトリ全体の `flutter analyze` 1回 + `flutter test` フルスイート
（1300件超, Issue #149本文より）1回分の実行時間が消える。

- 変更前 critical path: `validate`(analyze+test+build) →
  `smoke-e2e` → `check-latest` → `build`(**analyze+test**+build) → `deploy`
- 変更後 critical path: `validate`(analyze+test+build) →
  `smoke-e2e` → `check-latest` → `build`(build のみ) → `deploy`

`build` ジョブは `validate`/`smoke-e2e` の完了を待ってから開始する直列区間
であるため、ここで削れた analyze+test の時間はそのまま
merge→deploy のwall-clock短縮に直結する。具体的な秒数は環境依存のため
本レポートでは測定していないが、リポジトリ全体の `flutter test`
フルスイートを1回分（analyze込み）まるごと直列パスから除去する変更である。

## 未解決事項

- `build` ジョブの `flutter build web --release`（Pages用、base-href付き）
  自体は `validate` ジョブのbuildと重複したまま残っている。安全に統合する
  には（a) Flutter webのbase-hrefをビルド後に書き換える処理を追加するか、
  (b) `e2e/playwright.config.ts` のローカル配信をbase-href付きパスに
  対応させるかのいずれかが必要で、いずれもE2Eインフラ側の変更を伴い
  本タスクの「安全で単純な改善」のスコープを超えると判断し、今回は
  見送った。着手する場合はIssue #149の完了条件にある
  「削除/統合候補は根拠付きで別Issue化」に従い、別Issueとして切り出すことを
  推奨する
- `public-demo-validation.yml` / `public-demo-preview.yml` は
  `lib/game/public_demo/**` 等に触れるPRで `e2e.yml` の `validate` と並行して
  独自にanalyze(範囲限定)/test(範囲限定)/build web を実行しており、対象PRに
  限れば追加のCIジョブ本数増加要因になっている。ただし今回報告された
  「同一SHAでのFlutter test/build重複」＝merge→deploy直列パス上の重複とは
  性質が異なる（並行実行される別ジョブであり、merge→deploy待ち時間には
  直接効かない）ため、本タスクのスコープ外として変更していない。改善候補と
  して記録するに留める
- Issue #149本文にある「テスト分類(Domain/Engine/Presentation/...)ごとの
  件数・所要時間計測」「Tier1/2/3の運用ルール明文化」などの調査タスクは、
  今回の「最優先の重複改善」には含めておらず、未着手のまま残っている

## commit SHA

（push後に別コミットで記録する）

## push状態

（push後にここへ記録する）

## PR番号

（PR作成後にここへ記録する）

## merge readiness

CI/E2EワークフローのYAML変更のみで、ゲームロジック/UI/save/domainには
触れていない。変更は `build` ジョブから重複した2ステップを削除しただけの
縮小差分であり、既存の安全gate（`validate`の全検証、`smoke-e2e`の
curated E2E、`check-latest`の二重stale guard、`e2e-heavy.yml`の週次フル
リグレッション）はすべて無変更で維持している。実際の削除効果と
YAML妥当性はpush後のFast CI実行（`validate`/`smoke-e2e`/`build`/`deploy`の
成功）で最終確認できる状態であり、レビュー観点は「`build`
実行時点でのSHA同一性の前提が正しいか」（本レポートの該当節を参照）に
絞られる。
