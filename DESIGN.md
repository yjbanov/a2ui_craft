# A2UI Craft — Design

> **Status:** active. This document is the source of truth for the project's
> direction. Code and skills should defer to it; when reality and this document
> disagree, fix one of them deliberately.

## 1. What A2UI Craft is

A2UI Craft is a **framework-agnostic, client-side templating engine**. It takes
declarative UI templates written in the **RFW (Remote Flutter Widgets) text
format** and renders them with a target UI framework (Flutter, Jaspr, …),
binding the template to a reactive data model.

It is *not* a new language and *not* an ahead-of-time compiler to a wire format.
We adopt RFW's existing language and runtime essentially as-is, and generalize
the runtime so it is no longer tied to Flutter.

## 2. Why this shape (and why not the earlier AOT-to-A2UI idea)

The project briefly explored a new language ("Craft") that would AOT-compile
straight into [A2UI](https://github.com/google/A2UI) Transport (JSON) messages.
That doesn't work, for a fundamental reason:

- A **template** is a pure function `(data, state) → UI`. It describes what the
  UI should look like for the current inputs; it ignores prior UI state.
- **A2UI Transport** is an *imperative* protocol over a *stateful* surface
  (`updateComponents` presupposes a prior tree to mutate). Turning a template
  into Transport requires evaluating it with concrete data *and* diffing against
  the previously produced tree — i.e. **reconciliation** — which a compiler
  cannot do, because neither the data nor the prior tree exist at compile time.

So a template needs a **runtime engine** that owns state and reconciliation.
Two places that engine could live:

- **Server-side**: re-introduces a network round-trip for every local
  interaction and forces the server to hold per-client UI state. Against A2UI's
  grain.
- **Client-side**: local interactivity stays local; the engine renders templates
  using whatever framework the client is built on. **This is the approach we
  take, and it is exactly what RFW already is.**

### How this relates to A2UI

A2UI is already renderer-agnostic — it composes UI out of **catalog** items and
doesn't care how a renderer implements them. A2UI Craft slots in cleanly:

> The agent (e.g. an A2UI Python SDK app talking to an LLM) speaks A2UI against a
> plain catalog of components. It does **not** know templates exist. When it says
> `updateComponents … component="WeatherCard"`, the client picks a template
> named `WeatherCard` and renders it with its framework. There can be several
> client implementations — e.g. Flutter on mobile, Jaspr on web — all honoring
> the same catalog. A2UI's per-surface data model becomes the engine's
> `DynamicContent`.

In other words: **A2UI Craft templates are an implementation of an A2UI
catalog**, as opposed to wrapping native widgets one-for-one.

The vetted vocabulary (primitive widgets and higher-level templates) is
**predefined by the client** and registered once; an A2UI message only
**composes** it. How that composition is rendered — and how it stays correct
under A2UI's id-addressed, incremental updates — is the subject of §6.

> The first implementation in `a2ui_craft_bridge` took a shortcut: it translated
> each surface into a synthesized `RemoteWidgetLibrary` (`widget root = …`) and
> rendered that. It works, but it conflates "compose predefined widgets" with
> "define a library," and it re-synthesizes/re-renders the whole tree on every
> update. §6 describes the architecture we are moving to instead.

## 3. The hypotheses we are proving

1. **H1 — RFW generalizes across rendering engines.** The RFW language and
   runtime, despite the "F", are not Flutter-specific. We prove this by making
   the *same* template + runtime drive two genuinely different rendering engines.
   - **Current scope: Flutter + Jaspr, Dart-only.** Jaspr is chosen because it is
     Dart (so we test the *factoring*, not a *rewrite*) yet renders to the HTML
     DOM — a different rendering engine from Flutter's canvas/`RenderObject`.
   - Known limitation we are *accepting for now*: Flutter and Jaspr share a
     similar *reactive/state* programming model (`build` + `setState`), so this
     pair stresses the **rendering-engine** axis well but the **state-model** axis
     weakly. We judge that low-risk because templates only need to turn
     A2UI-supplied data into UI; they don't author novel interaction models.
     Proving the state-model axis fully (SwiftUI, Jetpack Compose, React) is
     future work, not part of the current milestone.

2. **H2 — a single cross-platform core component/type library exists** that is
   expressive enough for A2UI use cases and maps cleanly onto every framework.
   This is where rendering-engine differences bite hardest (Flutter's explicit
   layout/animation vs. the HTML DOM's hard split between markup and blackbox
   CSS layout/animation). H2 has started — the component contract and conformance
   harness (§8) — but the cross-platform type/style model is still ahead. The
   current core component sets are intentionally minimal harness fixtures, not the
   real library.

A2UI Craft is deliberately a **least-common-denominator** engine. The hunch is
that this denominator is still quite expressive and covers many A2UI use cases.
When a developer needs deeper, framework-specific capabilities, the escape hatch
is to **drop down to the raw framework** (per-framework, but that's an advanced
case).

## 4. Architecture

```
┌─────────────────────────────────────────────────────────────┐
│ a2ui_craft  (core, pure Dart, NO UI-framework dependency)     │
│   parsing + AST + binary format (vendored RFW formats layer)  │
│   DynamicContent (reactive data model)                        │
└─────────────────────────────────────────────────────────────┘
        ▲                                   ▲
        │ depends on                        │ depends on
┌───────────────────────┐         ┌───────────────────────────┐
│ a2ui_craft_flutter     │         │ a2ui_craft_jaspr           │
│  Runtime → Flutter      │         │  Runtime → Jaspr           │
│  Widget; core comps as  │         │  Component; core comps as  │
│  Flutter widgets        │         │  DOM (div/flexbox)         │
└───────────────────────┘         └───────────────────────────┘
```

- **Core (`a2ui_craft`)** is the **vendored RFW *formats* layer** (`binary`,
  `model`, `text`) plus `content` (the `DynamicContent` reactive model). It is
  pure Dart with zero UI-framework dependency. We **vendor** rather than depend
  on `package:rfw` because RFW's `pubspec.yaml` pulls in Flutter even though its
  `formats.dart` library does not — so there is no Flutter-free way to consume it
  today. (A future upstream restructuring could remove the need to vendor.)

- **Adapters (`a2ui_craft_flutter`, `a2ui_craft_jaspr`)** each contain their own
  copy of the **runtime** (`Runtime`, `DataSource`, the curried-node machinery)
  plus a minimal core-component library. Each runtime is a near-verbatim port of
  RFW's runtime; the unavoidable reason it cannot be shared as-is is that RFW's
  runtime is parameterized by the framework's *node type* (Flutter `Widget` vs.
  Jaspr `Component`), and Dart cannot abstract over that cheaply. So the runtime
  is duplicated per framework **by design**, and kept behaviorally identical.

