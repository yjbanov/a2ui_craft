# A2UI Craft

**A2UI Craft** is a framework-agnostic, **client-side templating engine**
optimized for generative UI use-cases. It renders declarative UI templates
using whatever UI framework the client is built on (currently **Flutter**
and **Jaspr**), binding them to a reactive data model.

## Try it

A live demo is available at https://a2ui-craft.web.app.

## Architecture at a glance

```
a2ui_craft           core engine — pure Dart, NO UI-framework dependency
  ├─ a2ui_craft_flutter   renders templates as Flutter widgets
  └─ a2ui_craft_jaspr     renders templates as HTML DOM (via Jaspr)
```

- **`a2ui_craft`** — parsing, AST, binary format, and the reactive
  `DynamicContent` model (the RFW *formats* layer, vendored to stay Flutter-free).
- **`a2ui_craft_flutter` / `a2ui_craft_jaspr`** — *adapters*. Each carries a copy
  of the RFW runtime specialized to its framework's node type, plus a minimal
  library of core components (`Text`, `Row`, `Column`, `Button`).

Every adapter exposes the **same API**, keeping RFW's upstream public names
(`Runtime`, `RemoteWidget`, `LocalWidgetLibrary`, `createCoreComponents`, …) so
client code reads identically across frameworks. What each adapter may and may not
change is specified in [`DESIGN.md` §7](DESIGN.md) and enforced by the project
skills in [`skills/`](skills).

## Getting started

Requires the **Flutter SDK** (its bundled Dart runs the pure-Dart and Jaspr
packages too). One member package depends on Flutter, so the whole workspace is
resolved with `flutter pub get`.

```bash
# Verify the whole workspace (resolve + format + analyze + test). This is what
# CI runs.
./tool/check.sh

# Or, individual pieces:
flutter pub get                                  # resolve every package
flutter test packages/a2ui_craft_flutter         # Flutter adapter parity test
dart test packages/a2ui_craft_jaspr              # Jaspr adapter parity test
dart test packages/a2ui_craft                    # core engine tests
cd packages/a2ui_craft_jaspr/example && jaspr serve   # run the Jaspr example
```

Both adapters render a shared template fixture (`packages/a2ui_craft_testing`)
and assert identical behavior, so "the same template renders the same on every
framework" is a continuously tested invariant, not just a claim.

## Status

The harness is in place: a Flutter-free core plus two working adapters proving
the same template renders on Flutter and on the DOM, with a cross-framework
behavioral conformance suite. A2UI integration and the cross-platform component
library (**H2**) are both underway. See [`ROADMAP.md`](ROADMAP.md) for status
and [`DESIGN.md` §6](DESIGN.md) for the A2UI rendering architecture.
