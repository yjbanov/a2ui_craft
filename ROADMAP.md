# A2UI Craft — Roadmap

> What is **not** done yet, and in what order. Completed work — and what building
> it taught — lives in [HISTORY.md](HISTORY.md); the stable design rationale
> lives in [DESIGN.md](DESIGN.md), and section references like `§9` point into
> it. Topic research notes live under `research/<topic>/`.
>
> This file churns. An item leaves it by moving to HISTORY.md, not by being
> ticked in place.

## Where we are

The framework covers the whole span a real app needs: **templates** over a
constrained cross-framework primitive set, **theming** (DTCG tokens, modes,
custom brands), **responsive** structure (size classes, `Grid`, the `media.`
scope), **motion**, **typography**, normalized **controls**, and now
**business logic** — mini-apps whose logic ships as data and runs in a sandbox,
proven by running the same conformance suite against a Dart driver and a
JavaScript one. Two adapters (Flutter, Jaspr) are held together by a shared
conformance suite that asserts real geometry, not structure.

What has *not* happened is someone building a real application on it, under
production conditions, without the repo's affordances at hand.

## Now — build a real app on it

The next move is not a framework feature. It is a **substantial demo app, built
outside this repository** and deployed for real use — first to the web, and if it
can be pulled off, to the Play Store and the App Store.

Why outside the repo: the point is to stand where a user of this framework
stands. An in-repo demo gets the tight fix-as-you-go loop, but it also gets
path dependencies, the workspace's pub resolution, `check.sh`, and every
affordance that a real adopter does not have. Out of the repo, the app needs its
own infrastructure — Firebase config, integration tests, backend code
uninteresting to Craft itself — and that is exactly the cost being measured. The
loss of loop tightness is a deliberate, accepted trade.

What it is expected to surface, and what nothing so far can:

- **Ephemeral delivery under real network conditions.** A template or a driver
  that fails to load on a subway is not a hypothetical; the framework's failure
  posture ("freeze beats betray") has only ever been exercised against fixtures.
- **The adopter's first hour.** Scaffolding, publishing, cache headers, the
  edit → re-publish → reload cycle with a host that is *not* the demo site.
- **Whether the primitive set is actually enough** for an app someone would use,
  as opposed to a gallery sample that was chosen because it fits.

Framework gaps found this way get fixed here, in slices, as they appear.

## Open threads

### Template computation — blocks and user-defined functions

The **standard-function layer shipped** (see HISTORY.md): a template author can
call host-provided pure functions in any value position and on a `set state`
right-hand side, with argument-schema validation and cross-adapter conformance.
What remains is the authoring layer above it.

**Blocks and user-defined functions are one arc, not two threads.** A
curly-braced block *is* the body syntax a user-defined function needs. One design
doc; two implementation phases (blocks first, which has standalone payoff in
callbacks).

This is the most expensive thing on the list to get wrong — template syntax is
the public contract of the format, and the packages are published — so it is
**design first**, following the repo's proven pattern: research note → phase plan
→ slices.

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
- **Likely prerequisite: move evaluation into the core.** Parsing lives once in
  the core, but `SetStateHandler` and function-call evaluation execute in *both*
  adapters' `runtime.dart`. Every new language construct means two
  implementations held together only by the conformance suite — the central
  architectural risk for this thread. This may deserve its own slice ahead of any
  syntax work.
- **Cheapest first step, before designing:** empirically verify whether a second
  `set` observes the first's write today. One test; it answers the open question
  and pins current behaviour before anything changes it.

Two facts already verified that shape the design:

