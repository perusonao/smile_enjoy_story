# SES_PWA-START-1 Result

Claude Code — PWA-START-1: iPhoneホーム画面起動先をPublic Demoへ修正

## 1. Root cause

`web/manifest.json` の `start_url` が `"."` になっていた。

Web App Manifest仕様上、`start_url` の相対値は **manifest.json自身のURL** を基準に解決される
（HTMLページ側の `<base href>` やアプリ内ルーティング状態は一切関与しない）。

- manifest.json の実URL: `https://perusonao.github.io/smile_enjoy_story/manifest.json`
- `start_url: "."` の解決結果: `https://perusonao.github.io/smile_enjoy_story/`
  （hashフラグメント無し）

一方 `lib/main.dart` はアプリ起動時に一度だけ `Uri.base`（＝ブラウザの現在地URL）を読み、
`lib/app/app_entry.dart` の `resolveAppExperience()` がそのフラグメントを見て
`#/public-demo-01` なら `AppExperience.publicDemo01`、フラグメントが無ければ
`AppExperience.development`（＝既存ゲーム「創業プロローグ」側）を選ぶ実装になっている
（Flutter Navigator 2.0 のルーティングではなく、起動時一回きりの静的な判定）。

iOS Safari の「ホーム画面に追加」は、追加操作をどのURLから行ったかに関わらず、
インストール後の起動時には `manifest.json` の `start_url` を優先して開く
（既に実機で確認済みの挙動と整合）。そのため `start_url` がフラグメント無しの
ルートURLを指している限り、Safariで `#/public-demo-01` を開いてからホーム画面に
追加しても、起動時には既存ゲーム側（development）が選ばれていた。

→ **仮説どおり。原因は `manifest.json` の `start_url` がPublic Demoのhashルートを
保持していなかったことであり、Flutter側のルーティングや `index.html` の base href、
GitHub Pagesのデプロイ設定には問題がなかった。**

## 2. Current start_url（修正前）

```json
"start_url": "."
```

## 3. Current scope（修正前）

`scope` フィールドは元々存在しない（未指定）。
Manifest仕様のデフォルトアルゴリズムでは、`scope` 未指定時は
「処理済み `start_url` のディレクトリ部分」がデフォルトscopeになる。
`start_url` がフラグメント付きに変わっても、パスのディレクトリ部分
（`/smile_enjoy_story/`）は変化しないため、デフォルトscopeの実効範囲は
修正前後で同一。

## 4. Flutter routing

- Navigator 2.0 / go_router 等は不使用。
- `lib/main.dart` の `main()` が起動時に一度だけ `Uri.base` を読み、
  `resolveAppExperience(Uri.base)`（`lib/app/app_entry.dart`）でURLの
  `#`以降（fragment）を見て `AppExperience` を決定する。
  - `fragment` が `public-demo-01` → `AppExperience.publicDemo01`
  - それ以外（空含む）→ `AppExperience.development`
- 決定した `AppExperience` は `SesApp`/`_GameRoot` に渡り、
  `publicDemo01` なら `PublicDemo01PlaceholderScreen` を、それ以外なら
  既存ゲームのUIツリー（`StartChoiceScreen` 等）を表示する。
- 起動後にURLのfragmentが変わっても再判定は行われない
  （＝ページロード時点のURLで一度だけ決まる設計）。

## 5. GitHub Pagesとの関係

- デプロイは `.github/workflows/e2e.yml` 内の `build`/`deploy` ジョブで実施。
- ビルドコマンド:
  ```
  flutter build web --release \
    --base-href "/${{ github.event.repository.name }}/" \
    --no-web-resources-cdn
  ```
  → `--base-href "/smile_enjoy_story/"`。`web/index.html` の
  `$FLUTTER_BASE_HREF` プレースホルダーがこの値に置換される。
- `web/manifest.json` はビルド時にテンプレート置換されず、
  そのまま `build/web/manifest.json` にコピーされる
  （`start_url` に repo 名や base-href を自動注入する仕組みは無い）。
- `actions/upload-pages-artifact` → `actions/deploy-pages` で
  `build/web` がそのまま `https://perusonao.github.io/smile_enjoy_story/` 配下に公開される。

## 6. Changed files

- `web/manifest.json` — 1行のみ変更（`start_url`）。

```diff
-    "start_url": ".",
+    "start_url": "./#/public-demo-01",
```

他のファイル（ゲームコード、E2E helper、WebKit関連、APP-ICON画像、
`web/index.html`、deploy workflow）は一切変更していない。

## 7. New start_url（修正後）

```json
"start_url": "./#/public-demo-01"
```

相対値のまま維持（`.` → `./#/public-demo-01`）。manifest.jsonのURLを基準に
解決されるため、repo名やbase-hrefをmanifest内にハードコードせずに済み、
既存の「相対start_url」方針を踏襲した最小変更。

