# A2UI Craft — Design

> **Status:** active. This document is the source of truth for the project's
> direction. Code and skills should defer to it; when reality and this document
> disagree, fix one of them deliberately. This document describes the design as
> it stands; implementation status and slice-by-slice plans live in
> [ROADMAP.md](ROADMAP.md).

**In one paragraph:** A2UI lets an agent drive real UI by composing a small,
vetted catalog of components — but someone must implement that catalog, by
hand, natively, once per UI framework, compiled into every host app. A2UI Craft
makes a catalog cheap: each catalog widget is authored **once**, as a
declarative RFW template over a small set of cross-framework **primitives**,
rendered by a framework-agnostic engine (Flutter and Jaspr today), and shipped
as an ephemerally-loadable **project** — pure data, deployable to a CDN,
updatable without a host redeploy.

## 1. The problem

[A2UI](https://github.com/google/A2UI)'s premise is that an agent (an LLM) can
drive real, trustworthy UI by *composing a catalog*: a small, pre-vetted set of
components the client offers, addressed over a declarative, data-only protocol.
The protocol is deliberately renderer-agnostic — it says which catalog
components go where, with what data, and never how to draw them.

That leaves the expensive part to every client: **someone must implement the
catalog.** Today that means hand-writing each catalog widget natively, once per
UI framework. Three costs follow:

1. **Multiplied authoring.** A catalog of N widgets on M frameworks is N×M
   implementations, kept behaviorally in sync by hand. The multiplication
   punishes exactly the catalogs that make agent-driven UI good — rich,
   domain-specific ones.
2. **Compiled into the host.** The catalog ships inside the host app's binary,
   so iterating on it means redeploying every host app. And the party who
   designs a catalog (the *template author* — a brand, a product team, a
   third-party integration) is often not the host-app developer, yet has no way
   to ship or update their work independently.
3. **The cheap alternative is worse.** Skipping vetted catalogs — letting the
   agent compose low-level pieces over the wire — bloats model context (defeating
   small, fast models), produces unpredictable output, and cannot be vetted
   before deployment, which kills high-trust business use-cases.

A2UI Craft removes the expense: author each catalog widget **once**, as a
declarative template; render it with whatever UI framework the client is built
on; and ship it as **data** — an ephemerally-loadable bundle, not compiled code.

## 2. What A2UI Craft is

A2UI Craft is a **framework-agnostic, client-side templating engine**. It takes
declarative UI templates written in the **RFW (Remote Flutter Widgets) text
format** and renders them with a target UI framework (Flutter, Jaspr, …),
binding the template to a reactive data model.

It is *not* a new language and *not* an ahead-of-time compiler to a wire format.
We adopt RFW's existing language and runtime essentially as-is, and generalize
the runtime so it is no longer tied to Flutter.

A2UI is already renderer-agnostic — it composes UI out of **catalog** items and
doesn't care how a renderer implements them. A2UI Craft slots in cleanly:

> The agent (e.g. an A2UI Python SDK app talking to an LLM) speaks A2UI against a
> plain catalog of components. It does **not** know templates exist. When it says
> `updateComponents … component="WeatherCard"`, the client picks a template
> named `WeatherCard` and renders it with its framework. There can be several
> client implementations — e.g. Flutter on mobile, Jaspr on web — all honoring
> the same catalog.

In other words: **A2UI Craft templates are an implementation of an A2UI
catalog**, as opposed to wrapping native widgets one-for-one.

### The hypotheses we are proving

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
   CSS layout/animation). **§8 defines the approach:** a *constrained
   common model* (flexbox-shaped, with an explicit value-type vocabulary) rather
   than mirroring either framework's native layout.

A2UI Craft is deliberately a **least-common-denominator** engine. The hunch is
that this denominator is still quite expressive and covers many A2UI use cases.
When a developer needs deeper, framework-specific capabilities, the escape hatch
is to **drop down to the raw framework** (per-framework, but that's an advanced
case).

## 3. Glossary

These terms recur throughout and are easy to conflate; this document uses them
precisely:

- **Primitive** — a single **low-level** building block available to template code
  (`Text`, `Row`, `Box`, `Button`, `Image`, …): one entry in an RFW
  **`LocalWidgetLibrary`**. Primitives are expressive, cross-framework, and
  **template-private** — composed *by* templates at build time, never referenced
  by an agent. A primitive may come from the **core primitives** we ship *or* be a
  **custom primitive** an app defines (apps super-set and sub-set the core set —
  see §8 "Extensible by design").
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

## 4. The design model

### The two-level model: agent-facing catalog widgets vs. template-private primitives

There are **two distinct levels of vocabulary**, and conflating them is the
central mistake to avoid:

