# SES Issue #133 Implementation Result

## Executive Summary

Issue #133 の Public Demo 0.1 における7月デッドロックを解消した。賞与「なし / ¥0」は、pending revenue 入金後に通常月次費用で現預金が負になっても、他月と同じ月次精算方針で7月を完了できる。有料賞与は、月次費用と賞与を合わせた支払後現預金が負になる場合、Domain authority が選択・精算を拒否する。

あわせて、Public Demoだけに確認付きの「4月からやり直す」を追加した。既存の `PublicDemoAggregate.initial()` と `PublicDemoSaveService` を再利用し、通常ゲームの保存領域には触れない。

- Branch: `codex/issue-133-july-deadlock-reset`
- Base: `7488ff176be86cb829014ea361414837d7b89340` (`origin/main`)
- Scope: Public Demo 0.1 only
- Pull request: not created, as requested

## Root Cause

7月だけ、pending revenue 入金後のcashから月次費用と夏季賞与を同時に差し引いた projected cash が負なら、賞与判断を含む月末処理全体を拒否していた。UIも独自に同じ projected cash / enabled 判定を持っていたため、月次費用だけで負になる報告fixtureでは「なし / ¥0」まで無効化された。

他月では給与・固定費によってcashが負になっても月次処理は進むため、7月固有の判定が必須タスクを完了不能にし、7月から8月へのP0 deadlockを起こしていた。

## Changes

- 夏季賞与の金額、支払後現預金、適用可否、eligibilityを返すpure Domain previewを追加した。
- July monthly close facadeに、pending revenueを含めた単一preview入口を追加した。
- 賞与なしは常にeligible、有料賞与は完全な支払後cashが負ならinsufficient cashとした。
- 不適格な有料賞与closeは、AR・成長・月次費用を一切確定しないatomic rejectionとした。
- 賞与ダイアログから独自の金額・cash・enabled計算を削除し、Domain previewだけを表示に使用した。
- Public Demo画面へ明示的な「テスト用操作」カードと、確認付き「4月からやり直す」を追加した。
- Domain、Widget、persistence/reset、Playwrightのregression testsを追加・更新した。

## July Settlement Authority

`PublicDemoSummerBonusPayment.preview()` が、bonus amount、available cash、monthly expenses、projected cash、eligibilityを決定する。`PublicDemoMonthlyClose.previewJuly()` はimmutableな一時stateにpending revenue settlementを適用してから同previewへ委譲するため、UIと実際のcloseが同じ金額・可否を参照する。

実closeはpreviewで可否を確認した後にだけ、pending revenue入金と月次精算を確定する。preview処理はstateを保存・変更せず、会計記録を作らない。これにより、表示とDomain validationの二重実装、およびreject時の部分入金・部分控除を防いだ。

## Before / After Behavior

| Case | Before | After |
|---|---|---|
| 賞与なし、月次費用後cash < 0 | UI disabled / July close拒否 | eligible、通常の月次精算を確定してAugustへ |
| 有料賞与、全支払後cash < 0 | UIとDomainの別判定。旧Domainは暗黙に¥0へ変換する経路あり | UI disabled、Domainもatomic reject、選択を暗黙変更しない |
| 同じcloseを再実行 | deadlock修正時に二重処理のリスク | month/paid guardによりexact no-op |

## ¥-210,000 Regression

次のfixtureをDomainとWidgetで固定した。

```text
cash                         ¥860,000
pending revenue             +¥500,000
monthly expenses          -¥1,570,000
summer bonus none                 ¥0
-----------------------------------
resulting cash             -¥210,000
```

結果はJulyからAugustへ進み、`summerBonusPaidAmount == 0`、cashは`-210000`となる。最新monthly cash flowには、入金`500000`、給与+固定費`1570000`、賞与`0`が一度だけ記録される。同じcloseを再実行するとstate、cash、pending revenue、cash-flow objectは変わらない。

同fixtureの0.5か月・1か月プランは、どちらもstateを変更せずrejectされる。

## Restart-to-April Implementation

Public Demo画面内にamber色の「テスト用操作」カードを追加し、「4月からやり直す」を配置した。操作時は破壊的変更の確認dialogを表示し、キャンセルできる。

confirm時は既存のrestart authorityを通し、Public Demo保存だけをclearしてから`PublicDemoAggregate.initial()`を再生成する。monthだけ、またはUI側の個別fieldを手動resetしていない。再開後はYear 1 Aprilで、canonicalなstateとworkflow（初期社員、応募者、案件、workflow flagsを含む）へ戻り、最初の`SkillSheetを確認`から操作できる。

## Persistence / Save Isolation

latest mainには既にPublic Demo専用のaggregateとsave serviceが存在したため、新しいrepositoryや通常`GameState`用`SaveService`への接続は追加していない。

