# craft — the A2UI Craft CLI

Scaffold and (later) manage **A2UI Craft projects**: self-contained, *data-only*
UI bundles that deploy to a CDN and load into a host app at runtime. A project is
a separate, independently deployable thing from whatever app renders it — no
compile step, because it is data, not code.

## Install

```sh
dart pub global activate --source path packages/craft
```

(From a published release, this becomes `dart pub global activate craft`.)

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
