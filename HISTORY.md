# A2UI Craft — What has been built

> The record of completed work, arc by arc. Each entry says what landed and, more
> usefully, what building it *taught* — the divergences found, the approaches
> rejected, the limitations accepted. Nothing here is a plan.
>
> What is still open lives in [ROADMAP.md](ROADMAP.md); the stable design
> rationale lives in [DESIGN.md](DESIGN.md), and section references like `§9`
> point into it. Topic research notes live under `research/<topic>/`.

## Foundations

- Pivot to client-side templating engine; drop the AOT-to-Transport idea.
- Core = vendored, Flutter-free RFW formats layer + `DynamicContent`.
- Jaspr adapter: runtime + minimal core components (`Text/Row/Column/Button`)
  + counter example.
- Flutter adapter: runtime + minimal core components + widget test proving
  parse → render → event → reactive update.
- Project skills governing adapter evolution.
- Dev harness: shared parity-test fixture (`a2ui_craft_testing`) rendered
  identically by both adapters; single `tool/check.sh` entrypoint; CI;
  `LICENSE` + `VENDORED.md` provenance.
- **One dependency, one import.** Each adapter's barrel re-exports
  `package:a2ui_craft`, so the engine's value types, theming, media context, and
  functions arrive alongside the rendering layer — making "depend on the adapter,
  not the engine" true at the *import* level, not just the dependency level.
  `Switch` is the one deliberate hole in the re-export: it names the engine's RFW
  control-flow node and would shadow Flutter's `Switch` for any app that also
  imports material, which is the common case. Apps that want the RFW node import
  the engine directly.

## The A2UI bridge (M1–M6)

Render an A2UI catalog + data model with the engine (§6). `a2ui_craft_bridge`
renders a catalog — data bindings, `ChildList` templates, and events — verified
on both adapters via `runA2uiConformance` and the Jaspr example. The early
"synthesize a library" shortcut is retired; rendering follows the §6
architecture (per-id host adapters + `Runtime.buildNode`), built bottom-up:

- **M1** — keyed `_Widget` (literal `key` lifted onto the wrapper) on both
  runtimes, with a reorder-reconciliation test. The linchpin; independently
  improves RFW.
- **M2** — `Runtime.buildNode` (render an ad-hoc composition + inject host
  widgets as slot args, transparently) on both runtimes.
- **M3** — `A2uiToRfwAdapter` + per-id listenable surface (static children);
  demo/conformance switched over and the shortcut retired. Covered by
  per-id partial-update isolation, child replace/removal, forward-reference,
  and custom-catalog reorder-identity tests.
- **M4** — data-driven lists via RFW's `Loop` (emitted inside the owning
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
- **M5 — the template layer (§6).** The bridge is catalog-agnostic (props →
  `args` by name; `children`/`child` structural; `{event}`/`{path}` by
  shape) and `A2uiToRfwAdapter` takes a configurable `scope`. Conformance +
  the Jaspr example render A2UI components (`Stack`/`Label`/`Tappable`)
  against a real catalog over `core`. Covered by
  `template_layer_spike_test` (runtime mechanics: named-template
  composition, host-widget injection through `args.children`,
  `EventHandler`-as-arg) and `runA2uiConformance` (end-to-end, both adapters).
- **M6 — layer `a2ui_core` underneath the protocol/data half (§5).**
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

## Samples, catalogs, and the gallery

- **Worked examples + sample tests.** Both adapters ship a gallery example
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
- **Ephemeral component APIs (`loadCatalog`).** A real client starts knowing
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
- **Cross-framework sample dedupe.** Because a sample is now pure data
  (RFW template + JSON-Schema catalog + A2UI messages) plus a small
  `onAction`, each sample is defined **once** as a framework-neutral
  `SampleSpec` in `a2ui_craft_examples`. Each example keeps only a thin
  per-framework `Sample` widget (parse template, `loadCatalog`, process
  messages, render the `root` adapter) and its gallery shell; the Flutter and
  Jaspr galleries render the *same* specs. This is a second proof of H1 — one
  set of sample definitions drives two genuinely different rendering engines.
- **Two-way binding (editable inputs).** Added the `TextField` and
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

- **Templatizing the A2UI Basic Catalog gallery examples.** Every spec
  example surface (`specification/v1_0/catalogs/basic/examples`) that our
  primitives can express is reproduced as a hand-authored **Craft template**
  over the primitives — the "bias to templatize" thesis at gallery scale.
  **Done:** all 34 templatizable examples (every one that doesn't need a
  missing primitive); the 7 remaining are blocked on `Modal`/`Tabs`/
  `ChoicePicker`/`DateTimeInput`/`AudioPlayer` (below). Key moves: format
  functions (`formatCurrency`/`formatDate`/…) are *not* a blocker, since a
  template renders strings and the agent supplies already-formatted data;
  A2UI's `children: {path, componentId}` child-list templating is expressed
  directly as a `...for` loop over an array arg; A2UI's `weight` (flex-grow)
  maps to the `Expanded(flex:)` primitive; label-bearing controls
  (`TextField`/`CheckBox`) become small templates over the bare input + a
  `Text`/`Heading`; and form validation `checks` are behavior, not layout
  (the templates reproduce appearance). Demo screens scroll the nav so the
  gallery scales.
  - **Landed (34):** Simple Text (00), Interactive Button (00), Login Form (00,
    labelled fields as a template over the bare input), Row Layout (00), Weather
    (04, `...for` forecast), Product Card (05), Restaurant Card (20), Account
    Balance (15), Shipping Status (21, `...for` step rows), Flight Status (01),
    Purchase Complete (11), Coffee Order (13, `...for` items), Credit Card (22),
    Child List Template (34, `List` + `...for`), Markdown (35, the `Markdown`
    primitive), Music Player (06, `Slider` + `Heading`), Permission (10), Sports
    Player (14), Event Detail (17), Step Counter (23), Countdown (28), User
    Profile (08), Chat (12, `...for` messages), Workout (16), Track List (18,
    `...for` + `Expanded`), Financial Data Grid (33, `weight` → `Expanded(flex:)`
    columns), Formatted Text (00), Incremental (00, `...for` cards), Complex
    Layout (00, `weight` → `Expanded` fields), Email Compose (02), Calendar Day
    (03, `...for` events), Sign In (09), Dashboard (31, `Expanded` panels +
    `...for` logs), Form Validator (32, `CheckBox`+label template). All tested on
    both adapters. (25_contact-card / 27_stats-card are **already covered** by
    the existing hand-authored Contact/Stats card samples, not re-vendored.)
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
    - **`AudioPlayer`** (26_podcast-episode) — transport + scrubber. A media
      capability, like `Video` — both belong in **`extended_primitives`** (see
      below), not the core set.
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

