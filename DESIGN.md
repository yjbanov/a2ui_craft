# A2UI Craft — Design

> **Status: draft / initial outline.** This document captures the starting
> design for A2UI Craft. It will evolve as the language and compiler are built.
> Where the document describes syntax, treat it as a proposal to be refined, not
> a frozen specification.

## 1. Overview

A2UI is a protocol for agents to drive user interfaces. It is layered:

| Layer | Audience | Optimized for |
| --- | --- | --- |
| **A2UI Transport** | Clients/renderers | A precise, validated JSON wire format. The "machine code" of A2UI. |
| **A2UI Express** | LLMs (token stream) | Token efficiency, generation latency, and accuracy. Compiled on-the-fly to Transport by an agent SDK. |
| **A2UI Craft** | Humans & coding agents | Readability, maintainability, expressivity, and trust for **predefined, reviewed** UI. |

**A2UI Transport** is the JSON protocol that defines how UI is encoded between
the agent and the client (`createSurface`, `updateComponents`,
`updateDataModel`, `deleteSurface`, `action`/`actionResponse`, a component
catalog, a data model with JSON-Pointer bindings, and registered functions).
See the A2UI specification (`v0.10`) for details.

**A2UI Express** is the inference-time language LLMs emit; an agent SDK compiles
it to Transport as tokens stream in. Its constraints pull toward brevity and
model-friendliness.

**A2UI Craft** (this project) serves the *other* major use case: UI that is
**authored and vetted ahead of time** — written by humans or coding agents,
code-reviewed, version-controlled, linted, and tested like any other source
code (Dart, C++, JavaScript…). This is how A2UI achieves predictability, trust,
and expressivity that Express deliberately cannot.

A2UI Craft is an **ahead-of-time compiled** language: it has a real compiler
(not just an interpreter) that produces A2UI Transport. It must be able to
express **everything** A2UI Transport can express, and it may add higher-level
features as long as each one **desugars** into Transport during compilation.

## 2. Goals and non-goals

### Goals

- **Capable** — can express the full feature set of A2UI Transport.
- **Readable** — a human can read a Craft file and understand the resulting UI.
- **Maintainable** — supports abstraction, reuse, and splitting code across files.
- **Bug-resistant** — strong compile-time checks: undefined components, bad
  references, cyclic imports, type/shape mismatches against the catalog, etc.,
  are caught before anything is shipped.
- **Toolable** — a clean, well-specified grammar and a reusable compiler library
  so an ecosystem (editors, linters, formatters, language servers) can grow.
- **Distributable** — the compiler is written in Dart and ships as an
  AOT-compiled standalone executable (plus an embeddable library).

### Non-goals

- **Not** optimized for LLM token streams — that is A2UI Express's job. Craft
  optimizes for human comprehension and review.
- **Not** a general-purpose programming language. It is a UI templating language
  with compile-time evaluation, not a runtime with arbitrary computation.
- **Not** a renderer. Craft produces Transport JSON; existing A2UI clients render
  it.

## 3. Influences

The surface syntax is inspired by **Remote Flutter Widgets (RFW)** — a C-style /
Dart-style, curly-brace language (`packages/rfw`). Familiar RFW ideas we adopt
or adapt:

- A widget/component is written as a **nested tree** of constructor-like calls
  (`Column(children: [ Text(text: "Hi") ])`), which reads far better than the
  flat adjacency list Transport uses.
- Named **arguments** in parentheses, map literals `{ ... }`, list literals
  `[ ... ]`.
