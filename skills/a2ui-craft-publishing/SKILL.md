---
name: a2ui-craft-publishing
description: >-
  Use when publishing (or preparing to publish) the A2UI Craft packages to
  pub.dev — cutting a release, bumping versions, or checking readiness. Covers
  which packages are public, the workspace-specific gotchas (the a2ui_core
  constraint, LICENSE propagation, cross-member version coherence),
  the per-package hygiene pub.dev requires (LICENSE/README/CHANGELOG/metadata),
  and the melos-orchestrated, dependency-ordered publish. Trigger on "publish to
  pub", "cut a 0.x release", "bump the versions", "is this ready to publish",
  "release the packages".
---

# Publishing A2UI Craft to pub.dev

The workspace has **eight** member packages but only **five are public**. The
rest carry `publish_to: none` and must never be published.

| Public (publish) | Private (`publish_to: none`) |
|---|---|
| `a2ui_craft` (core) | `a2ui_craft_testing` |
| `a2ui_craft_bridge` | `a2ui_craft_examples` |
| `a2ui_craft_flutter` | `craft` (CLI) |
| `a2ui_craft_jaspr` | `site`, both `example`s, `tool/testing` |
| `a2ui_craft_logic` | |

**`a2ui_craft_logic` is deliberately independent of the other four**: it
depends only on `a2ui_core` (never on `a2ui_craft` or an adapter), so it slots
anywhere in the publish order after nothing at all — but it *is* pinned by
version from `site` and `a2ui_craft_testing` (gotcha #2).

**`craft` (CLI) is private for two reasons**, not just convenience: the name
`craft` is already taken on pub.dev by an unrelated package (so publishing needs
a **rename** first, e.g. `a2ui_craft_cli`), and the CLI is still early
(hard-coded counter starter). Don't drop its `publish_to: none` without handling
both. Its runtime deps are only `args` + `path`, so it does not depend on
`a2ui_core` at all.

**Dependency order (publish in this order):** `a2ui_craft` → `a2ui_craft_bridge`
→ `a2ui_craft_flutter` / `a2ui_craft_jaspr`; `a2ui_craft_logic` depends on no
sibling and can go at any point. A package can't be published until the
sibling versions it depends on already exist on pub.dev. `melos publish`
computes this order automatically.

## Workspace-specific gotchas (get these wrong and it won't resolve or publish)

1. **`a2ui_core` is pre-1.0, so its constraint is a real coupling.** The four
   dependent packages (`bridge`, `flutter`, `jaspr`, `logic`) name `^0.1.1`.
   Under pub's pre-1.0 rules a caret on `0.x` allows only `0.1.z`, so a `0.2.0`
   is a **breaking bump requiring an edit in all four** — re-check the current
   published version on pub.dev before releasing and bump together.

   *Historical note:* until 2026-08-21 `a2ui_core` existed only as the
   prerelease `0.0.1-wip002`, which a bare `any`/`^0.0.1` cannot match, so the
   workspace root carried a `dependency_overrides` to pin it. Both the
   prerelease constraint and that override are gone; don't reintroduce them.

2. **Version bumps must stay coherent across the WHOLE workspace, not just the
   five public packages.** The unpublished members (`site`, both `example`s,
   `a2ui_craft_testing`) pin the public packages by version. If you bump
   `a2ui_craft` to `X` but leave `site`'s `a2ui_craft: ^old` behind, `pub get`
   fails with "version solving failed". After any bump, grep and fix every pin:
   ```
   grep -rn -E 'a2ui_craft(_bridge|_jaspr|_flutter|_logic)?:\s*\^' --include=pubspec.yaml packages site
   ```
   Do NOT blanket-sed `a2ui_craft*` — that also rewrites `a2ui_craft_examples`
   and `a2ui_craft_testing`, which are versioned independently and stay put.

3. **A2UI Craft's own version can now be a plain release.** While `a2ui_core`
   was a prerelease, a stable A2UI Craft release would have dragged a
   prerelease into every consumer's tree, so the guidance was to ship
   `0.1.0-dev.N` and signal the coupling honestly. `a2ui_core 0.1.1` removed
   that constraint — a plain `0.1.0` is now publishable. The dependency is
   still pre-1.0, which is a compatibility caveat for the README, not a reason
   to prerelease.

## Per-package hygiene pub.dev requires

Each of the five public packages needs, in its own directory:

- **`LICENSE`** — pub.dev requires it *inside the package*; the workspace root's
  LICENSE does NOT propagate (neither pub workspaces nor melos fan it out). It's
  a physical **copy** of the root LICENSE, kept byte-identical by the guard in
  `tool/check.sh` (`cmp LICENSE packages/<pkg>/LICENSE`). To refresh after a
  license edit: `cp LICENSE packages/<pkg>/LICENSE`.
- **`README.md`** — rendered on the package page; its absence tanks the pub score.
- **`CHANGELOG.md`** — one `## <version>` entry per release, newest on top.
- **Metadata in `pubspec.yaml`**: `repository`, `issue_tracker`, `topics`, and a
  real `description` (60–180 chars scores best).

Dev-dependencies do NOT have to be hosted — the adapters' dev-dependency on the
unpublished `a2ui_craft_testing` is fine. Only *regular* dependencies must be
hosted on pub.dev.

## Release procedure

1. **Confirm the constraint matches what is actually published.** The workspace
   resolves `a2ui_core` from pub.dev with no override, so `flutter pub get` +
   `./tool/check.sh` already builds against the real thing — but check pub.dev
   for a newer `a2ui_core` first, because a `0.2.x` would need the constraint
   bumped in all four dependent packages before it can be used at all.

2. **Bump versions** (all five together; keep them in lockstep for a coordinated
   release). Update each public `pubspec.yaml` `version:`, the sibling
   constraints (`^<new>` in the packages that depend on them), and every
   unpublished-member pin (gotcha #3). `dart run melos version` can drive this;
   expect to hand-edit the generated CHANGELOG bodies (history isn't
   conventional-commits, so melos's auto-changelog is a starting point only).

3. **Add a CHANGELOG entry** per package for the new version.

4. **Green the workspace:** `./tool/check.sh` (resolve, format, analyze, test,
   the generated-file drift guards, and the LICENSE guard) must pass.

5. **Dry-run each package** — this is the authoritative pre-publish validator:
   ```
   (cd packages/a2ui_craft        && dart pub publish --dry-run)
   (cd packages/a2ui_craft_bridge && dart pub publish --dry-run)
   (cd packages/a2ui_craft_jaspr  && dart pub publish --dry-run)
   (cd packages/a2ui_craft_flutter && flutter pub publish --dry-run)
   (cd packages/a2ui_craft_logic  && dart pub publish --dry-run)
   ```
   Expected non-blocking noise: an "uncommitted files" warning (publish from a
   clean tree instead). Anything else is a real finding to fix.

6. **Commit** the release (clean tree) so the "uncommitted files" warning clears.

7. **Publish, in dependency order.** `melos publish` orchestrates it:
   ```
   dart run melos publish              # dry-run of all five, in order
   dart run melos publish --no-dry-run # the real thing (needs pub.dev auth + TTY)
   ```
   The real publish requires interactive confirmation and pub.dev credentials —
   it is a human action; an agent must not run `--no-dry-run` without explicit
   permission (it pushes to an external, effectively irreversible registry).
   Alternatively publish each package by hand with `dart pub publish` in order.

## Melos

Melos 8 is configured in the root `pubspec.yaml` under the `melos:` key and
derives the package set from the native `workspace:` list — no `packages:` glob
needed. It is used ONLY for release orchestration (`version`, `publish`);
day-to-day verification stays in `tool/check.sh`. Run it via `dart run melos …`.

## Notes

- `pubspec.lock` is gitignored, so a local re-resolve leaves no tracked diff.
- A published version is immutable and effectively unretractable. Prefer another
  `-dev.N` prerelease over trying to "fix" a bad publish.
