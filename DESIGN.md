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
   CSS layout/animation). **H2 work has not started** — see §7. The current core
   component sets are intentionally minimal harness fixtures, not the real
   library.

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

## 6. Repository layout

```
a2ui-craft/
├── DESIGN.md                     # this document (source of truth)
├── README.md
├── AGENTS.md                     # agent-agnostic guidance (build/test, pointers)
├── LICENSE                       # BSD-3-Clause (forked from RFW)
├── VENDORED.md                   # provenance of vendored RFW code
├── pubspec.yaml                  # Dart pub workspace root
├── tool/check.sh                 # one entrypoint: resolve + format + analyze + test
├── .github/workflows/ci.yml      # CI: runs tool/check.sh
├── skills/                       # project skills (adapter-authoring guidance)
└── packages/
    ├── a2ui_craft/               # core: vendored RFW formats + DynamicContent
    ├── a2ui_craft_testing/       # shared parity-test fixtures (not published)
    ├── a2ui_craft_flutter/       # Flutter adapter (runtime + core comps + test)
    └── a2ui_craft_jaspr/         # Jaspr adapter (runtime + core comps + example + test)
```

Run `tool/check.sh` to verify the whole workspace (format, analyze, and tests for
every package) — it is exactly what CI runs.

Because one member (`a2ui_craft_flutter`) depends on the Flutter SDK, the whole
workspace is resolved with **`flutter pub get`** (Flutter's bundled Dart also runs
the pure-Dart and Jaspr packages fine). The *core* package itself remains
Flutter-free; only the workspace resolution involves the Flutter SDK.

## 7. Status & roadmap

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
- [ ] **H2:** design the real cross-platform core component/type library (NOT yet
      started — deliberately deferred until the harness is solid).
- [ ] Prove the state-model axis with a third, non-Flutter-like framework.
- [ ] A2UI integration: map an A2UI catalog + data model onto the engine.
- [ ] Consider upstream RFW restructuring so the formats layer need not be
      vendored.

## 8. Open questions

- **Core component vocabulary (H2):** what is the least-common-denominator set,
  and how are layout/animation differences reconciled between Flutter and the
  DOM?
- **Type model:** the equivalent of RFW's `argument_decoders` is intensely
  Flutter-specific and is explicitly *not* part of the core; H2 must define a
  framework-neutral type/style model that each adapter maps down.
- **Template packaging & the A2UI catalog binding:** how templates are named,
  bundled, and matched to A2UI `component` references.
