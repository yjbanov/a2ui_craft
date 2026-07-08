// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The files `craft create` writes for a new project — the counter starter, the
/// only template for now. Everything is **data**: an RFW template, a JSON-Schema
/// catalog, an A2UI bootstrap, dev test scenarios, a project manifest, and a
/// Firebase Hosting config. There is nothing to compile; deploying is copying
/// these files to a CDN.
library;

/// The files (relative path → contents) of a new counter project named [name].
Map<String, String> counterProjectFiles(String name) {
  final String display = humanizeName(name);
  return <String, String>{
    'manifest.json': _manifest(display),
    'template.craft': _templateCraft,
    'schema.json': _schemaJson,
    'app.json': _appJson,
    'tests.json': _testsJson,
    'firebase.json': _firebaseJson,
    'README.md': _readme(display, name),
  };
}

/// Turns a project id (`my_counter`, `my-counter`) into a display name
/// (`My Counter`).
String humanizeName(String name) => name
    .split(RegExp('[_-]+'))
    .where((String part) => part.isNotEmpty)
    .map((String part) => part[0].toUpperCase() + part.substring(1))
    .join(' ');

/// The consolidated project manifest (§13.9): display name + which component
/// catalog the host must provide. No theme block → the surface blends into its
/// host; add a `"theme"` block (e.g. `{ "theme": "default", "mode": "dark" }`)
/// to opt in.
String _manifest(String display) => '''
{
  "name": "$display",
  "catalogId": "demo"
}
''';

// The counter template: local `count` state incremented by `set state.count =
// add(...)` — RFW has no `+`, so `+ 1` is a call to the standard `add` function.
// No host code, no agent, identical on every adapter.
const String _templateCraft = r'''
import core;

widget Counter { count: 0 } = Column(children: [
  Text(text: args.label),
  Text(text: state.count),
  Button(
    onPressed: set state.count = add(a: state.count, b: 1),
    child: Text(text: args.buttonLabel),
  ),
]);
''';

// The component API the bootstrap/agent binds against (the A2UI schema catalog).
const String _schemaJson = r'''
{
  "catalogId": "demo",
  "components": {
    "Counter": {
      "properties": {
        "label": { "$ref": "DynamicString" },
        "buttonLabel": { "$ref": "DynamicString" }
      }
    }
  }
}
''';

// app.json — the mini-app bootstrap: the canned A2UI stream that builds the
// surface with no agent. A pure agent-driven deployment would delete this file
// and let the transport supply the stream live.
const String _appJson = r'''
[
  {
    "version": "v0.9",
    "createSurface": {
      "surfaceId": "demo",
      "catalogId": "demo",
      "sendDataModel": false
    }
  },
  {
    "version": "v0.9",
    "updateComponents": {
      "surfaceId": "demo",
      "components": [
        {
          "id": "root",
          "component": "Counter",
          "label": "You have pushed the button this many times:",
          "buttonLabel": "Increment"
        }
      ]
    }
  }
]
''';

// tests.json — optional, dev-only named scenarios for demoing/exercising the
// project without an LLM. Clearly test data, not the app's content.
const String _testsJson = r'''
{
  "default": [
    {
      "version": "v0.9",
      "createSurface": {
        "surfaceId": "demo",
        "catalogId": "demo",
        "sendDataModel": false
      }
    },
    {
      "version": "v0.9",
      "updateComponents": {
        "surfaceId": "demo",
        "components": [
          {
            "id": "root",
            "component": "Counter",
            "label": "You have pushed the button this many times:",
            "buttonLabel": "Increment"
          }
        ]
      }
    }
  ],
  "custom-labels": [
    {
      "version": "v0.9",
      "createSurface": {
        "surfaceId": "demo",
        "catalogId": "demo",
        "sendDataModel": false
      }
    },
    {
      "version": "v0.9",
      "updateComponents": {
        "surfaceId": "demo",
        "components": [
          {
            "id": "root",
            "component": "Counter",
            "label": "Taps so far:",
            "buttonLabel": "Tap me"
          }
        ]
      }
    }
  ]
}
''';

// Firebase Hosting config: serve the project files from the directory root with
// permissive CORS (so a host on another origin can fetch them — the whole point)
// and a short cache so re-published edits show up quickly. firebase.json and the
// README are not served.
const String _firebaseJson = r'''
{
  "hosting": {
    "public": ".",
    "ignore": ["firebase.json", "README.md", "**/.*"],
    "headers": [
      {
        "source": "**",
        "headers": [
          { "key": "Access-Control-Allow-Origin", "value": "*" },
          { "key": "Cache-Control", "value": "public, max-age=60" }
        ]
      }
    ]
  }
}
''';

String _readme(String display, String name) => '''
# $display — an A2UI Craft project

This is an **A2UI Craft project**: a self-contained, *data-only* UI bundle. There
is no code to compile — it is an RFW template, its component schema, an A2UI
bootstrap, and a manifest. A host app loads it **over HTTP at runtime**, so it is
a separate, independently deployable thing from whatever app renders it.

## Files

| File | Role | Deployed? |
|---|---|---|
| `manifest.json` | Name + catalog id (+ optional theme). | ✅ |
| `template.craft` | The UI, as an RFW template over the core primitives. | ✅ |
| `schema.json` | The component API the bootstrap/agent binds against. | ✅ |
| `app.json` | The **mini-app bootstrap** — the canned A2UI stream that builds the surface with no agent. Delete it for a pure agent-driven deployment. | ✅ |
| `tests.json` | Optional **dev scenarios** for demoing/testing without an LLM. Test data, clearly labelled. | ✅ (harmless) |
| `firebase.json` | Firebase Hosting config (CORS + cache). | ❌ (config) |

## Deploy to a CDN (Firebase Hosting)

No build step — deployment is publishing these static files:

```sh
firebase login
firebase use --add          # pick or create a Firebase project
firebase deploy --only hosting
```

Your project is now served at `https://<project>.web.app/` — e.g.
`https://<project>.web.app/manifest.json`. Point a host at that base URL to load
and render `$name`.

## The two-artifact property

The host app and this project deploy **independently**. Edit `template.craft` (or
any file), re-run `firebase deploy`, and reload the host — the UI updates with
**no host redeploy**. That is the ephemeral-loadability property: the UI travels
the author's channel, not the app store's.
''';
