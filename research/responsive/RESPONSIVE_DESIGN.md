# Research: responsive UI across form factors

Status: **research / proposal** (no code). The question: A2UI Craft renders one
template on phones, tablets, laptops, desktops, TVs, cars, and smart displays.
What must the **template language**, the **primitives**, and the **theming
system** grow so the same surface adapts to wildly different form factors — the
media-query-shaped problem — without betraying the cross-adapter, cross-platform
doctrine (DESIGN.md §7–§9)?

This note surveys the space, grounds it in what we already have, and recommends a
phased feature set. It does not implement anything.

## 1. Thesis

Two ideas organize everything below.

**(a) There are two kinds of responsiveness, and we already have one.** *Intrinsic*
(continuous) responsiveness adapts fluidly to available space with no thresholds —
flexbox `fill`/`flex`/`hug`, wrapping, aspect ratios. *Breakpoint* (discrete)
responsiveness **restructures** at thresholds — a row becomes a column, a sidebar
becomes a drawer, a control appears or vanishes. Our primitives are flexbox-shaped
(`Row`/`Column`/`Expanded`/`Wrap`/`Dimension.fill|flex|hug`), so **a large fraction
of responsive design is already expressible and needs no new concept.** What is
entirely missing is any way to *know how big we are* and restructure — the discrete
half.

**(b) Responsiveness is a second render-time input axis, exactly parallel to the
theme mode.** The framework already carries one host-supplied, n-ary, render-time
input that re-renders in place without remounting: the **theme mode** (light /
dark / high-contrast, DESIGN.md §9.5). A **window size class** is the same shape of
thing — the host measures the viewport, quantizes it to a class, supplies it at
render time, and a resize across a threshold re-renders like a dark-mode flip. This
reuse is the spine of the proposal: the same immutable-snapshot reactivity, the
same "host supplies render config, never the agent" trust model (§9.2), the same
quantized shared vocabulary (Pillar B), and the same conformance harness.

## 2. What we have today

- **Sizing algebra (Pillar B):** `Dimension` = `hug` / `fill` / `fixed` / `flex(n)`
  on width/height (`value_types.dart`). `Row`/`Column`/`Expanded`/`Flex` distribute
  space; `Wrap` flows to new lines; `AspectRatio`, `Center`, `Align`, `SizedBox`,
  `Box`, `ScrollView`. This is real intrinsic responsiveness, cross-adapter and
  conformance-pinned.
- **Render-time input model:** the ambient `CraftTheme` snapshot, host-supplied via
  `RemoteWidget.theme`, resolved through the `theme.<path>` scope (a real parsed
  scope alongside `args`/`data`/`state`). The **mode** is n-ary and host-selected.
- **Template branching:** `switch <expr> { case: …, default: … }` can branch on any
  scope value (a sample does `switch state.on { … }`), and the function library
  computes over scopes.
- **What is absent:** no viewport/container awareness anywhere — no `MediaQuery`, no
  `LayoutBuilder`, no size class, no `Grid`, no min/max constraints, no
  size-conditioned tokens. A template cannot ask "am I on a phone?"

## 3. Prior art (condensed)

| System | Discrete (breakpoint) | Continuous (intrinsic) | Tokens |
| --- | --- | --- | --- |
| **CSS** | `@media (min-width)`, and the newer **`@container`** (respond to the *parent*, not the viewport) | flexbox, grid `auto-fit`/`minmax`, intrinsic sizing | **`clamp()`** fluid values, custom-property switches |
| **Material 3** | **Window size classes** — Compact / Medium / Expanded / Large / Extra-large (by width dp) + height classes; canonical layouts per class | — | size-class-driven spacing & pane counts |
| **SwiftUI** | `horizontalSizeClass` / `verticalSizeClass` (compact / regular) as an **environment value** | stacks, `Spacer`, `GeometryReader` | dynamic type (a11y text scaling) |
| **Flutter** | `MediaQuery` (viewport), `LayoutBuilder` (container constraints) | `Flexible`/`Expanded`, `Wrap`, `FractionallySizedBox` | `MediaQuery.textScaler` |
| **Android/others** | resource qualifiers (`layout-sw600dp`) | ConstraintLayout | dimens per qualifier |

