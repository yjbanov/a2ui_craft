# Next threads — prioritized

A cross-cutting sequencing note (2026-07-21) covering the threads in flight and
queued. Topic design docs live in `research/<topic>/`; this file is only about
*order and rationale*, and should be pruned as threads land.

## The workstreams

| | Workstream | Status |
|---|---|---|
| **A** | Mobile pointer events (Flutter web `flt-semantics-placeholder`) | ✅ Landed (shim in `site/web/index.html`) |
| **B** | Template computation — logic blocks + user-defined functions | Needs design |
| **C** | Agent semantics / annotations | `agent-semantics` worktree, design-only |
| **D** | Animation Phase 1 | Planned & shovel-ready (`research/animation/PHASE_1_PLAN.md`) |
| **E** | Business-logic drivers (mini-apps) | Designed & planned (`research/logic/`), shovel-ready |

**Logic blocks and user-defined functions are one arc, not two threads.** A
curly-braced block *is* the body syntax a user-defined function needs. One design
doc; two implementation phases (blocks first).

## Grounding (verified 2026-07-21)

Three facts that shape the plan:

1. **Parameterized sub-UI already exists in the format.**
   `WidgetBuilderDeclaration(argumentName, widget)`
   (`packages/a2ui_craft/lib/src/model.dart:444`) is parsed by both the text and
   binary readers, alongside `WidgetDeclaration` for named reusable widgets. The
   "anonymous bit of UI embedded in a widget" idea may be largely an
   *exposure/ergonomics* problem rather than new syntax. **Inventory what is
   already expressible before designing anything new.**
2. **Evaluation is duplicated per adapter.** Parsing lives once in the core, but
   `SetStateHandler` and function-call evaluation execute in *both*
   `a2ui_craft_flutter/lib/src/runtime.dart` and the Jaspr equivalent. Every new
   language construct means two implementations held together only by the
   conformance suite. This is the central architectural risk for workstream B.
3. **State is already widget-scoped.** `WidgetDeclaration` carries
   `initialState` (`model.dart:902`), which supports the instinct that
   `set state.*` belongs to widget scope rather than arbitrary functions.

## P0 — Mobile pointer events (workstream A) — ✅ LANDED

**Shipped:** a CSS shim in `site/web/index.html` setting
`flt-semantics-placeholder { pointer-events: none !important; }`.

Verified in-browser: with the placeholder stretched to full-viewport (exactly
what the engine does on mobile), every probe point reached real page content —
including an `<a>` — where it previously hit the placeholder. The element stays
in the DOM with `role=button`, `aria-label`, and focusability intact.

Two findings worth keeping:

- The engine appends the placeholder to **`<body>`, not inside the
  `flutter-view`** — so on mobile it blankets the *whole Jaspr page*, not just
  the Flutter pane. On desktop it is 1x1 at (-1,-1), which is why this only
  reproduces on mobile.
- **CSS beat the MutationObserver plan**: no lifecycle or timing race, it keeps
  applying if the engine re-inserts or re-styles the element, and it is
  non-destructive (removal would have dropped the a11y affordance entirely).

Still to do: paste the upstream flutter/flutter issue link into the shim's
comment, and delete the shim once that bug is fixed.

The original analysis follows.

### Original analysis

Best value/effort ratio: a user-visible defect on the public demo
(https://a2ui-craft.web.app) at exactly the moment the packages go public.
Self-contained, independently verifiable, no language risk.

The problem: on mobile browsers Flutter web inserts a `<flt-semantics-placeholder>`
spanning the viewport, which swallows pointer events that should reach the
Jaspr-rendered DOM. This is an upstream Flutter multi-view bug (reported); what
we build here is a **temporary shim**.

Decisions to make deliberately:

- **The a11y tradeoff is real.** That placeholder is Flutter web's
  *enable-accessibility* affordance. Removing it outright drops that entry point
  for the embedded Flutter view — and this repo holds an a11y conformance
  dimension. Prefer the least-destructive fix first (`pointer-events: none`),
  and fall back to a self-destructing `MutationObserver` removal only if that
  breaks its click-to-enable behaviour. Document the regression either way.
- **Scope the shim to `site/`, not the published `a2ui_craft_jaspr`.** A
  Flutter-web-specific workaround does not belong in a package other people
  depend on.
- **Tag it with the upstream issue** so it is obviously deletable later.

## P1 — Template computation (workstream B), design first

Highest leverage and the most expensive to get wrong: template syntax is the
public contract of the format, and the packages are being published now. It is
far cheaper to settle before adoption. Follow the repo's proven pattern —
research note → phase plan → slices.

Order within the arc: **blocks first** (standalone payoff in callbacks), then
user-defined functions on top.

Design questions to resolve explicitly:

- **Purity framing.** A block containing `set state.*` is not pure. But if a
  block evaluates to *(value, enqueued mutations)* applied after the block
  completes, it stays a pure *description* of value + effects — preserving
  determinism and the "ignore prior UI state" render model. Name this model in
  the doc.
- **The key simplicity fork:** do functions receive a state handle (a new
  first-class "state sink" value), or are functions strictly pure-value-only,
  with `set` confined to widget event handlers? The latter is much simpler;
  default to it and treat the handle as a later extension.
- **Likely prerequisite:** move block/function *evaluation* into the core so
  adapters only construct nodes (see grounding #2). Otherwise every construct
  doubles and drifts. This may deserve its own slice ahead of any syntax work.
- **Cheapest first step, before designing:** empirically verify whether a second
  `set` observes the first's write today. One test; answers the open question and
  pins current behaviour before changing it.

## P2 — Pick one: Animation Phase 1 vs. starting B's implementation

These compete for the same slot. Animation (D) is already sliced and ready to
execute; B needs design first. A reasonable split is to **design B while
implementing D**.

## Out of band — Agent semantics (workstream C)

Being designed in the `agent-semantics` worktree; not re-planned here. One
scheduling note: it is design-only today (a single research doc, no code), but
when it starts implementing it will likely touch `text.dart` / `model.dart` /
`binary.dart` — the same files the blocks parser will. Avoid having both
mid-flight in those files simultaneously.
