# a2ui_craft_flutter

**Flutter** bindings for [A2UI Craft][repo]: render framework-agnostic RFW
templates as Flutter widgets.

A2UI Craft is a client-side templating engine for generative UI. This adapter
takes a template described by [`a2ui_craft`][core] and builds a live Flutter
widget tree bound to a reactive data model — with behavior held **identical to
the [Jaspr adapter][jaspr]** by a cross-framework conformance suite.

```dart
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
```

The adapter carries a copy of the RFW runtime specialized to Flutter's node
type, plus the built-in primitive library (layout, text, controls) that every
adapter shares. See the [repository][repo] for the design docs and examples.

## Status

Prerelease (`0.1.0-dev.x`), depending on a prerelease of `a2ui_core`.

## License

BSD 3-Clause — see [LICENSE](LICENSE).

[repo]: https://github.com/yjbanov/a2ui_craft
[core]: https://pub.dev/packages/a2ui_craft
[jaspr]: https://pub.dev/packages/a2ui_craft_jaspr
