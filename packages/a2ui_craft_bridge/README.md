# a2ui_craft_bridge

Renders **A2UI Transport** surfaces with the [A2UI Craft][repo] engine.

This package is the seam between the [A2UI protocol][a2ui_core] and the
framework adapters: it translates an A2UI catalog component tree and data model
into the RFW model that [`a2ui_craft`][core] describes and the adapters render.
It is **framework-neutral** — no UI-framework dependency — so both the Flutter
and Jaspr adapters build on the exact same translation.

You typically depend on this only when wiring A2UI messages into a renderer;
most apps depend on an adapter ([`a2ui_craft_flutter`][flutter] or
[`a2ui_craft_jaspr`][jaspr]), which pulls this in.

## Status

Prerelease (`0.1.0-dev.x`), depending on a prerelease of `a2ui_core`.

## License

BSD 3-Clause — see [LICENSE](LICENSE).

[repo]: https://github.com/yjbanov/a2ui_craft
[core]: https://pub.dev/packages/a2ui_craft
[a2ui_core]: https://pub.dev/packages/a2ui_core
[flutter]: https://pub.dev/packages/a2ui_craft_flutter
[jaspr]: https://pub.dev/packages/a2ui_craft_jaspr
