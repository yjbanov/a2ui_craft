---
name: a2ui-craft-adapters
description: >-
  Use when modifying, reviewing, or extending an A2UI Craft framework adapter
  (packages/a2ui_craft_flutter, packages/a2ui_craft_jaspr, or a new one) — its
  runtime, core components, RemoteComponent, or public API. Enforces the
  cross-adapter invariants: what MUST stay identical across every adapter and
  where framework-specific deviation is allowed. Trigger on any edit under
  packages/a2ui_craft_*/lib, on changes to the core (packages/a2ui_craft), or
  when asked to add/change a core component, the runtime, or the adapter API.
---

# Evolving A2UI Craft adapters

A2UI Craft is one framework-agnostic engine with thin per-framework adapters.
The whole value of the project is that **the same template renders identically
on every framework**. These rules keep that true as the adapters evolve. They
mirror `DESIGN.md` §5 — read it if anything here is unclear; `DESIGN.md` is the
source of truth.

## First question to ask: does this belong in the core or an adapter?

- **Language, parsing, AST, data model, reconciliation semantics → core
  (`packages/a2ui_craft`).** Never put these in an adapter.
- **Turning an evaluated node into a framework node, and the leaf widget
  implementations → adapter.**

If you are about to add parsing or template semantics to an adapter, stop — it
belongs in the core.

## MUST be identical across every adapter (no deviation)

1. **Template language & semantics.** Adapters consume the RFW format unchanged.
   No adapter adds, removes, or reinterprets language features (data binding,
   `...for`, `switch`, `state`, `event`, args). Parsing is core-only.
2. **Public API surface & names** — component-centric everywhere (never Flutter's
   "Widget" vocabulary in public names):
   - `Runtime` with `update(LibraryName, WidgetLibrary)` and
     `build(context, FullyQualifiedWidgetName, DynamicContent, RemoteEventHandler)`
   - `RemoteComponent` with fields `runtime`, `component`, `data`, `onEvent`
   - `LocalComponentLibrary` / `LocalComponentBuilder`
   - `DataSource` with `v<T>`, `child`, `childList`, `voidHandler`, `handler<T>`
   - `RemoteEventHandler`, `createCoreComponents()`
3. **Runtime behavior.** Reconciliation, data-path subscription, scope/relative
   path resolution, loop/switch expansion, local `state`, event dispatch — all
   behave identically. A template that works on one adapter works on all.
4. **Core component contract.** For every shared core component (`Text`, `Row`,
   `Column`, `Button`, …) the *name*, *argument names*, and *observable behavior*
   are identical across adapters.

## MAY deviate (framework latitude)

1. The **node type** produced (`Widget` vs `Component` vs …).
2. **How** a core component is realized (`Row` → Flutter `Row` vs `<div
   style="display:flex">`; `Button` → `GestureDetector` vs `<button>`). The
   mapping is the adapter's job; the contract is not.
3. **Framework lifecycle integration** (`StatefulWidget`/`State`/`setState` vs the
   framework's equivalent; how `RemoteComponent` hosts the built node).
4. **Styling/layout mechanics** inherent to the rendering engine, as long as the
   observable result honors the component contract.

## Workflow for any adapter change

1. If the change is language/parsing/data/reconciliation, make it in the **core**,
   not an adapter.
2. If it touches the **public API** or a **core component**, apply the *same*
   change to **every** adapter in the same change set. Keep names, argument
   names, and behavior identical. Do not let the adapters drift.
3. Keep each runtime behaviorally identical; the only legitimate per-adapter
   runtime differences are node type, lifecycle host, and leaf rendering.
4. Adding or changing a **core component** is governed by
   `packages/a2ui_craft_testing`:
   - Update the catalog manifest (`coreCatalog`) — the canonical set of component
     names every adapter must implement. A per-adapter contract test
     (`test/catalog_contract_test.dart`) asserts each adapter implements exactly
     it.
   - Add behavior to the shared conformance suite (`runCoreComponentConformance`,
     driven through the framework-neutral `CraftTester`), **not** to one adapter's
     test. Each adapter runs the same suite via `test/conformance_test.dart`.
   - Behavioral identity is the bar, not pixel identity (Material vs. Cupertino).
     To make a control activatable cross-framework, give it a `key` arg (located
     uniformly via `find.byKey`) — `jaspr_test` does not bubble events.
5. Verify with the single workspace check (resolve + format + analyze + test all
   packages): `./tool/check.sh`.
6. If you cannot satisfy a MUST invariant to make a framework work, **stop**. That
   is a real design gap. Surface it; if it points at A2UI Transport or RFW
   itself, write it up rather than quietly forking behavior.

## Red flags (you are probably breaking the design)

- Parsing or template semantics appearing inside an adapter.
- An adapter's public API name/shape diverging from the others.
- A template that renders on one adapter but not another.
- Flutter/Jaspr types leaking into `packages/a2ui_craft`.
- "I'll just special-case this one component in the Flutter adapter" — if it's a
  core component, the special-casing must be expressible within the shared
  contract or it isn't a core component.

## Scope reminder

Current scope is **Flutter + Jaspr, Dart-only**, and the core component sets are
**minimal harness fixtures**. The real cross-platform core component/type library
(`DESIGN.md` H2) is deliberately **not started yet** — do not begin it unless the
task explicitly asks for H2 work. To add a *new framework* adapter, see the
`a2ui-craft-new-framework` skill.
