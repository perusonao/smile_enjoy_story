// Phase 3A UX review (P1-1): money figures in play videos showed the yen
// sign rendering as an unrelated/odd glyph. Root cause: the bundled
// NotoSansJP subset font (tool/generate_font_subset.sh) had no glyph for
// U+00A5 (¥) at all — its character-collection scan only kept a *source*
// character when `ord(ch) > 0x2000`, which silently excludes the literal ¥
// (165) `lib/ui/theme.dart`'s formatYen() and several GameLogEntry messages
// use, and none of the scan's fixed safety-margin Unicode ranges covered
// Latin-1 Supplement either. Fixed by adding that range to the script and
// regenerating the two .woff2 assets (see git history for this file).
//
// This is deliberately a plain string-content test, not a golden/screenshot
// comparison (§ the brief's own instruction) — it can't verify the *font
// asset* has the glyph (that's covered by the regenerated .woff2 files
// themselves plus a manual/CI visual check), but it does lock down that
// every money-figure string in the game consistently uses the one correct
// codepoint, so a future edit can't reintroduce a different/wrong character
// by accident.
import 'package:flutter_test/flutter_test.dart';
import 'package:smile_enjoy_story/game/game.dart';
import 'package:smile_enjoy_story/ui/theme.dart';

/// U+00A5 YEN SIGN — the one currency codepoint this game uses. Compared by
/// codepoint (not by writing a second `¥` literal in this file) so a stray
/// lookalike character pasted into source would fail this test loudly
/// instead of silently comparing equal.
const int yenSignCodePoint = 0x00A5;
const int fullwidthYenSignCodePoint = 0xFFE5;

/// Every currency-ish symbol character actually observed across
/// lib/**/*.dart — collected once, statically, at test-authoring time
/// (mirrors the investigation this fix was based on) so this test doesn't
/// need to read the filesystem/source at runtime.
bool _looksLikeCurrencySymbol(int codeUnit) =>
    codeUnit == yenSignCodePoint ||
    codeUnit == fullwidthYenSignCodePoint ||
    codeUnit == 0x0024 /* $ */ ||
    codeUnit == 0x20AC /* € */ ||
    codeUnit == 0x00A3 /* £ */;

void main() {
  group('formatYen (P1-1)', () {
    test('uses exactly U+00A5 as the currency prefix, never a lookalike', () {
      final result = formatYen(1234567);
      expect(result.codeUnitAt(0), yenSignCodePoint);
      expect(result, '¥1,234,567');
    });

    test('negative amounts keep the minus sign before the yen sign', () {
      final result = formatYen(-500000);
      expect(result, '-¥500,000');
      expect(result.codeUnitAt(1), yenSignCodePoint);
    });

    test('zero and small amounts format correctly', () {
      expect(formatYen(0), '¥0');
      expect(formatYen(999), '¥999');
      expect(formatYen(1000), '¥1,000');
    });

    test('every character in a range of formatted amounts is either ASCII or the correct yen sign', () {
      for (final amount in [0, 1, 999, 1000, 12345, -12345, 999999999, -999999999]) {
        final text = formatYen(amount);
        for (final unit in text.codeUnits) {
          final isAscii = unit < 128;
          final isYenSign = unit == yenSignCodePoint;
          expect(
            isAscii || isYenSign,
            isTrue,
            reason: 'formatYen($amount) = "$text" contains unexpected codepoint U+${unit.toRadixString(16).padLeft(4, '0')}',
          );
        }
      }
    });
  });

  group('formatCompactYen (P1-1 regression baseline)', () {
    test('never uses a currency symbol at all (kanji-suffixed, already unaffected by the font bug)', () {
      for (final amount in [0, 850000, 3500000, 12500000, 100000000, -3500000]) {
        final text = formatCompactYen(amount);
        for (final unit in text.codeUnits) {
          expect(_looksLikeCurrencySymbol(unit), isFalse, reason: 'formatCompactYen($amount) = "$text" unexpectedly contains a currency symbol');
        }
      }
    });
  });

  group('GameLogEntry messages never use a different currency codepoint than formatYen', () {
    test('a representative playthrough\'s log text only ever uses U+00A5, never U+FFE5 or another lookalike', () {
      var state = GameEngine.newGame(seed: 42);
      // Exercise several of the log-message call sites that embed a raw
      // "¥$amount" directly (not through formatYen) — March/April
      // settlement, recruitment media, welfare spending, monthly closing —
      // so this test would have caught the same class of bug even for
      // strings that don't go through the shared formatter.
      state = GameEngine.postRecruitmentMedia(state, RecruitmentMediaType.engineerCareer);
      for (var i = 0; i < 8 && state.status == GameStatus.playing; i++) {
        state = GameEngine.advanceWeek(state);
      }
      state = GameEngine.conductHealthCheck(state, HealthCheckTier.basic);
      state = GameEngine.payBonus(state, BonusPlan.one);

      final offenders = <String>[];
      for (final entry in state.events) {
        for (final unit in entry.message.codeUnits) {
          if (_looksLikeCurrencySymbol(unit) && unit != yenSignCodePoint) {
            offenders.add('${entry.message} (U+${unit.toRadixString(16).padLeft(4, '0')})');
          }
        }
      }
      expect(offenders, isEmpty, reason: 'log messages using a currency codepoint other than U+00A5: $offenders');

      // Sanity: the playthrough actually produced at least one ¥-bearing
      // message, so this test isn't vacuously passing on an empty log.
      expect(state.events.any((e) => e.message.contains('¥')), isTrue);
    });
  });
}
