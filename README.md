# smile_enjoy_story

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Public Demo 0.1 (external playtesters)

Share this stable URL with external testers:

> https://perusonao.github.io/smile_enjoy_story/public-demo/

It's a static redirect (`web/public-demo/index.html`) into the existing
`#/public-demo-01` route — it doesn't add a route or change what the app
does. This is separate from the development root
(`https://perusonao.github.io/smile_enjoy_story/`), which keeps launching
the normal development experience.

## Playwright E2E (QA / UX audit)

`/e2e` drives the real, built Web app on mobile device profiles from a
brand-new game through the Founding Prologue to the first案件参画, the same
way a first-time player would — independent from the Dart headless
simulations under `/tool`. See [`e2e/README.md`](e2e/README.md) for setup,
local runs, and how to read a failure's video/screenshots/action trace.
