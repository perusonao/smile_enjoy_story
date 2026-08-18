// Unit-level checks for parseAriaSnapshot() — pure-function tests, no
// browser needed (same pattern as artifacts.allowlist.spec.ts). Covers a
// real bug found while investigating Playable 0.4C.4's first-assignment
// celebration screen: a named/quoted accessibility node that itself has
// children (Playwright prints it as `- group "...":` followed by indented
// child lines) was silently dropped in full — including whatever headline
// text it carried — because the regex had no case for a trailing `:` after
// a quoted name. This is exactly what Flutter Web produces when several
// Text widgets + a button get merged into one semantics node, which
// FirstContractCelebration's richer card layout newly triggers.
import { test, expect } from '@playwright/test';
import { enabledDialogButton, firstEnabledDialogButton, hasText, parseAriaSnapshot } from '../helpers/game-state';

test.describe('parseAriaSnapshot', () => {
  test('a plain quoted button line is parsed as before', () => {
    const snap = parseAriaSnapshot('- button "この方法で募集する"');
    expect(snap.buttons).toEqual([{ name: 'この方法で募集する', enabled: true }]);
    expect(snap.texts).toEqual([]);
  });

  test('a disabled button keeps its [disabled] annotation', () => {
    const snap = parseAriaSnapshot('- button "面接する" [disabled]');
    expect(snap.buttons).toEqual([{ name: '面接する', enabled: false }]);
  });

  test('a heading with a [level=N] annotation is still parsed (regression)', () => {
    const snap = parseAriaSnapshot('- heading "中村 翔太との面接" [level=2]');
    expect(snap.texts).toEqual(['中村 翔太との面接']);
  });

  test('a named group with children (trailing ":") keeps its own name and the nested button (regression)', () => {
    const raw = [
      '- group "🎉 初案件参画！ FIRST CONTRACT 田中 亮 さんが参画します。":',
      '  - button "経営を始める"',
    ].join('\n');
    const snap = parseAriaSnapshot(raw);
    expect(hasText(snap, '初案件参画')).toBe(true);
    expect(snap.buttons).toEqual([{ name: '経営を始める', enabled: true }]);
  });

  test('a disabled node with both [disabled] and a trailing ":" (children) still parses', () => {
    const raw = '- group "案内" [disabled]:';
    const snap = parseAriaSnapshot(raw);
    expect(snap.texts).toEqual(['案内']);
  });

  test('the always-excluded chrome buttons stay excluded regardless of a trailing ":"', () => {
    const raw = ['- button "最初からやり直す":', '  - text: dummy nested content'].join('\n');
    const snap = parseAriaSnapshot(raw);
    expect(snap.buttons).toEqual([]);
  });

  test('an unparseable line is skipped, not thrown', () => {
    const snap = parseAriaSnapshot('- this is not a valid aria line at all {{{');
    expect(snap.texts).toEqual([]);
    expect(snap.buttons).toEqual([]);
  });

  // Home layout整理 follow-up (PR #22 root cause): a real, on-CI Chromium
  // regression, reproduced locally, root-caused via a real Playwright
  // trace. `_HeroTaskCard`'s Home CTA can read exactly "採用を見る" —
  // the same text `founding_dialogs.dart`'s own `recruitmentUnlockCelebration`
  // dialog button uses — and `beginner-mode-player.ts`/the two `*.spec.ts`
  // drivers' CLOSE-list logic used to match on that text alone anywhere on
  // screen, misidentifying the Home CTA as a dismissible dialog and
  // clicking it mid week-advance loop. These pin down the fix at the
  // parser level: a button only counts as dialog-scoped when it's actually
  // nested under a `dialog`/`alertdialog` a11y node.
  test('a button outside any dialog is not dialog-scoped, even when its name matches a known dialog CTA (regression)', () => {
    const raw = [
      '- button "次の週へ (Week 13 → 14)"',
      '- button "採用を見る"', // _HeroTaskCard's own Home CTA — no dialog around it
    ].join('\n');
    const snap = parseAriaSnapshot(raw);
    expect(snap.buttons).toEqual([
      { name: '次の週へ (Week 13 → 14)', enabled: true },
      { name: '採用を見る', enabled: true },
    ]);
    expect(snap.dialogButtonNames).toEqual([]);
    expect(enabledDialogButton(snap, '採用を見る')).toBeUndefined();
    expect(firstEnabledDialogButton(snap, ['採用を見る', 'OK'])).toBeUndefined();
  });

  test('a same-named button genuinely inside a dialog/alertdialog is dialog-scoped', () => {
    const raw = [
      '- button "次の週へ (Week 13 → 14)"', // still on screen, behind the dialog
      '- alertdialog "🎉 新機能解放: 採用":',
      '  - text: 会社を拡大するため、新しいエンジニアを採用できるようになりました。',
      '  - button "採用を見る"',
    ].join('\n');
    const snap = parseAriaSnapshot(raw);
    expect(snap.dialogButtonNames).toEqual(['採用を見る']);
    expect(enabledDialogButton(snap, '採用を見る')).toEqual({ name: '採用を見る', enabled: true });
    expect(firstEnabledDialogButton(snap, ['採用を見る', 'OK'])?.name).toBe('採用を見る');
  });

  test('dialog scope closes once indentation returns to (or below) the dialog line\'s own level', () => {
    const raw = [
      '- alertdialog "確認":',
      '  - button "OK"',
      '- button "採用を見る"', // a sibling of the dialog, not a child — not scoped
    ].join('\n');
    const snap = parseAriaSnapshot(raw);
    expect(snap.dialogButtonNames).toEqual(['OK']);
    expect(enabledDialogButton(snap, '採用を見る')).toBeUndefined();
  });

  test('a disabled dialog-scoped button is not returned as an actionable close candidate', () => {
    const raw = ['- dialog "確認":', '  - button "OK" [disabled]'].join('\n');
    const snap = parseAriaSnapshot(raw);
    expect(snap.dialogButtonNames).toEqual(['OK']);
    expect(enabledDialogButton(snap, 'OK')).toBeUndefined();
  });
});
