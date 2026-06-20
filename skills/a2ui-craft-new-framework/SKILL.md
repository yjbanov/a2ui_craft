---
name: a2ui-craft-new-framework
description: >-
  Use when adding a NEW framework adapter to A2UI Craft — i.e. creating a new
  packages/a2ui_craft_<framework> that renders RFW templates with another UI
  framework. Codifies the recipe proven with the Flutter and Jaspr adapters
  (vendor/port the RFW runtime specialized to the framework's node type, repoint
  to the core, expose the unified component-centric API, implement minimal core
  components, add a parity test). Trigger on requests like "add a SwiftUI/Compose/
  React adapter" or "stand up a new a2ui_craft_<x> package".
---

# Adding a new A2UI Craft framework adapter

A new adapter must render the *same* templates, with the *same* public API and
behavior, as the existing adapters — only the produced node type and the leaf
rendering differ. Read the `a2ui-craft-adapters` skill and `DESIGN.md` §5 first;
they define the invariants this recipe must satisfy. **Copy the Flutter adapter
(`packages/a2ui_craft_flutter`) as the canonical reference** — it is itself a
near-verbatim, repointed copy of RFW's runtime.

## Current scope: Dart only

The proven path keeps everything in Dart (Flutter, Jaspr). A non-Dart framework
(SwiftUI, Jetpack Compose, React) additionally requires porting the runtime to
that language — out of current scope. Do not start a non-Dart adapter unless the
task explicitly calls for it.

## Recipe

1. **Create the package** `packages/a2ui_craft_<framework>` with `pubspec.yaml`
   (`resolution: workspace`, dependency on `a2ui_craft` via path, and the target
   framework). Add it to the root `pubspec.yaml` `workspace:` list.

2. **Port the runtime** into `lib/src/runtime.dart`:
   - Start from RFW's runtime (`packages/.../rfw/lib/src/flutter/runtime.dart`)
     or the Flutter adapter's already-ported `runtime.dart`.
   - Repoint imports: replace the RFW-internal `formats`/`content` imports with a
     single `import 'package:a2ui_craft/a2ui_craft.dart';`. Keep the target
     framework's imports.
   - Specialize the **node type** to the framework's (e.g. `Widget`, `Component`,
     `View`). This is the one pervasive, *allowed* change.
   - Apply the **unified, component-centric API names**: `LocalComponentLibrary`,
     `LocalComponentBuilder`, etc. Do NOT introduce framework-native names
     (e.g. "Widget") into the public API.

3. **Port `RemoteComponent`** into `lib/src/remote_component.dart` — same fields
   (`runtime`, `component`, `data`, `onEvent`) and behavior; host it using the
   framework's stateful-component lifecycle. (Watch for getter/field aliasing,
   e.g. Flutter's `State.widget` — hand-write this file rather than sed.)

4. **Implement minimal core components** in `lib/src/core_components.dart`:
   `createCoreComponents()` returning a `LocalComponentLibrary` with `Text`,
   `Row`, `Column`, `Button` — **the exact same names, argument names, and
   behavior** as the other adapters, realized with the new framework's
   primitives. Keep it minimal; this is a harness fixture, not the H2 core
   library.

5. **Barrel** `lib/a2ui_craft_<framework>.dart` exporting `runtime`,
   `remote_component`, `core_components` (mirror the existing adapters).

6. **Parity test** in `test/`: add a dev dependency on `a2ui_craft_testing` and
   render the shared `CounterScenario` fixture (the *same* template every other
   adapter renders), asserting: initial render, event reaches `onEvent`, and a
   `DynamicContent` update re-renders the bound text. Copy an existing adapter's
   `test/remote_component_test.dart` as the template. It must pass before the
   adapter is considered working. If the new adapter needs shared behavior not in
   the fixture, extend `a2ui_craft_testing` (so every adapter gets it), not just
   this test.

## Verify

- Add the package to the root `pubspec.yaml` `workspace:` list.
- `./tool/check.sh` passes (it resolves, format-checks, analyzes, and tests every
  package, including the new one and the existing adapters).
- The same shared template renders equivalently on the new adapter and
  the existing ones.

## If the framework fights the invariants

If the framework's model makes a MUST invariant (from `a2ui-craft-adapters` /
`DESIGN.md` §5) genuinely impossible, that is a finding about H1 (does RFW
generalize across rendering/state models?). Document it in `DESIGN.md` rather
than weakening the shared contract to force a fit.
