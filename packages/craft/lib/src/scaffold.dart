// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The files `craft create` writes for a new project — the counter starter, or
/// (with `--logic`) a mini-app that ships its own driver. Everything is
/// **data**: an RFW template, a JSON-Schema catalog, an A2UI bootstrap, dev
/// test scenarios, a project manifest, and a Firebase Hosting config. There is
/// nothing to compile; deploying is copying these files to a CDN.
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

/// The consolidated project manifest (§10): display name + which component
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

/// The files (relative path → contents) of a new **mini-app** named [name] — a
/// project that ships business logic.
///
/// The difference from [counterProjectFiles] is one manifest slot and one extra
/// file. A mini-app declares a `logic` block naming a driver, and the driver
/// answers the events the template dispatches. It is not renderable without
/// that driver, which is deliberate: a mini-app loaded with its logic missing
/// would be a screen of controls that answer nothing.
Map<String, String> miniAppProjectFiles(String name) {
  final String display = humanizeName(name);
  return <String, String>{
    'manifest.json': _miniAppManifest(display),
    'template.craft': _miniAppTemplateCraft,
    'schema.json': _miniAppSchemaJson,
    'app.json': _miniAppJson,
    'logic.js': _miniAppLogicJs,
    'firebase.json': _firebaseJson,
    'README.md': _miniAppReadme(display, name),
  };
}

// The `logic` slot: *what* the logic is, never where it runs. A project names
// the file it ships and the language that file is written in; whether the host
// runs it in a worker, an iframe, a webview, or an embedded engine is the
// host's decision, so the same bundle works everywhere. `capabilities` is
// empty because this version grants none.
String _miniAppManifest(String display) => '''
{
  "name": "$display",
  "catalogId": "reserve",
  "logic": {
    "entry": "logic.js",
    "language": "javascript",
    "capabilities": []
  }
}
''';

// Nothing here decides anything. The field echoes what the user types at
// tier-1 latency (two-way binding, no round trip); the status line shows
// whatever the driver last said.
const String _miniAppTemplateCraft = r'''
import core;

widget Reserve = Card(child: Column(crossAxisAlignment: "stretch", gap: 8.0,
  children: [
    Heading(text: args.title, level: 2),
    Text(text: args.prompt, variant: "caption"),
    TextField(value: args.name, onChanged: args.setName),
    Text(text: args.status),
    Button(onPressed: args.check, child: Text(text: args.checkLabel)),
  ]));
''';

// `actions` is the agent-facing half: the inference catalog. A driver-backed
// action is a capability an agent can invoke without knowing how it works.
const String _miniAppSchemaJson = r'''
{
  "catalogId": "reserve",
  "components": {
    "Reserve": {
      "properties": {
        "title": { "$ref": "DynamicString" },
        "prompt": { "$ref": "DynamicString" },
        "name": { "$ref": "DynamicString" },
        "status": { "$ref": "DynamicString" },
        "checkLabel": { "$ref": "DynamicString" },
        "check": { "$ref": "Action" }
      }
    }
  },
  "actions": [
    {
      "name": "reserve",
      "description": "Reserves the username currently in the field, if it is available."
    }
  ]
}
''';

// The cold boot: a complete, honest surface before the driver connects.
const String _miniAppJson = r'''
[
  {
    "version": "v0.9",
    "createSurface": {
      "surfaceId": "app",
      "catalogId": "reserve",
      "sendDataModel": false
    }
  },
  {
    "version": "v0.9",
    "updateDataModel": {
      "surfaceId": "app",
      "path": "/",
      "value": {
        "name": "",
        "status": "Connecting…"
      }
    }
  },
  {
    "version": "v0.9",
    "updateComponents": {
      "surfaceId": "app",
      "components": [
        {
          "id": "root",
          "component": "Reserve",
          "title": "Reserve a username",
          "prompt": "Three characters or more.",
          "name": { "path": "/name" },
          "status": { "path": "/status" },
          "checkLabel": "Reserve",
          "check": { "event": { "name": "reserve" } }
        }
      ]
    }
  }
]
''';

// The driver: the part the template cannot be. Which names are taken has to
// survive the surface, so it is tier 3 by definition.
//
// The `a2uiDriver` function comes from the A2UI Craft driver SDK, which the
// host prepends when it starts the worker — this file is the whole of the
// logic, with nothing to install and nothing to build.
const String _miniAppLogicJs = r'''
var taken = ['ada', 'grace', 'alan'];

a2uiDriver({
  onInit: function (ctx) {
    ctx.write('/status', 'Type a name and reserve it.');
  },
  handlers: {
    reserve: function (ctx, event) {
      // The field is two-way bound, so what the user typed is already on
      // screen. The event carries it here, and what this writes back is
      // authoritative.
      var name = String(event.values['/name'] || '').trim().toLowerCase();
      if (name.length < 3) {
        ctx.write('/status', 'Too short — three characters or more.');
        return;
      }
      if (taken.indexOf(name) !== -1) {
        ctx.write('/status', '"' + name + '" is taken. Try another.');
        return;
      }
      taken.push(name);
      ctx.write('/status', 'Reserved "' + name + '".');
    },
  },
});
''';

String _miniAppReadme(String display, String name) => '''
# $display — an A2UI Craft mini-app

A **mini-app**: an A2UI Craft project that ships its own business logic. The
template renders and the driver decides, and they are coupled by nothing but a
protocol — so the driver can be written in any language that can hold state and
read and write JSON. This one is JavaScript.

Note what the manifest does *not* say: where the driver runs. That is the
host's decision — a web host may use a worker or an iframe, a mobile host a
webview or an embedded engine — so the same bundle is portable across all of
them.

## Files

| File | Role | Deployed? |
|---|---|---|
| `manifest.json` | Name, catalog id, and the **`logic` slot** — what the logic is, never where it runs. | ✅ |
| `template.craft` | The UI, as an RFW template over the core primitives. | ✅ |
| `schema.json` | The component API, plus the **`actions`** an agent may invoke. | ✅ |
| `app.json` | The cold boot: a complete surface before the driver connects. | ✅ |
| `logic.js` | The **driver** — the part the template cannot be. | ✅ |
| `firebase.json` | Firebase Hosting config (CORS + cache). | ❌ (config) |

## What belongs where

Most interaction should never cross the wire:

| Tier | Mechanism | Latency | Belongs here |
|---|---|---|---|
| 1 | template `state` + `set` | none | open tab, draft text, expand/collapse |
| 2 | template functions | none | formatting, arithmetic, visibility |
| 3 | the driver | round trip | validate, submit, fetch, persist |

Rule of thumb: **if it must survive the surface, or have effects beyond it, it
is tier 3.** Everything else belongs in the template. In this project, which
names are already taken is tier 3 — the surface cannot know it, and one that
pretended to would be lying.

## Deploy to a CDN (Firebase Hosting)

No build step; deployment is publishing these static files:

```sh
firebase login
firebase use --add          # pick or create a Firebase project
firebase deploy --only hosting
```

Point a host at `https://<project>.web.app/` to load and render `$name`. Edit
any file, re-deploy, reload the host — including `logic.js`. The UI *and its
behavior* travel the author's channel, with no host redeploy.
''';
