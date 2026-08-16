// Defense-in-depth check applied before the Viewer uses a manifest-supplied
// relative path (video/result/actionTrace) as a fetch()/src/href target.
// manifest.json is same-origin CI output, not attacker-supplied user
// input, but this keeps the Viewer from ever following a path outside the
// replay package directory or a non-http(s) URL scheme if that ever
// changes — mirrors the path-traversal defense already applied when the
// package is built (see e2e/scripts/build-replay-manifest.mjs).
//
// Grounded in real URL-resolution semantics (the WHATWG URL Standard —
// implemented identically by every browser and by Node's URL/fetch), not
// just string matching:
//
// 1. https://url.spec.whatwg.org/#url-parsing steps 1-2: before a URL
//    parser does ANYTHING else with an input string — including scheme
//    detection — it strips leading/trailing C0-control-or-space, then
//    deletes every ASCII TAB/LF/CR anywhere in the string. A
//    scheme-prefix check run against the un-normalized string can be
//    defeated by embedding a raw tab/newline/CR inside an otherwise
//    -blocked scheme: "java\nscript:alert(1)" doesn't textually match
//    "javascript:", but a real parser deletes the embedded newline
//    before ever checking the scheme and resolves it as a live
//    "javascript:" URL (verified against `new URL()`). Percent-encoded
//    control characters ("%0a", "%0d", "%09") are NOT stripped this way
//    by a real parser — confirmed the same way — so those are instead
//    covered by the decode-and-recheck pass below, as defense in depth.
//
// 2. https://url.spec.whatwg.org/#path-state: resolving a relative
//    reference like "%2e%2e/evil.mp4" against a same-origin base walks
//    up a directory exactly like "../evil.mp4" would. The spec
//    special-cases the *literal* (undecoded) segment spellings ".",
//    "..", "%2e", ".%2e", "%2e.", "%2e%2e" (all case-insensitive) as
//    single-/double-dot segments during path resolution — it does not
//    first percent-decode the whole path. A check that only rejects a
//    literal ".."/"." segment therefore misses the encoded forms; this
//    checks for both.

const SCHEME_PREFIX = /^[a-zA-Z][a-zA-Z0-9+.-]*:/;

// The exact "single-dot path segment" / "double-dot path segment"
// spellings from the WHATWG URL Standard, checked case-insensitively
// against the RAW (undecoded) segment text — matching what a
// spec-compliant URL parser itself matches against.
const DOT_SEGMENT = /^(?:\.|\.\.|%2e|\.%2e|%2e\.|%2e%2e)$/i;

// URL Standard "URL parsing" steps 1-2 (see file header): trim
// leading/trailing C0 control-or-space, then delete every ASCII
// TAB/LF/CR anywhere in what's left. Applied before any other check in
// this module so what gets validated is exactly what a real URL parser
// would actually see — not the string as manifest.json literally spells
// it.
const LEADING_TRAILING_C0_OR_SPACE = /^[\u0000-\u0020]+|[\u0000-\u0020]+$/g;
const ASCII_TAB_OR_NEWLINE = /[\t\n\r]/g;

function stripUrlParserWhitespace(value) {
  return value.replace(LEADING_TRAILING_C0_OR_SPACE, '').replace(ASCII_TAB_OR_NEWLINE, '');
}

function hasUnsafeSegments(value) {
  // Splitting on both "/" and "\" mirrors the URL Standard treating
  // backslash as an additional path separator for "special" schemes
  // (http/https/file/...) — the only schemes this Viewer ever resolves
  // a relative path against.
  return value.split(/[\\/]/).some((seg) => seg.length === 0 || DOT_SEGMENT.test(seg));
}

function isSafeAgainst(value) {
  if (value.startsWith('/') || value.startsWith('\\')) return false;
  // Any URL scheme prefix (http:, javascript:, data:, file:, ...) is
  // rejected — this must stay a plain path relative to manifest.json's
  // own directory.
  if (SCHEME_PREFIX.test(value)) return false;
  return !hasUnsafeSegments(value);
}

/** Percent-decodes `value` exactly once, returning null on malformed
 * percent-encoding (a lone "%", "%2", "%zz", ...) instead of throwing —
 * callers treat a null result as unsafe, never as a crash. One decode
 * pass is sufficient here: it's enough to reveal a double-encoded
 * traversal attempt like "%252e%252e" as the (still-rejected, by
 * DOT_SEGMENT) literal segment "%2e%2e", and enough to reveal an encoded
 * backslash ("%5c") as an actual "\" separator for the split-and-check
 * pass below — a second decode pass would only re-decode content this
 * function has already ruled unsafe or already accepted as literal. */
function tryDecodeOnce(value) {
  try {
    return decodeURIComponent(value);
  } catch {
    return null;
  }
}

export function isSafeRelativePath(value) {
  if (typeof value !== 'string' || value.length === 0) return false;

  // Normalize exactly like a URL parser would BEFORE checking anything
  // else — a scheme/segment check run against the un-normalized string
  // can be defeated by whitespace the browser silently deletes (see file
  // header, point 1). An input that's nothing but whitespace/control
  // characters normalizes to "", which the empty-segment check inside
  // hasUnsafeSegments already rejects.
  const normalized = stripUrlParserWhitespace(value);
  if (!isSafeAgainst(normalized)) return false;

  // Checked against a single percent-decode pass too (defense in depth
  // against encoded separators/dot-segments/whitespace this function's
  // own consumers — or a future one — might decode before use); the
  // decoded form is re-normalized for the same reason before recheck.
  const decoded = tryDecodeOnce(normalized);
  if (decoded === null) return false;
  return isSafeAgainst(stripUrlParserWhitespace(decoded));
}
