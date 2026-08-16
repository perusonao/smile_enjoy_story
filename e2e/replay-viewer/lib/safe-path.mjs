// Defense-in-depth check applied before the Viewer uses a manifest-supplied
// relative path (video/result/actionTrace) as a fetch()/src/href target.
// manifest.json is same-origin CI output, not attacker-supplied user
// input, but this keeps the Viewer from ever following a path outside the
// replay package directory or a non-http(s) URL scheme if that ever
// changes — mirrors the path-traversal defense already applied when the
// package is built (see e2e/scripts/build-replay-manifest.mjs).
//
// Grounded in real URL-resolution semantics (the WHATWG URL Standard —
// https://url.spec.whatwg.org/#path-state — implemented identically by
// every browser and by Node's URL/fetch), not just string matching:
// resolving a relative reference like "%2e%2e/evil.mp4" against a
// same-origin base walks up a directory exactly like "../evil.mp4"
// would. The spec special-cases the *literal* (undecoded) segment
// spellings ".", "..", "%2e", ".%2e", "%2e.", "%2e%2e" (all case
// -insensitive) as single-/double-dot segments during path resolution —
// it does not first percent-decode the whole path. A check that only
// rejects a literal ".."/"." segment therefore misses the encoded forms;
// this checks for both.

const SCHEME_PREFIX = /^[a-zA-Z][a-zA-Z0-9+.-]*:/;

// The exact "single-dot path segment" / "double-dot path segment"
// spellings from the WHATWG URL Standard, checked case-insensitively
// against the RAW (undecoded) segment text — matching what a
// spec-compliant URL parser itself matches against.
const DOT_SEGMENT = /^(?:\.|\.\.|%2e|\.%2e|%2e\.|%2e%2e)$/i;

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
  // Checked against BOTH the raw value (what a URL parser itself matches
  // dot-segments against) and a single percent-decode pass (defense in
  // depth against encoded separators/dot-segments this function's own
  // consumers — or a future one — might decode before use).
  if (!isSafeAgainst(value)) return false;
  const decoded = tryDecodeOnce(value);
  if (decoded === null) return false;
  return isSafeAgainst(decoded);
}