- **Demo site (`site/`).** A single Jaspr web app — *with Flutter embedded*
  (`jaspr_flutter_embed`) — to browse the samples, flip each between the
  Jaspr and Flutter renderers, and open/edit its template/schema/messages
  with a live preview. Prerequisites that landed with it: samples became
  **code-free data projects** (`samples/<id>/{template.craft,schema.json,
  app.json}` + `manifest.json`, the single source of truth, baked to a
  zero-IO constants file by `tool/gen_samples.dart`, decoded by
  `SampleSpec.fromData`); the
  per-framework renderer was extracted into each adapter as a reusable
  `SampleView`; and a generic **action log** replaced per-sample Dart action
  handlers. Built and served locally (`jaspr serve`); no deployment config
  in-repo. Key embed gotcha, recorded: the deferred Flutter engine must be
  **preloaded at page start** (`FlutterEmbedView.preload()`), as a lazy
  first-toggle load fails. The fixed built-in primitive set is a known
  limitation (DartPad-style dynamic primitives are out of scope).

- **`/primitives` — the kitchen-sink page.** One specimen card per primitive
  family (small-caps title, blurb, rendered specimen, monospace role-mapping
  footnote), covering every primitive in the set at the time (27) in multiple
  states: heading levels 1–6,
  body/caption text, enabled/disabled/explicit-colour/text/pill buttons,
  checked/unchecked/disabled controls, a radio group, image variants, layout and
  scroll demos. It is where cross-adapter and cross-brand divergences become
  visible at a glance — the typography bug below was found on this page — and it
  carries its own Jaspr/Flutter toggle and sticky header.
- **The embedded Flutter view sizes itself to its content.** The embed's host
  element is intrinsically sizeless to the DOM (it is a canvas), so the browser
  cannot lay it out from the Flutter content — which is why every sample sat in a
  hardcoded 640px box (560px on `/load`). The fix inverts it: the Flutter widget
  and the Jaspr host compile into *one Dart app*, so the content can measure
  itself and report back through a plain Dart callback. A measuring
  `RenderProxyBox` inside the scroll view (unbounded height → intrinsic content
  height under the host width) reports post-frame whenever the laid-out height
  changes, and the screen sets the host element's height from the report; the old
  fixed height survives only as the pre-first-report fallback. The report→resize
  cycle converges because equal width yields equal measured height, and runtime
  growth (steppers, incremental lists) tracks automatically. Toggle's embed hugs
  at 150px, Product Card at 416px.
- **Demo site on a phone.** The toolbars spelled every axis out inline —
  a segment per brand, per size class, per adapter, beside a `select` per
  axis — which reads at desk width and wraps into three rows on a phone
  before the sample is visible. Now: one reusable `CraftMenu` dropdown
  (`site/lib/menu.dart`) backs the color scheme, the brand, the mode, the
  size class, and a `☰` overflow; the trigger is glyph-only for the scheme
  and the hamburger, the editor button is a bare `✎`, and the back control
  is the circled arrow with no "Gallery" beside it. Below 720px the
  occasional axes fold into the overflow menu; below 560px the whole action
  group drops to its own row so the title stays readable (it was
  ellipsizing to a single letter). Native `<select>` could not do this —
  it renders the selected option's text in the closed state, so an
  icon-only trigger would have meant icon-only options. Verified at
  375×812 and desktop on both the sample screen and `/primitives`.

- **Demonstrated-property labels + gallery filter.** Every sample manifest
  carries a `demonstrates` list from a fixed vocabulary
  (`demo_properties.dart`: layout / controls & state / theming / functions
  / a2ui), baked into `RawSample` and surfaced as the gallery's checkbox
  filter bar (AND semantics, per-property counts, tag chips on cards).
  Labeling is deliberately strict, so the counts double as a coverage
  audit. The gaps it exposed are tracked in [ROADMAP.md](ROADMAP.md).

## The core primitives (H2)

The framework-neutral value-type vocabulary (the `argument_decoders`
replacement — `Dimension`/`Color`/`EdgeInsets`/alignment/`TextStyle`),
conformance sharpened to geometry-with-tolerance, and the catalog grown
depth-first on layout.

- **`Flex` vertical slice (Pillars A–C).** The cross-framework value types
  (`Dimension` = `hug`/`fill`/`fixed`/`flex`, `FlexAxis`,
  `MainAxisAlign`/`CrossAxisAlign`) decode in the **core**, not per-adapter.
  `Row`/`Column`/`Flex`/`Expanded` are one spec-driven builder per adapter
  on **explicit sizing** (neither Flutter's nor CSS's native defaults).
  Conformance graduated to **geometry-with-tolerance**, run against *real*
  layout on both sides: Flutter `RenderBox` (`WidgetTester.getRect`) and
  Jaspr **headless-Chrome** `getBoundingClientRect` (`dart test -p chrome`,
  wired into `check.sh`) — not a CSS-structure proxy.
- **`Box` slice.** The container primitive (size + padding + margin +
  background) on the same explicit-sizing / border-box model, with `Insets`
  and `Rgba` value types (decoded in the core) and asymmetric-inset geometry
  conformance on both adapters.
- **Atoms slice (toward the A2UI Basic Catalog).** `Text` (`variant`),
  `Image` (`ImageFit` + `ImageVariant` canonical sizes), `Icon` (shared
  name→glyph subset), `Divider` (`axis`), and `List`, with behavioral +
  geometry conformance. Proven end-to-end by rendering the gallery's
  **Contact Card** surface as a Craft template on both adapters.
- **Layout-depth primitives.** The primitive set grows toward what a real
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
- **`Markdown` primitive.** Agents emit Markdown constantly, so a dedicated
  rich-text primitive is worth its keep. `Text` stays **plain** (the
  constrained, predictable leaf); `Markdown` renders headings, paragraphs,
  ordered/unordered lists, and inline **bold**/*italic*/`code`/links.
  Parsing lives in the **core** (`a2ui_craft`'s `parseMarkdown` → a neutral
  `MarkdownBlock`/`MarkdownSpan` model, like the value-type decoders), so
  both adapters render the *same* model and can't disagree; each renders it
  **structurally** (Flutter widgets / DOM `h1`–`h6`/`p`/`ul`/`strong`/…),
  never by injecting raw HTML — upholding the secure-by-design posture
  (§11). Core unit tests cover the parser; a shared conformance case proves
  cross-adapter parity. (Block quotes, code fences, images, and tables
  degrade to text for now.)
- **`Heading` primitive.** Rather than overloading `Text` with a heading
  mode, a dedicated `Heading(text, level)` carries a real **heading role +
  level** for assistive tech (Flutter `Semantics(headingLevel:)`; an
  `h1`–`h6` element on the web) — semantically distinct from a styled
  `Text`/`span`, which screen readers can't use for outline navigation or
  "jump to heading". `level` defaults to **1** (a heading with no context is
  the most prominent one; deeper levels are author-set) and is clamped to
  1–6; `Markdown` headings carry the same semantics. Kept simple: one line,
  no inline markup (use `Markdown` for rich content) — the "many simple
  widgets over one complex one" rule.
