#!/usr/bin/env bash
#
# One entrypoint to verify the entire workspace: resolve, format-check, analyze,
# and test every package. CI runs this; run it locally before pushing.
#
# Requires the Flutter SDK on PATH (its bundled Dart runs the pure-Dart and
# Jaspr packages too), because one workspace member depends on Flutter.

set -euo pipefail
cd "$(dirname "$0")/.."

step() { printf '\n\033[1m==> %s\033[0m\n' "$1"; }

step "Resolve workspace (flutter pub get)"
flutter pub get

step "Format check (dart format)"
dart format --output=none --set-exit-if-changed .

step "Analyze: a2ui_craft (core)"
(cd packages/a2ui_craft && dart analyze)

step "Analyze: a2ui_craft_bridge (A2UI integration)"
(cd packages/a2ui_craft_bridge && dart analyze)

step "Analyze: a2ui_craft_testing"
(cd packages/a2ui_craft_testing && dart analyze)

step "Analyze: a2ui_craft_jaspr"
(cd packages/a2ui_craft_jaspr && dart analyze)

step "Analyze: a2ui_craft_jaspr/example"
(cd packages/a2ui_craft_jaspr/example && dart analyze)

step "Analyze: a2ui_craft_flutter"
(cd packages/a2ui_craft_flutter && flutter analyze)

step "Analyze: a2ui_craft_flutter/example"
(cd packages/a2ui_craft_flutter/example && flutter analyze)

step "Analyze: tool/testing (repo-wide checks)"
(cd tool/testing && dart analyze)

step "Test: tool/testing (repo-wide checks, e.g. license headers)"
(cd tool/testing && dart test)

step "Test: a2ui_craft (core)"
(cd packages/a2ui_craft && dart test)

step "Test: a2ui_craft_bridge (A2UI translation)"
(cd packages/a2ui_craft_bridge && dart test)

step "Test: a2ui_craft_jaspr (parity)"
(cd packages/a2ui_craft_jaspr && dart test)

step "Test: a2ui_craft_jaspr/example (samples)"
(cd packages/a2ui_craft_jaspr/example && dart test)

step "Test: a2ui_craft_flutter (parity)"
(cd packages/a2ui_craft_flutter && flutter test)

step "Test: a2ui_craft_flutter/example (samples)"
(cd packages/a2ui_craft_flutter/example && flutter test)

printf '\n\033[1;32m==> ALL CHECKS PASSED\033[0m\n'
