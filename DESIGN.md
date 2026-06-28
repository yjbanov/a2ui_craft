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

## Glossary

These terms recur throughout and are easy to conflate; this document uses them
precisely ("primitive" and "catalog" replace the older "low-level catalog" /
"high-level catalog"):

- **Primitive** — a single **low-level** building block available to template code
  (`Text`, `Row`, `Box`, `Button`, `Image`, …): one entry in an RFW
  **`LocalWidgetLibrary`**. Primitives are expressive, cross-framework, and
  **template-private** — composed *by* templates at build time, never referenced
  by an agent. A primitive may come from the **core primitives** we ship *or* be a
  **custom primitive** an app defines (apps super-set and sub-set the core set —
  see §11 "Extensible by design").
- **Core primitives** — the **standard** primitive set A2UI Craft ships (the
  base/standard primitives). `createCoreComponents()` builds them and
  `corePrimitives` pins the contract every adapter must implement. Unqualified,
  "primitives" means the general category; "core primitives" means specifically our
  shipped set.
- **Catalog** — the **high-level**, **agent-facing** set of semantic widgets
  (`WeatherCard`, `ContactCard`, …) that an A2UI message references at runtime.
  This is A2UI's own term — the agent speaks to a *catalog*. Each catalog widget is
  materialized from a **template** that composes primitives. In code this is
  `a2ui_core`'s `Catalog<ComponentApi>`.

In short: **a catalog widget is a template over primitives** — and the primitives
it composes are the core primitives plus any custom ones the app registers.

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

### The two-level model: agent-facing catalog widgets vs. template-private primitives

There are **two distinct catalogs**, and conflating them is the central mistake to
avoid:

1. **Primitives** — a rich set of primitives (`Text`, `Row`, `Column`,
   `Button`, `TextField`, `Checkbox`, `Image`, …). This is **never exposed to the
   agent.** A large primitive vocabulary bloats model context (defeating small,
   fast models), and letting an LLM compose primitives at runtime is
   unpredictable and impossible to vet before deployment — which kills high-trust
   business use-cases. Primitives exist to be composed **by templates, at
   design/build time.**
2. **Catalog** — a *small*, vetted set of domain widgets
   (`WeatherCard`, `ProductCard`, `FifaStandings`, …) plus a few layout widgets
   (`Grid`, `Carousel`, `List`) that give the agent enough control to arrange
   them for good information architecture. **This is the only catalog A2UI
   references at runtime:** small context, low latency, predictable output, each
   widget pre-vetted. **Every catalog widget is materialized from a template.**

**Templates (RFW) are the bridge between the two levels.** A catalog widget is
authored once as an RFW template that composes the primitives (and may
reuse other catalog widgets — e.g. a `ProductList` template using `ProductCard`
— but that is the template's private business; an agent can equally place a bare
`ProductCard`). Authoring catalog widgets as templates — rather than
hand-writing each one natively per framework — is exactly what buys cross-framework
reuse: the same template renders on Flutter and Jaspr. **This is the core of H1,
and the reason RFW is load-bearing here** even as the A2UI protocol/data layer
moves to `a2ui_core` (§10).

A2UI operates **only** on the catalog. The bridge maps an A2UI
catalog component to its template; the template composes the primitives.
§6 covers how that composition is rendered and kept correct under partial updates,
and the concrete template layer; §10 covers how `a2ui_core` layers above it.

The vetted vocabulary (primitive widgets and higher-level templates) is
**predefined by the client** and registered once; an A2UI message only
**composes** it. How that composition is rendered — and how it stays correct
under A2UI's id-addressed, incremental updates — is the subject of §6.

### Bias to templatize

Whenever a chunk of UI *can* be authored once as a template, it should be —
collapsing a tree of A2UI nodes into a single catalog widget is the core value
this project delivers. It moves complexity off the wire (and out of the agent) to
build time: the agent emits one `component="ContactCard"` plus data instead of a
dozen nested layout/text/image nodes. That buys **less for the agent to reason
about, fewer tokens over the wire, more predictable and pre-vettable output, and
richer visual expression** than an agent would assemble on the fly.

The rare exception is UI whose **structure is itself the agent's creative act** — a
one-off arrangement that could not have been conceived as a template ahead of
time. There, raw A2UI transport keeps expressive power a template would remove. But
that is the exception, not this project's focus: A2UI Craft exists to make the
**templating** path expressive and capable; developers choose, per surface, when to
template and when to fall back to raw A2UI.

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
   real library. **§11 defines the approach** for growing them: a *constrained
   common model* (flexbox-shaped, with an explicit value-type vocabulary) rather
   than mirroring either framework's native layout.

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
   - `RemoteWidget` (fields: `runtime`, `widget`, `data`, `onEvent`),
   - `LocalWidgetLibrary` / `LocalWidgetBuilder`,
   - `DataSource` (with `v<T>`, `child`, `childList`, `voidHandler`, `handler<T>`),
   - `RemoteEventHandler`, `createCoreComponents()`.
   We keep RFW's upstream public names verbatim, so the vendored runtime stays a
   clean, upstreamable delta and client code reads identically across frameworks.
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
   Jaspr's equivalents; how `RemoteWidget` hosts the built node.
4. **Styling/layout mechanics** that are inherent to the rendering engine, as
   long as the observable result honors the component contract.

If you find yourself wanting to deviate on something in the MUST list to make a
framework work, that is a signal of a real design gap — surface it (and, if it
points at A2UI Transport or RFW itself, write it up) rather than quietly forking
behavior.

### How the contract is enforced

Two mechanisms in `packages/a2ui_craft_testing` turn the contract above into
automated checks:

- **Primitives set (`corePrimitives`)** — the canonical set of core component
  names. Each adapter has a contract test asserting its
  `createCoreComponents().widgets.keys` equals `corePrimitives`, so no adapter
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

Per the two-level model (§2), **A2UI components reference catalog widgets,
each backed by an RFW template**; the bridge maps a component to its template, and
the template composes the primitives.

Primitives — an RFW `LocalWidgetLibrary`, implemented per framework:

```
core: Text, Row, Column, Button, Image, TextField, Checkbox, …
```

Catalog — an RFW `RemoteWidgetLibrary`, authored once and vetted at
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

