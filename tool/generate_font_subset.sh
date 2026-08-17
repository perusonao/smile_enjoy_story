#!/usr/bin/env bash
# Regenerates assets/fonts/NotoSansJP-{Regular,Bold}.subset.woff2 from the
# characters actually used under lib/**/*.dart, plus a small Unicode-block
# safety margin (full Hiragana/Katakana, CJK punctuation, fullwidth forms,
# basic ASCII) so a stray new kana/punctuation character added later still
# renders without needing a rebuild.
#
# Why this exists (Playable 0.4C.3 Japanese-rendering fix, see lib/ui/theme.dart):
# Flutter Web's CanvasKit renderer ships Roboto (no CJK glyphs) and falls
# back to fetching a Noto CJK subset from Google's font CDN at runtime when
# it meets a codepoint Roboto can't draw. That fetch fails in offline/
# sandboxed/CI environments (and is fragile even online), producing missing-
# glyph "tofu" boxes for Japanese text. Bundling a subsetted CJK font as a
# first-class app asset and setting it as the app's fontFamily removes that
# runtime dependency entirely.
#
# Usage: tool/generate_font_subset.sh
# Requires: git, python3 with `pip install fonttools brotli`.
set -euo pipefail
cd "$(dirname "$0")/.."
REPO_ROOT="$(pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "== Fetching Noto Sans JP (variable font) from google/fonts =="
git -C "$WORK" init -q
git -C "$WORK" remote add origin https://github.com/google/fonts.git
git -C "$WORK" config core.sparseCheckout true
mkdir -p "$WORK/.git/info"
echo "ofl/notosansjp/*" > "$WORK/.git/info/sparse-checkout"
git -C "$WORK" fetch --depth 1 origin main -q
git -C "$WORK" checkout main -q
VF="$WORK/ofl/notosansjp/NotoSansJP[wght].ttf"

echo "== Instantiating static Regular(400)/Bold(700) weights =="
python3 -m fontTools.varLib.instancer "$VF" wght=400 -o "$WORK/Regular-full.ttf"
python3 -m fontTools.varLib.instancer "$VF" wght=700 -o "$WORK/Bold-full.ttf"

echo "== Collecting characters used in lib/**/*.dart plus a full-CJK safety margin =="
# Playable 0.4C.3: a scan of lib/**/*.dart alone under-covers the game — the
# player types a free-text company name (and other names) at Founding time,
# so the font must render *any* common kanji the player might type, not just
# the ones that happen to already appear in our own source strings (verified
# by a real E2E run: a player-typed "E2Eテスト株式会社" hit "株", which no
# in-source string uses — see the PR description's Japanese-rendering-fix
# notes). Covering the full CJK Unified Ideographs block sidesteps needing a
# curated joyo/jinmeiyo kanji list to get this right.
python3 - "$WORK/chars.txt" <<'PY'
import sys, glob
out_path = sys.argv[1]
chars = set()
for path in glob.glob('lib/**/*.dart', recursive=True):
    with open(path, encoding='utf-8') as f:
        for ch in f.read():
            if ord(ch) > 0x2000:
                chars.add(ch)
# Safety margin: full Hiragana/Katakana, CJK punctuation, fullwidth forms,
# common quote/arrow symbols, basic ASCII, and the full CJK Unified
# Ideographs block (covers free-text player input, e.g. a typed company
# name, not just strings baked into our own source).
ranges = [
    (0x00A0, 0x00FF),  # Latin-1 Supplement (¥ U+00A5, £, ¢, °, ×, ÷, ...) —
                        # added after a real bug: the source-scan above only
                        # keeps a character if ord(ch) > 0x2000, which
                        # silently excludes the literal ¥ (U+00A5, 165) used
                        # by lib/ui/theme.dart's formatYen() and several
                        # GameLogEntry message strings. Without a glyph for
                        # it, the subsetted font had a hole at exactly the
                        # currency symbol shown on every money figure in the
                        # game, and CanvasKit's fallback substitution made it
                        # render as a mismatched/odd glyph next to the rest
                        # of a NotoSansJP-rendered amount.
    (0x3040, 0x30FF),  # Hiragana + Katakana
    (0x3000, 0x303F),  # CJK punctuation
    (0xFF00, 0xFFEF),  # Halfwidth/fullwidth forms
    (0x2018, 0x201F),  # curly quotes
    (0x2026, 0x2027),
    (0x2190, 0x21FF),  # arrows
    (0x4E00, 0x9FFF),  # CJK Unified Ideographs (common+uncommon kanji)
    (0x3400, 0x4DBF),  # CJK Unified Ideographs Extension A
]
for lo, hi in ranges:
    for cp in range(lo, hi + 1):
        chars.add(chr(cp))
for cp in range(0x20, 0x7F):
    chars.add(chr(cp))
with open(out_path, 'w', encoding='utf-8') as f:
    f.write(''.join(sorted(chars)))
print(f"{len(chars)} unique characters")
PY

echo "== Subsetting to woff2 =="
mkdir -p "$REPO_ROOT/assets/fonts"
for pair in "Regular-full.ttf:NotoSansJP-Regular.subset.woff2" "Bold-full.ttf:NotoSansJP-Bold.subset.woff2"; do
  src="${pair%%:*}"; dst="${pair##*:}"
  python3 -m fontTools.subset "$WORK/$src" \
    --text-file="$WORK/chars.txt" \
    --flavor=woff2 --layout-features='*' --glyph-names --symbol-cmap --legacy-cmap \
    --notdef-glyph --notdef-outline --recommended-glyphs \
    --name-IDs='*' --name-legacy --name-languages='*' \
    --output-file="$REPO_ROOT/assets/fonts/$dst"
done

ls -la "$REPO_ROOT/assets/fonts/"
echo "Done. Re-run \`flutter build web\` and diff the two subset.woff2 files into git."