- **Parameterized sub-UI already exists in the format.**
  `WidgetBuilderDeclaration(argumentName, widget)` (`a2ui_craft`'s `model.dart`)
  is parsed by both the text and binary readers, alongside `WidgetDeclaration`
  for named reusable widgets. "An anonymous bit of UI embedded in a widget" may
  be largely an *exposure/ergonomics* problem rather than new syntax. **Inventory
  what is already expressible before designing anything new.**
- **State is already widget-scoped.** `WidgetDeclaration` carries `initialState`,
  which supports the instinct that `set state.*` belongs to widget scope rather
  than to arbitrary functions.

### Business-logic drivers — Phase 2, the reactive driver framework

Planned and shovel-ready: `research/logic/PHASE_2_PLAN.md`, over the research in
`research/logic/REACTIVE_FRAMEWORK.md`. It builds the **measurement instrument
first**, because signals-as-bindings versus VDOM-diff is an empirical question,
and building the framework first would turn it into a taste question defended
after the fact.

Also open from Phase 1, recorded in `research/logic/DECISIONS.md`: the mini-app
panes bypass `SampleView`, so a themed logic project renders unthemed (the fix is
an externally-owned-surface mode on `SampleView`); the JS SDK reports faults the
way the Dart machine does but does not yet validate frame bodies field by field;
and multi-surface sessions remain deliberately unbuilt.

### Agent semantics

Being designed in the `agent-semantics` worktree; design-only today (one research
doc, no code). **Scheduling note:** when it starts implementing it will likely
touch `text.dart` / `model.dart` / `binary.dart` — the same files a blocks parser
will. Avoid having both mid-flight in those files simultaneously.

### Control normalization — the remaining gaps

Every control has its role mapping and both adapters paint it (HISTORY.md). What
is left is per-idiom and per-control polish, tracked in DESIGN.md §13:

- `TextField` and `Select` render their Material form under the Cupertino
  preview (neither has an `.adaptive` path); `Radio` keeps its custom glyph in
  both idioms; the `/load` screen has no idiom picker.
- Interactive `Select` conformance (the Flutter popup renders options only while
  open), native radio **grouping** and the change-vs-click event choice, and
  disabled-button visuals (samples still use handler-less buttons as static
  decoration — revisit when they stop).
- A shared conformance probe for glyph colors; per-adapter pins cover the role
  mapping today.

### Sample coverage gaps

The `demonstrates` labels double as a coverage audit, because labeling is
deliberately strict. Counted over the 49 sample projects (2026-08-21):
`controls` 21, `layout` 13, `functions` 7, `a2ui` 4, `theming` 2.

- **A2UI integration is the thinnest (4/49):** only `greeting`, `profile_card`,
  `form`, and `settings` compose multiple components by id refs or touch the
  data model; everything else is a single-component `updateComponents`. No
  sample uses an A2UI-level `ChildList` (`child_list_template`, despite the
  name, loops *inside* its template), and none demonstrates streamed/incremental
  surface updates (`incremental` / `incremental_dashboard` are single-shot).
- **Layout gaps:** no sample — and no primitive — demonstrates Stack/z-order,
  baseline alignment, margin, or transform, matching the §8 Pillar D backlog.
- **Controls gaps:** `settings` covers Switch, Select, and a Radio group. What
  is left is **tabs**, which is blocked on a `Tabs` primitive (see below), not
  on a sample.
- **Theming reads as 2/49 by design, not by neglect.** Per-sample brand themes
  were deliberately retired once the site's brand picker could recolor any
  sample (HISTORY.md); the label now means "ships custom tokens its template
  references by name", which only `calculator` and `motion` do.
- **18 samples demonstrate none of the tracked properties** — static showcase
  cards: `chat_message`, `child_list_template`, `contact_card`,
  `countdown_timer`, `credit_card`, `event_detail`, `flight_status`, `gallery`,
  `incremental`, `markdown_text`, `purchase_complete`, `restaurant_card`,
  `shipping_status`, `simple_text`, `sports_player`, `user_profile`, `weather`,
  `workout_summary`. Candidates for upgrading, or for a future "catalog
  breadth" property.

Also still missing as primitives, each blocking spec examples that could
otherwise be templatized: **`Modal`** (is an overlay a primitive, or a host-app
concern the surface merely requests?), **`Tabs`**, **`ChoicePicker`**, and
**`DateTimeInput`**. `AudioPlayer` belongs in `extended_primitives`, below.

### `extended_primitives` — keep the core dependency-light

The **core primitive set is the universal, dependency-light vocabulary** every
adapter on every target can implement cheaply (layout, text, `Heading`, `Image`,
`Icon`, inputs, …). Lightweight *pure-Dart* logic deps are acceptable in the
core (e.g. the `markdown` parser — no platform code, runs everywhere). But
**heavy, platform-specific capabilities** — `Video`/`AudioPlayer` (a media
plugin per platform; just `<video>`/`<audio>` on the web), maps, payment,
camera, file/image picker, sign-in providers, vector graphics, charts — drag in
big optional dependencies and belong in a **separate, opt-in
`extended_primitives` library** that brings its own deps, so an app that
doesn't use video never pays for `video_player`.

- **Stand up `extended_primitives` when the first real heavy primitive
  lands** (a working `Video`, or `Modal`/maps) — not before (an empty
  library is its own smell). Design note for then: a surface may reference a
  component the host didn't load, so the runtime must **degrade gracefully**
  (unknown component → placeholder/skip, never crash).

### Mapping a specific catalog is not a framework deliverable

Mapping a *specific* catalog (e.g. A2UI's Basic Catalog) onto Craft is an
embedder/app concern, **not a framework deliverable** — and not a license to let
that catalog drive primitive design (the Basic Catalog is itself stuck between
low- and high-level, §8 "Not a copy of A2UI's basic catalog"). When a gallery
demo is built, each component is realized by the artifact that fits its
semantics — a template for composed/domain widgets, a direct mapping for
primitive-shaped or bespoke ones — chosen per component, not by a blanket "every
component → a primitive" rule.

### Whole-sample geometry testing (Ahem test mode)

Today's parity net is the **abstract geometry-with-tolerance
conformance** (`a2ui_craft_testing`): fixed-size, text-free fixtures,
asserted exactly on both adapters' real layout. It is deliberately text-free
because Flutter (its test font) and the browser shape real fonts
differently. Interim strategy — sufficient for now — is to **distill every
spotted cross-adapter divergence into a minimal fixture case** (as the Stats
Card / Contact Card hug-sizing fix did) and to use the **demo site's
side-by-side Jaspr/Flutter view as the manual gate** when adding a sample
("looks right on both" is part of done). The follow-up is to pin *whole
samples* (not just hand-built fixtures) geometrically across adapters. The
chosen approach — **one** golden variant, not a stopgap — is an **Ahem-style
test font** (every glyph a statically sized em box) forced on both renderers,
so text-driven layout becomes deterministic and a *single* shared golden per
sample can be compared on both adapters with tight tolerance. Prior art makes
this low-risk: Flutter widget tests pass across mobile and web with Ahem at
tight tolerances **including the old HTML-renderer era, where the browser did
all text shaping** — the exact Flutter-vs-browser boundary we have. Effort is
a ~1–2 day spike (load Ahem via `@font-face` in the headless-Chrome harness;
pin `font-size`/`line-height` against Flutter's `StrutStyle`; the Flutter
test font is already Ahem-equivalent), **not** a re-creation of Flutter's
test infrastructure. Deliberately deferred: golden harnesses pay off against
a *stable* surface, and the primitive set + layout model are still moving
(the cross-axis sizing model changed recently); build this once they settle
and the sample count outgrows side-by-side eyeballing — and explicitly
**avoid** standing up a loose per-adapter golden first (two golden variants
is the thing to not do).

### The rest

- Prove the state-model axis with a third, non-Flutter-like framework.
- **Security: uphold A2UI's secure-by-design promise (§11).** When templates
  are delivered ephemerally, treat them as untrusted input: add engine-level
  operation budgets (loop / instantiation / depth / node counters + wall-clock
  deadline) — **time-windowed, not reset-per-update**, and routing all
  engine-scheduled async (microtasks/timers) through one instrumented,
  cancellable scheduler so chains can't evade the counters — with cooperative
  interruption and cleanup, and keep the catalog + surface scope as the
  capability ceiling. Noted, not yet designed.
- Consider upstream RFW restructuring so the formats layer need not be
  vendored.

## Sequencing

1. **The demo app** (above) is the active thread. It is the only thing that can
   tell us which of the items below actually matter, and in which order — every
   other ranking here is a guess made from inside the repo.
2. **Design the blocks/user-defined-functions arc while the app is being built.**
   It is design-heavy and implementation-light up front, which composes well with
   a thread that is the reverse; and settling syntax before wider adoption is far
   cheaper than settling it after.
3. **Logic Phase 2** competes for the same implementation slot as the blocks arc.
   It is already sliced and starts with measurement, so it can begin the moment
   an implementation slot opens.
4. **Everything else is demand-driven.** `extended_primitives` stands up when the
   first genuinely heavy primitive lands, not before. The Ahem golden mode waits
   for the primitive set to stop moving. Security budgets (§11) need design
   before slices. The third adapter is a hypothesis test, best run when the
   contract it would test has stopped changing.