- Canonical fresh state: `PublicDemoAggregate.initial()`
- Public Demo storage authority: `PublicDemoSaveService`
- Normal game storage: unchanged

テストでは有効なnormal game saveを作成し、Public Demo restart前後のraw保存文字列がbyte-for-byteで同一であること、restart後もnormal saveをloadできること、Public Demo keyだけが削除されたことを確認した。

## Tests Added

- Domain
  - Issue #133の`860000 + 500000 - 1570000 = -210000` none settlement
  - 0.5か月・1か月のatomic rejection
  - duplicate closeのexact no-op
  - preview eligibilityとprojected cash
  - Revenueによって有料賞与が支払可能になる既存timing
- Widget
  - exact fixtureで「なし」がenabled、有料2案がdisabled
  - `-¥210,000`表示、none選択、July close、August到達
- Reset / persistence
  - Julyからconfirmしてcanonical April state/workflowへ戻る
  - 複数回resetで同一canonical state
  - cancelでsession不変
  - normal game saveがbyte-for-byte不変
- E2E
  - real UIでApril → May → June → July → bonus none → August
  - restart cancelとconfirm、canonical April actionの再表示
  - 既存Playwright profileのPixel 7 mobile ChromiumとiPhone 14 mobile WebKit

## Verification Results

| Verification | Result | Evidence |
|---|---|---|
| Focused Flutter tests | PASS | 84 tests passed |
| Full `flutter test --no-pub --reporter compact` | PASS | 1,317 tests passed, 7m08s |
| `flutter analyze --no-pub` | PASS | No issues found, 9.5s |
| `flutter build web --release --no-pub --no-web-resources-cdn` | PASS | `build/web` generated, 69.1s |
| `npx tsc --noEmit` | PASS | no diagnostics |
| mobile Chromium E2E | PASS | 1 passed, final combined run 29.5s test duration |
| mobile WebKit E2E | PASS | 1 passed, final combined run 46.0s test duration |
| Combined browser run | PASS | 2 passed, 49.9s |
| `git diff --check` | PASS | no whitespace errors |

Full Flutter suite中に既存の意図的な破損JPEG fallback test由来のshell warningが出たが、test failureはなく1,317件すべて完了した。今回の変更起因または既存CI failureは観測していない。

## Changed Files

- `lib/game/public_demo/public_demo_aggregate.dart`
- `lib/game/public_demo/public_demo_monthly_close.dart`
- `lib/game/public_demo/public_demo_summer_bonus_payment.dart`
- `lib/ui/public_demo/public_demo_01_placeholder_screen.dart`
- `lib/ui/public_demo/public_demo_summer_bonus_dialog.dart`
- `test/game/public_demo/public_demo_financial_status_test.dart`
- `test/game/public_demo/public_demo_monthly_close_revenue_test.dart`
- `test/game/public_demo/public_demo_monthly_close_test.dart`
- `test/game/public_demo/public_demo_summer_bonus_payment_test.dart`
- `test/ui/public_demo/public_demo_01_persistence_test.dart`
- `test/ui/public_demo/public_demo_summer_bonus_dialog_test.dart`
- `e2e/tests/public-demo-july-restart.spec.ts`
- `docs/reports/SES_ISSUE-133_Implementation_Result.md`

## Diff Review

- latest `origin/main`から専用branch/worktreeを作成し、元のdirty working treeを取り込んでいない。
- normal gameの`GameEngine.payBonus`、Issue #14、initial cash、revenue、monthly expense、month guardは変更していない。
- UIだけをenabledにせず、close authorityも同じeligibilityでrejectする。
- cash clamp、retry、skip、sleep、timeout延長、assertion弱体化は追加していない。
- rejectionは元stateを返し、eligible closeだけがAR・expense・bonus・month transitionを記録する。
- `git diff --check`はPASSした。

## Risks / Remaining Issues

- E2Eの通常fresh-start routeでは報告fixtureのcashを人工注入していないため、`-¥210,000`という厳密な値はDomain/Widget testsで検証し、ブラウザでは実際の通常操作によるJuly → none → Augustとrestart smokeを検証している。
- 「テスト用操作」は要件どおりPublic Demo画面に常時表示される。normal gameのroute/widgetには追加していない。
- 新しいpersistence architectureは追加していない。将来Public Demo session authorityが変更される場合は、restartもそのcanonical factoryへ合わせる必要がある。

## CI Readiness

Static analysis、focused/full Flutter tests、web release build、TypeScript check、mobile Chromium/WebKitの対象E2EがすべてPASSした。既存CI設定のskip/retry/timeoutは変更していない。CIへ送れる状態である。

## Merge Readiness

READY。Issue #133の要求範囲を満たし、ローカル検証はすべてPASSしている。PRは依頼どおり未作成で、ChatGPTによる実装レビュー後に作成判断できる。
