# AGENTS.md

Guidance for AI coding agents working in this repository. Humans should read
[`README.md`](README.md) and [`DESIGN.md`](DESIGN.md) — agents should read those
too. `DESIGN.md` is the **source of truth** for direction and decisions; when
code and `DESIGN.md` disagree, fix one of them deliberately.

## Project overview

A2UI Craft is a **framework-agnostic, client-side templating engine**. It renders
declarative UI templates (RFW — Remote Flutter Widgets — text format) using a
target UI framework, binding them to a reactive data model. The goal is to prove
that one engine can drive many rendering engines.

It is a Dart [pub workspace](https://dart.dev/tools/pub/workspaces):

- `packages/a2ui_craft` — core engine. Pure Dart, **no UI-framework dependency**:
  parsing, AST, binary format, and the `DynamicContent` reactive model.
- `packages/a2ui_craft_flutter` — adapter that renders templates as Flutter widgets.
- `packages/a2ui_craft_jaspr` — adapter that renders templates as HTML DOM (Jaspr).

## Dev environment

Requires the **Flutter SDK** (its bundled Dart runs the pure-Dart and Jaspr
packages too). One workspace member depends on Flutter, so the whole workspace is
resolved with `flutter pub get`. The core package itself stays Flutter-free;
only the workspace *resolution* involves the Flutter SDK.

```bash
flutter pub get                # resolve the entire workspace
```

## Build & test

Before considering a change complete, run the single workspace check (this is
exactly what CI runs — resolve, format-check, analyze, and test every package):

```bash
./tool/check.sh
```

Individual commands, if you need them:

```bash
dart test packages/a2ui_craft                 # core engine (pure Dart)
dart test packages/a2ui_craft_jaspr           # Jaspr adapter conformance + contract
flutter test packages/a2ui_craft_flutter      # Flutter adapter conformance + contract
cd packages/a2ui_craft_jaspr/example && jaspr serve   # run the Jaspr example
```

Cross-framework behavior is verified by `packages/a2ui_craft_testing`: a
framework-neutral **conformance suite** (`runCoreComponentConformance`) that each
adapter runs against its own renderer through a `CraftTester`, plus a **catalog
contract** (`coreCatalog`) pinning the component set. Behavioral identity is the
bar, not pixel identity. When you add or change a core component, extend the
shared catalog + conformance suite — not a single adapter's test (see
[`DESIGN.md` §5](DESIGN.md) and the `a2ui-craft-adapters` skill).

## Code style

- Match the surrounding code; format with `dart format`.
- Lints are shared via the root `analysis_options.yaml`; keep `analyze` clean.
- Sort imports: `dart:` first, then `package:` (alphabetical), then relative.

## Working on framework adapters (read this before touching `packages/a2ui_craft_*`)

The whole project depends on **the same template rendering identically on every
framework**. The rules that keep this true are specified in [`DESIGN.md` §5](DESIGN.md)
and elaborated in the project skills under [`skills/`](skills):

- [`skills/a2ui-craft-adapters`](skills/a2ui-craft-adapters/SKILL.md) — the
  cross-adapter invariants: what MUST stay identical across adapters (template
  language/semantics, public API names, runtime behavior, the core-component
  contract) and where framework-specific deviation is allowed (node type, how a
  component is realized, lifecycle integration, styling mechanics).
- [`skills/a2ui-craft-new-framework`](skills/a2ui-craft-new-framework/SKILL.md) —
  the recipe for standing up a new framework adapter.

> Note: `skills/` follows the [Agent Skills](https://agentskills.io/specification)
> `SKILL.md` open standard, placed in a vendor-neutral location. The format is
> standardized but a cross-agent discovery location is not yet, so some agents
> may not auto-load these — read them directly when doing adapter work.

Quick rules of thumb:

- Language, parsing, AST, data model, and reconciliation semantics belong in the
  **core**, never in an adapter.
- Changes to the public API or a core component must be applied to **every**
  adapter in the same change set, with identical names, argument names, and
  behavior.
- Add/extend a parity test so the same template is proven to work across adapters.
- If a framework genuinely cannot satisfy an invariant, that is a design finding —
  document it in `DESIGN.md` rather than forking behavior.

## Scope guardrail

Current scope is **Flutter + Jaspr, Dart-only**. The core component sets are
**minimal harness fixtures**. The real cross-platform core component/type library
("H2" in `DESIGN.md`) is deliberately **not started yet** — do not begin it unless
a task explicitly calls for H2 work.
