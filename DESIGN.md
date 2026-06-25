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

### The two-level catalog: agent-facing high-level widgets vs. template-private primitives

There are **two distinct catalogs**, and conflating them is the central mistake to
avoid:

1. **Low-level catalog** — a rich set of primitives (`Text`, `Row`, `Column`,
   `Button`, `TextField`, `Checkbox`, `Image`, …). This is **never exposed to the
   agent.** A large primitive vocabulary bloats model context (defeating small,
   fast models), and letting an LLM compose primitives at runtime is
   unpredictable and impossible to vet before deployment — which kills high-trust
   business use-cases. Primitives exist to be composed **by templates, at
   design/build time.**
2. **High-level catalog** — a *small*, vetted set of domain widgets
   (`WeatherCard`, `ProductCard`, `FifaStandings`, …) plus a few layout widgets
   (`Grid`, `Carousel`, `List`) that give the agent enough control to arrange
   them for good information architecture. **This is the only catalog A2UI
   references at runtime:** small context, low latency, predictable output, each
   widget pre-vetted. **Every high-level widget is materialized from a template.**

**Templates (RFW) are the bridge between the two levels.** A high-level widget is
authored once as an RFW template that composes the low-level catalog (and may
reuse other high-level widgets — e.g. a `ProductList` template using `ProductCard`
— but that is the template's private business; an agent can equally place a bare
`ProductCard`). Authoring high-level widgets as templates — rather than
hand-writing each one natively per framework — is exactly what buys cross-framework
reuse: the same template renders on Flutter and Jaspr. **This is the core of H1,
and the reason RFW is load-bearing here** even as the A2UI protocol/data layer
moves to `a2ui_core` (§10).

A2UI operates **only** on the high-level catalog. The bridge maps an A2UI
high-level component to its template; the template composes the low-level catalog.
§6 covers how that composition is rendered and kept correct under partial updates,
and the concrete template layer; §10 covers how `a2ui_core` layers above it.

The vetted vocabulary (primitive widgets and higher-level templates) is
**predefined by the client** and registered once; an A2UI message only
**composes** it. How that composition is rendered — and how it stays correct
under A2UI's id-addressed, incremental updates — is the subject of §6.

> The first implementation in `a2ui_craft_bridge` took a shortcut: it translated
> each surface into a synthesized `RemoteWidgetLibrary` (`widget root = …`) and
> rendered that. It worked, but it conflated "compose predefined widgets" with
> "define a library," and it re-synthesized/re-rendered the whole tree on every
> update. That shortcut has been replaced by the §6 architecture (per-id host
> adapters + `Runtime.buildNode`), which composes the predefined catalog directly
> and updates each component in place.

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

Both are small, additive, and behavior-preserving for existing RFW usage. Each is
recorded in `VENDORED.md` (extensions #6 and #5) and is a good candidate to
propose to upstream RFW.

1. **`Runtime.buildNode(context, composition, data, handler, {scope})`** *(done —
   M2)* — render an ad-hoc composition (a `ConstructorCall` whose slot arguments
   may be already-built host widgets) against the registered libraries, resolving
   names via `scope`. *Why A2UI needs it:* the structure is decided at runtime,
   and RFW otherwise renders only **named** declarations and **forbids recursive
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
relative bindings resolve against each item. We render this with **RFW's own
`Loop`**, emitted *inside* the owning component's `buildNode` composition (the
`ChildList` becomes `children: [ ...for x in <input>: <template> ]`). RFW already
gives us everything a list needs here: it unrolls the data array, scopes each
item via a depth-aware `LoopReference` (so relative bindings — including nested
`ChildList`s — resolve against the right item), and rebuilds reactively when the
array changes. A separate host-side "list adapter" was considered and rejected:
its only extra power was per-item *keyed* identity, which the limitation below
makes moot, and A2UI list items are template instances (one shared `componentId`),
so they are not individually id-addressable anyway. (M4)

**Known limitation — positional reconciliation of unrolled children.** Static
components reconcile **keyed by their A2UI id** (above), but the A2UI spec
currently attaches **no stable identifier to the elements of a data array** that a
`ChildList` unrolls. With no per-item id to key on, list items are reconciled
**positionally** — index 0 onto index 0, and so on. This is precisely the
imprecise behavior this section otherwise argues against: inserting, removing, or
reordering items in the *middle* of a list shifts every following item by a slot,
so element-held state (a checkbox value, in-progress text input, scroll offset,
animation) reconciles onto the wrong item or is dropped. In-place item updates and
append/truncate at the *end* are unaffected; only mid-list structural churn is.

