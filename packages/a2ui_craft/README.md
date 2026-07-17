# a2ui_craft

The framework-agnostic **core** of [A2UI Craft][repo] — a client-side
templating engine for generative UI. Pure Dart, with **no UI-framework
dependency**, so the same declarative templates render identically on any
framework via an adapter.

This package provides:

- **Parsing, AST, and the binary format** for the RFW template language.
- The reactive **`DynamicContent`** data model that templates bind to.
- The shared **value types** (colors, dimensions, corner radii, borders, …),
  **design-token** resolution (DTCG), and the **semantic contract** of theme
  roles that both adapters read.
- The neutral **Markdown** model, and the built-in **function library**
  (math, string, comparison, logic) available to templates.

You normally don't depend on this package directly — pick a renderer:

| Package | Renders templates as |
|---|---|
| [`a2ui_craft_flutter`][flutter] | Flutter widgets |
| [`a2ui_craft_jaspr`][jaspr] | HTML DOM (via Jaspr) |

Both adapters expose the **same API** and are held to a cross-framework
behavioral conformance suite, so "the same template renders the same on every
framework" is a continuously tested invariant.

## Status

Prerelease (`0.1.0-dev.x`). The API is still moving and this release depends on
a prerelease of the underlying `a2ui_core` protocol package.

## License

BSD 3-Clause — see [LICENSE](LICENSE).

[repo]: https://github.com/yjbanov/a2ui_craft
[flutter]: https://pub.dev/packages/a2ui_craft_flutter
[jaspr]: https://pub.dev/packages/a2ui_craft_jaspr
