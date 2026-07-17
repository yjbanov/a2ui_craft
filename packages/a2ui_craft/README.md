# a2ui_craft

The framework-agnostic **engine** of [A2UI Craft][repo] — a client-side
templating engine for generative UI. Pure Dart, with **no UI-framework
dependency**.

## Start with an adapter, not this package

`a2ui_craft` renders nothing on its own — it's the engine the adapters build on.
**To build an app, depend on the adapter for your framework.** Each one pulls
this engine in and adds the rendering layer, so it's your single entrypoint:

| You build with… | Depend on | Renders templates as |
|---|---|---|
| Flutter | [`a2ui_craft_flutter`][flutter] | Flutter widgets |
| Jaspr | [`a2ui_craft_jaspr`][jaspr] | HTML DOM |

Both adapters expose the **same API** and are held to a cross-framework
behavioral conformance suite, so "the same template renders the same on every
framework" is a continuously tested invariant.

Depend on `a2ui_craft` **directly** only for framework-free work: tooling that
parses or transforms templates, or building a new adapter. (The engine has no
Flutter dependency on purpose — so pure-Dart and web/server consumers can use it
without pulling in the Flutter SDK.)

## What's in the engine

- **Parsing, AST, and the binary format** for the RFW template language.
- The reactive **`DynamicContent`** data model that templates bind to.
- The shared **value types** (colors, dimensions, corner radii, borders, …),
  **design-token** resolution (DTCG), and the **semantic contract** of theme
  roles that both adapters read.
- The neutral **Markdown** model, and the built-in **function library**
  (math, string, comparison, logic) available to templates.

## Status

Prerelease (`0.1.0-dev.x`). The API is still moving and this release depends on
a prerelease of the underlying `a2ui_core` protocol package.

## License

BSD 3-Clause — see [LICENSE](LICENSE).

[repo]: https://github.com/yjbanov/a2ui_craft
[flutter]: https://pub.dev/packages/a2ui_craft_flutter
[jaspr]: https://pub.dev/packages/a2ui_craft_jaspr
