# A2UI Craft — Status & roadmap

> The living status checklist and the slice-by-slice implementation plans. This
> file tracks **status** and churns as work lands; the stable design rationale
> lives in [DESIGN.md](DESIGN.md), and section references like `§9` point into
> it.

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
      example. The early "synthesize a library" shortcut is retired; rendering now
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
  - [x] **M6 — layer `a2ui_core` underneath the protocol/data half (§5).**
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
        (§8): the catalog is the app developer's job,
        authored *as templates over* these primitives. Approach decided —
        constrained common model + value-type vocabulary + geometry conformance.
        **First slice landed:** see the `Flex` vertical slice below.
- [~] **H2 type/style model + capable primitives (§8).** Build the
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
        (§11). Core unit tests cover the parser; a shared conformance case proves
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
        **templates** over primitives, §4): some local widgets are pointless to
        rebuild from primitives and are better exposed as-is (§8, "Bespoke
        widgets"). The capability is **catalog-agnostic and decoupled from the
        core primitives** — proven by a self-contained test that maps a synthetic
        `Hero` component onto a bespoke `Banner` widget (static and data-bound) on
        both adapters; the framework ships no catalog-specific default mapping.
  - [ ] **Toward the gallery.** Mapping a *specific* catalog (e.g. A2UI's Basic
        Catalog) onto Craft is an embedder/app concern, **not a framework
        deliverable** — and not a license to let that catalog drive primitive
        design (the Basic Catalog is itself stuck between low- and high-level, §8
        "Not a copy of A2UI's basic catalog"). When we build a gallery demo, each
        component is realized by the artifact that fits its semantics — a template
        for composed/domain widgets, a direct mapping for primitive-shaped or
        bespoke ones — chosen per component, not by a blanket "every component → a
        primitive" rule.
  - [x] **Templatizing the A2UI Basic Catalog gallery examples.** Every spec
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
  - [x] **Demo site (`site/`).** A single Jaspr web app — *with Flutter embedded*
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
  - [x] **Cross-axis hug sizing — defer to the parent (`auto`), not
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
- [ ] **`extended_primitives` — keep the core dependency-light.** The **core
      primitive set is the universal, dependency-light vocabulary** every adapter
      on every target can implement cheaply (layout, text, `Heading`, `Image`,
      `Icon`, inputs, …). Lightweight *pure-Dart* logic deps are acceptable in the
      core (e.g. the `markdown` parser — no platform code, runs everywhere). But
      **heavy, platform-specific capabilities** — `Video`/`AudioPlayer` (a media
      plugin per platform; just `<video>`/`<audio>` on the web), maps, payment,
      camera, file/image picker, sign-in providers, vector graphics, charts —
      drag in big optional dependencies and belong in a **separate, opt-in
      `extended_primitives` library** that brings its own deps, so an app that
      doesn't use video never pays for `video_player`.
  - [x] **Removed the `Video` stub from the core set.** It was a fake (a black
        box) carrying contract weight while promising a capability the core can't
        honor dependency-free. No sample used it. It returns — implemented for
        real — once `extended_primitives` exists.
  - [ ] **Stand up `extended_primitives` when the first real heavy primitive
        lands** (a working `Video`, or `Modal`/maps) — not before (an empty
        library is its own smell). Design note for then: a surface may reference a
        component the host didn't load, so the runtime must **degrade gracefully**
        (unknown component → placeholder/skip, never crash).
- [ ] **Systematic cross-adapter geometry testing for whole samples (Ahem test
      mode).** Today's parity net is the **abstract geometry-with-tolerance
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
  - [x] **Pure-template interactivity proven on both current adapters.** RFW's
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
  - [x] **Template functions — read-side slice (`add`).** First delivery of the
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
  - [x] **Template functions — set-state, argument-schema validation, and the
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
  - [ ] **Template computation — a two-layer plan.** How does a *template author*
        (not the agent) express computation like a counter's `count + 1`?
        Rejected: encoding it in the A2UI transport message — that's authored by
        the **agent** (an LLM), so it's the wrong trust domain and not
        author-controlled. The plan:
        - **Now — standard functions in the template language.** Extend RFW's
          expression grammar with function calls (`add(state.count, 1)`), backed
          by a host-provided **template-facing function registry** supplied
          alongside the `LocalWidgetLibrary` — the same author↔host handshake as
          the primitive widgets. *functions : computation :: primitives :
          rendering*: named in the template, implemented per target (one shared
          pure-Dart lib serves Flutter + Jaspr), and conformance-tested on both
          (determinism watch-outs: locale/date/rounding/number-format). Functions
          are **pure** (`args → value`); mutation stays in RFW `set state`/events
          (so `set state.count = add(state.count, 1)`). Purity is required because
          value positions re-evaluate reactively. Covers math/string/bool/date.
        - **Later — ephemeral sandboxed logic.** Business logic that must ship
          ephemerally (JS/Dart/Kotlin, changing per template load) can't be AOT
          Dart; it runs in a **strong sandbox** (iframe/webview/web worker) and
          responds to template **events**. Additive: same `event 'foo' {…}`
          template syntax, a new registry backend.
        **Two refinements that pin the design:**
        - *Trust boundary — separate registries, not one library.* Shared
          *implementations* are fine, but **exposure = registration is per trust
          domain**: the template-facing registry (trusted author) is distinct from
          `a2ui_core`'s agent-facing `Catalog.functions` (untrusted). A function
          reaching the agent registry is a separate, security-reviewed choice.
          Functions must be **total** (bad input → null/NaN, never throw), because
          agent-controlled `data.x` flows into author-written calls — totality is
          what lets the boundary hold while data crosses it. Invariant: **agent
          supplies data; the template author supplies computation.**
        - *Event handlers are always-async, effect-via-data-write.* You can't make
          async look sync without freezing the surface (observable jank, stalled
          agent updates, hung-sandbox hangs), so make *every* handler async from
          day one (local Dart resolves on a microtask; a sandbox over postMessage)
          — the local→sandbox swap is then unobservable. Handlers communicate only
          through data-model writes, never a sync return. Pure function
          *expressions* stay synchronous. This routes through the §11 cancellable
          scheduler (timeouts/cancellation for free).
  - [ ] **Ephemeral theming / design systems (§9).** Design settled: the
        trust model (author's channel, never the agent's), the **W3C DTCG token
        format**, the cascade, explicit-never-implicit theming, and the project
        bundle (§10); prior-art survey under `research/theming/`.
        Implementation plan — thin end-to-end slices, each conformance-tested
        on both adapters before the next begins:
        - [x] **1. Runtime DTCG parser + resolver** in `a2ui_craft` (shared by
          both adapters — §9.6 determinism by construction): parse (groups →
          dot-paths, `$type` inheritance down groups, aliases recorded) →
          resolve (layer merge for mode overlays, alias dereference with cycle
          detection) → typed total reads (`color` / `dimension` / `number`
          first, accepting both the 2025.10 object forms and the legacy string
          forms). Total throughout: malformed token → null → fallback, never
          throw.
        - [x] **2. Explicit token references** — the `theme.` scope (§9.4) on
          both adapters; `Box(color: theme.color.action)` renders the token's
          color on Flutter + Jaspr, pinned by a conformance case. Decides the
          scope-vs-function syntax question at the smallest surface.
        - [x] **3. Ambient role-defaults** — semantic contract v1 (small
          neutral role set with surface/foreground pairing, §9.4): primitives
          read their roles when props are unset, fall back to the host default
          when the theme omits a role; theming-conformance dimension started.
          Delivered as `ThemeRoles` + `CraftTheme` (the immutable snapshot
          carrier that unified the two reactivity regimes), painted-decision
          probes (`textColorOf`/`textFontSizeOf`), partial-theme and unthemed
          regression guards, and per-adapter wiring tests.
        - [x] **4. Default theme** — open-source base `.tokens.json` + mode
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
        - [x] **5. Project bundle (§10)** — theme as the 4th sample-trio
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
          both adapters. The demo site loads a project's theme and offers its
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
        - [x] **6. System dark/light + custom themes.** Hosts map the
          browser/system `prefers-color-scheme` onto a themed project's modes
          (`ProjectTheme.modeFor` — host render-time config, §9.5) and
          re-theme live when it flips; the site chrome follows via CSS
          variables and the embedded Flutter shell via `ThemeMode.system`; the
          Flutter gallery reads platform brightness, the Jaspr gallery a
          conditionally-imported `prefers-color-scheme` watcher. The inline
          `ProjectTheme` shape gained per-mode overlays (`"modes"`, each
          resolved `[base, overlay]` — §9.5's file shape inlined) and an
          optional default `"mode"`; `product_card` / `chat_message` /
          `weather` ship bespoke light+dark brands. The site's editor sidebar
          became tabbed (Template / Schema / App bootstrap / Theme), the Theme
          tab editing a themed project's manifest theme block with Preview
          re-parse. Pinned by inline-modes/`modeFor` units and light↔dark
          re-theme tests in both example galleries (default + custom themes).
        - [x] **7. Adaptive host fallbacks + global scheme toggle.** Root-cause
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
- [~] **Demonstrated-property labels + gallery filter.** Every sample manifest
      carries a `demonstrates` list from a fixed vocabulary
      (`demo_properties.dart`: layout / controls & state / theming / functions
      / a2ui), baked into `RawSample` and surfaced as the gallery's checkbox
      filter bar (AND semantics, per-property counts, tag chips on cards).
      Labeling is deliberately strict, so the counts double as a coverage
      audit. **Gaps it exposed** (each a follow-up sample candidate):
      - [ ] **A2UI integration is the thinnest (3/45):** only `greeting`,
        `profile_card`, and `form` compose multiple components by id refs or
        touch the data model; everything else is a single-component
        `updateComponents`. No sample uses an A2UI-level `ChildList`
        (`child_list_template`, despite the name, loops *inside* its
        template), and none demonstrates streamed/incremental surface updates
        (`incremental` / `incremental_dashboard` are single-shot).
      - [ ] **Layout gaps:** no sample (and no primitive) demonstrates Stack/
        z-order, baseline alignment, margin, or transform — matching the §8
        Pillar D backlog.
      - [ ] **Controls gaps:** no Switch, no Radio-group sample, no tabs, no
        Select in any sample.
      - [ ] **16 samples demonstrate none of the tracked properties** (static
        showcase cards: contact_card, gallery, simple_text, restaurant_card,
        shipping_status, flight_status, purchase_complete, credit_card,
        child_list_template, markdown_text, sports_player, event_detail,
        countdown_timer, user_profile, workout_summary, incremental) —
        candidates for upgrading or for a future "catalog breadth" property.
- [ ] **Control normalization (DESIGN.md §8, "The controls").** Give every
      control primitive its specified, theme-driven, platform-idiomatic look —
      the H2 proof for controls: framework never visible, platform may be;
      each role inks the same part to the same degree on both adapters.
      Control-by-control slices, each spec → both adapters → conformance →
      samples:
      - [ ] **1. `CornerRadius` value type** in the shared vocabulary (Pillar
        B): scalar px, half-extent clamp specified; corner *style* left to the
        idiom.
      - [ ] **2. `Button`** — the four-layer paint model (surface / state layer
        / content / composite effects; child is content, never chrome). Props
        `color`, `cornerRadius`; default = idiom's stock button on
        `primary`/`onPrimary`; transparent surface = text button. Flutter:
        `Material` + `InkWell(customBorder:)`; Jaspr: strip UA chrome, hover /
        active overlays + `:focus-visible` ring. Simplify the calculator `Key`
        onto it.
      - [ ] **3. `Checkbox` + `Radio`** — pattern-setters for painted glyph
        controls: `appearance: none` custom rendering on Jaspr (accent-color
        can only tint); role mapping (`primary` active fill, `outline` box,
        `onPrimary` mark); resolves both adapters' Radio TODOs.
      - [ ] **4. `TextField`** — chrome spec (border/padding via `outline`,
        ink via `onSurface`); the one control with no `.adaptive` path.
      - [ ] **5. `Slider`** — the hardest paint (track/thumb); role mapping
        `primary` active track + thumb, `outline` inactive track.
      - [ ] **6. `Switch` + `Select`** — new primitives once the pattern
        exists (also fills the controls sample gap above).
      - [ ] **7. Cupertino idiom preview** — `ThemeData.platform` toggle in
        the site's Flutter pane steering the `.adaptive` constructors;
        per-idiom role-limit tables authored per control (DESIGN.md §13).
- [ ] **Project authoring & deployment tooling (§10).** Show a project is a
      *separate, ephemerally loadable artifact* from its host, publishable to a
      CDN with no compile step. Thin slices:
      - [x] **1. `app.json` bootstrap.** Rename each sample's `messages.json` →
        `app.json` (the mini-app bootstrap stream), aligning the samples with the
        deployable project format; behavior-preserving (generated file
        byte-identical). `tests.json` (named dev scenarios) is introduced by the
        slices that consume it.
      - [x] **2. `craft` CLI** (`packages/craft`, installed via
        `dart pub global activate --source path packages/craft`).
        `craft create <name>` scaffolds a deployable project — `manifest.json`,
        `template.craft`, `schema.json`, `app.json`, a demo `tests.json`, a
        `firebase.json` (CORS + cache headers), and a README — hard-coded to the
        counter for now (a `--template` menu later). No build step yet (deploy the
        dir as-is); an "assemble" step (drop tests, merge split templates) waits
        for multi-file templates. Tests scaffold into a temp dir and assert the
        output parses end-to-end (manifest, RFW template, schema + app.json
        bootstrap, every tests.json scenario).
      - [x] **3. Runtime loader + host URL bar.** `CraftProjectLoader`
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
- [ ] Prove the state-model axis with a third, non-Flutter-like framework.
- [ ] **Security: uphold A2UI's secure-by-design promise (§11).** When templates
      are delivered ephemerally, treat them as untrusted input: add engine-level
      operation budgets (loop / instantiation / depth / node counters + wall-clock
      deadline) — **time-windowed, not reset-per-update**, and routing all
      engine-scheduled async (microtasks/timers) through one instrumented,
      cancellable scheduler so chains can't evade the counters — with cooperative
      interruption and cleanup, and keep the catalog + surface scope as the
      capability ceiling. Noted, not yet designed.
- [ ] Consider upstream RFW restructuring so the formats layer need not be
      vendored.