- **Direct component→widget mapping (the "bespoke widget" path).** A
  developer can surface an existing local widget *directly* as an A2UI
  component — no template wrapper, no extra binding layer — via the
  adapter's optional `mapComponent` seam, which maps a component's `type`
  and props onto a [ConstructorCall] (renaming props onto the widget's
  args). This complements the primary value proposition (a **catalog** of
  **templates** over primitives, §4): some local widgets are pointless to
  rebuild from primitives and are better exposed as-is (§8, "Bespoke
  widgets"). The capability is **catalog-agnostic and decoupled from the
  core primitives** — proven by a self-contained test that maps a synthetic
  `Hero` component onto a bespoke `Banner` widget (static and data-bound) on
  both adapters; the framework ships no catalog-specific default mapping.

- **Removed the `Video` stub from the core set.** It was a fake (a black
  box) carrying contract weight while promising a capability the core can't
  honor dependency-free. No sample used it. It returns — implemented for
  real — once `extended_primitives` exists.

- **`Card` normalized; it owns its paint.** The primitive had diverged by
  framework — Flutter returned Material's `Card` (inheriting its elevation shadow
  and M3 surface-tint edge) while Jaspr hand-rolled a div with a different fixed
  shadow, no border, and an ancestor that clipped it. That is the "framework must
  never be visible" rule (§8) being broken in the open. Card now paints from one
  shared spec on both sides — an outlined surface with a soft shadow — backed by
  new Pillar-B value types `BorderSpec`, `Elevation`, and `ShadowSpec` +
  `shadowForElevation(dp)`, so the border and the depth cue are specified by us
  rather than inherited from each framework's stock chrome. (Named to dodge the
  `Border`/`Shadow` classes both frameworks already export.)
- **`Box` gained opt-in decoration** over those same shared types —
  `cornerRadius`, `border`, `elevation` — closing the gap between what §8 Pillar D
  says a Box is ("size + padding + margin + decoration") and what it carried (a
  background). Unlike Card, decoration is **opt-in**: a bare Box paints nothing.
  When set, `color` stays the author's explicit fill (Box reads no surface role),
  a `border` with no colour inks `color.outline`, and `elevation` casts the
  shared canonical shadow. Flutter folds the border width into its padding so
  content sits the same distance from the edge as the CSS border-box.
- **`data-craft` markers on the DOM.** Debugging Jaspr output was guesswork
  because a `<div>` gives no hint whether it is a Box, a Row, or a Column. The
  runtime now stamps every core-primitive element with `data-craft="<Name>"`,
  added centrally at the one point the runtime invokes a primitive's builder, so
  the rendered DOM is legible in the inspector without each primitive
  remembering to do it.
- **Cross-axis hug sizing — defer to the parent (`auto`), not
  `fit-content`.** Surfaced by the Contact Card and Stats Card rendering
  differently on the two adapters. Root cause: Flutter carries a bounded
  cross extent *down* through hug intermediaries, so a `fill` child (a
  `width:"fill"` Row inside a `Box(width:300)`) or a full-bleed `Divider`
  raises the column to the available width; CSS `fit-content` severs that —
  it collapses to content and a `100%`/greedy descendant can't expand it.
  Fix: the Jaspr `Flex` keeps `fit-content` on the **main** axis but leaves
  the **cross** axis to CSS `auto`, which fills a block parent (so the fixed
  ancestor reaches `fill` descendants) yet still shrink-wraps when the flex
  is itself a flex *item* (e.g. a `Stat` column in a `Row`) — matching
  Flutter's constraint flow. The `Divider` also gets `align-self: stretch`
  so it spans the parent's cross extent (contributing ~0 to it) instead of
  collapsing under `align-items: center`. Geometry-with-tolerance
  conformance stays green; both samples now match across adapters.

## Template functions

- **Pure-template interactivity proven on both current adapters.** RFW's
  stateful templates (a `{ field: init }` state map, `set state.x = …`
  handlers, `switch state.x { … }`) render and react **identically** on
  Flutter and Jaspr — a tap flips local state and the template re-renders
  with no host code, no `a2ui_core` data-model round-trip, and no agent in
  the loop (this is the *client-side* layer of §2, distinct from A2UI's
  agent-in-the-loop action→data model). Shipped as the `toggle` sample and
  a both-adapters behavioral conformance case. **Limitation noted:** the
  RFW expression language has **no arithmetic/operators**, so state changes
  are literals, references, toggles (`set x = switch x {…}` — there is no
  `!`), or fixed-case `switch`es; an unbounded counter (`count + 1`) is
  *not* expressible purely in-template and needs either the A2UI
  action→data path or a future expression/computation capability.
- **Template functions — read-side slice (`add`).** First delivery of the
  two-layer plan below: a template can call a host-provided pure function
  in any value position, e.g. `Text(text: add(a: 2, b: 3))` → "5". No
  grammar change — `name(arg: …)` already parses as a `ConstructorCall`;
  the runtime treats it as a function when the name is in a **template-
  facing `LocalFunctionLibrary`** and is *not* a widget in scope (widgets
  win). Bound arg nodes resolve through the normal resolvers, so calls
  stay reactive and nest. Guarded: an empty registry is byte-for-byte
  unchanged. `createCoreFunctions()` ships a total `add`; `Text` coerces a
  numeric value to its string form. **Strict + total, no coercion:** a
  numeric function takes numbers only — a string in a numeric position is
  a type error yielding null (an absent result), *not* a silently parsed
  number (no JS-style `"5"→5`). Totality (null, never throw) is scoped to
  keeping wrong-typed **untrusted data** from crashing the UI; it is *not*
  a license to guess at author intent. An "earlier, useful error" for
  author type-mistakes belongs in future argument-schema validation (which
  can also tell a literal from a binding). Both adapters + a conformance
  case (incl. a `test-the-test` no-coercion guard).
