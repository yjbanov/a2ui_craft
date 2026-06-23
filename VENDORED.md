# Vendored code

A2UI Craft is, in effect, a fork of [Remote Flutter Widgets
(RFW)](https://pub.dev/packages/rfw) generalized beyond Flutter. Rather than
depend on `package:rfw` (whose `pubspec.yaml` pulls in Flutter even though its
`formats.dart` library does not), we **vendor** the relevant source so the core
can stay Flutter-free and each adapter can specialize the runtime. This file
records exactly what was copied and how it was modified, so future re-syncs are
deliberate.

## Source

- **Upstream:** `flutter/packages` → `packages/rfw`
- **Package version:** `rfw` 1.1.3
- **Commit:** `c516c92dcf` (2026-06-18)
- **License:** BSD-3-Clause ("The Flutter Authors"), preserved in [`LICENSE`](LICENSE)
  and in each vendored file's header.

## What was vendored, and the modifications applied

### Core — `packages/a2ui_craft/lib/src/` (framework-agnostic)

Copied from RFW's framework-free layer:

| File | Upstream origin | Modification |
| --- | --- | --- |
| `binary.dart` | `rfw/lib/src/dart/binary.dart` | none |
| `model.dart` | `rfw/lib/src/dart/model.dart` | none |
| `text.dart` | `rfw/lib/src/dart/text.dart` | none |
| `content.dart` | `rfw/lib/src/flutter/content.dart` | removed the sole Flutter dependency: the `objectRuntimeType` call in `toString()` (and its `package:flutter/foundation.dart` import) |

### Adapters — the runtime (per framework)

RFW's runtime is parameterized by the framework's node type, which Dart cannot
abstract cheaply, so each adapter vendors its own copy of
`rfw/lib/src/flutter/runtime.dart` with these modifications:

1. **Repointed imports:** the RFW-internal `formats`/`content` imports →
   `import 'package:a2ui_craft/a2ui_craft.dart';`.
2. **Unified public API names** (component-centric, not Flutter "Widget"
   vocabulary): `LocalWidgetLibrary` → `LocalComponentLibrary`,
   `LocalWidgetBuilder` → `LocalComponentBuilder`.
3. **Node-type specialization:** the Flutter adapter keeps `Widget`; the Jaspr
   adapter uses Jaspr's `Component`.
4. **Minor lint fixes** kept identical across adapters (e.g. `assert(library ==
   null)`).
5. **Keyed `_Widget` (A2UI Craft extension #1).** `_CurriedWidget.build` lifts a
   reserved literal `key` argument onto the `_Widget` reconciliation unit (via
   `_liftKey`), so a keyed remote-widget subtree reconciles by identity rather
   than position. This is additive and behavior-preserving for existing RFW usage
   (widgets without a `key` arg are unaffected). It is needed for A2UI's
   id-addressed, reorderable updates and independently improves RFW for dynamic
   lists — a candidate to propose upstream. Rationale and design: `DESIGN.md` §6.

`RemoteComponent` (from RFW's `remote_widget.dart`) is reimplemented per adapter
with the unified API (`RemoteComponent`, field `component`) rather than RFW's
`RemoteWidget`.

> Note: RFW's `argument_decoders.dart` and `core_widgets.dart` are **not**
> vendored — they are intensely Flutter-specific. Each adapter defines its own
> minimal `createCoreComponents()` instead. The real cross-platform core
> component/type library is future work ("H2" in [`DESIGN.md`](DESIGN.md)).

## Re-syncing with upstream

When pulling a newer `rfw`: re-copy the core files and re-apply the single
`content.dart` change; re-copy `runtime.dart` per adapter and re-apply
modifications 1–5 above. The parity/conformance tests (`a2ui_craft_testing` +
`packages/*/test`, including the keyed-reconciliation tests) are the safety net
that the runtimes still behave identically.