Convergences worth stealing:

- **Quantize to size *classes*, don't expose raw pixels.** Every platform above
  hands authors a small enum, not a pixel width, at the decision layer. Raw pixels
  are a cross-adapter hazard (device pixel ratio, browser zoom, the CanvasKit
  viewport jitter we already hit) and invite `@media (min-width: 733px)` magic
  numbers. M3's window size classes are the ready-made vocabulary.
- **The industry is moving from viewport queries to *container* queries**, because a
  component composed into an arbitrary slot should respond to *its* space, not the
  window. This matters acutely for us: templates are composed into host slots we do
  not control. But container queries need a measured layout pass (two-pass), so
  they are the harder, later tool.
- **Size is not the whole story for form factor.** A TV is not "a big phone": it is
  a *10-foot UI* (large type, high contrast, D-pad/remote **focus** navigation, few
  targets); a car is safety-constrained (minimal interaction, huge glanceable text,
  often voice); a watch is glanceable. These are **input-modality and
  viewing-distance** axes orthogonal to width. Size class is the 80% lever; the rest
  is real but should not block it.

## 4. The design space, mapped to the three subsystems

### 4.1 Primitives — intrinsic first (the preferred path)

Most restructuring should be achievable with *no breakpoints at all*, because
magic-number-free layouts travel best across unknown form factors. The gaps:

- **`Grid` with auto-fit** — the single highest-leverage responsive primitive. "Lay
  out as many equal columns as fit, each ≥ some min width" (CSS
  `repeat(auto-fit, minmax(200px, 1fr))`) turns a product grid, a dashboard, a photo
  wall responsive with zero thresholds. Both adapters can express it (CSS grid;
  Flutter `SliverGridDelegateWithMaxCrossAxisExtent`).
- **Min/max constraints** — a `Box`/sizing form that clamps (`minWidth`/`maxWidth`),
  so content stops growing on a TV and stops shrinking on a watch. The `Dimension`
  algebra has no clamp today.
- **`Wrap` is under-used** — it already flips a Row to multiple rows when space runs
  out; document it as the first tool and make sure gap/alignment parity holds.

These need **no** size input and **no** language change — they are Pillar-D layout
work (DESIGN.md §13 already flags `Grid`/overflow as open). They are the cheapest,
most portable responsiveness and should come first.

### 4.2 The render-time environment input (the spine) — new

A quantized environment value the host supplies at render time, parallel to
`CraftTheme`:

```
MediaContext {
  WindowSizeClass width;    // compact | medium | expanded | large | extraLarge
  WindowHeightClass height; // compact | medium | expanded
  Orientation orientation;  // portrait | landscape   (cheap, derivable)
}
```

- A **new Pillar-B value type** with total decoding (unknown class → a safe
  default), the same discipline as `Dimension`/`CraftTheme`.
- Supplied via a new render-time parameter beside `theme` (`RemoteWidget.media` /
  `buildNode(media: …)`), immutable-snapshot reactivity: a resize crossing a class
  boundary supplies a new snapshot and re-resolves in place (no remount — template
  state survives, exactly like retheme; conformance-pinnable the same way).
- **Host-measured, host-quantized.** The host owns the mapping from real pixels to a
  class (using M3 breakpoints as the default), so the class vocabulary is identical
  on every adapter and no raw pixels reach the template. This mirrors "the host
  supplies render-time config" (§9.5) and keeps the **agent out of it** — the model
  should never send different messages per screen size; one description renders
  responsively (a direct extension of the §9.2 trust model).

**Later axes (flagged, not v1):** `formFactor`/`platformClass` (phone/tablet/
desktop/tv/car/watch), `inputModality` (pointer/touch/**focus**/voice),
`density`/viewing-distance. These carry the TV/car story (10-foot UI, D-pad focus,
safety) that width alone misses. Adding them later is additive — `MediaContext`
grows fields; templates that ignore them are unaffected.

