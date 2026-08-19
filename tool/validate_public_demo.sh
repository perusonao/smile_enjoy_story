#!/usr/bin/env bash
set -euo pipefail

flutter pub get
flutter analyze lib/game/public_demo lib/ui/public_demo
flutter test test/game/public_demo
flutter build web --release

echo 'Public Demo validation passed.'
