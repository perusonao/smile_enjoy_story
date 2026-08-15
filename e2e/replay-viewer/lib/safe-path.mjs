// Defense-in-depth check applied before the Viewer uses a manifest-supplied
// relative path (video/result/actionTrace) as a fetch()/src/href target.
// manifest.json is same-origin CI output, not attacker-supplied user
// input, but this keeps the Viewer from ever following a path outside the
// replay package directory or a non-http(s) URL scheme if that ever
// changes — mirrors the path-traversal defense already applied when the
// package is built (see e2e/scripts/build-replay-manifest.mjs).
export function isSafeRelativePath(value) {
  if (typeof value !== 'string' || value.length === 0) return false;
  if (value.startsWith('/') || value.startsWith('\\')) return false;
  // Any URL scheme prefix (http:, javascript:, data:, ...) is rejected —
  // this must stay a plain path relative to manifest.json's own directory.
  if (/^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(value)) return false;
  const segments = value.split(/[\\/]/);
  return segments.every((seg) => seg !== '..' && seg !== '.' && seg.length > 0);
}
