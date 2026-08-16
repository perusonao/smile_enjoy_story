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
import { hasText, parseAriaSnapshot } from '../helpers/game-state';

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
});