- **Template functions — set-state, argument-schema validation, and the
  rest of basic math.** Completes the "Now" layer's mechanics:
  - *Set-state calls.* `set state.count = add(a: state.count, b: 1)` — a
    call on a `set state` right-hand side — drives the `counter` sample,
    which now counts **purely in-template** (was an agent-in-the-loop
    `increment` event nothing handled, so it never counted). No new runtime
    code: the read-side resolution already covered the set-state leaf.
    Conformance taps 0→1→2; both example apps tap the real sample through
    the full A2UI-surface/adapter path.
  - *Argument-schema validation.* Each `LocalFunction` now carries an
    argument schema (`{name: FunctionArgType}`). At bind time, in **debug
    only** (an `assert`), a call is checked: unknown argument name, missing
    required argument, or a **literal** of the wrong type throws a
    descriptive error — the "earlier, useful error" for author mistakes.
    Only *literals* are checked; a **binding** (`data.x`, `state.y`, a
    nested call — any `BlobNode`) is skipped, because its value is
    runtime/agent-controlled and must degrade via totality, not crash. This
    is the literal-vs-binding distinction the trust boundary requires,
    tested per-adapter (framework exception plumbing differs, so it lives
    outside the behavioral conformance harness).
  - *Math library.* `add`/`subtract`/`multiply`/`divide` (divide-by-zero →
    null, stays total), strict + total, cross-adapter conformance.
  - *Consolidated + expanded library.* Because the functions are pure and
    framework-neutral, the whole standard library now lives **once** in
    `package:a2ui_craft` (`src/functions.dart`) — types, `createCoreFunctions`,
    and `numberToDisplayString` — rather than being duplicated per adapter;
    duplication that must stay byte-identical is precisely what threatens
    the determinism guarantee, so single-sourcing removes the hazard (the
    runtime *hooks* stay per-adapter). The library now covers: number
    (`add`/`subtract`/`multiply`/`divide`/`mod`/`min`/`max`/`abs`/`round`/
    `floor`/`ceil`), comparison→bool (`greaterThan`/`lessThan`/`…OrEqual`,
    `equals`/`notEquals` — cross-type-safe, no coercion), boolean logic
    (`and`/`or`/`not`, fed to a `switch` since RFW has no `if`), and string
    (`concat` — stringifies any operand, `uppercase`/`lowercase`/`trim`/
    `length`). All strict + total, each with a cross-adapter conformance
    case (which also guards determinism, e.g. `uppercase` across VM/dart2js).
  - *Determinism watch-out, hit for real.* `(4.0).toString()` is `"4.0"` on
    the Dart VM but `"4"` on dart2js, so `divide(20, 5)` rendered
    differently on Flutter vs Jaspr. Fixed in the number→string coercion:
    an integer-valued double renders with no trailing `.0` on every
    platform. (Non-integer double formatting is otherwise consistent across
    VM/dart2js; only the whole-value ".0" differed.) A concrete instance of
    the "number-format" determinism note below — the shared coercion is the
    right layer to enforce it.

- **The samples put the library to work.** Four display cards became live
  computations rather than static renderings, which is what turned the function
  library from a tested capability into a demonstrated one: `step_counter`
  (a button bumps `steps`; distance ÷2000, calories `round(×0.04)`, and goal
  progress `min(×100÷10000, 100)` all derive and re-render), `product_card`
  (a −/+ stepper clamped at 1 with `max` drives a live line total),
  `account_balance` (deposit/withdraw compute a new balance, the withdrawal
  clamped at 0, rendered as dollars by dividing cents), and `coffee_order`
  (rewritten from a static `...for` list into a cart: each line's quantity is
  local state, a reusable stateless `Line` widget takes the quantity, the −/+
  handlers, and the computed line total as args, and the parent sums the lines).
  `product_card` established the **numeric-prop pattern** — a plain
  `{"type": "integer"}` component prop flows through as a real number, so
  `multiply` then `divide(…, 100)` computes exact dollars from cents. The
  `calculator` sample joined them as the purpose-built showcase: arithmetic and
  state, entirely in-template.

## Theming & design systems (§9)