### 4.3 Template language — a `media.` scope + a responsive primitive

Two complementary ways to consume the size class; we likely want both, in this
order:

1. **A `Responsive` primitive (adapter-owned, no language change) — recommended
   first.** Picks one child by the ambient size class:
   `Responsive(compact: <stacked>, expanded: <side-by-side>)` (falling back to the
   nearest smaller class when one is omitted). This keeps the branch declarative and
   moves "which class am I" into adapter code — the same philosophy as controls
   owning their micro-interactions (§8), and it needs **only** the `MediaContext`
   input, not a language change. Most structural swaps are one `Responsive`.
2. **A `media.` reference scope (a language change) — for finer control.** A read-
   only scope parallel to `theme.`, so `switch`/functions branch on it:
   `switch media.width { compact: …, expanded: … }`, or a helper
   `atLeast(media.width, "medium")` returning a bool for use in any expression. This
   is more expressive (branch a *prop*, not just a whole subtree — e.g.
   `gap: switch media.width { compact: 8.0, default: 24.0 }`) but verbose; the
   primitive covers the common case, the scope the long tail.

Guard rail: the scope exposes the **class enum**, never pixels — no
`switch media.pixelWidth { … }`. Anything selector-shaped or pixel-exact is the
drop-to-raw-framework escape hatch (§2), same as theming's "no CSS in JSON" line
(§9.4).

### 4.4 Theming — responsive tokens (a size axis, like modes)

Restructuring is layout; *proportioning* is theming. A TV wants larger type and
looser spacing (10-foot legibility); a phone wants denser spacing. Model this as
the theme resolving **dimension tokens per size class**, exactly as it resolves
color per mode — the size class becomes a second overlay axis in the cascade
(mode × size class). `type.body.size` and a future spacing scale would carry
per-class values; the primitive reads the same role and gets the class-appropriate
number.

- This is the cleanest home for "10-foot UI" and "glanceable" — a *token* concern,
  not a layout one, so a template stays structurally identical while its rhythm
  scales.
- It adds a combinatorial axis to theme resolution (already flagged as a modeled
  cost in §9.5). Recommend it as a **later phase**: prove the render-time size input
  + layout primitives first; extend the (already n-ary) theme resolver to a second
  axis once the input exists.
- A fluid **`clamp()`-style dimension token** (interpolate min↔max by measured size)
  is the continuous analogue; more complex (needs measurement), flagged as future.

## 5. Guard rails (the doctrine applied)

- **Behavioral identity across adapters.** The size-class vocabulary is a shared,
  quantized value type; both adapters must pick the same child / same token for the
  same class. No raw pixels at the decision layer.
- **Not a CSS reimplementation.** Small enum of classes, not arbitrary min/max
  queries; no selectors; the escape hatch absorbs the exotic.
- **The agent is not responsible for responsiveness.** Like theming, it is host
  render-time config. One surface description adapts; the model does not re-emit per
  form factor. (If anything, this *strengthens* the "templatize" bias — the template
  encodes the responsive intent once.)
- **Totality.** `MediaContext` is host-supplied ephemeral-shaped data; parse total,
  unknown class → default, never throw.
- **Intrinsic before breakpoints.** Prefer `fill`/`flex`/`Wrap`/`Grid`
  (magic-number-free, maximally portable); reach for a size class only to
  *restructure*, not to fine-tune spacing (that is a token).

## 6. Recommended phasing

- **Phase 0 — already have.** Intrinsic flexbox responsiveness. Document it as the
  first tool; add a responsive sample (e.g. a card grid) to prove it.
- **Phase 1 — the spine + the ergonomic consumer.** `MediaContext` +
  `WindowSizeClass` value type (Pillar B, total), the render-time `media` input
  (immutable-snapshot reactivity, both adapters), and the **`Responsive` primitive**.
  Minimal, high-leverage: structural restructuring with a shared vocabulary and *no*
  language change. Conformance: inject a size class, assert both adapters pick the
  same child and re-render on class change (the retheme pattern).
