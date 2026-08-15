// Pure HTML-escaping helper — shared by app.js (browser) and its unit
// tests (Node's built-in test runner). No DOM dependency.
//
// Every piece of text this Viewer renders ultimately comes from a
// Playwright test run (scenario names, candidate names, console error
// text, action-trace labels...). None of it is operator-typed HTML, but
// none of it should be trusted as safe-to-inject either — this is applied
// to every interpolated value before it reaches innerHTML.
export function escapeHtml(value) {
  const s = value === null || value === undefined ? '' : String(value);
  return s.replace(/[&<>"']/g, (ch) => {
    switch (ch) {
      case '&':
        return '&amp;';
      case '<':
        return '&lt;';
      case '>':
        return '&gt;';
      case '"':
        return '&quot;';
      case "'":
        return '&#39;';
      default:
        return ch;
    }
  });
}