We **accept this cost** rather than invent a client-side key — indexes don't help
(they *are* the position), and hashing item contents is fragile and breaks on
edits. The proper fix belongs in the protocol and is filed as
[a2ui#1745](https://github.com/a2ui-project/a2ui/issues/1745): give `ChildList`
items a stable identifier (a per-item key, or a template-declared key path),
resolved at the spec and `a2ui_core` level. This is **protocol-inherent, not an RFW
artifact**: `a2ui_core`'s own `GenericBinder` unrolls a `ChildList` into
`ChildNode`s that share the template `componentId` and are distinguished only by an
index-based `basePath` — i.e. the reference implementation reconciles list items
positionally for the same reason.

**Design policy — keyed-when-present, positional-fallback (permanent).** The engine
keys each unrolled child instance by a **per-item key when the list provides one**,
and **falls back to the positional index when it does not**. This is *not* an
interim stance that a2ui#1745 retires: even once the spec gains per-item keys, they
are **opt-in** — an agent or a template can always emit an unkeyed list — so the
engine must never assume keys are present and must degrade to positional
reconciliation gracefully. The fallback is therefore permanent; the keyed path is
an *upgrade* applied per list, not a global mode switch.

We are already **structurally ready** for the fix: keyed reconciliation reuses the
keyed-`_Widget` (M1) / per-id-adapter (M3) machinery; only the **key source**
changes (today: none → positional index; post-fix: the item's key surfaced by
`a2ui_core`'s `ChildNode`). Per-item keys are **scoped within their parent list**
(salted by the list's component id) so a list-item key can never collide with a
sibling component's A2UI-id key.

### The template layer: what A2UI references, and what the bridge targets

Per the two-level catalog (§2), **A2UI components reference high-level widgets,
each backed by an RFW template**; the bridge maps a component to its template, and
the template composes the low-level catalog.

Low-level catalog — an RFW `LocalWidgetLibrary`, implemented per framework:

```
core: Text, Row, Column, Button, Image, TextField, Checkbox, …
```

High-level catalog — an RFW `RemoteWidgetLibrary`, authored once and vetted at
build time (`import core;`):

```
widget ProductCard = Column(children: [
  Image(src: args.imageUrl),
  Text(text: args.title),
  Text(text: args.price),
  Button(onPressed: event 'addToCart' { productId: args.id },
         child: Text(text: 'Add to cart')),
]);

// a layout widget: its children are supplied by A2UI at runtime
widget Grid = Column(children: args.children);
```

An A2UI message references only high-level names; a component's props are the
template's `args`, and a layout widget's `children` are child component ids:

```
{ "id": "root", "component": "Grid", "children": ["p1", "wx"] }
{ "id": "p1", "component": "ProductCard", "title": …, "imageUrl": … }
```

Rendering is exactly the M1–M4 machinery, re-pointed at the high-level library:
the `p1` adapter (keyed by its id) renders `buildNode(ConstructorCall('ProductCard',
{…props…}), scope: catalogLib)`; `'ProductCard'` resolves to the **template**,
which imports and composes `core`. `Grid`'s `args.children` receive the child
adapters (`p1`, `wx`) via host-widget injection, reconciled by id under partial
updates.

**Known gap (current code).** The bridge today maps A2UI components straight to
low-level `core` components, and A2UI references those primitive names — i.e. it
treats the low-level catalog as if it were the high-level one (a degenerate case
where high == low, no templates). The high-level template library, and pointing
the bridge's `scope` at it, is the next structural step (M5).

**Mechanic validated (M5 spike).** `template_layer_spike_test` (both adapters)
proves the rendering path with **no runtime changes**: `buildNode` resolves a
*named* high-level template against `scope: catalog` (which `import core;`), binds
component props as `args`, composes the low-level catalog, and — the previously
open question — injects runtime host-widget `children` through a named template's
`args.children` (e.g. a `Grid` of injected `ProductCard`s). What remains for M5 is
**bridge wiring only**: register the high-level `RemoteWidgetLibrary`, point the
adapter's `scope` at it, and map A2UI component props → template `args`
generically (children → injected child adapters), replacing the hardcoded
low-level type switch.

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
      (§6). **Done:** `a2ui_craft_bridge` renders the seed catalog
      (Text/Row/Column/Button) incl. data bindings, `ChildList` templates, and
      events — verified on both adapters via `runA2uiConformance` and the Jaspr
      example. The "synthesize a library" shortcut (§2) is retired; rendering now
      follows the §6 architecture (per-id host adapters + `Runtime.buildNode`),
      built bottom-up:
  - [x] **M1** — keyed `_Widget` (literal `key` lifted onto the wrapper) on both
        runtimes, with a reorder-reconciliation test. The linchpin; independently
        improves RFW.
  - [x] **M2** — `Runtime.buildNode` (render an ad-hoc composition + inject host
        widgets as slot args, transparently) on both runtimes.
  - [x] **M3** — `A2uiToRfwAdapter` + per-id listenable surface (static children);
        demo/conformance switched over and the shortcut retired. Covered by
        per-id partial-update isolation, child replace/removal, forward-reference,
        and custom-catalog reorder-identity tests.
  - [x] **M4** — data-driven lists via RFW's `Loop` (emitted inside the owning
        component's `buildNode`): array unroll, depth-scoped item bindings
        (incl. nested `ChildList`s), and reactive add/remove/field-update through
        `updateDataModel` (now array-index-aware). Unrolled items reconcile
        **positionally** — the A2UI spec has no per-item id to key on (known
        limitation, §6; spec fix filed as
        [a2ui#1745](https://github.com/a2ui-project/a2ui/issues/1745)). Policy is
        keyed-when-present, positional-fallback (§6) — the fallback is permanent.
        No new RFW deviation (Loop is used as-is). Covered by bridge unit tests
        (list field/append/remove, nested-loop scoping) and cross-adapter
        conformance (list grow/shrink, per-item update, nested lists).
  - [ ] **M5 — the template layer (§6).** Author the high-level catalog as an RFW
        `RemoteWidgetLibrary` over the low-level `core` library, point the bridge's
        `scope` at it, and feed component props as template `args`. This is the
        degenerate-case fix (today high == low) and the heart of the hypothesis.
        Validate named-template invocation with injected host-widget `children`.
  - [ ] **M6 — layer `a2ui_core` underneath the protocol/data half (§10).** Adopt
        `a2ui_core` for A2UI ingest, the data model, and binding/function/`checks`
        resolution; keep RFW + the bridge for template materialization. This is how
        functions/`formatString`, `checks`, two-way-binding inputs, theme, and
        `deleteSurface` are delivered — by delegation, **not** by building them on
        RFW (whose AST has no function/expression node). `deleteSurface` also
        retires the current map-growth limitation (`A2uiSurface._components` /
        `_componentListenables` grow monotonically; a2ui_core owns that lifecycle).
        (M1 & M2 are vendored-RFW divergences: recorded in `VENDORED.md`; propose
        upstream.)
  - [ ] **Then** — grow the high-level catalog; richer layout widgets.
- [ ] **H2 type/style model** (the `argument_decoders` replacement) — the unlock
      for more low-level components and theme; see §9.
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
- **List-item identity — filed as [a2ui#1745](https://github.com/a2ui-project/a2ui/issues/1745).**
  A2UI gives every *component* a stable id but attaches **no identifier to the
  elements of a data array** unrolled by a `ChildList`, forcing positional
  reconciliation for list items (§6). The fix is requested at the spec +
  `a2ui_core` level. Our side is **keyed-when-present, positional-fallback
  (permanent)** — see §6; the fallback stays even after keys land, since per-item
  keys are opt-in. To adopt keys when available: surface the item key from
  `a2ui_core`'s `ChildNode` and set it as the child adapter's key (salted by the
  parent list id). Track the issue for the final key shape.
- **`a2ui_core` seam (§10):** with `a2ui_core` resolving props to concrete values
  fed as template `args`, reactivity becomes component-granular (whole-component
  rebuild) rather than per-binding. Open: is that granularity acceptable for the
  high-level catalog (likely yes — small vetted widgets), and how exactly do
  template-internal inputs wire back to `a2ui_core`'s two-way setters?

## 10. Layering with `a2ui_core` (planned direction)

`a2ui_core` (the Dart core package in `flutter/genui` that backs the `genui`
Flutter renderer — mirroring how `web_core` backs the Angular/React/Lit renderers)
owns the A2UI protocol, the data model, and the resolution of
bindings/functions/`checks`. It is **complementary to RFW, not a replacement**:
`a2ui_core` sits *above* the template layer, RFW sits *below* it. This supersedes
the protocol/data half of the interim bridge; the template/rendering half (§6)
stays on RFW.

### The stack

```
A2UI message (high-level component refs + data + functions/checks)
  │  a2ui_core: MessageProcessor + DataModel + GenericBinder
  ▼  → resolved props (concrete scalars), id'd child tree, action callbacks, two-way setters
  │  bridge (thin): component name → RFW template; resolved props → template ARGS;
  │                 inject child adapters; wire callbacks → events
  ▼
  │  RFW: buildNode(ConstructorCall(templateName, {args, children:[adapters]}), scope: catalogLib)
  │       template composes the LOW-level catalog (args.* / internal ...for / switch)
  ▼
Flutter / Jaspr low-level widgets
```

### Why this is the right division

RFW is the **build-time template engine** that materializes high-level widgets
from low-level primitives, once, cross-framework (§2). `a2ui_core` is the
**runtime A2UI layer** — protocol, data, and the value-level computation RFW
deliberately lacks (functions/`formatString`, `checks`, two-way binding, theme;
RFW's AST has no function/expression node). Building those on RFW would duplicate
canonical logic and diverge from the reference implementation.

### The seam

`a2ui_core` resolves bindings/functions/`checks` to **concrete values**, handed to
a template as **args** — not data references. Consequences:

- **RFW's data layer (`DynamicContent`, `data.x` path bindings) is no longer used
  for A2UI.** Reactivity moves to **component granularity**: when inputs change,
  `a2ui_core`'s `resolvedProps` signal fires, the per-id adapter rebuilds, and
  `buildNode` re-renders the template with new args.
- **RFW's `Loop` survives only for template-*internal* iteration** over an args
  list (`...for p in args.products`). The A2UI-level `ChildList` is resolved by
  `a2ui_core` into the id'd child tree and injected as host adapters.
- A `preact_signals → setState` bridge per adapter, plus wiring `a2ui_core`
  actions / two-way setters to RFW `EventHandler` / `voidHandler`.

### What moves, stays, and gets built

| Concern | Disposition |
| --- | --- |
| A2UI ingest (`A2uiSurface`), `SurfaceListenable`, `_buildComponent`/`_children`→`Loop`, `_value`/`_pathRef` | **delete** → `a2ui_core` |
| A2UI data (`DynamicContent`) + M4 data-path (`_applyDataUpdate`/`_descend`/`_assign`/`_segment`) | **delete** → `a2ui_core` `DataModel` |
| functions/`formatString`, `checks`, two-way setters, theme, `deleteSurface` (+ the map-growth leak) | **don't build** → `a2ui_core` provides |
| RFW runtime: `buildNode`, host-injection, keyed `_Widget`, `Loop`, `args`, `Switch` (M1/M2) | **keep** |
| low-level `core_components` catalog | **keep** |
| per-id adapter tree (M3) | **keep, re-rooted** on `a2ui_core`'s component tree + `resolvedProps` signals |
| the bridge | **keep, thin** — name→template, args feed, child injection, event wiring |
| high-level template `RemoteWidgetLibrary` | **build** (the missing layer, §6 / M5) |

M1–M4 are not wasted: they are the template-rendering plumbing. Only the
protocol/data/binding half of the bridge is delegated.

### Risks & status

- **Maturity:** `a2ui_core` is pre-1.0 (`0.0.1-wip002`); API may churn. It is the
  canonical direction (the JS stack already follows it).
- **Pure-Dart deps** (`collection`, `json_schema_builder`, `meta`,
  `preact_signals` — no Flutter), so Jaspr-compatible.
- **Status: planned, not started (M6).** De-risk with a thin Jaspr spike — a
  `ProductCard` + `Grid` template library over `core`, an A2UI surface placing two
  cards in a grid, `a2ui_core` resolving one `formatString` and one
  `updateDataModel` — before deleting anything.