## 5. Adapter invariants — what MUST NOT deviate, and what MAY

This section is the contract that keeps the adapters honest. It is mirrored by
the project skill that governs adapter work.

The goal is **behavioral identity, not pixel identity** — like Flutter's Material
vs. Cupertino, the same contract can look different per framework. "Behavior"
means: the same template renders the same content, the same data bindings update
the same way, and the same interactions dispatch the same events.

### MUST be identical across every adapter (no deviation)

1. **Template language & semantics.** Adapters consume the RFW text/binary format
   unchanged. No adapter may add, remove, or reinterpret language features (data
   binding, `...for` loops, `switch`, `state`, `event`, args). Parsing lives in
   the core, not in adapters.
2. **Public API surface & names.** Every adapter exposes the same names with the
   same shapes:
   - `Runtime` (with `update(LibraryName, WidgetLibrary)` and
     `build(context, FullyQualifiedWidgetName, DynamicContent, RemoteEventHandler)`),
   - `RemoteComponent` (fields: `runtime`, `component`, `data`, `onEvent`),
   - `LocalComponentLibrary` / `LocalComponentBuilder`,
   - `DataSource` (with `v<T>`, `child`, `childList`, `voidHandler`, `handler<T>`),
   - `RemoteEventHandler`, `createCoreComponents()`.
   We use **component-centric** names everywhere (not Flutter's "Widget"
   vocabulary), so client code reads identically regardless of framework.
3. **Runtime behavior.** Reconciliation, data-path subscription, scope/relative
   path resolution, loop/switch expansion, local `state`, and event dispatch must
   behave identically. A template that works on one adapter must work on all.