- **Phase 2 — intrinsic gaps. ✅ done.** `Grid` (auto-fit) and `Box` min/max sizing
  constraints — the highest-ROI portable primitives, independent of Phase 1.
  Geometry-conformance-pinned so both adapters derive the same column count.
- **Phase 3 — the `media.` scope. ✅ done.** `MediaReference` (binary tag 0x15),
  a read-only scope parallel to `theme.`, resolving `media.width`/`.height`/
  `.orientation` to class ids for `switch media.width { … }`, plus the
  `atLeast(a, b)` threshold helper. Same subscription/re-theme reactivity, both
  adapters, conformance-pinned.
- **Phase 4 — responsive tokens. ✅ done.** The size class is a second overlay
  axis in the (already n-ary) resolver: `DefaultTheme.of(mode, sizeClass:)` and
  `ProjectTheme.resolve(mode, sizeClass)` append a size-class overlay (the
  `roomy` type-scale bump at expanded+) over the mode layers — colour re-points
  per mode, proportioning per size class, orthogonally. Host-resolved and
  supplied as the usual immutable snapshot, so a class change re-themes in
  place; no primitive or read-path change. Core + project tests pin it.
- **Flagged / later.** Container queries (measured, two-pass, more correct for
  composed slots); the `formFactor`/`inputModality` axes (TV D-pad focus, car
  safety, watch glanceability); fluid `clamp()` tokens. Each is additive on the
  Phase-1 spine.

## 7. Cross-adapter conformance angle

Because the size class is a value type, the existing harness extends directly: a
new conformance dimension injects a `MediaContext` (as it injects a `CraftTheme`),
then asserts structure and painted decisions — the `Responsive` primitive selects
the same child on both adapters; a size-class token lands the same number; a class
change re-renders without remount (state survives, mirroring the retheme case). No
pixels, same as §9.6.

## 8. Open questions

- **Viewport vs container size class for v1.** Viewport (host-measured, cheap,
  matches the mode model) restructures the whole surface uniformly; container
  (per-slot, correct for composed components) needs a measured layout pass. Start
  viewport; is a container variant a Phase-2 primitive (`ContainerResponsive` fed by
  a `LayoutBuilder`/`ResizeObserver`) or a deeper engine change?
- **Where the pixel→class mapping lives.** Host-owned with M3 defaults is the
  proposal; do projects ever need to declare custom breakpoints (like a theme
  declares mode wiring), or is that the CSS-magic-number cliff we are avoiding?
- **How many environment axes before over-scoping.** Width class is clearly in;
  height and orientation are cheap; `formFactor`/`inputModality` are real for
  TV/car but risk a combinatorial config surface. Which are v1 vs earned later?
- **Interaction with the embedding/style-isolation problem (§9.7).** On the web a
  container query needs a scoped measurement context; this couples to the shadow-
  root/scoping unknown already flagged for theming.
- **`Grid` sizing semantics in the `Dimension` algebra** — how auto-fit columns
  interact with `flex`/`fill`/intrinsic children (the §13 type-model open question).

## 9. One-paragraph recommendation

Treat responsiveness as a **second render-time axis parallel to the theme mode**,
built on a quantized **window size class** the host supplies. Ship it in leverage
order: lean on the intrinsic flexbox we already have (add a responsive sample),
then land the `MediaContext` input plus a `Responsive` selection primitive (the
minimal spine — restructuring, shared vocabulary, no language change), then fill the
intrinsic primitive gaps (`Grid`, min/max), and only then extend the language
(`media.` scope) and the theme resolver (size-class tokens). Keep raw pixels out of
templates, keep the agent out of the loop, and let the escape hatch — not a growing
query language — absorb the exotic. Container queries and the form-factor/input axes
(the true TV/car story) are real and additive, deferred behind the size-class spine.