An A2UI message references only catalog names; a component's props are the
template's `args`, and a layout widget's `children` are child component ids:

```
{ "id": "root", "component": "Grid", "children": ["p1", "wx"] }
{ "id": "p1", "component": "ProductCard", "title": …, "imageUrl": … }
```

Rendering is exactly the M1–M4 machinery, re-pointed at the catalog library:
the `p1` adapter (keyed by its id) renders `buildNode(ConstructorCall('ProductCard',
{…props…}), scope: catalogLib)`; `'ProductCard'` resolves to the **template**,
which imports and composes `core`. `Grid`'s `args.children` receive the child
adapters (`p1`, `wx`) via host-widget injection, reconciled by id under partial
updates.

**Status: done (M5).** The two levels are no longer conflated. The bridge is now
**catalog-agnostic** — `_buildComponent` maps a component's props to `args` **by
name** (`children`/`child` are structural slots by key; an `{event}`→`EventHandler`,
a `{path}`→data binding, else literal), with no per-type knowledge — and
`A2uiToRfwAdapter` takes a configurable `scope` (the catalog library).
A catalog template then maps those args onto the primitives (e.g.
`widget Tappable = Button(onPressed: args.action, …)`). The conformance suite and
the Jaspr example now render A2UI components (`Stack`/`Label`/`Tappable`) against a
real catalog over `core`. Validated bottom-up: `template_layer_spike_test`
proves the runtime mechanics (named-template composition, host-widget injection
through `args.children`, `EventHandler`-as-arg) with **no runtime changes**;
`runA2uiConformance` proves the end-to-end bridge path on both adapters.

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
    ├── a2ui_craft_bridge/        # A2UI → engine, on a2ui_core (framework-neutral)
    ├── a2ui_craft_testing/       # shared conformance suite + catalog (not published)
    ├── a2ui_craft_examples/      # shared, framework-neutral sample specs (demo only)
    ├── a2ui_craft_flutter/       # Flutter adapter (runtime + core comps + example)
    └── a2ui_craft_jaspr/         # Jaspr adapter (runtime + core comps + example)
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
      component contract (`corePrimitives`) and the cross-framework behavioral
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
  - [x] **M5 — the template layer (§6).** The bridge is catalog-agnostic (props →
        `args` by name; `children`/`child` structural; `{event}`/`{path}` by
        shape) and `A2uiToRfwAdapter` takes a configurable `scope`. Conformance +
        the Jaspr example render A2UI components (`Stack`/`Label`/`Tappable`)
        against a real catalog over `core`. Covered by
        `template_layer_spike_test` (runtime mechanics: named-template
        composition, host-widget injection through `args.children`,
        `EventHandler`-as-arg) and `runA2uiConformance` (end-to-end, both adapters).
  - [x] **M6 — layer `a2ui_core` underneath the protocol/data half (§10).**
        `a2ui_core` (a git dependency on `flutter/genui`) now owns A2UI ingest, the
        data model, and binding/function/`checks` resolution; RFW + the bridge keep
        materializing templates. The bridge shrank to `A2uiComponentBinding`
        (one per component id: wraps `a2ui_core`'s `GenericBinder`, surfaces resolved
        props) + `a2uiArgsFromProps`; each `A2uiToRfwAdapter` now takes an
        `a2ui_core` `SurfaceModel` + `basePath`, maps resolved props → template args,
        injects keyed child adapters (A2UI id for static children, positional
        `basePath` for `ChildList` items), and renders via `buildNode`. Actions are
        dispatched by `a2ui_core` and wired to RFW `voidHandler` via the resolved-
        callback affordance (VENDORED extension #3). Deleted: `A2uiSurface`,
        `SurfaceListenable`, `_buildComponent`/`_children`→`Loop`, `_value`/`_pathRef`,
        and the M4 data-path — together with the map-growth limitation (`a2ui_core`
        owns the component/data lifecycle, incl. `deleteSurface`). Reactivity is now
        component-granular (a `GenericBinder` resolvedProps signal per component).
        functions/`formatString`, `checks`, and theme are delivered by `a2ui_core` and
        available to the catalog. Two-way setter wiring (editable inputs)
        remains follow-on. Verified by the rewritten cross-adapter
        `runA2uiConformance`, the bridge `A2uiComponentBinding` tests, the custom-
        catalog reorder test, and the `a2ui_core` seam spike. (M1 & M2 are
        vendored-RFW divergences; M6 adds extension #3 — all in `VENDORED.md`.)
  - [x] **Worked examples + sample tests.** Both adapters ship a gallery example
        (Greeting, Counter, Profile Card, Image Gallery) that demonstrates the
        two-level model concretely: each agent-facing widget (`Greeting`,
        `Counter`, `ProfileCard`, `Gallery`) is a **vetted RFW template** composing
        `core` primitives (incl. `Image`/`Icon`/`Divider`/`ScrollView`/
        `Card`, added unprefixed alongside `Text`/`Row`/`Column`/`Button`), so the
        A2UI payloads only **compose** those templates with a few props — e.g.
        `Column(children: [ProfileCard(name, avatarUrl, bio), …])`, or a single
        `Gallery(images: [...])` whose template iterates internally (`...for url in
        args.images`). Each sample lives in its **own file** as a subclass of an
        abstract `Sample` widget that owns the sample's catalog, message script,
        `Runtime`, and surface — so samples are fully isolated from one another;
        `test/samples_test.dart` mounts each `Sample` and asserts it renders (and
        that its actions update bound data) — wired into `tool/check.sh`. This
        surfaced (and fixed) a bridge gap: **single child references** — a prop
        typed as a `componentId` (e.g. a `Card`'s `child`), which `a2ui_core`
        resolves to a plain id string — are now injected as one child adapter
        (`A2uiComponentBinding.childRefs` + `a2uiArgsFromProps`), alongside the
        existing `children` lists.
  - [x] **Ephemeral component APIs (`loadCatalog`).** A real client starts knowing
        *nothing* about a template's component API, but its code is precompiled —
        so the API must be **loadable as data**, like the RFW template and the JSON
        messages. `loadCatalog` (in the bridge) parses a catalog delivered as **raw
        JSON Schema**: each component is an object schema whose props reference the
        A2UI **common-type vocabulary** (`DynamicString`/`Action`/`ChildList`/
        `ComponentId`/… ) by `$ref`, resolved against `a2ui_core`'s `CommonSchemas`
        so `GenericBinder` can scrape behavior. The boundary is exactly right: the
        *protocol* (common types + RFW grammar) is precompiled; *per-template*
        schemas arrive as data. The samples now declare their catalog as JSON
        Schema (no in-code `ComponentApi` classes).
  - [x] **Cross-framework sample dedupe.** Because a sample is now pure data
        (RFW template + JSON-Schema catalog + A2UI messages) plus a small
        `onAction`, each sample is defined **once** as a framework-neutral
        `SampleSpec` in `a2ui_craft_examples`. Each example keeps only a thin
        per-framework `Sample` widget (parse template, `loadCatalog`, process
        messages, render the `root` adapter) and its gallery shell; the Flutter and
        Jaspr galleries render the *same* specs. This is a second proof of H1 — one
        set of sample definitions drives two genuinely different rendering engines.
  - [x] **Two-way binding (editable inputs).** Added the `TextField` and
        `Checkbox` core components (both adapters). The write-back path needed **no
        new plumbing**: `a2ui_core`'s `GenericBinder` already resolves a `setX`
        callback for a `{path}`-bound prop, and the runtime's resolved-callback
        affordance (ext #3) lets a template wire it to the widget's `onChanged`
        (`widget Field = TextField(value: args.value, onChanged: args.setValue)`).
        Editing writes straight back to the data model, and bound widgets
        re-render. Proven cross-framework by a `runA2uiConformance` checkbox test
        (toggle → data model updates on both adapters) and a Flutter `Form` sample
        test (free-text typing → a Label bound to the same path mirrors it).
        *Harness note:* `jaspr_test` can't synthesize a real DOM input value, so
        free-text *entry* is exercised on Flutter; the cross-framework write-back
        contract is proven via the checkbox (a value-free toggle) plus the shared
        setter path. A `Form` sample demonstrates both inputs in the gallery.
  - [~] **Then** — grow the **core primitives** into a capable vocabulary
        (§11): the catalog is the app developer's job,
        authored *as templates over* these primitives. Approach decided —
        constrained common model + value-type vocabulary + geometry conformance.
        **First slice landed:** see the `Flex` vertical slice below.
- [~] **H2 type/style model + capable primitives (§11).** Build the
      framework-neutral value-type vocabulary (the `argument_decoders`
      replacement — `Dimension`/`Color`/`EdgeInsets`/alignment/`TextStyle`),
      sharpen conformance to geometry-with-tolerance, and grow the catalog
      depth-first on layout (`Flex` vertical slice first). The unlock for richer
      primitives and, later, theming.
  - [x] **`Flex` vertical slice (Pillars A–C).** The cross-framework value types
        (`Dimension` = `hug`/`fill`/`fixed`/`flex`, `FlexAxis`,
        `MainAxisAlign`/`CrossAxisAlign`) decode in the **core**, not per-adapter.
        `Row`/`Column`/`Flex`/`Expanded` are one spec-driven builder per adapter
        on **explicit sizing** (neither Flutter's nor CSS's native defaults).
        Conformance graduated to **geometry-with-tolerance**, run against *real*
        layout on both sides: Flutter `RenderBox` (`WidgetTester.getRect`) and
        Jaspr **headless-Chrome** `getBoundingClientRect` (`dart test -p chrome`,
        wired into `check.sh`) — not a CSS-structure proxy.
  - [x] **`Box` slice.** The container primitive (size + padding + margin +
        background) on the same explicit-sizing / border-box model, with `Insets`
        and `Rgba` value types (decoded in the core) and asymmetric-inset geometry
        conformance on both adapters.
  - [x] **Atoms slice (toward the A2UI Basic Catalog).** `Text` (`variant`),
        `Image` (`ImageFit` + `ImageVariant` canonical sizes), `Icon` (shared
        name→glyph subset), `Divider` (`axis`), and `List`, with behavioral +
        geometry conformance. Proven end-to-end by rendering the gallery's
        **Contact Card** surface as a Craft template on both adapters.
  - [x] **Layout-depth primitives.** The primitive set grows toward what a real
        cross-framework layout vocabulary needs — taking RFW's `createCoreWidgets`
        as the reference menu, **not** the A2UI Basic Catalog (which isn't a
        benchmark for anything). Landed: `Align` (a 9-anchor `Alignment2D`,
        generalizing `Center`), `AspectRatio`, `Wrap` (flex-wrap flow), and
        `Opacity` — each with behavioral conformance and, for the layout-affecting
        ones, geometry conformance against real layout on both adapters. Shown in
        the demo app's **Layout** screen. (`Stack`/`Positioned` are deferred: they
        ride Flutter's `ParentDataWidget` mechanism, which the keyed-`_Widget`
        runtime wrapper would intercept — needs a runtime pass-through, like the
        host-injection work.)
  - [x] **`Markdown` primitive.** Agents emit Markdown constantly, so a dedicated
        rich-text primitive is worth its keep. `Text` stays **plain** (the
        constrained, predictable leaf); `Markdown` renders headings, paragraphs,
        ordered/unordered lists, and inline **bold**/*italic*/`code`/links.
        Parsing lives in the **core** (`a2ui_craft`'s `parseMarkdown` → a neutral
        `MarkdownBlock`/`MarkdownSpan` model, like the value-type decoders), so
        both adapters render the *same* model and can't disagree; each renders it
        **structurally** (Flutter widgets / DOM `h1`–`h6`/`p`/`ul`/`strong`/…),
        never by injecting raw HTML — upholding the secure-by-design posture
        (§12). Core unit tests cover the parser; a shared conformance case proves
        cross-adapter parity. (Block quotes, code fences, images, and tables
        degrade to text for now.)
  - [x] **`Heading` primitive.** Rather than overloading `Text` with a heading
        mode, a dedicated `Heading(text, level)` carries a real **heading role +
        level** for assistive tech (Flutter `Semantics(headingLevel:)`; an
        `h1`–`h6` element on the web) — semantically distinct from a styled
        `Text`/`span`, which screen readers can't use for outline navigation or
        "jump to heading". `level` defaults to **1** (a heading with no context is
        the most prominent one; deeper levels are author-set) and is clamped to
        1–6; `Markdown` headings carry the same semantics. Kept simple: one line,
        no inline markup (use `Markdown` for rich content) — the "many simple
        widgets over one complex one" rule.
  - [x] **Direct component→widget mapping (the "bespoke widget" path).** A
        developer can surface an existing local widget *directly* as an A2UI
        component — no template wrapper, no extra binding layer — via the
        adapter's optional `mapComponent` seam, which maps a component's `type`
        and props onto a [ConstructorCall] (renaming props onto the widget's
        args). This complements the primary value proposition (a **catalog** of
        **templates** over primitives, §2): some local widgets are pointless to
        rebuild from primitives and are better exposed as-is (§3, "Bespoke
        widgets"). The capability is **catalog-agnostic and decoupled from the
        core primitives** — proven by a self-contained test that maps a synthetic
        `Hero` component onto a bespoke `Banner` widget (static and data-bound) on
        both adapters; the framework ships no catalog-specific default mapping.
  - [ ] **Toward the gallery.** Mapping a *specific* catalog (e.g. A2UI's Basic
        Catalog) onto Craft is an embedder/app concern, **not a framework
        deliverable** — and not a license to let that catalog drive primitive
        design (the Basic Catalog is itself stuck between low- and high-level, §11
        "Not a copy of A2UI's basic catalog"). When we build a gallery demo, each
        component is realized by the artifact that fits its semantics — a template
        for composed/domain widgets, a direct mapping for primitive-shaped or
        bespoke ones — chosen per component, not by a blanket "every component → a
        primitive" rule.
  - [~] **Templatizing the A2UI Basic Catalog gallery examples.** Each of the
        spec's 42 example surfaces (`specification/v1_0/catalogs/basic/examples`)
        is reproduced as a hand-authored **Craft template** over the primitives —
        the "bias to templatize" thesis at gallery scale. Key moves: format
        functions (`formatCurrency`/`formatDate`/…) are *not* a blocker, since a
        template renders strings and the agent supplies already-formatted data;
        A2UI's `children: {path, componentId}` child-list templating is expressed
        directly as a `...for` loop over an array arg. Demo screens scroll the nav
        so the gallery scales.
    - **Landed (20):** Simple Text (00), Interactive Button (00), Login Form (00,
      labelled fields as a template over the bare input), Weather (04, `...for`
      forecast), Product Card (05), Restaurant Card (20), Account Balance (15),
      Shipping Status (21, `...for` step rows), Flight Status (01), Purchase
      Complete (11), Coffee Order (13, `...for` items), Credit Card (22), Child
      List Template (34, `List` + `...for`), Markdown (35, the `Markdown`
      primitive), Music Player (06, `Slider` + `Heading`), Permission (10),
      Sports Player (14), Event Detail (17), Step Counter (23), Countdown (28) —
      the last five using the `Heading` primitive for their titles. All tested on
      both adapters.
    - **Templatizable, not yet authored (16):** 00_complex-layout,
      00_formatted-text, 00_incremental, 00_row-layout, 02_email-compose,
      03_calendar-day, 08_user-profile, 09_login-form, 12_chat-message,
      16_workout-summary, 18_track-list, 25_contact-card, 27_stats-card,
      31_incremental-dashboard, 32_advanced-form-validator (layout only — see
      below), 33_financial-data-grid. (25/27 overlap the existing hand-authored
      Contact/Stats cards.)
    - **Blocked — missing primitives (7 examples, 5 primitives):**
      - **`Modal`** (29_movie-card, 36_modal) — an overlay/dialog surface. Needs
        an overlay primitive; on Flutter a routed/`OverlayEntry` layer, on the web
        a positioned/`dialog` element. Open question: is the modal a *primitive*
        or a host-app concern the surface merely requests?
      - **`Tabs`** (24_recipe-card) — a tab bar + switched panel. Composable from
        primitives + selection state once we have a stateful selection model; may
        instead be a catalog template over a `Row` of `Button`s + a switched child.
      - **`ChoicePicker`** (19_software-purchase, 30_live-invitation-builder) —
        single/multi select. High-level; likely a template over `Radio`/`Checkbox`
        (already primitives) once grouping/selection state is modeled.
      - **`DateTimeInput`** (07_task-card, 30) — a date/time control. Needs a
        platform input primitive (Flutter pickers; web `<input type=date/time>`).
      - **`AudioPlayer`** (26_podcast-episode) — transport + scrubber. Like
        `Video` (currently a stub), a media primitive; low priority.
    - **Notes / fidelity gaps:** `Text` is plain by design; rich content uses the
      dedicated **`Markdown`** primitive (see above), so the heading/emphasis
      markers A2UI puts in `Text` are honored where a sample opts into `Markdown`.
      Form **validation** functions (`required`/`email`/`length`/
      `regex`/`and`/`or` in 09/32) are behavior, not layout — templatized samples
      reproduce the form's *appearance*, not its live validation. The composite
      label-bearing controls (`TextField`/`CheckBox`/`Slider` with a `label`) are
      templates over the bare input + a `Text`. Cross-cutting `weight` (flex-grow)
      and theming remain open. (The pinned `a2ui_core` implements only
      `formatString`; baking formatted data sidesteps the rest.)
- [ ] Prove the state-model axis with a third, non-Flutter-like framework.
- [ ] **Security: uphold A2UI's secure-by-design promise (§12).** When templates
      are delivered ephemerally, treat them as untrusted input: add engine-level
      operation budgets (loop / instantiation / depth / node counters + wall-clock
      deadline) — **time-windowed, not reset-per-update**, and routing all
      engine-scheduled async (microtasks/timers) through one instrumented,
      cancellable scheduler so chains can't evade the counters — with cooperative
      interruption and cleanup, and keep the catalog + surface scope as the
      capability ceiling. Noted, not yet designed.
- [ ] Consider upstream RFW restructuring so the formats layer need not be
      vendored.

## 9. Open questions

- **Core component vocabulary (H2):** what is the least-common-denominator set,
  and how are layout/animation differences reconciled between Flutter and the
  DOM? **Direction decided (§11):** a constrained common model with a flexbox
  spine and explicit sizing, rather than mirroring either framework. Still open:
  the exact per-category widget set and how far the layout algebra reaches (e.g.
  `Grid`, scrolling/overflow, `Stack` z-order) before the "drop to raw framework"
  escape hatch (§3).
- **Type model:** the equivalent of RFW's `argument_decoders` is intensely
  Flutter-specific and is explicitly *not* part of the core; H2 must define a
  framework-neutral type/style model that each adapter maps down. **Direction
  decided (§11):** a small value-type vocabulary (`Dimension`/`Color`/`EdgeInsets`/
  alignment/`TextStyle`) extending the A2UI common-type `$ref` mechanism. Still
  open: the precise canonical shapes and how `Dimension`'s `flex`/`fill`/`hug`
  interact with nested scroll/intrinsic-sizing edge cases.
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
  catalog (likely yes — small vetted widgets), and how exactly do
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
A2UI message (catalog component refs + data + functions/checks)
  │  a2ui_core: MessageProcessor + DataModel + GenericBinder
  ▼  → resolved props (concrete scalars), id'd child tree, action callbacks, two-way setters
  │  bridge (thin): component name → RFW template; resolved props → template ARGS;
  │                 inject child adapters; wire callbacks → events
  ▼
  │  RFW: buildNode(ConstructorCall(templateName, {args, children:[adapters]}), scope: catalogLib)
  │       template composes the primitives (args.* / internal ...for / switch)
  ▼
Flutter / Jaspr primitives
```

### Why this is the right division

RFW is the **build-time template engine** that materializes catalog widgets
from primitives, once, cross-framework (§2). `a2ui_core` is the
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
| `core_components` primitives | **keep** |
| per-id adapter tree (M3) | **keep, re-rooted** on `a2ui_core`'s component tree + `resolvedProps` signals |
| the bridge | **keep, thin** — name→template, args feed, child injection, event wiring |
| catalog template `RemoteWidgetLibrary` | **build** (the missing layer, §6 / M5) |

M1–M4 are not wasted: they are the template-rendering plumbing. Only the
protocol/data/binding half of the bridge is delegated.

### Risks & status

- **Maturity:** `a2ui_core` is pre-1.0 (`0.0.1-wip002`); API may churn. It is the
  canonical direction (the JS stack already follows it).
- **Pure-Dart deps** (`collection`, `json_schema_builder`, `meta`,
  `preact_signals` — no Flutter), so Jaspr-compatible.
- **Status: spike landed; full adoption in progress (M6).** The de-risking
  Jaspr spike (`a2ui_core_seam_spike_test.dart`) is green and proves the seam end
  to end with the **real, published** `a2ui_core` (`^0.0.1-dev002` from pub.dev):
  a `ProductCard` + `Grid` template library over `core`, an A2UI surface placing
  two cards in a grid, `a2ui_core` resolving a `formatString` price and an
  `updateDataModel`. Findings:
  - **No RFW runtime change is needed for the data/binding/structural seam.**
    `a2ui_core`'s `MessageProcessor` + `SurfaceModel` + `GenericBinder` produce
    `resolvedProps` (concrete scalars + `List<ChildNode>`); a thin per-id adapter
    maps props → template `args`, injects child adapters for `ChildNode`s, and
    renders via the existing `buildNode(scope: catalogLib)`.
  - **Reactivity is component-granular and works:** an `updateDataModel` flows
    `DataModel` → `formatString` `computed` → `resolvedProps` signal → a
    `preact_signals`-`subscribe` → `setState` bridge → only the affected card's
    adapter rebuilds (guard-verified: disabling the bridge fails the update test).
  - **Action seam proven.** `GenericBinder` resolves an `action` prop to a Dart
    `Future<void> Function()`; a template wires it to a `Button` primitive's
    `onPressed`; clicking dispatches an `A2uiClientAction` (name + context) back
    through `a2ui_core`. This required **one small additive runtime affordance** —
    `handler<T>`/`voidHandler` now accept an already-resolved `Function` arg
    (VENDORED extension #3, both runtimes; guard-verified). Two-way setters (the
    `setX` callbacks `GenericBinder` injects for `{path}`-bound props) remain to be
    wired for editable inputs — a follow-on, not a blocker for read/action UIs.
  - **Dependency strategy resolved:** depend on `a2ui_core` via a **git dependency**
    on `flutter/genui` (`packages/a2ui_core`) so we track latest and others can run
    it locally. (`resolution: workspace` does not block a git or path dep; a bare
    path breaks CI, and the published pub.dev prerelease lags `main`.) Switch to a
    published version once the team cuts a release.

  **Adoption complete (M6).** The deletion + re-rooting in the table above is
  done: the bridge is now `A2uiComponentBinding` + `a2uiArgsFromProps` over
  `a2ui_core`; both `A2uiToRfwAdapter`s render from an `a2ui_core` `SurfaceModel`;
  `runA2uiConformance`, the bridge binding tests, the custom-catalog reorder test,
  and the seam spike are green on both adapters. `a2ui_core` is pulled via a git
  dependency on `flutter/genui` (a workspace-wide `dependency_overrides`), to be
  pinned once the team cuts a release. Two-way setters for editable inputs are
  now wired (see the roadmap entry in §8).

## 11. The core primitives: a constrained common model

This section defines the approach for growing the primitives (the
`LocalWidgetLibrary` / "core" library) from today's seed into a **capable**
primitive vocabulary. It is the concrete plan for **H2** (§3) and supersedes the
"see §9" placeholders for the type/style model.

### Why this is the load-bearing library

The core primitives are the framework's **instruction set**. Per the two-level
model (§2), app developers **compose it into templates** to build their own
domain-specific catalogs — and they can also **extend and replace** it
with bespoke or brand-styled widgets ("Extensible by design", below). So our job
is not to ship a catalog, nor an exhaustive one: it is to ship a
**strong, broadly-useful, cross-framework default** — expressive enough to build
most catalogs, and extensible where it isn't. Two requirements pull
against each other:

- **Expressiveness** — it must scale to a wide variety of use-cases, because each
  app's catalog is unique.
- **Cross-framework identity** — a primitive must behave the same whether a
  template is rendered by Flutter or Jaspr (§5). Every primitive we add multiplies
  the surface where the two can silently diverge.

### Not a copy of A2UI's basic catalog

The core primitives are **not** A2UI's [Basic
Catalog](https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json)
re-implemented 1:1. That catalog is caught **between** the two worlds (§2) and
serves neither cleanly: several of its components bake in **opinionated layout**
that a primitive should not impose. Its `TextField` and `CheckBox` bundle
a `label` with a fixed arrangement (label above the field; label beside the box);
its `ChoicePicker` is an entire composite (options, single/multi-select, chips,
filtering). Those are template decisions wearing a primitive's clothing — exactly
the in-between mismatch this layer fixes.

So our controls (as primitives) are the **bare parts** — a text input, a checkbox, a
radio — the way Flutter's material/cupertino libraries expose them. Label
placement, option lists, and selection grouping are composed **in templates**,
where they belong and where they can differ per design without changing the
primitive (a labeled field or a choice picker is then itself a catalog
template). This is the general move (§2's *bias to templatize*): keep each
primitive minimal and cross-framework, and templatize the opinionated composition.
We therefore borrow A2UI's catalog as a **coverage target** — what the catalog
templates must be able to express — not as the shape of the primitives themselves.

### Extensible by design: sub- and super-setting the primitives

The core primitives we ship are a **default, not a closed set**. Real apps must be able to
**super-set** it (add widgets) and **sub-set** it (replace widgets), for two needs
that don't go away:

- **Bespoke widgets.** An app has local widgets that are hard or pointless to
  rebuild from primitives; the developer wants to register and reuse them directly.
- **Branded design language.** An app's **controls** (`Button`, `TextField`,
  `Checkbox`, `Switch`, `Radio`) are usually heavily styled to its UX. Layout
  primitives are broadly reusable as-is; controls are the frequent replacement
  target.

#### Considered and rejected: an HTML/CSS-expressive primitive set

The alternative is to make our primitive set so expressive you can build anything
by composing it (effectively "HTML/CSS in a box"), and never need to replace a
widget. We reject that:

- It is a **heavy lift, and a *cross-framework* one.** A maximally expressive
  primitive set *is* building our own UI framework — which would make the
  "cross-framework" claim tongue-in-cheek (we'd *be* a framework, not an adapter
  onto frameworks).
- It **doesn't remove the need** for sub-/super-setting anyway: bespoke widgets and
  brand styling are real-app requirements no matter how expressive the core is.
- **Design language is coupled to the framework the developer already chose.** They
  picked HTML/CSS on the web and SwiftUI on iOS because those toolkits give the
  best results; adopting A2UI Craft should let them keep extracting those results,
  not wall them off behind our primitives.
- **It matches how A2UI already works** without Craft — a catalog of framework-
  native widgets — so sub-/super-setting keeps the overall model familiar and
  consistent.

So extension and replacement are **first-class and must be ergonomic**, not an
afterthought. Mechanically this is a short step from where we are: the primitives
are already a `LocalWidgetLibrary` (a name→builder map), so super-setting is adding
entries and sub-setting is overriding them; what's missing is an ergonomic
compose/override API and clear registration. This is the **structured form of §3's
"drop to the raw framework" escape hatch** — applied at the primitive level instead
of abandoning the engine.

#### Where the contract still bites

The cross-framework behavioral contract (§5) and conformance (Pillar C, below)
cover the widgets *we* ship. A developer's additions and replacements are theirs to
keep consistent: a replacement that preserves the same **name, props, and
observable behavior** stays template-portable across their frameworks (and they can
run it through our conformance harness to prove it); one that diverges is, by
choice, framework-specific. Two complementary axes serve "make it look like my
app": **theming** (the deferred H2 layer — restyle *our* control via tokens) for
the light-touch case, and **replacement** (swap in a native or bespoke control) for
the heavy case.

This also **relieves pressure on the primitives' breadth** (Pillar D): because apps
extend and replace, our core need not chase every widget or every styling knob. We
aim for a strong, broadly-useful default — especially the **layout spine** (the
most reusable, least-restyled part) and the common controls — and let extension
cover the long tail.

### Why the seed won't scale as-is

The core primitives began as two hand-written files (`core_components.dart` ×2) whose
headers said they "deliberately mirror, component-for-component" each other, with
`runCoreComponentConformance` — coarse "is this text visible?" probes — as the only
thing holding them together. That is fine for a handful of demo widgets, but it
does not scale:

- **The frameworks have genuinely different layout models.** Flutter is
  constraint-based (constraints down, sizes up; explicit `mainAxisSize`/`Expanded`);
  the DOM is the CSS box model (flow, margin collapse, `height:auto` vs.
  `width:100%` defaults, intrinsic sizing). Mirroring two native implementations
  by hand means the defaults diverge silently as the primitives grow.
- **Coarse probes can't see layout divergence.** "Is this text visible?" passes
  even when a `Row` lays out completely differently on the two sides. The gap
  between "tests green" and "actually identical" widens with every widget.
- **Hand-mirrored implementations drift in telling ways.** The seed `Video` is a
  stub box on Flutter but a real `<video>` on Jaspr; the seed `Card` hard-codes its
  padding and shadow independently on each side. Nothing coarse catches the
  mismatch.

So the task is not "write more widgets like these." It is to **establish a
contract that makes the adapters converge by construction, and sharpen the
enforcement enough to keep them honest** — which is what the rest of this section
defines.

> **Progress (this is underway, not hypothetical).** The `Flex`, `Box`, and atoms
> slices (§8) are now built **against the spec** rather than by mirroring: their
> value types decode in the **core**, the per-adapter builders implement that
> contract, and **geometry conformance** runs on both adapters against real layout
> (`RenderBox` / `getBoundingClientRect`), so divergence is *caught* rather than
> invisible. The headers that once said "deliberately mirror" now say "implements
> the spec." The not-yet-converged tail is the remaining seed components — `Card`,
> `Video`, `AudioPlayer` — which still need to be brought onto the contract.

### The decision: a constrained common model, flexbox-shaped

The load-bearing choice is *whose layout model the primitives' contract speaks*.
Three options were considered: **Flutter-canonical** (Jaspr emulates Flutter's
constraint protocol in CSS — doesn't scale; intrinsic sizing is very hard to fake),
**CSS-canonical** (Flutter emulates flow layout and margin collapse — same problem
mirrored), and a **constrained common model** that both adapters render natively.
We choose the **constrained common model**: a small layout algebra that is cheap
and faithful on *both* sides. The core primitives are therefore **neither "Flutter widgets"
nor "HTML elements"** — it is its own vocabulary that each adapter maps down.

This is tractable because **flexbox is the one layout model both sides already
implement with near-identical semantics** (not a coincidence — Flutter's `Flex`
was modeled on flexbox). It is the spine of the model:

| Common model | Flutter | CSS |
| --- | --- | --- |
| `mainAxisAlignment` | `MainAxisAlignment` | `justify-content` |
| `crossAxisAlignment` | `CrossAxisAlignment` | `align-items` |
| flex factor on a child | `Expanded(flex:)` / `Flexible` | `flex-grow` |
| `gap` | spacing between children | `gap` |
| wrap | `Wrap` | `flex-wrap` |

The one real trap *within* flexbox is **default sizing**: a Flutter `Column` with
`mainAxisSize.min` hugs its children, whereas a CSS flex container fills its
cross-axis and hugs its main-axis by `auto`. The fix is to **not inherit either
platform's defaults** — make sizing **explicit** through a shared dimension type.
That single decision removes the largest source of silent divergence, and it is
the seed of the type model below.

#### Considered and rejected: Yoga as a shared runtime layout engine

[Yoga](https://www.yogalayout.dev/) is the canonical embeddable flexbox engine (a
C++ core implementing CSS Flexbox, exposed via a C API with native/WASM bindings;
the archived [zup-archive/yoga](https://github.com/zup-archive/yoga) wired it into
Flutter over FFI). The tempting idea: run Yoga on the native frameworks (Flutter,
SwiftUI, Compose) and plain HTML/CSS on the web — and because Yoga *targets web
standards*, the two stay consistent. We **rejected it as a runtime dependency**:

- **No advantage over the native frameworks worth its weight.** Flutter `Flex`,
  SwiftUI stacks, and Compose `Row`/`Column` are *already* flexbox-shaped native
  implementations of this exact model. Yoga's consistency-with-the-web is real but
  **redundant** — it mainly buys tighter *bit-for-bit* parity with CSS, which this
  contract explicitly does not need (behavioral identity within a tolerance band,
  not pixel parity — §5). We'd pay a large fixed cost to close a gap the contract
  already tolerates.
- **The cost lands exactly where it hurts.** A C++ library plus per-platform FFI
  bindings (and no FFI-to-native on Flutter web), which **breaks host-only
  `flutter test`** — undermining Pillar C (geometry conformance), the one
  mechanism that keeps the adapters honest.
- **It does not solve the hard part.** Yoga delegates *leaf measurement* (text
  shaping, font fallback, line-breaking — the real source of cross-framework
  divergence) back to the host, so feeding it host-measured sizes leaves the same
  divergence; it just relocates into the measure callbacks.
- **Yoga is for environments that *lack* flexbox** (game engines, custom canvases).
  Every target we care about already has a native flexbox-equivalent, so we **map
  onto** each framework's native layout rather than **embedding a third engine** —
  embedding one only reduces divergence if *both* adapters route through it, at
  which point we've stopped using either framework's renderer (and, on the web,
  bypassed the DOM and broken SSR).

Yoga remains useful as a **reference**: it is the de-facto "flexbox minus CSS
cruft" spec, so its well-tested prop set, enums, and defaults are a good model to
crib for the `Flex`/`Dimension` vocabulary, and it is third-party validation that
flexbox is the right spine. It may also serve as a **test-time geometry oracle**
for layout-only fixtures (Pillar C) — but not as a shipped dependency.

### Pillar A — the primitives are a *specification*, not parallel implementations

There is **one framework-neutral source of truth** per primitive: its prop names,
their value types and defaults, and its behavioral semantics stated concretely
enough to test. Both adapters implement *against* that spec; neither adapter's code
is the contract. `corePrimitives` is the embryo of this — it pins the *set of names* —
and it grows into the real contract by also pinning props, types, and semantics.
The header comment "deliberately mirrors the other adapter" is replaced by "implements
the spec"; the spec, not a sibling file, is what each adapter answers to.

### Pillar B — a shared value-type vocabulary (the H2 type model)

The core primitives need a small set of cross-framework value types, each with one
canonical representation that every adapter maps down. This is the
framework-neutral replacement for RFW's intensely Flutter-specific
`argument_decoders` (§9), and the foundation theming later plugs into:

| Type | Canonical shape | Notes |
| --- | --- | --- |
| `Dimension` | `hug` \| `fill` \| `fixed(px)` \| `flex(n)` | the explicit-sizing decision; removes default-divergence |
| `Color` | RGBA | |
| `EdgeInsets` | per-side px (padding / margin) | |
| `MainAxisAlignment` / `CrossAxisAlignment` | flexbox-aligned enums | map per the table above |
| `Axis` | `horizontal` \| `vertical` | `Row`/`Column` are `Flex` + this |
| `TextStyle` | size, weight, color, … | |

These extend the **A2UI common-type vocabulary** already settled for ephemeral
schemas (the `$ref`/`CommonSchemas` mechanism behind `loadCatalog`, §8), so a
template author and a catalog schema describe a dimension or a color the same way
A2UI describes a `DynamicString`. Designing these now — even minimally — is
deliberate: they are load-bearing for every primitive and brutal to retrofit.
**Theming itself is deferred** ("one step at a time"), but the types it will hang
on are not.

### Pillar C — conformance graduates from "visible" to geometry-with-tolerance

The contract is only real if it is enforced. The probes must rise from "is this
text visible?" to **"this child sits at this offset, at this size — within
tolerance."** `CraftTester` gains geometry queries (a node's box position and
size); `runCoreComponentConformance` asserts layout outcomes for `Flex`, sizing,
alignment, gap, and wrap on both adapters.

Parity is **behavioral with a tolerance band**, never pixel-exact — text shaping
and line-breaking differ across engines, so exact pixels are impossible and not the
goal (§5). Choosing the constrained model (above) is precisely what keeps the band
small. This sharpening is where the real investment goes; without it the contract
is just a comment.

> **Realized for the `Flex` slice.** `CraftGeometryTester`/`runFlexGeometryConformance`
> (in `a2ui_craft_testing`) now assert child offsets and sizes for main/cross
> alignment, gap, and flex distribution against **real layout on both adapters**:
> Flutter `RenderBox` via `WidgetTester.getRect`, and Jaspr via a **headless
> browser** — `getBoundingClientRect` under `dart test -p chrome`, wired into
> `check.sh`. This settles the open worry that Jaspr layout could only be checked
> host-only (where the DOM does no layout): geometry parity is enforced against a
> genuine browser, not a CSS-structure proxy. Fixtures use fixed-size boxes (no
> text) so the band is sub-pixel. Note this is the one place a real browser is
> required in CI — a deliberate, contained cost for the layout spine.

### Pillar D — breadth by category, depth-first on layout

A capable catalog needs coverage across these categories (today's seed is a thin
slice of each):

- **Layout** — `Flex` (`Row`/`Column`), `Box`/`Container` (size + padding + margin
  + decoration), `Align`/`Center`, `Stack` + `Positioned`, `Spacer`/`Gap`, `Wrap`,
  `ScrollView`, `Grid`.
- **Atoms** — `Text` (over the `TextStyle` type), `Image`, `Icon`, `Divider`.
- **Controls** — `Button`, `TextField`, `Checkbox`, `Switch`, `Radio`, `Slider`,
  `Select`. (Two-way binding is already proven, §8.)

The order is **depth-first on layout + the value types**: `Flex`, `Box`, and the
`Dimension`/`EdgeInsets`/alignment types are where Pillars A–C are proven and where
cross-framework divergence is hardest. Controls and atoms then compose on that
proven foundation, so breadth is comparatively cheap. The first concrete step is a
**vertical slice through `Flex`** — spec + value types + geometry conformance — end
to end on both adapters, before going wide.

### What this is not (yet)

- **Not theming.** The value types are theming's foundation; the theming layer on
  top is deliberately later.
- **Not pixel parity.** Behavioral identity within a tolerance band (§5).
- **Not a Flutter or DOM mirror.** The catalog is its own constrained vocabulary;
  "looks like a Flutter `Row`" / "looks like a `<div style=flex>`" is an adapter
  implementation detail, not the contract.

## 12. Security: upholding A2UI's secure-by-design promise

> **Status: noted, not yet designed.** This section records a requirement so it is
> not forgotten. The actual threat model and mechanisms are future work, orthogonal
> to the primitives (§11) and not designed in this pass.

A2UI is built for **secure, trusted agentic experiences**. Its security rests on
the ephemerally-loaded payload being **declarative data, not code**: A2UI Transport
is JSON that *composes a vetted catalog* and *binds a scoped data model*, with **no
arbitrary code execution**, so an agent-influenced payload stays within the
boundaries the client allows. A2UI Craft adds expressivity — most notably
**templates** — and that expressivity must not erode the promise.

### The invariant we inherit, and must keep

A2UI Craft preserves the no-arbitrary-code property: RFW templates are
**declarative** (data binding, `...for` loops, `switch`, `state`, `event`/args)
with **no host-code eval**. The only things a template can *do* are compose the
**catalog** and dispatch scoped **events/actions** — so **the catalog is the
capability ceiling.** (This is also why sub-/super-setting, §11, is the right place
to reason about what a deployment grants: capability is conferred by what goes into
the catalog.) Keeping that boundary intact as the language and engine grow is the
core security invariant.

### Where the risk concentrates: template provenance

The threat scales with **who supplies a template, and when**:

- **Build-time, vetted, shipped with the client** (today's stance, §2) — templates
  are *app code*: trusted, reviewed, not an external attack vector. A runaway
  template only harms its own author.
- **Ephemerally delivered at runtime** (the trajectory: `loadCatalog` already makes
  component *schemas* data; templates are the natural next thing to deliver on
  demand) from a server, a third-party catalog, or anything the agent can
  influence — now a template is **untrusted input** and must be treated with the
  same suspicion as the rest of the ephemeral payload.

The work below matters precisely when templates cross into the second category.

### Threat classes (initial, non-exhaustive)

- **Resource exhaustion / DoS** *(primary)* — template nesting and loops make it
  easy to overload CPU or exhaust memory: deep or recursive composition, large
  fan-out, long or nested `...for` loops, pathological data driving an unrolled
  `ChildList`.
- **Async amplification (counter-reset evasion)** — a subtler variant that
  specifically defeats naive per-update counters. Budgets are presumably checked
  and **reset around an update**, but template-driven work can schedule
  **microtasks or timers** that the VM runs *after* that reset. Each resulting
  update is individually within budget, yet each schedules the next — so an
  attacker sustains unbounded aggregate work as a chain of innocuous-looking
  updates, escaping any counter that returns to zero between them. (Dart
  microtasks / `Timer`s; the JS event loop under Jaspr — both adapters.)
- **Capability / data-scope** — a template must not bind or exfiltrate data, nor
  dispatch actions, beyond what the surface is scoped to allow. The catalog plus
  the surface's data/action scope define the ceiling, and the engine must not let a
  template widen it.

### Direction for the primary class

Install **engine-level operation budgets** in the runtime (both adapters, in
lockstep): counters for loop iterations, widget/component instantiations, tree
depth, and total node count, plus a wall-clock deadline. When a budget is exceeded,
**cooperatively interrupt** the interpreter and **clean up** the partial tree
rather than let it run away.

Two constraints follow from the async-amplification case and must be designed in
from the start, not bolted on:

- **Budgets accrue over a time window; they do not reset to zero per update.** A
  rate-limited budget (e.g. a token bucket that refills at a fixed rate over
  wall-clock time) bounds *sustained* cross-update work, so a chain of
  individually-cheap updates still trips the limit. A hard per-update reset is the
  exact hole the microtask/timer chain exploits.
- **All engine-scheduled async funnels through one instrumented scheduler.** The
  engine routes its own microtasks, timers, futures, and frame callbacks through a
  single chokepoint that (a) counts them against the budget, (b) attributes them to
  the originating surface, so a runaway surface can be isolated and torn down
  without killing the app, and (c) is fully **cancellable** on cleanup, so
  interrupting a surface also drains its pending async. Bounding chained-update
  depth within the window catches feedback loops (an update that re-triggers an
  update).

Because this lives in the vendored RFW runtime (alongside keyed `_Widget` and
`buildNode`), it is another candidate VENDORED extension and a plausible
upstream-RFW contribution — any host running untrusted RFW wants resource limits.

Revisit this when ephemeral template delivery (or a security review of the
ephemeral surface) is on the table.