4. **The core component contract.** For any component in the shared core library
   (`Text`, `Row`, `Column`, `Button`, …), the *name*, its *argument names*, and
   its *observable behavior* are identical across adapters.

### MAY deviate (framework latitude)

1. **Node type produced.** Flutter builds `Widget`s; Jaspr builds `Component`s.
2. **How a core component is realized.** `Row` → a Flutter `Row` vs. a
   `<div style="display:flex">`. `Button` → a `GestureDetector` vs. a `<button>`.
   The *mapping* is the adapter's job; the *contract* (name/args/behavior) is not.
3. **Framework lifecycle integration.** `StatefulWidget`/`State`/`setState` vs.
   Jaspr's equivalents; how `RemoteComponent` hosts the built node.
4. **Styling/layout mechanics** that are inherent to the rendering engine, as
   long as the observable result honors the component contract.

If you find yourself wanting to deviate on something in the MUST list to make a
framework work, that is a signal of a real design gap — surface it (and, if it
points at A2UI Transport or RFW itself, write it up) rather than quietly forking
behavior.

### How the contract is enforced

Two mechanisms in `packages/a2ui_craft_testing` turn the contract above into
automated checks:

- **Catalog manifest (`coreCatalog`)** — the canonical set of core component
  names. Each adapter has a contract test asserting its
  `createCoreComponents().widgets.keys` equals `coreCatalog`, so no adapter
  silently gains or drops a component.
- **Conformance suite (`runCoreComponentConformance`)** — a single,
  framework-neutral behavioral spec. Each adapter runs it against its own
  renderer through a small `CraftTester` abstraction (behavioral probes:
  "is this text visible?", "did activating this control fire its event?" —
  never pixels). A template that behaves differently on one framework fails its
  conformance run. Adding/altering a core component means extending the manifest
  and the suite, not writing per-adapter tests.

## 6. Rendering A2UI surfaces: composition, identity, and partial updates

This section defines how an A2UI surface is rendered, and the two small, additive
extensions to the RFW runtime it requires. It supersedes the "translate to a
library" shortcut noted in §2.

### The model: a predefined catalog that the message composes

Two things are **predefined by the client and registered once**:

- a `LocalWidgetLibrary` of primitive widgets (the native building blocks), and
- optionally a `RemoteWidgetLibrary` of vetted higher-level templates (e.g.
  `WeatherCard`) that may expose **slots** (`args.child` / `args.children`).

An A2UI message **never defines widgets**. It carries a *composition*: a flat,
id-referenced adjacency list of component *instances* that reference predefined
names and bind data. Rendering a component means looking it up in the predefined
catalog and composing it — A2UI's own "catalog of components" model.

Widgets and data live in two separate worlds in RFW, and this separation is
load-bearing:

- the **template/args world** holds widgets (nested `ConstructorCall`s, `args.*`
  projection, builders);
- the **data world** (`DynamicContent`) holds only plain values
  (`int/double/bool/String`, maps, lists).

We verified that data cannot carry widgets: `DataSource.child`/`childList` only
accept already-built widget nodes, a `data.x` reference resolves to a plain
value, and `DynamicContent` asserts its leaves are scalars. So a
dynamically-shaped A2UI tree **must** be expressed in the template/args world,
not smuggled through data. This is the trust boundary that stops runtime data
from injecting UI — and it's why the composition must be built as widget nodes at
render time.

### The adapter tree: host widgets are the retained A2UI component tree

Each A2UI component is rendered by a host wrapper widget, `A2uiToRfwAdapter`,
**keyed by the A2UI component id**. The adapter:

- renders its own component via `Runtime.buildNode` (below), and
- passes each child as a nested `A2uiToRfwAdapter` injected into the component's
  `child` / `children` slot.

So the **host framework's widget tree _is_ the A2UI component tree** — one keyed
adapter per id. The engine renders one component at a time (including a vetted
multi-node template with its slots). The rule: **structure _between_ components is
the adapters' job; structure _within_ a component (template internals) is RFW's.**
A predefined template's internals are never A2UI-addressable, which is exactly the
property we want for vetted components.

### Identity & reconciliation: why positional matching is not enough

