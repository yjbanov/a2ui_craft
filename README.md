# A2UI Craft

**A2UI Craft** is a templating language for authoring [A2UI](https://github.com/google/A2UI)
user interfaces. It is a human-friendly, C-style (Dart-style) language that
**compiles ahead-of-time to A2UI Transport** — the JSON protocol A2UI clients
render.

> ⚠️ **Early stage.** The language design is taking shape in
> [`DESIGN.md`](DESIGN.md). The compiler currently implements lexing; parsing
> and code generation are next. Syntax shown below is a proposal and may change.

## Why A2UI Craft?

A2UI has three complementary languages:

- **A2UI Transport** — the validated JSON wire format between agent and client.
- **A2UI Express** — a terse language LLMs emit and an agent SDK compiles to
  Transport on the fly, optimized for token efficiency and generation accuracy.
- **A2UI Craft** (this project) — for **predefined UI authored and reviewed
  ahead of time** by humans and coding agents. It optimizes for readability,
  maintainability, expressivity, and trust — things you get from source code
  that is version-controlled, code-reviewed, linted, and tested.

Where A2UI Express trades expressivity for brevity, A2UI Craft does the
opposite: it is meant to be **read, understood, maintained, and tooled**.

## What it looks like

```craft
import "core";

surface ProductCard {
  catalog: "https://a2ui.org/specification/v0_10/catalogs/basic/catalog.json";

  data {
    name: "Wireless Headphones Pro",
    price: 199.99,
  }

  root: Card(
    child: Column(children: [
      Text(text: data.name, variant: "h3"),
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

The author writes a **nested tree**; the compiler flattens it into A2UI
Transport's flat adjacency-list of components, allocates ids, and lowers data
references, string interpolation, loops, events, and function calls into their
Transport forms. See [`examples/`](examples/) and [`DESIGN.md`](DESIGN.md).

## Project layout

This is a [Dart pub workspace](https://dart.dev/tools/pub/workspaces) (monorepo).

```
packages/
  a2ui_craft/       # the compiler core library (pure Dart, no Flutter dependency)
  a2ui_craft_cli/   # the `craft` command-line compiler (AOT-compilable)
examples/           # illustrative .craft sources
DESIGN.md           # language & compiler design
```

Why Dart? The compiler can be distributed as a single **AOT-compiled native
executable**, while also being embeddable as a pure-Dart library (for editors,
linters, language servers, and build steps).

## Getting started

Requires the Dart SDK (3.6+).

```bash
# Resolve all workspace packages with a shared lockfile.
dart pub get

# Run the test suites.
(cd packages/a2ui_craft && dart test)
(cd packages/a2ui_craft_cli && dart test)

# Run the CLI from source.
dart run packages/a2ui_craft_cli/bin/craft.dart --version

# Build a standalone native executable.
dart compile exe packages/a2ui_craft_cli/bin/craft.dart -o craft
./craft --help
```

> Today the compiler lexes input and then reports that parsing/codegen are not
> implemented yet. That is expected — see the roadmap in `DESIGN.md`.

## Status & roadmap

Implemented:

- [x] Multi-package Dart workspace scaffolding
- [x] Lexer (comments, identifiers, int/double/hex numbers, strings, punctuation)
- [x] Diagnostics with source spans
- [x] `craft` CLI skeleton (AOT-compilable)

Next (tracked in [`DESIGN.md`](DESIGN.md)):

- [ ] Parser & AST
- [ ] Import resolution with cycle detection
- [ ] Semantic analysis / catalog validation
- [ ] Compile-time evaluation (constants, config, conditionals)
- [ ] Lowering to the adjacency-list model
- [ ] A2UI Transport JSON/JSONL code generation

## License

To be determined.