Design settled first — the trust model (the author's channel, never the
agent's), the **W3C DTCG token format**, the cascade, explicit-never-implicit
theming, and the project bundle (§10); prior-art survey under
`research/theming/`. Then thin end-to-end slices, each conformance-tested on
both adapters before the next began:

- **Ephemeral theming / design systems (§9).** Design settled: the
  trust model (author's channel, never the agent's), the **W3C DTCG token
  format**, the cascade, explicit-never-implicit theming, and the project
  bundle (§10); prior-art survey under `research/theming/`.
  Implementation plan — thin end-to-end slices, each conformance-tested
  on both adapters before the next begins:
  - **1. Runtime DTCG parser + resolver** in `a2ui_craft` (shared by
    both adapters — §9.6 determinism by construction): parse (groups →
    dot-paths, `$type` inheritance down groups, aliases recorded) →
    resolve (layer merge for mode overlays, alias dereference with cycle
    detection) → typed total reads (`color` / `dimension` / `number`
    first, accepting both the 2025.10 object forms and the legacy string
    forms). Total throughout: malformed token → null → fallback, never
    throw.
  - **2. Explicit token references** — the `theme.` scope (§9.4) on
    both adapters; `Box(color: theme.color.action)` renders the token's
    color on Flutter + Jaspr, pinned by a conformance case. Decides the
    scope-vs-function syntax question at the smallest surface.
  - **3. Ambient role-defaults** — semantic contract v1 (small
    neutral role set with surface/foreground pairing, §9.4): primitives
    read their roles when props are unset, fall back to the host default
    when the theme omits a role; theming-conformance dimension started.
    Delivered as `ThemeRoles` + `CraftTheme` (the immutable snapshot
    carrier that unified the two reactivity regimes), painted-decision
    probes (`textColorOf`/`textFontSizeOf`), partial-theme and unthemed
    regression guards, and per-adapter wiring tests.
  - **4. Default theme** — open-source base `.tokens.json` + mode
    overlays (light / dark / high-contrast); host-supplied n-ary mode
    input; reactive re-theme of a live surface. Explicit, never implicit
    (§9.5). Delivered as the DTCG token layers under
    `packages/a2ui_craft/lib/src/themes/default/` (a neutral palette,
    the contract roles aliased onto it, the type scale) + a `manifest.json`
    carrying the mode → resolution-order wiring (ours, not the token
    files); a generator bakes them zero-IO into `default_theme.g.dart`
    (drift-guarded in `check.sh`, like the sample trios); `DefaultTheme.of`
    + the `CraftThemeMode` enum (light / dark and their high-contrast
    variants) resolve a cached immutable `CraftTheme` per mode. Light
    restates the pre-contract literals (regression-anchored); a conformance
    case paints the modes and flips one in place (ink re-points, state
    survives). Never applied unasked — theming stays explicit.
  - **5. Project bundle (§10)** — theme as the 4th sample-trio
    file, then the project manifest (name, catalog id, theme reference,
    mode wiring); the demo site loads projects; agent-optional
    (canned-message mini-app mode). Delivered: an optional `theme.json`
    alongside each `samples/<id>/` trio, parsed by `ProjectTheme`
    (a reference to the default theme + a mode, n-ary; or an inline token
    set) and carried on `SampleSpec.theme`; the samples generator bakes it
    into `RawSample.theme`. A `theme` param on `SampleView` +
    `A2uiToRfwAdapter` threads it to the root adapter's ambient scope — the
    first theme flowing through the real A2UI-surface path — with
    `profile_card` shipping as a themed (default/dark) project, pinned on
    both adapters (later retired — see "Brand themes" below). The demo site loads a project's theme and offers its
    modes through a render-time picker (the n-ary mode input) that
    re-themes both the Jaspr-native and embedded-Flutter renders.
    Agent-optional is already the samples' shape — each project's
    `app.json` *is* a canned bootstrap stream (§10). The consolidated
    project
    manifest then folded name + catalog id + theme-ref + mode-wiring into
    one `samples/<id>/manifest.json` per project (parsed by
    `ProjectManifest`), replacing the standalone `theme.json` and the
    top-level per-entry label — which became a plain gallery-order id list.
    The migration was behavior-preserving: the generated samples file came
    out byte-identical.
  - **6. System dark/light + custom themes.** Hosts map the
    browser/system `prefers-color-scheme` onto a themed project's modes
    (`ProjectTheme.modeFor` — host render-time config, §9.5) and
    re-theme live when it flips; the site chrome follows via CSS
    variables and the embedded Flutter shell via `ThemeMode.system`; the
    Flutter gallery reads platform brightness, the Jaspr gallery a
    conditionally-imported `prefers-color-scheme` watcher. The inline
    `ProjectTheme` shape gained per-mode overlays (`"modes"`, each
    resolved `[base, overlay]` — §9.5's file shape inlined) and an
    optional default `"mode"`; `product_card` / `chat_message` /
    `weather` shipped bespoke light+dark brands (later retired — see
    "Brand themes" below). The site's editor sidebar
    became tabbed (Template / Schema / App bootstrap / Theme), the Theme
    tab editing a themed project's manifest theme block with Preview
    re-parse. Pinned by inline-modes/`modeFor` units and light↔dark
    re-theme tests in both example galleries (default + custom themes).
  - **7. Adaptive host fallbacks + global scheme toggle.** Root-cause
    fix for unthemed samples breaking on dark hosts: the Jaspr
    primitives' host-default fallbacks (Card surface, Divider, caption)
    were hardcoded light while body text inherited the dark page — now
    they are CSS `light-dark()` pairs resolving against the page's
    `color-scheme`, the CSS analogue of Flutter's `Theme.of` fallback
    (which is why Flutter never broke). Flutter's two non-Material
    fallbacks (caption, Markdown link) became brightness-aware to keep
    the pair identical on dark hosts; the conformance tester's color
    canonicalizer resolves `light-dark()` as a light host. The site
    gained a global 🌓 System / ☀️ Light / 🌙 Dark toggle (`SiteTheme` +
    `ThemeToggle`, persisted, on every screen): it writes an inline
    `color-scheme` override on `<html>`, which the palette variables and
    primitive fallbacks follow, while screens read `effectiveDark` for
    what CSS can't reach (a themed project's mode, the embedded Flutter
    shell's explicit ThemeMode). Pinned by per-adapter fallback tests
    (light-dark pairs on Jaspr; light/dark brightness on Flutter).

- **Brand themes, and the retirement of per-sample themes.** Three brands
  beyond Default — **Terminal** (sharp 0px corners, monospace, phosphor
  green), **Editorial** (serif, burgundy/gold, 4px hairline), and
  **Bubblegum** (22px pills, hot pink/violet, 2px borders) — each driving two
  things from *one* colour source: the rendered surface, via a real
  DTCG-token `CraftTheme` built through the runtime theming API (the §9.5
  ephemeral path), and the page chrome, via CSS custom properties, which is
  where the corners, border weights, and fonts the semantic contract v1 does
  not carry actually live. Brand is an axis **orthogonal** to light/dark and
  to high-contrast: every brand answers all four n-ary `CraftThemeMode`s. The
  picker moved from `/primitives` to every sample screen, where choosing a
  brand re-inks both panes in place *and* drops that brand's theme block into
  the editable Theme tab — one shared `_colorBlock` backs both the resolved
  theme and the editable JSON, so parsing the JSON reproduces exactly the
  resolved theme and the two cannot drift.

  With any sample recolorable from the picker, the samples that shipped their
  own semantic-role themes (`chat_message`, `product_card`, `profile_card`,
  `settings`, `weather`) **added nothing the picker did not**, so their theme
  blocks and now-redundant `theming` tags were removed; each became a plain
  sample that blends into the host and is themeable from the picker. The
  `calculator` keeps its theme, because it defines **custom** tokens
  (`theme.keypad.*`) that its template references by name — a genuine
  demonstration a brand picker cannot replace, since brands only cover the
  semantic contract. The `ProjectTheme` machinery was untouched: it still
  backs the picker, the calculator, and URL-loaded projects.

## Responsive design

Design in `research/responsive/RESPONSIVE_DESIGN.md`: responsiveness is
**intrinsic first** (flexbox already restructures), and where it cannot be, the
decision layer is a *quantized size class* supplied at render time — never raw
pixels, which are a cross-adapter hazard (device pixel ratio, browser zoom,
viewport jitter) and the road to `@media (min-width: 733px)` magic numbers.

- **Phase 0 — intrinsic responsiveness**, documented as the first tool.
- **Phase 1 — the spine + its consumer.** `MediaContext` + the `WindowSizeClass`
  value type (Material 3 breakpoints, ordered so classes compare), the
  render-time `media` input on both adapters, and the **`Responsive`** primitive
  with nearest-smaller fallback. The context is an **immutable snapshot**: a
  resize that crosses a class boundary supplies a new one and re-renders in
  place, no remount — exactly the re-theme pattern, which is why it needed no
  new reactivity machinery.
- **Phase 2 — the intrinsic gaps.** `Grid` (auto-fit) and `Box` min/max sizing,
  geometry-conformance-pinned so both adapters derive the same column count and
  clamp to the same bounds.
- **Phase 3 — the `media.` scope.** `MediaReference` (binary tag 0x15), a
  read-only scope parallel to `theme.`, resolving `media.width`/`.height`/
  `.orientation` to class ids for `switch media.width { … }`, plus the
  `atLeast(a, b)` threshold helper.
- **Phase 4 — responsive tokens.** The size class becomes a second overlay axis
  in the already-n-ary resolver (`DefaultTheme.of(mode, sizeClass:)`,
  `ProjectTheme.resolve(mode, sizeClass)`): colour re-points per mode,
  proportioning per size class, orthogonally. Host-resolved and supplied as the
  usual immutable snapshot, so no primitive or read-path changed.

## Animation (Phase 1)

Design settled in `research/animation/ANIMATION_DESIGN.md`: animation
fights the prior-state-ignoring render model, but the reconciler
(retained host components keyed by A2UI id, §6) supplies the "from" — so
**implicit animation = interpolate when a retained component's animatable
property differs between two rebuilds**. Conformance is
**endpoint-and-envelope, never frame identity** (an explicit §7 widening
of the tolerance band along the time axis). Motion is a **token system**
parallel to color/type. **Phase 1**
(`research/animation/PHASE_1_PLAN.md`) ships the motion vocabulary plus
the first implicit-animation primitive — thin slices, each green on
`check.sh`, the render slices live-verified in the browser:

- **1. Motion value types** in `a2ui_craft`: `MotionEasing`
  (linear / standard / emphasized / decelerate / accelerate, each
  carrying its four **cubic-bézier control points** — the single source
  both adapters read, so the interpolation curve is *identical* and only
  frame cadence differs, the §7 platform latitude) + `Motion`
  (`durationMs` + easing, total `decode`). Named `MotionEasing` (not
  `Easing`) to avoid colliding with Flutter Material's `Easing` once the
  adapters re-export the engine; no bare `Duration` type (dart:core
  collision). `emphasized` is a documented single-cubic approximation of
  M3's two-segment curve.
- **2. Motion tokens** — `motion.duration.{short,medium,long}` +
  `motion.easing.{standard,emphasized,decelerate,accelerate}` roles in
  `ThemeRoles`; `ResolvedTokens.duration()` reads a DTCG `duration` token
  as ms (object + `"200ms"`/`"0.2s"` forms), canonicalized into the
  `theme.` scope; easings stay **named-string ids** (not raw
  `cubicBezier` — the quantized-vocabulary guard rail). The default theme
  ships 150 / 250 / 400 ms, mode-invariant; drift-guarded
  `default_theme.g.dart`.
- **3. `prefers-reduced-motion`** — a `MediaContext.reducedMotion`
  bool (default `false`, matching both platforms' "no stated preference";
  hosts should plumb the OS signal), exposed as `media.reducedMotion` and
  pinned by a conformance case that flips it in place. The accessibility
  MUST, shipped with the spine.
- **4. `Box(animate:)`** — the faithful implicit-animation primitive:
  a **per-property modifier** (mirroring Flutter's per-property
  `AnimatedContainer` and CSS `transition`), not a generic wrapper (which
  needs enter/exit and moves to Phase 2). Shared `resolveMotion`
  (`true` → the theme's medium + standard) in the core so both adapters
  resolve the identical `Motion`; Flutter wraps the decoration and the
  definite-size layers in `AnimatedContainer(curve: Cubic(points))`, Jaspr
  adds a CSS `transition` over the same property set; both collapse to
  instant on reduced-motion / `none`. **The decoration (color, border,
  corner, shadow) and the definite width/height animate** (`hug`/`fill`/
  `flex` extents aren't finite, so they don't tween — the intrinsic-sizing
  edge case; padding/margin are a later phase). Live-verified: the Jaspr
  adapter emits the exact `background-color 250ms cubic-bezier(0.2,0,0,1)`
  (+ props incl. `width`) through the real adapter, and an `animate: true`
  box renders identically on the Jaspr and Flutter panes.
- **5. Conformance** — `MotionProbe boxMotionOf` + `settle` on the
  tester; three cases in the shared suite: `animate: true` declares the
  same duration + easing on both adapters, an endpoint-after-`retheme`
  lands the new surface color on both (motion never changes the
  destination — it rides `retheme`'s established no-remount contract, so
  the box animates rather than jumps), and reduced motion declares no
  transition and reaches the endpoint immediately. The coarse t≈50%
  "strictly between" case is deliberately skipped: Flutter could sample it
  under the fake clock, but the Jaspr VM tester renders no CSS motion to
  sample, so a shared midpoint case would be asymmetric — declaration +
  endpoint + reduced-motion-collapse is the contract.
- **6. Demo + docs** — a `motion` sample with two demos: a
  **button-triggered easing race** (five bars run the same 12→320 width
  change through linear / standard / emphasized / decelerate / accelerate,
  1.2 s, so the curves are legible side by side) and a **theme cross-fade**
  card that eases its surface + border over 1.5 s on a light/dark flip.
  Live-verified on the Jaspr pane: the bars grow to full width on click,
  and the card interpolates dark→light on a mode flip. Phase 1 marked done
  in `research/animation/`. (Phase 2+ — enter/exit transition wrapper,
  keyframes, gesture-driven motion — stays in the research note.) *Also
  extended `Box(animate:)` to definite width/height here (the deferred size
  piece), so movement — not just cross-fade — is expressible; pinned by a
  size-animation conformance case.*

## Typography

Found via a real divergence: switching brands on `/primitives` re-fonted the Jaspr
specimens but not the Flutter ones. The cause was not a Flutter bug —
the brand font was a **CSS chrome variable**, which DOM text inherits and
a canvas cannot see, and the semantic contract carried no family at all.
The same hole was already shipping in a core primitive: `Markdown` code
spans asked Flutter for the family `'monospace'`, a CSS generic Flutter
has no concept of — on CanvasKit (which resolves families only from its
registered font collection, `canonicalizeFontFamily` being reachable only
from the `web_paragraph`/text-editing paths) that silently rendered
proportional, while Jaspr's `<code>` got real monospace from the UA
stylesheet. Nothing caught it because the conformance suite had zero font
coverage. The fix treats a family as a **request to the host**, like a
primitive or a function:

- **`FontRole`** — a closed `sans` / `serif` / `mono` vocabulary with a
  total `decode` (plus a nullable `tryDecode`), mirroring `MotionEasing`.
  A raw typeface name decodes to *nothing*, so a theme can never hand the
  host a download it never agreed to — and three roles every platform can
  answer beats an open namespace that degrades invisibly on the adapter
  that matters most.
- **`CraftFonts`** — the host's binding from role → ordered family stack,
  an ambient scope beside the theme (`fonts:` on `Runtime.build` /
  `SampleView`), defaulting to the platform's own UI faces. Named
  `CraftFonts`, not `FontFamilies`, because Jaspr's `dom.dart` already
  exports that name — a collision that would have landed on every host
  app author, not just on us.
- **Contract + resolver** — `type.{body,caption,heading,code}.family` as
  named-string tokens, resolved by `resolveFontFamily`, which returns
  **null when the theme is silent** so the adapters emit no family and the
  §9.4 host-blend invariant holds for type. `Markdown` code spans pass the
  one built-in fallback (`mono`).
- **Conformance** — `textFontFamilyOf` on the tester, normalizing
  Flutter's `fontFamily` + `fontFamilyFallback` pair and CSS's single list
  to the same stack. Five cases: a themed body family resolves identically,
  an unthemed surface sets none, a raw typeface name never reaches the
  host, a code span is mono on every adapter even unthemed (the regression
  guard — verified to fail against the old `'monospace'` code), and a theme
  can re-face code spans.
- **Site** — `BrandShape.font` is now a `FontRole` driving *both* the
  specimen theme tokens and the chrome CSS variable from one source, so a
  brand switch re-fonts both adapters instead of half the page.
  *Deliberately not done:* the brands lost their exact faces (Trebuchet,
  Georgia) since v1 has no way to name them; making a brand font genuinely
  visible in Flutter web needs the host to ship real font assets, which is
  exactly the `CraftFonts` seam and is left to the host. Font **weights**
  remain deferred.

## Control normalization (§8, "The controls")

Give every control primitive its specified, theme-driven, platform-idiomatic
look — the H2 proof for controls: framework never visible, platform may be;
each role inks the same part to the same degree on both adapters.
Control-by-control slices, each spec → both adapters → conformance → samples:
- **1. `CornerRadius` value type** in the shared vocabulary (Pillar
  B): scalar px; the half-extent pill/circle clamp is engine-native on
  both adapters (Skia RRect scaling ≡ CSS overlapping-curves); corner
  *style* left to the idiom; the reserved per-corner list form is
  rejected, not misread.
- **2. `Button`** — the four-layer paint model landed on both
  adapters (surface `color`/`cornerRadius`/`padding` props; state layer
  = Material ink splash clipped to the corner shape vs. a head-injected
  `.craft-button` hover/active stylesheet — pseudo-classes can't be
  inline, and the injection is imperative+idempotent because surfaces
  render under several roots; content layer = stock 8/16 padding,
  hug-then-center, and a **content-ink scope** that Text/Icon/caption
  consult before their ambient roles, so the default button inks
  `onPrimary` without leaking to siblings). Unstyled = idiom's stock
  button on `primary`/`onPrimary` (host fallbacks: `ColorScheme` on
  Flutter, `light-dark()` blues on Jaspr); explicit color owns the whole
  surface, ambient ink stands; transparent = text button. Conformance:
  `buttonSurfaceColorOf` probe + role-mapping cases (default per theme,
  re-theme re-inks, explicit fill, transparent). The calculator `Key`
  colors the Button directly (`padding: 0` keeps fixed key size) and
  gained press feedback; live-verified in both panes, both modes.
  **Deferred:** disabled visual dimming (samples still use handler-less
  buttons as static decoration — revisit when they stop) and the
  composite-effects idiom split (Cupertino pressed-fade waits for the
  slice-7 platform toggle).
- **3. `Checkbox` + `Radio`** — pattern-setters for painted glyph
  controls, with the principled split: **unthemed = the host stock
  control** (blend in, §9.1 — native UA input / host Material);
  **themed = adapter-painted per the role mapping** (`outline` unchecked
  box/ring, `primary` full checked fill + radio dot, `onPrimary`
  checkmark). Jaspr paints `appearance: none` glyphs with the checked
  state styled inline (controlled element — no pseudo-classes; SVG
  checkmark stroked with the resolved onPrimary, radial-gradient dot);
  `accent-color` remains only on the range input. Flutter lands the
  mapping on Material's knobs (activeColor/checkColor/side; unselected
  radio ring ← outline). Pinned per adapter in theming_defaults tests.
  **Still open from the Radio TODOs:** native radio *grouping* and the
  change-vs-click event choice (deferred to the Radio-group sample /
  `RadioGroup` API settling); a shared conformance probe for glyph
  colors (per-adapter pins cover the mapping today).
- **4. `TextField`** — chrome per the role mapping, degrading
  role-by-role: `outline` draws the 1px box border (stock 6px corner,
  8/12 padding), `primary` the focused border + caret, `onSurface` the
  text ink; unthemed = host stock field. Flutter: `InputDecoration`
  (the shared `_fieldDecorationFor`); Jaspr: inline chrome + a
  `--craft-focus` custom property the control stylesheet's
  `:focus`/`:focus-visible` rules read (the pseudo-class boundary,
  crossed the same way as the Button state layer).
- **5. `Slider`** — Flutter on Material's knobs (active/inactive
  colors); Jaspr adapter-painted when themed: primary→outline gradient
  track split at the bound value (controlled element), thumb via
  `--craft-slider-thumb` + pseudo-element rules, `color-mix` fallback
  for a missing outline. `accent-color` fully retired.
- **6. `Switch` + `Select`** — new primitives in `corePrimitives`.
  Switch: two-way bound; Material knobs on Flutter; on the web there is
  **no stock switch element**, so the Jaspr control is always
  adapter-painted (pill + radial-gradient thumb, `role=switch`,
  scheme-adaptive fallbacks). Select: single-choice over string
  options, two-way; `DropdownButtonFormField` over the shared field
  chrome (wrapped in `IntrinsicWidth` — hugs like the web `<select>`);
  native `<select>` + `selected:` options on Jaspr. Conformance:
  Switch toggle round-trip (new `toggleSwitch` probe) + Select shows
  its bound option live; interactive option-picking is per-idiom (the
  Flutter popup renders options only while open).
- **6b. `settings` sample** — the controls showcase: a project exercising
  every control through the role mapping; Switch/Select/TextField/Checkbox
  two-way via the A2UI data model, the Radio group via template state +
  `equals()` ("grouping is the template's job"), Save dispatching an A2UI
  action. It shipped themed (teal, light+dark) and labeled
  controls/theming/functions/a2ui; the theme and its `theming` label were
  retired with the other per-sample themes (see "Brand themes" above), so it
  carries controls/functions/a2ui today.
- **7. Cupertino idiom preview** — the idiom is host-selected:
  Checkbox/Switch/Slider moved to their `.adaptive` constructors
  (CupertinoSlider ignores `outline` — the first exercised per-idiom
  limit); the Button swaps its state layer (composite pressed-fade at
  0.4 via the InkWell highlight state, no splash) and corner style
  (`RoundedSuperellipseBorder`) under iOS/macOS; the site's Flutter
  pane header gained a Material/Cupertino picker steering
  `ThemeData.platform`. DESIGN.md §8 carries the v1 per-idiom
  role-limit tables. **Remaining gaps** (DESIGN.md §13): TextField and
  Select render their Material form under the Cupertino preview (no
  `.adaptive` path); Radio keeps its custom glyph in both idioms; the
  `/load` screen has no idiom picker yet. Also still open from earlier
  slices: interactive Select conformance, the Radio grouping /
  change-vs-click TODO, disabled-button visuals.

- **8. The grooming pass — specified defaults, not hand-mirrored ones.**
  Getting the role *mapping* right left the geometry hand-written on each side,
  which is the same hazard one layer down. Each painted-glyph control gained
  framework-neutral defaults in `primitive_specs.dart` that both adapters read:
  `CheckboxDefaults` (size 18, corner 4, border width 2), `RadioDefaults`
  (size 18, border 2), `SwitchDefaults` (track 36×20, thumb 14, inset 4). The
  Jaspr glyphs stopped hardcoding those numbers (CSS output unchanged), and the
  Flutter side closed real drift — the custom radio glyph went 24 → 18. Two
  findings came out of it: the semantic contract's table **claimed `outline` had
  no control consumers and `onPrimary` none at all** while Checkbox/Radio/Switch
  were already reading both, so the table was lying about the very thing it is
  the source of truth for; and the Switch's two adapters **disagreed about what
  `outline` inks** — Jaspr filled the inactive *track*, Flutter the inactive
  *thumb* plus a track border, which §8 forbids outright. Both now fill the
  inactive track, with the off-thumb a contrasting neutral rather than a role.
  Paint models written up per control under `research/theming/`.

## Business-logic drivers — mini-apps (Phase 1)

The "later, ephemeral sandboxed logic" half of the template-computation plan,
built 2026-08-13 → 2026-08-21 and merged to `main`. The shape changed under
construction: logic is **not** a function-registry backend but a *surface
driver* speaking A2UI Transport behind a session envelope. Design in `research/logic/BUSINESS_LOGIC.md` and slices in
`research/logic/PHASE_1_PLAN.md`.

- **`packages/a2ui_craft_logic`** — the session protocol (`hello`/`init`/
  `event`/`update`/`error`/`terminate`/`ping`/`pong` over gapless sequence
  numbers), the fault taxonomy, channel budgets, `DriverSession`,
  `MiniAppRunner`, the in-process and web-worker runners, and a dependency-free
  **JavaScript driver SDK** (one file, no build step). It depends only on
  `a2ui_core`: a driver never sees the template engine or an adapter.
- **The `cart` reference mini-app** ships its logic **twice** — Dart and
  JavaScript — and the driver conformance suite runs *unmodified* against both.
  That is what proves the coupling surface is the protocol and nothing else.
- **Failure is loud.** "Freeze beats betray": every terminal state latches and
  the host takes the surface out of service with a reason, rather than leaving
  live-looking chrome that nothing will answer. A driver that never completes
  the handshake, one that stops answering the heartbeat, one that floods the
  channel, and one that writes outside its surface or into the host's namespace
  all end the same visible way.
- **The project format grew a `logic` slot** — `entry`/`language`/
  `capabilities`, or a `url` — vetted by the host against its own
  `HostLogicSupport`. A host that cannot run a project's language refuses with a
  reason; the manifest never names a *runtime*, because where logic runs is the
  host's choice and the project's business only up to the language.
- **The production path is live**: `craft create --logic` scaffolds it, the loader
  fetches it, and the demo site's `/load` screen runs a fetched project's own
  JavaScript in a worker on both the Jaspr and the embedded-Flutter panes.

## Project authoring & deployment (§10)

Show a project is a *separate, ephemerally loadable artifact* from its host,
publishable to a CDN with no compile step.

- **1. `app.json` bootstrap.** Rename each sample's `messages.json` →
  `app.json` (the mini-app bootstrap stream), aligning the samples with the
  deployable project format; behavior-preserving (generated file
  byte-identical). `tests.json` (named dev scenarios) is introduced by the
  slices that consume it.
- **2. `craft` CLI** (`packages/craft`, installed via
  `dart pub global activate --source path packages/craft`).
  `craft create <name>` scaffolds a deployable project — `manifest.json`,
  `template.craft`, `schema.json`, `app.json`, a demo `tests.json`, a
  `firebase.json` (CORS + cache headers), and a README — hard-coded to the
  counter for now (a `--template` menu later). No build step yet (deploy the
  dir as-is); an "assemble" step (drop tests, merge split templates) waits
  for multi-file templates. Tests scaffold into a temp dir and assert the
  output parses end-to-end (manifest, RFW template, schema + app.json
  bootstrap, every tests.json scenario).
- **3. Runtime loader + host URL bar.** `CraftProjectLoader`
  (`a2ui_craft_examples`) fetches a project over HTTP (manifest →
  template/schema/`app.json`, plus optional `tests.json`) into a
  `LoadedProject`; total on failure (a `ProjectLoadException` the host
  surfaces), pinned by mock-client tests. A `/load` URL-bar screen in the
  demo site loads a project from any URL (a text field, not a query param —
  it carries to future mobile/desktop app modes), renders it on either
  adapter with the n-ary mode picker, and offers `tests.json` scenarios as
  an optional canned-demo picker — demonstrating the edit → re-publish →
  reload cycle with the host untouched. (Site UI is analyzer-checked glue
  over the tested loader + SampleView theming; no live browser test.)

## Feature detection and environmental adaptation (§14)

Built 2026-09 to enable templates to adapt safely across clients, form factors,
hardware capabilities, and version skew without crashing on unsupported branches.
Design in `research/feature_detection/FEATURE_DETECTION_DESIGN.md`.

- **Pillar 1 — Environmental capabilities (`MediaContext`):** Expanded `media.` scope
  with quantized `media.formFactor` (`phone`, `tablet`, `desktop`, ...),
  `media.platform` (`ios`, `android`, `web`, ...), `media.engine` (`flutter`, `jaspr`),
  and hardware capability flags (`media.hasGps`, `media.hasCamera`, `media.hasBiometrics`,
  `media.hasNfc`). Reactive re-rendering on ambient change.
- **Pillar 2 — Runtime API introspection & metadata dictionaries:** Host-registered
  widgets and functions accept open static metadata (`Map<String, Object?>`).
  `SymbolReference` added to RFW text and binary formats (`0x16`), enabling direct member
  access (`Widget.args.argName`). Total introspection helpers (`hasWidget`, `hasFunction`,
  `hasArg`, `meta`, `runtimeVersion`, `appVersion`).
- **Load-time AST specialization & constant folding:** `specializeLibrary` in the
  core engine simplifies boolean logic, evaluates compile-time introspection calls, and
  excises dead `Switch` branches before template binding. Deferred function validation
  ensures unselected branches never throw validation errors.
- **Simulator & version skew:** Pure-Dart `A2uiCraftSimulator` and `ClientProfile`
  controller with interactive simulator toolbar added to both Flutter and Jaspr
  sample galleries, demonstrating 3-tier version skew with automatic fallback polyfills.
- **Conformance & demo site:** Multi-scenario cross-framework conformance suite
  (`runFeatureDetectionConformance`, 7 scenarios) pinned across both adapters, sample
  projects (`feature_detection`, `version_skew_polyfill`), and a live interactive
  section on the landing page.

## Cross-cutting fixes

- **Mobile pointer events on the demo site.** On mobile browsers Flutter web
  inserts a `<flt-semantics-placeholder>` spanning the viewport, which swallowed
  pointer events that should reach the Jaspr-rendered DOM — a user-visible
  defect on the public demo. Shipped as a CSS shim in `site/web/index.html`
  (`flt-semantics-placeholder { pointer-events: none !important; }`), scoped to
  the site rather than the published adapter, since a Flutter-web workaround
  does not belong in a package other people depend on. Two findings worth
  keeping: the engine appends the placeholder to **`<body>`, not inside the
  `flutter-view`**, so on mobile it blankets the whole Jaspr page (on desktop it
  is 1×1 at (-1,-1), which is why this only reproduced on mobile); and **CSS beat
  the MutationObserver plan** — no lifecycle or timing race, it keeps applying if
  the engine re-inserts or re-styles the element, and it is non-destructive,
  where removal would have dropped the accessibility affordance entirely. The
  shim is deletable once the upstream Flutter multi-view bug is fixed.