Host frameworks reconcile children by `runtimeType` + `key`; with no key they
match **positionally**. RFW today attaches **no key** to its widget wrapper
(`_Widget`), so RFW subtrees reconcile purely by position. That is correct for
**in-place leaf updates** (same shape) but wrong for **insert / remove /
reorder**: shifting a child by one slot makes a sibling's element-held state (a
checkbox value, in-progress text input, scroll offset, animation) reconcile onto
the wrong widget, or get dropped.

A2UI components have **stable ids** and updates are **id-addressed**, with
reordering expected. So reconciliation must be **keyed by the A2UI id**, not by
position.

We adopt Flutter's own idiom for preserving identity through wrapper widgets.
`SliverChildBuilderDelegate.build` wraps each list child in decorators yet keeps
identity by **lifting the child's key onto the outermost wrapper** —
`KeyedSubtree(key: _SaltedValueKey(child.key), child: …)` — so the key sits at the
reconciliation position despite the wrappers. We do the same: RFW's `_Widget`
becomes the keyed wrapper, lifting a reserved `key` argument (set to the A2UI id)
as a typed `ValueKey` so host reconciliation matches RFW subtrees by A2UI id.
(Salting à la `_SaltedValueKey` — to stay `GlobalKey`-safe when a key value is
itself a `Key` — is deferred; current keys are scalar ids and the inner child is
unkeyed, so there is nothing to collide with.)

### Partial updates

State lives in two places, and each kind of update touches only what it must:

- **`updateDataModel`** writes to `DynamicContent`; RFW's existing path-keyed
  subscriptions rebuild only the bound nodes. No structural work.
- **`updateComponents`** is routed **per id**: the surface holds, per component
  id, a listenable of the latest component definition; only the addressed
  `A2uiToRfwAdapter` rebuilds, re-rendering from that node down. No whole-tree
  re-synthesis, no re-currying of unaffected nodes.

Localizing updates to the affected subtree (plus keyed reconciliation keeping
sibling/descendant state intact) is the main reason for the adapter tree.

### Two additive deviations from RFW (candidates to upstream)

Both are small, additive, and behavior-preserving for existing RFW usage. Each
will be recorded in `VENDORED.md` when implemented in the vendored runtimes, and
each is a good candidate to propose to upstream RFW.

1. **`Runtime.buildNode(context, composition, data, handler, {scope})`** — render
   an ad-hoc composition (a `ConstructorCall` whose slot arguments may be
   already-built host widgets) against the registered libraries, resolving names
   via `scope`. *Why A2UI needs it:* the structure is decided at runtime, and RFW
   otherwise renders only **named** declarations and **forbids recursive
   templates** — so there is no way to render a runtime-built tree without
   synthesizing a throwaway library per message.
2. **Keyed `_Widget`** *(done — M1)* — honor a reserved literal `key` argument,
   lifted onto the `_Widget` wrapper as a typed `ValueKey`. *Why A2UI needs it:*
   id-addressed updates with reordering require identity-based reconciliation. It
   also independently improves RFW for any dynamic-list UI, so it has merit beyond
   A2UI.

These replace the earlier idea of a "transparent injection" that bypassed the
wrapper: lifting the key onto the wrapper is the idiomatic Flutter approach and
solves both the standalone-RFW and A2UI cases with one mechanism.

### Lists and scope (the delicate part)

A2UI `ChildList` templates (data-driven lists) create a child data scope:
relative bindings resolve against each item. With the adapter tree, RFW's loop
machinery does **not** span the adapter boundary, so the **list adapter** iterates
the data array itself, spawns one keyed item adapter per item (keyed by item
identity, à la `KeyedSubtree.wrap(child, index)`), and hands each a **scoped** view
of the data so relative bindings resolve. This is the most delicate piece; it is
designed and built as its own step, after the static-children path is proven.

## 7. Repository layout