解決結果（GitHub Pages上）:
`https://perusonao.github.io/smile_enjoy_story/#/public-demo-01`

`scope` は今回追加していない（未指定のまま）。理由は4節の通り、
デフォルトscope計算の実効範囲が変わらないため、追加は不要な変更面積の
拡大になると判断した。

## 8. root URLへの影響

**影響なし。** Safari等で直接
`https://perusonao.github.io/smile_enjoy_story/`（フラグメント無し）を
開いた場合は、従来どおり `resolveAppExperience` が development 扱いとなり、
既存ゲーム（創業プロローグ）が起動する。Chromiumでの実機検証でも
スタート選択画面（初心者モード/自由モード）が表示されることを確認済み
（10節参照）。

## 9. Public Demo URLへの影響

**影響なし（正常動作を維持）。**
`https://perusonao.github.io/smile_enjoy_story/#/public-demo-01` への
直接アクセスは従来どおりPublic Demo 0.1が起動することをChromiumで確認。

加えて、`manifest.json` を実際に `fetch` して `start_url` を
`new URL(start_url, manifestUrl)` でPWA起動時と同じ方法で解決し、
そのURLへ実際にナビゲートするシミュレーションを行い、Public Demo 0.1の
画面（「S.E.S. Public Demo 0.1」ヘッダー、佐藤健/鈴木葵の一覧等）が
表示されることを確認した（10節参照）。

## 10. analyze / test / build / diff-check 結果

環境にFlutter SDKが無かったため、CI固定バージョン（`flutter-version: "3.44.9"`,
stable）を一時的にダウンロードし、CIと同じ手順で検証した。

- `flutter analyze` → **No issues found!**
- `flutter test` → **All tests passed!**（673件）
- `flutter build web --release --base-href "/smile_enjoy_story/" --no-web-resources-cdn`
  → **成功**（`build/web` 生成）
  - `build/web/manifest.json` の `start_url` が `"./#/public-demo-01"` に
    なっていることを確認。
  - `build/web/index.html` の `<base href="/smile_enjoy_story/">` が
    正しく置換されていることを確認。
- `git diff --check` → **問題なし（空白/改行エラー無し）**
- Chromium（Playwright、`/opt/pw-browsers` 同梱バージョン）で `build/web` を
  `/smile_enjoy_story/` パス配下に配置してローカルHTTPサーバーで検証:
  - `/smile_enjoy_story/`（root URL）→ 既存ゲームのスタート選択画面を表示（スクリーンショット確認）
  - `/smile_enjoy_story/#/public-demo-01`（直接アクセス）→ Public Demo 0.1を表示（スクリーンショット確認）
  - `manifest.json` を実際にfetchして `start_url` をPWA起動と同じ方法で解決し
    ナビゲート → Public Demo 0.1を表示（スクリーンショット確認、＝実機PWA起動の再現）

## 11. Commit / remote HEAD

- ベースブランチ: `origin/main` = `40d2a1aca6d69e8e73920c785eca910e979c70f1`
  （feat(web): add S.E.S. app icon (#56)）
- 作業ブランチ: `claude/public-demo-pwa-start-route-rhqk6a`
  （`origin/main` から作成。過去に本ブランチへ積まれていたコミットは
  main側に既に統合済みだったため、`origin/main` から作り直した）
- 本タスクの変更: `web/manifest.json` の1行差分をコミットし
  `origin/claude/public-demo-pwa-start-route-rhqk6a` へpush。
  （コミットハッシュはpush後にこのファイル下部へ追記——コミットログ参照）

## 12. iPhone再確認手順

修正版デプロイ後、以下の手順で実機確認すること
（iOS Safari/PWAはmanifest等をキャッシュする可能性があるため）:

1. iPhoneのホーム画面から既存のS.E.S.アイコンを一度削除する。
2. Safariで `https://perusonao.github.io/smile_enjoy_story/#/public-demo-01`
   を開く（キャッシュが疑わしい場合はSafariの「履歴とWebサイトデータを消去」、
   またはこのサイトのWebサイトデータ削除も検討）。
3. 共有メニューから「ホーム画面に追加」で新しいアイコンを追加する。
4. 新しいホーム画面アイコンからS.E.S.を起動し、Public Demo 0.1
   （「S.E.S. Public Demo 0.1」ヘッダー画面）が表示されることを確認する。
5. 念のため、SafariでルートURL
   （`https://perusonao.github.io/smile_enjoy_story/`）に直接アクセスし、
   従来どおり既存ゲーム（創業プロローグ/スタート選択画面）が表示されることも
   確認する。

## Not done / STOP条件について

原因は仮説どおり `manifest.json` の `start_url` であり、Flutterルーティングの
大規模変更や `scope` の追加・変更は不要と判断したため、STOPせず最小修正のみ
実施した。PR作成・マージ・本番デプロイは指示どおり未実施。