- A `...for x in <list>: <body>` **spread/loop** construct inside child lists.
- Reusable, parameterized **component declarations** (RFW's `widget`).
- Data references via a dotted path root (RFW uses `data.foo.bar`; we map this to
  A2UI's JSON Pointer `/foo/bar`).
- C-style line (`//`) and block (`/* */`) comments.

Key difference from RFW: A2UI Craft targets **A2UI Transport**, not Flutter's
binary RFW format. The component catalog, data-binding model, events, and
functions are A2UI's, and the compiler emits A2UI envelope messages.

## 4. What the language must map onto (A2UI Transport)

The compiler's job is to lower friendly Craft constructs into Transport. The
core mapping:

| A2UI Craft construct | A2UI Transport output |
| --- | --- |
| `surface Name { ... }` | `createSurface` (+ `updateComponents`, `updateDataModel`) |
| Nested component tree | Flat `components` adjacency list with generated `id`s and `child`/`children` refs |
| `Text(text: "Hi")` | `{ "id": "...", "component": "Text", "text": "Hi" }` |
| `data.user.name` (path ref) | `{ "path": "/user/name" }` (a `Dynamic*` binding) |
| Relative ref inside a loop | Relative JSON Pointer (e.g. `name`) resolved in the child scope |
| `"Hi ${data.user.name}!"` (interpolated string) | `formatString` `FunctionCall` |
| `formatCurrency(value: ..., ...)` | `{ "call": "formatCurrency", "args": {...}, "returnType": ... }` |
| `...for item in data.items: Card(...)` | `ChildList` **template** form `{ "path": "/items", "componentId": "..." }` |
| `onPress: event "name" { ctx }` | `action.event` `{ "name": ..., "context": {...} }` |
| `onPress: openUrl(url: ...)` | `action.functionCall` |
| `checks: [ required(...) ... ]` | component `checks` array |
| `theme { primaryColor: ... }` | `createSurface.theme` |
| `data { ... }` | initial `dataModel` |

### 4.1 Two kinds of "dynamic", kept distinct

A2UI has two distinct dynamic mechanisms, and Craft must keep them separate:

1. **Compile-time reuse** — `component` declarations (below) are **expanded
   (inlined)** by the compiler. Transport has no notion of reusable widget
   definitions, so these vanish at compile time, producing concrete components.
2. **Run-time data-driven lists** — when a child list iterates over a **data
   model array**, it must compile to A2UI's `ChildList` **object template**
   (`{ path, componentId }`) so the client stays reactive as the data changes.
   A `...for` over a data path lowers to this; a `...for` over a *compile-time*
   list is unrolled at compile time instead.

### 4.2 Adjacency-list flattening & id allocation

The author writes a tree; the compiler flattens it. Every component needs a
stable `id`. Rules (initial proposal):

- Exactly one component must become `id: "root"` (the `root:` of a `surface`).
- Authors may pin an explicit id: `Text#title(text: ...)` → `id: "title"`.
- Otherwise the compiler generates deterministic, stable ids (e.g. derived from
  the path in the tree) so that re-compiling the same source is reproducible and
  diff-friendly.

## 5. Language sketch

> Illustrative only — see `examples/product_card.craft`. Subject to change.

```craft
import "core";          // import another Craft file (see §6)

// A reusable, parameterized component. Inlined at compile time.
component Stars(rating) = Text(text: data.stars, variant: "body");

surface ProductCard {
  catalog: "https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json";
  sendDataModel: true;

  data {                // initial data model
    name: "Headphones",
    price: 199.99,
    reviewCount: 2847,
  }

  root: Card(
    child: Column(children: [
      Text(text: data.name, variant: "h3"),
      Text(
        text: "(${formatNumber(value: data.reviewCount)} ${pluralize(value: data.reviewCount, one: "review", other: "reviews")})",
        variant: "caption",
      ),
      Text(text: formatCurrency(value: data.price, currency: "USD"), variant: "h2"),
      Button(
        variant: "primary",
        child: Text(text: "Add to Cart"),
        onPress: event "addToCart" {},
      ),
    ]),
  );
}
```

### 5.1 Lexical structure (implemented)

The lexer (`packages/a2ui_craft/lib/src/lexer.dart`) already recognizes the
intended lexical grammar:

- **Comments:** `// line` and `/* block */` (non-nested).
- **Identifiers:** `[A-Za-z_][A-Za-z0-9_]*`.
- **Numbers:** integers (decimal, optional leading `-`), hex (`0xFF`), and
  doubles (with `.` fraction and/or `e`/`E` exponent). Int vs. double is
  distinguished syntactically, matching Transport's number model.
- **Strings:** single- or double-quoted, with `\b \f \n \r \t \" \' \/ \\` and
  `\uXXXX` escapes. (String **interpolation** is a parser/lowering concern, not
  lexical, in this first cut.)
- **Punctuation:** `{ } ( ) [ ] : ; , . =` and the `...` spread token.

## 6. Module system

- A program may be split across multiple `.craft` files.
- `import "path";` brings another file's declarations into scope.
- **Cyclic imports are forbidden**, and the compiler **must enforce** this:
  building the module dependency graph and rejecting any cycle with a clear
  diagnostic naming the cycle.
- Resolution order: lex/parse each file, build the import graph, topologically
  sort, then analyze. Imports are resolved relative to the importing file's URI.

## 7. Compile-time features

These are the "may add its own features, so long as they desugar" powers:

- **Constants:** `const PRIMARY = "#00BFFF";` — compile-time values usable in
  templates.
- **External config:** a config file (e.g. JSON/YAML) fed to the compiler
  alongside the sources, exposing values (feature flags, environment names,
  brand colors) for **compile-time** evaluation. Modeled today as
  `CompileOptions.config` (`packages/a2ui_craft/lib/src/compiler.dart`).
- **Compile-time conditionals / expressions:** e.g. selecting components or
  values based on config, fully evaluated away before codegen so the emitted
  Transport contains no trace of them.

Compile-time evaluation is deliberately limited and total (no unbounded
computation) to preserve predictability.

## 8. Compiler architecture

The compiler is a conventional multi-stage AOT pipeline. Stage 1 exists today;
later stages are stubs tracked here.

1. **Lex** — source text → tokens. *(implemented)*
2. **Parse** — tokens → AST.
3. **Resolve imports** — build the module graph; reject cycles.
4. **Analyze** — name/reference resolution; validate components and arguments
   against the catalog; type/shape checks; two-way-binding rules.
5. **Evaluate** — fold constants, apply config, resolve compile-time conditionals.
6. **Lower** — expand `component` definitions; flatten the tree to the
   adjacency-list model; allocate ids; convert path refs, interpolations, loops,
   events, and function calls to their Transport forms.
7. **Emit** — serialize the ordered A2UI Transport envelope messages to
   JSON / JSONL.

Diagnostics (`packages/a2ui_craft/lib/src/diagnostic.dart`) are
location-anchored (`SourceSpan`) and accumulated so the compiler can report many
problems at once rather than failing on the first.

### Design principles for the compiler

- **Pure-Dart core.** `a2ui_craft` has no Flutter dependency, so it runs on
  servers and in CLIs.
- **Library first, CLI second.** All real logic lives in the library; the
  `craft` CLI is a thin front-end. This lets editors/linters/LSP reuse the core.
- **Deterministic output.** The same input (sources + config) always produces
  byte-identical Transport, for reviewable, diffable builds.
- **Fail loudly, honestly.** Unimplemented stages throw rather than silently
  emitting empty output.

## 9. Repository layout

```
a2ui-craft/
├── DESIGN.md                 # this document
├── README.md
├── pubspec.yaml              # Dart pub *workspace* root (ties packages together)
├── analysis_options.yaml     # shared lints
├── examples/                 # illustrative .craft sources
└── packages/
    ├── a2ui_craft/           # the compiler core library (pure Dart)
    │   ├── lib/a2ui_craft.dart
    │   └── lib/src/{source,diagnostic,token,lexer,compiler,version}.dart
    └── a2ui_craft_cli/       # the `craft` executable (AOT-compilable)
        └── bin/craft.dart
```

The project is structured as a **multi-package Dart workspace** from the start
because it is expected to grow (e.g. a language server, a formatter, a catalog
schema package, build-system integrations). New packages go under `packages/`
and are added to the `workspace:` list in the root `pubspec.yaml`.

## 10. Open questions / future work

- **Id allocation strategy** — fully implicit vs. explicit `#id` pins; how to
  guarantee stability across edits.
- **Catalog awareness** — should the compiler load a catalog schema to validate
  component names, property types, and function signatures? (Strongly desirable
  for bug-resistance.)
- **Source extension** — `.craft` is the working choice.
- **Streaming semantics** — how authors express multiple `updateComponents` /
  `updateDataModel` messages, partial/progressive surfaces, and `deleteSurface`.
- **String interpolation grammar** — exact rules and how it maps to nested
  `formatString` expressions.
- **State & local interactivity** — Transport models interactivity via the data
  model + actions; decide how much, if any, RFW-style local `state` Craft should
  expose, and how it lowers.
- **Formatter & language server** — likely future packages in this workspace.
