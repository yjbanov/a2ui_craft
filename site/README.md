# A2UI Craft demo site

A [Jaspr](https://jaspr.site) web app that showcases the A2UI Craft samples, with
**Flutter embedded** (via
[`jaspr_flutter_embed`](https://docs.jaspr.site/going_further/flutter_embedding)).
Each sample can be flipped between the **Jaspr** and **Flutter** renderers, and
its template / schema / messages opened and edited with a live preview.

## Run locally

```sh
cd site
jaspr serve     # dev server with hot reload at http://localhost:8080
```

`jaspr serve` handles client-side routing, so deep links like `/sample/greeting`
load directly.

To produce a static bundle:

```sh
cd site
jaspr build     # outputs to site/build/jaspr
```

The static bundle is self-contained (the Jaspr app, the compiled Flutter engine,
and `canvaskit/`). Serving it from a plain static file server works for the
landing page and in-app navigation; deep links to a sample route need an SPA
rewrite (serve `index.html` for unknown paths) — `jaspr serve` already does this.
`web/index.html` sets `<base href="/">` so that once `index.html` is served for a
deep path like `/sample/contact_card`, its relative assets (`main.dart.js`,
`flutter_bootstrap.js`, the Flutter assets) still load from the site root instead
of being requested under `/sample/`.

There is intentionally **no deployment config** in this repo.

## How it fits together

- Samples are the **code-free data projects** from `a2ui_craft_examples`
  (`samples/<id>/{template.craft,schema.json,app.json}` + `manifest.json`),
  decoded with `SampleSpec.fromData`. `app.json` is the mini-app bootstrap (the
  canned A2UI stream that builds the surface with no agent).
- The Jaspr render uses `a2ui_craft_jaspr`'s `SampleView`; the Flutter render
  embeds `a2ui_craft_flutter`'s `SampleView` inside a `FlutterEmbedView`
  (`lib/flutter_host.dart` is the only file that imports `package:flutter`).
- The Flutter engine is preloaded at page start (`web/main.dart`), because the
  deferred Flutter library fails to load if triggered lazily on first toggle.
- The sample screen is responsive: when the preview pane (the viewport minus the
  editor sidebar, when open) is at least 800px wide, the Jaspr and Flutter
  renders show **side by side**; below that they collapse into a Jaspr/Flutter
  **tab toggle**. The breakpoint is computed in Dart from a `resize` listener
  (`lib/sample_screen.dart`) rather than a CSS media query, so it can account for
  the editor's width and avoid mounting the Flutter engine in tab mode unless the
  Flutter tab is selected.
