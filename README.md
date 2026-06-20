# A2UI Craft

**A2UI Craft** is a framework-agnostic, **client-side templating engine**. It
renders declarative UI templates — written in the [Remote Flutter Widgets
(RFW)](https://pub.dev/packages/rfw) text format — using whatever UI framework
the client is built on (currently **Flutter** and **Jaspr**), binding them to a
reactive data model.

The guiding hypothesis: *RFW's language and runtime are not actually
Flutter-specific, and one engine can drive many rendering engines.* See
[`DESIGN.md`](DESIGN.md) for the full rationale, scope, and architecture — it is
the source of truth for the project.

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

Every adapter exposes the **same component-centric API** (`Runtime`,
`RemoteComponent`, `LocalComponentLibrary`, `createCoreComponents`, …) so client
code reads identically across frameworks. What each adapter may and may not
change is specified in [`DESIGN.md` §5](DESIGN.md) and enforced by the project
skills in [`skills/`](skills).

## Why not compile templates to A2UI Transport directly?

Templates are *declarative* (`data → UI`); A2UI Transport is an *imperative*
protocol that mutates a live, stateful UI. Bridging the two requires evaluating
the template against data and reconciling it against the previous tree — a
*runtime* concern, not something an ahead-of-time compiler can do. So A2UI Craft
is a client-side engine, and A2UI simply treats its templates as an
implementation of an A2UI **catalog**. (Full reasoning in [`DESIGN.md` §2](DESIGN.md).)

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
the same template renders on Flutter and on the DOM. The next major effort is
**H2** — designing the real cross-platform core component/type library — which is
deliberately not started until the harness is solid. See [`DESIGN.md` §7](DESIGN.md).