```
a2ui-craft/
├── DESIGN.md                     # this document (source of truth)
├── README.md
├── AGENTS.md                     # agent-agnostic guidance (build/test, pointers)
├── LICENSE                       # BSD-3-Clause (forked from RFW)
├── VENDORED.md                   # provenance of vendored RFW code
├── pubspec.yaml                  # Dart pub workspace root
├── tool/check.sh                 # one entrypoint: resolve + format + analyze + test
├── tool/testing/                 # repo-wide checks (e.g. license headers); not published
├── .github/workflows/ci.yml      # CI: runs tool/check.sh
├── skills/                       # project skills (adapter-authoring guidance)
└── packages/
    ├── a2ui_craft/               # core: vendored RFW formats + DynamicContent
    ├── a2ui_craft_bridge/        # A2UI Transport → engine (framework-neutral)
    ├── a2ui_craft_testing/       # shared conformance suite + catalog (not published)
    ├── a2ui_craft_flutter/       # Flutter adapter (runtime + core comps + test)
    └── a2ui_craft_jaspr/         # Jaspr adapter (runtime + core comps + example + test)
```

Run `tool/check.sh` to verify the whole workspace (format, analyze, and tests for
every package) — it is exactly what CI runs.

Because one member (`a2ui_craft_flutter`) depends on the Flutter SDK, the whole
workspace is resolved with **`flutter pub get`** (Flutter's bundled Dart also runs
the pure-Dart and Jaspr packages fine). The *core* package itself remains
Flutter-free; only the workspace resolution involves the Flutter SDK.

## 8. Status & roadmap

- [x] Pivot to client-side templating engine; drop the AOT-to-Transport idea.
- [x] Core = vendored, Flutter-free RFW formats layer + `DynamicContent`.
- [x] Jaspr adapter: runtime + minimal core components (`Text/Row/Column/Button`)
      + counter example.
- [x] Flutter adapter: runtime + minimal core components + widget test proving
      parse → render → event → reactive update.
- [x] Project skills governing adapter evolution.
- [x] Dev harness: shared parity-test fixture (`a2ui_craft_testing`) rendered
      identically by both adapters; single `tool/check.sh` entrypoint; CI;
      `LICENSE` + `VENDORED.md` provenance.
- [~] **H2:** the cross-platform core component/type library. **Started:** the
      component contract (`coreCatalog`) and the cross-framework behavioral
      conformance harness (`runCoreComponentConformance` + `CraftTester`) are in
      place, validated on the seed components. **Next:** the framework-neutral
      type/style model (the `argument_decoders` replacement) and growing the
      component set.
- [~] A2UI integration: render an A2UI catalog + data model with the engine
      (§6). **Done (interim):** `a2ui_craft_bridge` renders the seed catalog
      (Text/Row/Column/Button) incl. data bindings, `ChildList` templates, and
      events — verified on both adapters via `runA2uiConformance` and the Jaspr
      example, but via the "synthesize a library" shortcut (§2). **Rework to the
      §6 architecture, built bottom-up (interim bridge stays green until M3):**
  - [x] **M1** — keyed `_Widget` (literal `key` lifted onto the wrapper) on both
        runtimes, with a reorder-reconciliation test. The linchpin; independently
        improves RFW.
  - [ ] **M2** — `Runtime.buildNode` (render an ad-hoc composition + inject host
        widgets as slot args) on both runtimes.
  - [ ] **M3** — `A2uiToRfwAdapter` + per-id listenable surface (static children);
        switch the demo/conformance over and retire the shortcut.
  - [ ] **M4** — data-driven lists: list adapter + scoped data views.
  - [ ] **Then** — functions/`formatString`, more components, two-way-binding
        inputs, `deleteSurface`, theme.
        (M1 & M2 are vendored-RFW divergences: record in `VENDORED.md`; propose
        upstream.)
- [ ] Prove the state-model axis with a third, non-Flutter-like framework.
- [ ] Consider upstream RFW restructuring so the formats layer need not be
      vendored.

## 9. Open questions

- **Core component vocabulary (H2):** what is the least-common-denominator set,
  and how are layout/animation differences reconciled between Flutter and the
  DOM?
- **Type model:** the equivalent of RFW's `argument_decoders` is intensely
  Flutter-specific and is explicitly *not* part of the core; H2 must define a
  framework-neutral type/style model that each adapter maps down.
- **Template packaging & richer A2UI catalog binding:** the basic binding
  exists (`a2ui_craft_bridge` maps A2UI `component` types to core components by
  name). Still open: named higher-level templates (e.g. a `WeatherCard` template
  resolving an A2UI `component="WeatherCard"`), and how such templates are
  authored, bundled, and versioned alongside a catalog.