1. **Primitives** — a rich set of building blocks (`Text`, `Row`, `Column`,
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
lives in `a2ui_core` (§5).

A2UI operates **only** on the catalog. The bridge maps an A2UI
catalog component to its template; the template composes the primitives.
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

### Where the engine runs: a client-side runtime

A **template** is a pure function `(data, state) → UI`. It describes what the
UI should look like for the current inputs; it ignores prior UI state. **A2UI
Transport**, by contrast, is an *imperative* protocol over a *stateful* surface
(`updateComponents` presupposes a prior tree to mutate). Bridging the two
requires evaluating the template with concrete data *and* diffing against the
previously produced tree — i.e. **reconciliation**. So a template needs a
**runtime engine** that owns state and reconciliation. Two shapes were
considered and rejected before settling on the third:

- **Considered and rejected: AOT-compiling templates to A2UI Transport.** A
  compiler cannot reconcile: neither the concrete data nor the prior tree exist
  at compile time. Any "template language that compiles to A2UI messages" runs
  into this wall regardless of syntax.
- **Considered and rejected: a server-side engine.** Running the engine on the
  server re-introduces a network round-trip for every local interaction and
  forces the server to hold per-client UI state. Against A2UI's grain.
- **Client-side runtime engine** — local interactivity stays local; the engine
  renders templates using whatever framework the client is built on. **This is
  the approach we take, and it is exactly what RFW already is.**

## 5. Architecture

The stack, from an incoming agent message down to pixels:

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

### Division of labor: `a2ui_core` above, RFW below

`a2ui_core` (the Dart core package in `flutter/genui` that backs the `genui`
Flutter renderer — mirroring how `web_core` backs the Angular/React/Lit
renderers) owns the A2UI protocol, the data model, and the resolution of
bindings/functions/`checks`. It is **complementary to RFW, not a replacement**:
`a2ui_core` sits *above* the template layer, RFW sits *below* it.

RFW is the **build-time template engine** that materializes catalog widgets
from primitives, once, cross-framework (§4). `a2ui_core` is the
**runtime A2UI layer** — protocol, data, and the value-level computation RFW
deliberately lacks (functions/`formatString`, `checks`, two-way binding;
RFW's AST has no function/expression node). Building those on RFW would
duplicate canonical logic and diverge from the reference implementation.

### The seam

`a2ui_core` resolves bindings/functions/`checks` to **concrete values**, handed
to a template as **args** — not data references. Consequences:

- **RFW's data layer (`DynamicContent`, `data.x` path bindings) is not used for
  A2UI.** Reactivity is **component-granular**: when a component's inputs
  change, `a2ui_core`'s `resolvedProps` signal fires, the per-id adapter
  rebuilds, and `buildNode` re-renders that component's template with new args.
  A small `preact_signals → setState` bridge per adapter carries the signal into
  the framework's lifecycle.
- **RFW's `Loop` survives only for template-*internal* iteration** over an args
  list (`...for p in args.products`). The A2UI-level `ChildList` is resolved by
  `a2ui_core` into an id'd child tree and injected as host adapters (§6).
- **Actions and two-way binding pass through resolved.** `a2ui_core`'s
  `GenericBinder` resolves an `action` prop to a plain Dart callback and injects
  `setX` setters for `{path}`-bound props; the bridge hands both to templates as
  args. To make that wiring direct, the runtimes' `handler<T>`/`voidHandler`
  accept an already-resolved `Function` argument (VENDORED extension #3).

### Packages

```
┌─────────────────────────────────────────────────────────────┐
│ a2ui_craft  (core, pure Dart, NO UI-framework dependency)     │
│   parsing + AST + binary format (vendored RFW formats layer)  │
│   DynamicContent · design tokens + CraftTheme · functions     │
└─────────────────────────────────────────────────────────────┘
        ▲                                   ▲
        │ depends on                        │ depends on
┌───────────────────────┐         ┌───────────────────────────┐
│ a2ui_craft_flutter     │         │ a2ui_craft_jaspr           │
│  Runtime → Flutter      │         │  Runtime → Jaspr           │
│  Widget; primitives as  │         │  Component; primitives as  │
│  Flutter widgets        │         │  DOM (div/flexbox)         │
└───────────────────────┘         └───────────────────────────┘
        ▲                                   ▲
        └───────── a2ui_craft_bridge ───────┘
              (A2UI → engine, on a2ui_core; framework-neutral)
```

- **Core (`a2ui_craft`)** is the **vendored RFW *formats* layer** (`binary`,
  `model`, `text`) plus `content` (the `DynamicContent` reactive model, used by
  standalone-RFW hosting), the design-token parser/resolver and `CraftTheme`
  (§9), and the shared function library. It is pure Dart with zero UI-framework
  dependency. We **vendor** rather than depend on `package:rfw` because RFW's
  `pubspec.yaml` pulls in Flutter even though its `formats.dart` library does
  not — so there is no Flutter-free way to consume it today. (A future upstream
  restructuring could remove the need to vendor.)

- **Adapters (`a2ui_craft_flutter`, `a2ui_craft_jaspr`)** each contain their own
  copy of the **runtime** (`Runtime`, `DataSource`, the curried-node machinery)
  plus their implementation of the core primitives. Each runtime is a
  near-verbatim port of RFW's runtime; the unavoidable reason it cannot be
  shared as-is is that RFW's runtime is parameterized by the framework's *node
  type* (Flutter `Widget` vs. Jaspr `Component`), and Dart cannot abstract over
  that cheaply. So the runtime is duplicated per framework **by design**, and
  kept behaviorally identical (§7).

- **Bridge (`a2ui_craft_bridge`)** is the thin, framework-neutral glue between
  `a2ui_core` and the engine: `A2uiComponentBinding` (a per-component listenable
  of resolved props) and `a2uiArgsFromProps` (props → template args, child
  injection, callback wiring).

- **`a2ui_core`** is consumed as a **git dependency** on `flutter/genui`
  (`packages/a2ui_core`) so we track latest and others can run the repo locally;
  it will be pinned to a published version once the team cuts a release. It is
  pre-1.0, so some API churn is expected. Its dependencies are pure Dart
  (`collection`, `json_schema_builder`, `meta`, `preact_signals` — no Flutter),
  so it is Jaspr-compatible.

## 6. Rendering A2UI surfaces: composition, identity, and partial updates

This section defines how an A2UI surface is rendered, and the small, additive
extensions to the RFW runtime it requires.

### The model: a predefined catalog that the message composes

Two things are **predefined by the client and registered once**:

- a `LocalWidgetLibrary` of primitive widgets (the native building blocks), and
- a `RemoteWidgetLibrary` of vetted higher-level templates (e.g.
  `WeatherCard`) that may expose **slots** (`args.child` / `args.children`).

An A2UI message **never defines widgets**. It carries a *composition*: a flat,
id-referenced adjacency list of component *instances* that reference predefined
names and bind data. Rendering a component means looking it up in the predefined
catalog and composing it — A2UI's own "catalog of components" model.

Widgets and data live in two separate worlds in RFW, and this separation is
load-bearing:

- the **template/args world** holds widgets (nested `ConstructorCall`s, `args.*`
  projection, builders);
- the **data world** holds only plain values (`int/double/bool/String`, maps,
  lists).

Data cannot carry widgets: `DataSource.child`/`childList` only
accept already-built widget nodes, a data reference resolves to a plain
value, and the data model asserts its leaves are scalars. So a
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
Lifting the key onto the wrapper solves the standalone-RFW and A2UI cases with
one mechanism — no bypassing of the wrapper is needed. (Salting à la
`_SaltedValueKey` — to stay `GlobalKey`-safe when a key value is itself a `Key` —
is deferred; current keys are scalar ids and the inner child is unkeyed, so
there is nothing to collide with.)

### Partial updates

State lives in two places, and each kind of update touches only what it must:

- **`updateDataModel`** writes to `a2ui_core`'s `DataModel`. Each component
  whose resolved props depend on the changed paths gets a new `resolvedProps`
  value, and only that component's adapter rebuilds (component-granular
  reactivity, §5). No structural work.
- **`updateComponents`** is routed **per id**: only the addressed
  `A2uiToRfwAdapter` rebuilds, re-rendering from that node down. No whole-tree
  re-synthesis, no re-currying of unaffected nodes.

Localizing updates to the affected subtree (plus keyed reconciliation keeping
sibling/descendant state intact) is the main reason for the adapter tree.

### Two additive deviations from RFW (candidates to upstream)

Both are small, additive, and behavior-preserving for existing RFW usage. Each is
recorded in `VENDORED.md` (extensions #6 and #5) and is a good candidate to
propose to upstream RFW.

1. **`Runtime.buildNode(context, composition, data, handler, {scope, theme})`**
   — render an ad-hoc composition (a `ConstructorCall` whose slot arguments
   may be already-built host widgets) against the registered libraries, resolving
   names via `scope`. *Why A2UI needs it:* the structure is decided at runtime,
   and RFW otherwise renders only **named** declarations and **forbids recursive
   templates** — so there is no way to render a runtime-built tree without
   synthesizing a throwaway library per message.
2. **Keyed `_Widget`** — honor a reserved literal `key` argument,
   lifted onto the `_Widget` wrapper as a typed `ValueKey`. *Why A2UI needs it:*
   id-addressed updates with reordering require identity-based reconciliation. It
   also independently improves RFW for any dynamic-list UI, so it has merit beyond
   A2UI.

### Lists and scope (the delicate part)

A2UI `ChildList` templates (data-driven lists) expand into one child per data
item, with relative bindings resolving against each item. `a2ui_core` resolves a
`children` slot — both a static id list and a `ChildList` template — into a
`List<ChildNode>`, and the bridge injects **one child adapter per `ChildNode`**.
A static child keys its adapter by its (unique) A2UI id; a `ChildList` item has
a deeper, per-item `basePath` (the item's data path), which becomes its
reconciliation key. Template-*internal* iteration over an args list
(`...for p in args.products`) still uses RFW's own `Loop`, which scopes each
item via a depth-aware `LoopReference` so relative bindings — including nested
loops — resolve against the right item.

**Known limitation — positional reconciliation of list items.** Static
components reconcile **keyed by their A2UI id** (above), but the A2UI spec
currently attaches **no stable identifier to the elements of a data array** that a
`ChildList` unrolls. With no per-item id to key on, list items are reconciled
**positionally** — the index-based `basePath` *is* the position. This is precisely
the imprecise behavior this section otherwise argues against: inserting,
removing, or reordering items in the *middle* of a list shifts every following
item by a slot, so element-held state (a checkbox value, in-progress text input,
scroll offset, animation) reconciles onto the wrong item or is dropped. In-place
item updates and append/truncate at the *end* are unaffected; only mid-list
structural churn is.

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
keyed-`_Widget` / per-id-adapter machinery; only the **key source** changes
(today: the positional `basePath`; post-fix: the item's key surfaced by
`a2ui_core`'s `ChildNode`). Per-item keys are **scoped within their parent list**
(salted by the list's component id) so a list-item key can never collide with a
sibling component's A2UI-id key.

### The template layer: what A2UI references, and what the bridge targets

Per the two-level model (§4), **A2UI components reference catalog widgets,
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

Rendering is exactly the machinery above, pointed at the catalog library:
the `p1` adapter (keyed by its id) renders `buildNode(ConstructorCall('ProductCard',
{…props…}), scope: catalogLib)`; `'ProductCard'` resolves to the **template**,
which imports and composes `core`. `Grid`'s `args.children` receive the child
adapters (`p1`, `wx`) via host-widget injection, reconciled by id under partial
updates.

The bridge is **catalog-agnostic**: it maps a component's props to `args` **by
name** (`children`/`child` are structural slots by key; an `{event}` becomes an
`EventHandler`, a `{path}` a data binding, else a literal), with no per-type
knowledge — and `A2uiToRfwAdapter` takes a configurable `scope` (the catalog
library). A catalog template then maps those args onto the primitives (e.g.
`widget Tappable = Button(onPressed: args.action, …)`). The machinery is pinned
bottom-up by tests: `template_layer_spike_test` proves the runtime mechanics
(named-template composition, host-widget injection through `args.children`,
`EventHandler`-as-arg) with no runtime changes, and `runA2uiConformance` proves
the end-to-end bridge path on both adapters.

## 7. Adapter invariants — what MUST NOT deviate, and what MAY

This section is the contract that keeps the adapters honest. It is mirrored by
the project skill that governs adapter work.

The goal is **behavioral identity, not pixel identity** — like Flutter's Material
vs. Cupertino, the same contract can look different per **platform idiom**; what
it may never do is look different because of the *framework* (the consistency
principle, §8). "Behavior" means: the same template renders the same content,
the same data bindings update the same way, and the same interactions dispatch
the same events.

### MUST be identical across every adapter (no deviation)

1. **Template language & semantics.** Adapters consume the RFW text/binary format
   unchanged. No adapter may add, remove, or reinterpret language features (data
   binding, `...for` loops, `switch`, `state`, `event`, args). Parsing lives in
   the core, not in adapters.
2. **Public API surface & names.** Every adapter exposes the same names with the
   same shapes:
   - `Runtime` (with `update(LibraryName, WidgetLibrary)`,
     `build(context, FullyQualifiedWidgetName, DynamicContent, RemoteEventHandler)`,
     and `buildNode(…, {scope, theme})`),
   - `RemoteWidget` (fields: `runtime`, `widget`, `data`, `theme`, `onEvent`),
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

## 8. The core primitives: a constrained common model

This section defines the design of the core primitives (the
`LocalWidgetLibrary` / "core" library): a **capable, cross-framework**
primitive vocabulary. It is the concrete answer to **H2** (§2).

### Why this is the load-bearing library

The core primitives are the framework's **instruction set**. Per the two-level
model (§4), app developers **compose it into templates** to build their own
domain-specific catalogs — and they can also **extend and replace** it
with bespoke or brand-styled widgets ("Extensible by design", below). So our job
is not to ship a catalog, nor an exhaustive one: it is to ship a
**strong, broadly-useful, cross-framework default** — expressive enough to build
most catalogs, and extensible where it isn't. Two requirements pull
against each other:

- **Expressiveness** — it must scale to a wide variety of use-cases, because each
  app's catalog is unique.
- **Cross-framework identity** — a primitive must behave the same whether a
  template is rendered by Flutter or Jaspr (§7). Every primitive we add multiplies
  the surface where the two can silently diverge.

### Not a copy of A2UI's basic catalog

The core primitives are **not** A2UI's [Basic
Catalog](https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json)
re-implemented 1:1. That catalog is caught **between** the two levels (§4) and
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
template). This is the general move (§4's *bias to templatize*): keep each
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
compose/override API and clear registration. This is the **structured form of §2's
"drop to the raw framework" escape hatch** — applied at the primitive level instead
of abandoning the engine.

#### Where the contract still bites

The cross-framework behavioral contract (§7) and conformance (Pillar C, below)
cover the widgets *we* ship. A developer's additions and replacements are theirs to
keep consistent: a replacement that preserves the same **name, props, and
observable behavior** stays template-portable across their frameworks (and they can
run it through our conformance harness to prove it); one that diverges is, by
choice, framework-specific. Two complementary axes serve "make it look like my
app": **theming** (§9 — restyle *our* control via tokens) for
the light-touch case, and **replacement** (swap in a native or bespoke control) for
the heavy case.

This also **relieves pressure on the primitives' breadth** (Pillar D): because apps
extend and replace, our core need not chase every widget or every styling knob. We
aim for a strong, broadly-useful default — especially the **layout spine** (the
most reusable, least-restyled part) and the common controls — and let extension
cover the long tail.

### Why hand-mirrored implementations don't converge

The naive way to build a cross-framework primitive set is to write it twice —
one Flutter file, one Jaspr file, each promising to "mirror" the other — with
coarse visibility probes as the safety net. That does not scale:

- **The frameworks have genuinely different layout models.** Flutter is
  constraint-based (constraints down, sizes up; explicit `mainAxisSize`/`Expanded`);
  the DOM is the CSS box model (flow, margin collapse, `height:auto` vs.
  `width:100%` defaults, intrinsic sizing). Mirroring two native implementations
  by hand means the defaults diverge silently as the primitives grow.
- **Coarse probes can't see layout divergence.** "Is this text visible?" passes
  even when a `Row` lays out completely differently on the two sides. The gap
  between "tests green" and "actually identical" widens with every widget.
- **Hand-mirrored implementations drift in telling ways** — a padding hard-coded
  independently on each side, a capability stubbed on one framework and real on
  the other. Nothing coarse catches it. (Heavy capabilities like video belong in
  an extended primitives package, not the core set — ROADMAP.md.)

So the task is not "write more widgets by hand, carefully." It is to **establish
a contract that makes the adapters converge by construction, and sharpen the
enforcement enough to keep them honest** — which is what the rest of this section
defines. Concretely: each primitive's value types decode in the **core**, the
per-adapter builders implement that contract, and **geometry conformance** runs
on both adapters against real layout, so divergence is *caught* rather than
invisible.

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
  not pixel parity — §7). We'd pay a large fixed cost to close a gap the contract
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
is the contract. `corePrimitives` pins the *set of names*, and the contract also
pins props, types, and semantics. Each adapter answers to the spec, not to a
sibling file.

### Pillar B — a shared value-type vocabulary (the H2 type model)

The core primitives need a small set of cross-framework value types, each with one
canonical representation that every adapter maps down. This is the
framework-neutral replacement for RFW's intensely Flutter-specific
`argument_decoders`, and the foundation theming plugs into (§9):

| Type | Canonical shape | Notes |
| --- | --- | --- |
| `Dimension` | `hug` \| `fill` \| `fixed(px)` \| `flex(n)` | the explicit-sizing decision; removes default-divergence |
| `Color` | RGBA | |
| `EdgeInsets` | per-side px (padding / margin) | |
| `CornerRadius` | scalar px; large values clamp to half the box (pill / circle) | corner *style* (arc vs. continuous curve) is platform idiom (the controls, below); a per-corner form is a reserved extension |
| `MainAxisAlignment` / `CrossAxisAlignment` | flexbox-aligned enums | map per the table above |
| `Axis` | `horizontal` \| `vertical` | `Row`/`Column` are `Flex` + this |
| `TextStyle` | size, weight, color, … | |

These extend the **A2UI common-type vocabulary** already used for ephemeral
schemas (the `$ref`/`CommonSchemas` mechanism behind `loadCatalog`), so a
template author and a catalog schema describe a dimension or a color the same way
A2UI describes a `DynamicString`. These types are load-bearing for every
primitive and brutal to retrofit, which is why they are designed alongside the
first primitives rather than after them.

### Pillar C — conformance is geometry-with-tolerance, not "is it visible"

The contract is only real if it is enforced. Probes like "is this text visible?"
cannot see layout divergence, so conformance asserts **"this child sits at this
offset, at this size — within tolerance."** `CraftGeometryTester` /
`runFlexGeometryConformance` (in `a2ui_craft_testing`) assert child offsets and
sizes for main/cross alignment, gap, and flex distribution against **real layout
on both adapters**: Flutter `RenderBox` via `WidgetTester.getRect`, and Jaspr via
a **headless browser** — `getBoundingClientRect` under `dart test -p chrome`,
wired into `check.sh`. Geometry parity is enforced against a genuine browser,
not a CSS-structure proxy (host-only Dart tests do no DOM layout). Fixtures use
fixed-size boxes (no text) so the band is sub-pixel. This is the one place a
real browser is required in CI — a deliberate, contained cost for the layout
spine.

Parity is **behavioral with a tolerance band**, never pixel-exact — text shaping
and line-breaking differ across engines, so exact pixels are impossible and not the
goal (§7). Choosing the constrained model (above) is precisely what keeps the band
small.

### Pillar D — breadth by category, depth-first on layout

A capable catalog needs coverage across these categories:

- **Layout** — `Flex` (`Row`/`Column`), `Box`/`Container` (size + padding + margin
  + decoration), `Align`/`Center`, `Stack` + `Positioned`, `Spacer`/`Gap`, `Wrap`,
  `ScrollView`, `Grid`.
- **Atoms** — `Text` (over the `TextStyle` type), `Image`, `Icon`, `Divider`.
- **Controls** — `Button`, `TextField`, `Checkbox`, `Switch`, `Radio`, `Slider`,
  `Select`. (Two-way binding flows through `a2ui_core`'s setters, §5.)

The order is **depth-first on layout + the value types**: `Flex`, `Box`, and the
`Dimension`/`EdgeInsets`/alignment types are where Pillars A–C are proven and where
cross-framework divergence is hardest. Controls and atoms then compose on that
proven foundation, so breadth is comparatively cheap.

### The controls: one spec, platform-idiomatic renderings

Layout primitives are look-free: they arrange, and whatever they contain
provides the pixels. **Controls cannot be look-free.** A checkbox glyph, a
slider's track and thumb, a button's pressed feedback must be *painted*, and
none of it can be composed out of other primitives — there is no templatizing a
thumb drag, or an ink splash spreading under a label. Micro-interactions are
exactly the kind of thing the template language must never be asked to express
(§4): the cost of native-grade interaction lives in **adapter code**, written
once per framework with the full power of that framework, not in templates. So
each control primitive owns a **specified default look**, and its spec (Pillar
A) pins three things: its props and behavior (§7), its **role mapping** (which
theme roles ink which parts, §9.4), and its **paint model** (below).

#### The consistency principle: the framework must never be visible; the platform may be

A control renders as a function of *(spec, platform idiom, theme)* — and
nothing else. Idiom variance is intentional; it is the point of native
rendering: a switch *should* look Material on Android, Cupertino on iOS, and
web-native in a browser. (The demo site's side-by-side panes deliberately show
two idioms at once — "this is the web; this is mobile.") What H2 forbids is
variance that traces to the *framework*:

- Two adapters rendering the **same idiom** must agree on the role mapping and
  the geometry envelope.
- Two idioms rendering the **same template** must agree on behavior and on role
  *semantics*: a role inks the same part of the control to the same degree —
  `primary` **fully fills** the active state everywhere, never a full fill on
  one adapter and a partial tint on another.
- Pixel identity remains a non-goal (§7).

The idiom is **host-selected, not framework-implied**. The Flutter adapter
renders Material or Cupertino from render-time configuration (mechanically:
`ThemeData.platform` steering the `.adaptive` control constructors) — one
adapter, several idioms. The Jaspr adapter renders the web idiom with
**adapter-owned styling** (`appearance: none` + explicit CSS): UA-styled
controls accept only a tint (`accent-color`), which cannot satisfy the role
mapping.

**Per-idiom limits.** An idiom may **ignore** a role it does not surface;
each control's spec states which roles each idiom consumes. An idiom must
never *repurpose* a role onto a different part. The v1 tables (the Cupertino
column is the `.adaptive` preview):

| Control | Material | Cupertino | Web |
| --- | --- | --- | --- |
| `Button` | full mapping; ink-splash state layer; circular-arc corner | same mapping; **pressed-fade** state layer (composite, 0.4); **superellipse** corner | same mapping; hover/active-brightness state layer; `border-radius` corner |
| `Checkbox` | `primary` fill, `onPrimary` mark, `outline` box | same (CupertinoCheckbox honors all three) | same (painted glyph) |
| `Radio` | `primary` selected, `outline` ring (custom glyph; grouping TODO) | same custom glyph — no adaptive rendering yet | same (painted glyph) |
| `Switch` | `primary` active track, `onPrimary` on-thumb, `outline` inactive | same (the adaptive switch takes the iOS look, same knobs) | same (always adapter-painted — the web has no stock switch) |
| `Slider` | `primary` active track + thumb, `outline` inactive track | **`outline` ignored** (CupertinoSlider has no inactive-track knob) | same as Material |
| `TextField` | full field chrome (`outline` box, `primary` focus + caret, `onSurface` ink) | **no adaptive path — renders the Material chrome** (§13) | same as Material |
| `Select` | full field chrome | same as Material (no adaptive dropdown) | same as Material |

#### The paint model: four layers, one owner

| # | Layer | What it paints |
| --- | --- | --- |
| 1 | **Surface** | background color, border, corner shape |
| 2 | **State layer** | hover / pressed overlays and ink splash, clipped to the surface |
| 3 | **Content** | the child (label, icon, row), placed with padding + alignment |
| 4 | **Composite effects** | pressed-fade, disabled dimming — applied to the whole stack |

The control owns **all four layers**. The state layer *interleaves* the others
— Material draws ink on the surface **under** the label; a hover wash sits
above the background but below the content; Cupertino's pressed state fades the
composite, label included — so no decomposition in which the child supplies the
surface can order the layers correctly. Hence the rule: **a control's child is
content, never chrome.**

`Button` is the control this rule bites hardest. It owns its surface (`color`,
`cornerRadius` props), its state layer in the active idiom (ink splash under
Material, pressed-fade under Cupertino, hover/active overlays and a
`:focus-visible` ring on the web), its content placement, and its composite
effects. Unstyled, it is the idiom's stock button inked by
`primary`/`onPrimary`; a transparent surface is the "text button" degenerate
case — so there is **no separate look-free pressable primitive**, and a fully
bespoke button is the replacement escape hatch (above).

`Checkbox` is the same four layers in miniature, and shows where the checkbox
*differs* from the button. Layer 1 is the **box**: `outline` inks the border
while unchecked, `primary` **fully fills** it while checked (the fill subsumes
the border — there is no separate outline over a checked box), with a size and
corner from the specified default (`CheckboxDefaults`, not a per-instance prop).
Layer 3 is the **mark**, inked `onPrimary`, drawn only while checked (an
indeterminate dash is a reserved third state). Unlike the button, a checkbox has
a perfectly good host rendering, so **unthemed it blends in** (§9.1) — the web
idiom returns the native UA control, Flutter the native `Checkbox.adaptive` —
and only once a theme supplies `primary` does the web idiom paint the spec glyph.
Enabling a theme therefore changes the web checkbox's *geometry* (native → spec
glyph), not only its color; that is accepted idiom latitude, not framework
variance. The Flutter idiom keeps the native box's own size/corner and honors
only the shared border width — the one geometry knob a native control exposes.

`Radio` is the same painted-glyph model with **one fewer role**: `primary` inks
the selected glyph (ring + dot), `outline` the unselected ring, and there is no
`onPrimary` — a radio's dot is the accent itself, not content on an accent fill.
It blends into the host unthemed, like the checkbox. Its Flutter rendering is
*custom* (a Material radio `Icon`, sized from the shared default) rather than the
native `Radio<T>` — not by preference but because that API is mid-migration to
`RadioGroup`; the move to native is the same deferred sibling pass as the
checkbox's, and the radio is what blocks it.

#### Corner radius is an amount; corner style is idiom

`CornerRadius` is a **scalar** in the shared value vocabulary (Pillar B): `0`
is sharp, `n` rounds, and a large value clamps to half the box's smaller extent
(pill / circle — the clamp is specified so both adapters agree). How the corner
*curves* is the idiom's decision — a circular arc under Material and on the web
(`border-radius`), Apple's continuous superellipse under Cupertino
(`RoundedSuperellipseBorder`). The template says how *much*, never *which
curve*. There is deliberately **no `shape` prop**: it would push a per-platform
geometry decision onto template authors, and the web could not honor most of it
anyway. A per-corner form is a reserved additive extension; anything beyond
rounded rectangles is the replacement escape hatch.

#### Control conformance

Pillar C extends per control, on both adapters, in light and dark: the default
look reads its mapped roles, and re-theming a role re-inks the mapped part —
asserted with the painted-probe pattern (§9.6), never pixels.

### What this is not

- **Not pixel parity.** Behavioral identity within a tolerance band (§7).
- **Not a Flutter or DOM mirror.** The primitive set is its own constrained
  vocabulary; "looks like a Flutter `Row`" / "looks like a `<div style=flex>`" is
  an adapter implementation detail, not the contract.
- **Not theming.** The value types are theming's foundation; theming itself is
  the layer on top (§9).

## 9. Theming & design systems

The direction below came out of a prior-art survey — W3C DTCG, Material 3, the
web token systems, the native platforms — written up under `research/theming/`.
The load-bearing decisions: the trust model (§9.2), adopting the **W3C DTCG
token format** (§9.3), and the ephemeral transport (§9.5).

### 9.1 The problem

Templates compose the host's **local** primitives, so they inherit the host app's
look for free — Flutter `Theme.of(context)`, or the CSS cascade in Jaspr. That is
the right default and covers the common case: a template that should **blend into**
its host. We keep it as the zero-config baseline.

It fails one case, the one that motivates this section: the template author and the
host developer are **different parties** who want to brand **separately**. The
author needs to ship a design system *with* their templates, and — because it is
not part of the AOT-compiled host — it must load **ephemerally**, over the same
kind of channel as the template itself.

### 9.2 Whose concern is a design system? (the trust model)

There are three parties, and putting theming on the right one is the crux:

| Party | Artifact | Trust |
|---|---|---|
| **Host developer** | the compiled app: primitives + the standard function library (AOT Dart) | fully trusted (it *is* the app) |
| **Template author** | the catalog templates (`.craft`) + their schema, loaded ephemerally | trusted *author*, untrusted *transport* |
| **Agent (LLM)** | the A2UI transport messages — which components, the data, the actions | **untrusted** |

A design system is a **template-author** concern — "how *my* templates look" — in
exactly the way the templates themselves are. So it belongs in the **author's
ephemeral channel** (bundled with the templates), **not** the agent's message
channel.

#### Considered and rejected: A2UI's `createSurface` theme channel

A2UI's `createSurface` carries an opaque `theme` map, which looks at first like
the natural ephemeral channel for a design system. It is the wrong one, for two
reasons: (a) it is part of the A2UI **Basic Catalog**, which A2UI Craft
explicitly does not implement; and (b) it is **agent-authored** — the wrong
trust domain, the same mistake already rejected for computation. The invariant
there was "the agent supplies *data*; the author supplies *computation*"; its
theming corollary is "the author supplies the *brand*." A brand chosen by the
LLM is not the author's brand. **Default: the agent does not control theme.**

Dynamic theming that *is* legitimate — dark/light mode, a user's accent
preference, a host wanting to inject *its own* brand into an embedded template —
comes from the **host** (trusted), as render-time configuration, not from agent
messages. Letting the agent influence theme at all would be a separate, explicitly
opt-in, security-reviewed capability (mirroring how a function reaching the
agent-facing catalog is a separate choice) — never the default.

### 9.3 What a design system decomposes into

A design system is not one thing. Split it by what must be compiled vs. what can be
data, and most of it turns out to be ephemeral-capable already:

1. **Design tokens** — named values: a palette, semantic colour roles, a type
   scale, a spacing rhythm, radii/shape, elevation. Pure **data**; serializes to
   JSON; loads ephemerally like anything else. *This is the genuinely missing
   piece.* **Format: the W3C DTCG Design Tokens format** (`.tokens.json`, core
   module stable as of 2025.10) — adopted as-is for interop with Figma / Tokens
   Studio / Style Dictionary rather than inventing our own; its **aliases**
   (`"{color.base.blue}"`) are exactly the primitive→semantic split below. The
   entire DTCG ecosystem is *build-time* (compilers baking tokens into apps),
   and our requirement is *runtime* interpretation of ephemerally-loaded tokens
   — so we adopt the **format, not the tooling**, and keep a small total
   runtime parser + resolver in `a2ui_craft`, shared by both adapters
   (`research/theming/DESIGN_TOKENS.md`). (Design systems layer these:
   **primitive** tokens — `blue/500` — and **semantic** tokens — `color.action
   → blue/500`. Re-skinning is remapping the semantic layer over the primitive
   one, so the indirection is worth keeping. Mature systems add a third,
   *component* tier — `button.background → color.action`; for us that tier *is*
   item 2 below: branded catalog templates.)
2. **Component styling / variants** — "our button is pill-shaped with our accent."
   **Already the author's job, already ephemeral:** a branded component is a
   *catalog template* over primitives (`widget BrandButton = Button(color:
   theme.color.brand, cornerRadius: …, child: …)` — styling the control's
   surface while its state layer and feedback stay the control's, §8), and the
   author *owns the catalog the agent draws from*. Tokens make this clean — the
   branded templates reference tokens instead of hardcoded values, so a re-skin
   swaps tokens, not templates.
3. **New render code / novel interaction behaviors** — a genuinely new painted
   widget, a custom gesture or animation. These **cannot** be ephemeral (same limit
   as custom primitives; this is the "Later — ephemeral sandboxed logic" layer in
   ROADMAP.md's two-layer plan).

So the honest boundary: **ephemeral theming governs *appearance + composition*, not
new rendering or behavior.** The browser analogy holds exactly — the engine
(primitives) is compiled and fixed; the stylesheet (tokens) loads ephemerally and
drives appearance. **A design system here _is_ a token set + the author's catalog.**
The only genuinely new primitive we owe is **tokens, plus a way to reference them.**

### 9.4 How tokens reach the primitives

Three tiers, increasingly explicit — again the CSS model:

- **Ambient role-defaults (the cascade).** The runtime holds the resolved active
  theme; each primitive reads its role default when a prop is unset — an unstyled
  `Text` takes `color.onSurface` and the type scale, a `Checkbox` accent takes
  `color.primary`, an unstyled `Button` takes a `color.primary` surface with
  `color.onPrimary` content ink (the control paint model, §8). This is what lets
  an *unmodified* template pick up the brand with zero per-widget work. When a role is unset in the theme, the
  primitive falls back to the **host** default (Flutter `Theme.of` / CSS
  inherit) — so "blend in" is simply the base layer of the cascade, and a
  partial theme overrides only what it names.
- **Explicit token references.** A token is referenceable in a template value
  position, like a data binding — conceptually `Box(color: theme.color.brand)` /
  CSS `var(--brand)` — for bespoke compositions.
- **Branded component templates** (§9.3, item 2) compose both.

**Mechanism.** A theme is a **fourth ambient value scope**, parallel to `args` /
`data` / `state`: a dedicated `theme.<path>` reference (a real parsed scope,
`ThemeReference`, binary tag 0x14) resolved against the ambient **`CraftTheme`**
— an immutable resolved-token snapshot the host supplies (`RemoteWidget.theme` /
`buildNode(theme: …)`). Immutability is the reactivity model: re-theming (a
dark-mode flip) is providing a *new* snapshot; the scope change re-resolves live
references and rebuilds role-reading primitives in one motion, without
remounting (template state survives — conformance-pinned). The function-style
alternative (`token(name: …)`) was rejected: it strains "functions are pure."

**The semantic contract (`ThemeRoles` in `a2ui_craft`).** DTCG
standardizes token *structure*, never *meaning* — nothing in the format says a
caption uses `color.onSurfaceVariant`. The fixed set of token paths each
primitive reads is therefore the one piece of "standard" we author ourselves: a
small, versioned contract living in `a2ui_craft` next to the primitive spec
(§8), documented by the default theme (§9.5). v1 (the full crosswalk is
`research/theming/SEMANTIC_CONTRACT.md`): a *small neutral* role set with
surface/foreground pairing, using **Material 3's names** where M3 has one — the
M3 ∩ shadcn intersection — so existing exports map on without translation:
`color.surface`/`onSurface`/`onSurfaceVariant`, `color.primary` (the accent),
`color.outline`, `color.link`, plus a sizes-only type scale
(`type.body.size`, `type.caption.size`, `type.heading.<n>.size`);
`onPrimary` is consumed by the control paint model (§8);
`error`/`onError` are named-now-consumed-later. Radius/spacing
scales, font families/weights, and `color.background` are deliberately deferred.

**No selectors — a deliberate divergence from CSS.** A CSS stylesheet can
*target* arbitrary elements from the outside; our theme cannot. Tokens select
nothing — primitives *pull* their roles from the contract. Anything
selector-shaped ("all buttons inside cards look different") is a **branded
catalog template** (§9.3, item 2), not a theme feature. This is the guard rail
against the "reimplement CSS in JSON" cliff (§9.7).

### 9.5 The ephemeral transport

The theme artifact travels in the **author's** channel: bundled with the
project (§10) next to `template.craft` / `schema.json`, and in production
served from the author's origin with the rest of the bundle. Concretely, a
theme is a **base DTCG `.tokens.json` plus per-mode overlay files** (each
independently a valid DTCG document), with the mode wiring declared in
**project config** — *ours*, not the token files — because DTCG's own
multi-mode answer (the Resolver Module) is an unstable preview draft; we mirror
its model (sets + modifier contexts + resolution order) behind our own config
so we can conform when it stabilizes. The **host** supplies render-time
configuration only — the active mode, and optionally a host-brand base layer to
seed the cascade. The mode input is **n-ary** (light / dark / their
high-contrast variants), not a boolean — accessibility modes are first-class
axes alongside dark (the Apple/M3 lesson). Nothing here rides an agent message.

**Theming is explicit, never implicit.** A project *names* its theme; a project
with no theme gets the baseline behavior — blend into the host (§9.1). We ship an
open-source **default theme** (light, dark, and high-contrast modes) that themes
the standard primitives; it is the starter kit for custom themes, the reference
documentation of the semantic contract, and the theming-conformance fixture —
but the runtime never applies it unasked, so embedded surfaces keep blending in.

The cascade (lowest → highest precedence): **host defaults → author design
system → host render-time config (mode / injected brand) → explicit per-widget
props.** Each layer is a partial token map merged over the one below.

### 9.6 Cross-adapter fidelity

The token schema is framework-neutral (like the existing value types); each adapter
maps a token to its native styling — a colour → `Color` / CSS colour; a type token
→ `TextStyle` / CSS font; spacing/shape → the already-proven `Dimension` path.
**Token *application* is deterministic** (the same token yields the same declared
intent on both adapters); **pixel rendering is not**, and is explicitly not the
goal (§7) — a design system encodes *decisions*, not pixels.
The theming conformance dimension reuses the geometry-harness pattern: assert a
token lands on a primitive on both adapters (resolved padding/colour via
`getRect` / inspection).

**Totality.** A theme is untrusted-shaped ephemeral data, so parsing is total: an
unknown or malformed token falls back to the layer below (ultimately the host
default), never throws — the same discipline as the function library.

### 9.7 Hard sub-problems (flagged, not solved)

- **Style isolation — asymmetric across adapters.** Separate branding implies the
  template's styling must not leak into the host, nor the host's into the template
  beyond intended inheritance. Flutter is naturally isolated (no cascade; widget
  styling is explicit). Jaspr/DOM is **not** — CSS cascades globally, so a template
  rendered into a host page can bleed styles both ways. Truly separate branding on
  the web likely needs scoping (a shadow root, or a strict scoping / containment
  strategy). This is the biggest adapter-specific unknown, and it interacts with
  the embedding story (Flutter-in-Jaspr on the demo site).
- **Font loading.** A type token names a family, but the family must *exist* on the
  platform. Ephemeral font *files* are large binary assets and their own hard
  problem (like ephemeral code). v1: reference fonts by name, host-resolved
  (bundled or system); ephemeral `@font-face`-style loading is later.
- **Token vocabulary — answered (§9.4):** a small neutral role set with
  surface/foreground pairing, M3-name-compatible where obvious; the semantic
  contract is ours to author and version.
- **Dark mode — answered (§9.5):** neither a second vocabulary nor a bare
  flag — the semantic layer selects a different value per **n-ary mode input**
  (light / dark / high-contrast), the shape CSS `light-dark()`, Panda condition
  tokens, DTCG resolver modifiers, and M3 `isDark` all converge on
  (`research/theming/PRIOR_ART.md` §B.3). Role names never change across modes.
- **How much per-component style surface** to expose before this becomes
  "reimplement CSS in JSON." The catalog-template escape hatch (§9.3, item 2) is
  the pressure-release valve — keep the token set small and push bespoke styling
  into templates.

## 10. The A2UI Craft project (the ephemeral bundle)

The unit that travels the author's channel deserves a name: an **A2UI Craft
project** is a self-contained, *ephemerally loadable* bundle of everything a
template author ships — catalog templates (`.craft`), their A2UI bindings
(component schema), a theme (§9.5), and config (a small manifest: name, catalog
id, theme reference, mode wiring). Being ephemeral, it contains **data only** —
no code; ephemeral business logic (ROADMAP.md's sandboxed-logic layer) gets a
manifest slot *later*, empty for now.

A project is **agent-optional**, which splits its A2UI messages into two roles:

- **`app.json` — the bootstrap.** For a **mini-app** deployment (no agent), the
  project ships a canned A2UI stream that builds the initial surface; the host
  loads and replays it. This is real, deployed content. A **pure-A2UI**
  (agent-driven) deployment omits `app.json` — the transport supplies the stream
  live, and the runtime just exposes the hooks to connect it.
- **`tests.json` — named dev scenarios.** An *optional* map of named A2UI streams
  (e.g. `empty` / `loaded` / `error`), clearly labeled test data, for exercising
  or demoing a project without an LLM. Not the app's content; a tool concern.

The demo samples prove the mini-app shape: each `samples/<id>/` project
(`template.craft` + `schema.json` + `app.json` + `manifest.json`) is a mini-app
whose `app.json` *is* its bootstrap, and the demo site is a project loader. The
consolidated `manifest.json` (`ProjectManifest`) carries the display name, the
catalog id, and the theme reference + mode wiring; the samples root is reduced
to a gallery-order id list.

Because a project is **data, not code**, deployment is just publishing static
files to a CDN (Firebase Hosting will do): no compile step. The host fetches the
project from its URL at runtime, so editing and re-publishing the project updates
the UI with **no host redeploy** — the ephemeral-loadability property made
concrete. The tooling that demonstrates this: the `craft` CLI
(`craft create`) scaffolds a deployable project, the runtime `CraftProjectLoader`
fetches one over HTTP (manifest → template/schema/`app.json`, plus optional
`tests.json`), and the demo site's URL-bar screen loads a project from any URL and
renders it on either adapter.

## 11. Security: upholding A2UI's secure-by-design promise

> **Status: noted, not yet designed.** This section records a requirement so it is
> not forgotten. The actual threat model and mechanisms are future work, orthogonal
> to the primitives (§8) and not designed in this pass.

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
capability ceiling.** (This is also why sub-/super-setting, §8, is the right place
to reason about what a deployment grants: capability is conferred by what goes into
the catalog.) Keeping that boundary intact as the language and engine grow is the
core security invariant.

### Where the risk concentrates: template provenance

The threat scales with **who supplies a template, and when**:

- **Build-time, vetted, shipped with the client** (§4) — templates
  are *app code*: trusted, reviewed, not an external attack vector. A runaway
  template only harms its own author.
- **Ephemerally delivered at runtime** (the project, §10; `loadCatalog` already
  makes component *schemas* data) from a server, a third-party catalog, or
  anything the agent can influence — now a template is **untrusted input** and
  must be treated with the same suspicion as the rest of the ephemeral payload.

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

## 12. Repository layout

```
a2ui-craft/
├── DESIGN.md                     # this document (source of truth)
├── ROADMAP.md                    # status & slice-by-slice implementation plans
├── README.md
├── AGENTS.md                     # agent-agnostic guidance (build/test, pointers)
├── LICENSE                       # BSD-3-Clause (forked from RFW)
├── VENDORED.md                   # provenance of vendored RFW code + our extensions
├── pubspec.yaml                  # Dart pub workspace root
├── tool/check.sh                 # one entrypoint: resolve + format + analyze + test
├── tool/testing/                 # repo-wide checks (e.g. license headers); not published
├── .github/workflows/ci.yml      # CI: runs tool/check.sh
├── skills/                       # project skills (adapter-authoring guidance)
├── research/                     # design research notes (e.g. theming prior art)
├── site/                         # demo site: Jaspr host + embedded Flutter; gallery + project loader
└── packages/
    ├── a2ui_craft/               # core: vendored RFW formats, tokens/theme, functions
    ├── a2ui_craft_bridge/        # A2UI → engine, on a2ui_core (framework-neutral)
    ├── a2ui_craft_testing/       # shared conformance + geometry suites (not published)
    ├── a2ui_craft_examples/      # sample projects, SampleSpec, CraftProjectLoader
    ├── a2ui_craft_flutter/       # Flutter adapter (runtime + core primitives + example)
    ├── a2ui_craft_jaspr/         # Jaspr adapter (runtime + core primitives + example)
    └── craft/                    # the `craft` CLI (`craft create`)
```

Run `tool/check.sh` to verify the whole workspace (format, analyze, and tests for
every package) — it is exactly what CI runs.

Because one member (`a2ui_craft_flutter`) depends on the Flutter SDK, the whole
workspace is resolved with **`flutter pub get`** (Flutter's bundled Dart also runs
the pure-Dart and Jaspr packages fine). The *core* package itself remains
Flutter-free; only the workspace resolution involves the Flutter SDK.

## 13. Open questions

- **Core primitive vocabulary (H2):** the constrained common model (§8) settles
  the *shape*; still open is the exact per-category widget set and how far the
  layout algebra reaches (e.g. `Grid`, scrolling/overflow, `Stack` z-order)
  before the "drop to raw framework" escape hatch (§2) takes over.
- **Type model:** the precise canonical shapes of the §8 value types, and how
  `Dimension`'s `flex`/`fill`/`hug` interact with nested scroll/intrinsic-sizing
  edge cases.
- **Per-idiom gaps in the Cupertino preview (§8):** the v1 role-limit tables
  are authored, but two controls render their Material form under the
  Cupertino idiom — `TextField` (no `.adaptive` constructor; a
  `CupertinoTextField` mapping is a candidate) and `Select` (no adaptive
  dropdown). Whether to hand-map those, and whether `Radio` should gain an
  adaptive glyph, is open.
- **Catalog packaging & versioning:** the project (§10) answers how templates
  are authored and bundled; still open is how catalogs and their templates are
  **versioned** as they evolve — what a host pins, and how a project declares
  compatibility.
- **List-item identity — filed as [a2ui#1745](https://github.com/a2ui-project/a2ui/issues/1745).**
  A2UI gives every *component* a stable id but attaches **no identifier to the
  elements of a data array** unrolled by a `ChildList`, forcing positional
  reconciliation for list items (§6). The fix is requested at the spec +
  `a2ui_core` level. Our side is **keyed-when-present, positional-fallback
  (permanent)** — see §6; the fallback stays even after keys land, since per-item
  keys are opt-in. To adopt keys when available: surface the item key from
  `a2ui_core`'s `ChildNode` and set it as the child adapter's key (salted by the
  parent list id). Track the issue for the final key shape.
- **Reactivity granularity (§5):** with `a2ui_core` resolving props to concrete
  values fed as template `args`, reactivity is component-granular
  (whole-component rebuild) rather than per-binding. Open: is that granularity
  acceptable as catalogs grow (likely yes — small vetted widgets), or does some
  hot path eventually want per-binding updates back?
