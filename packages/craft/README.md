# craft — the A2UI Craft CLI

Scaffold and (later) manage **A2UI Craft projects**: self-contained, *data-only*
UI bundles that deploy to a CDN and load into a host app at runtime. A project is
a separate, independently deployable thing from whatever app renders it — no
compile step, because it is data, not code.

## Install

```sh
dart pub global activate --source path packages/craft
```

(Not yet published: the `craft` name is taken on pub.dev by an unrelated
package, so a published release will require renaming — e.g.
`dart pub global activate a2ui_craft_cli`.)

## Usage

```sh
craft create my_counter        # scaffold a new project in ./my_counter
cd my_counter
firebase deploy --only hosting # publish the static files to a CDN
```

`craft create` writes a complete, deployable project — an RFW `template.craft`,
its `schema.json`, an `app.json` bootstrap (the mini-app stream that builds the
surface with no agent), optional `tests.json` dev scenarios, a `manifest.json`,
and a `firebase.json` (CORS + cache) so deploying is one command. It is
hard-coded to the counter starter for now; more templates and an assemble/build
step come later.

### Mini-apps: `--logic`

```sh
craft create my_cart --logic
```

Scaffolds a project that ships its own **business logic** beside its UI: the
same files plus a `logic.js` driver, and a `manifest.json` whose `logic` slot
names the entry file and the language it is written in — never where to run it.
Where the driver runs (a web worker, an iframe, a webview, an embedded engine)
is the *host's* decision, which is what lets one published bundle work
everywhere. A host that cannot run the named language refuses the project with a
reason rather than rendering chrome nothing will answer.

The driver speaks the A2UI Transport session protocol; see
`package:a2ui_craft_logic` for the runners and the JavaScript driver SDK.
