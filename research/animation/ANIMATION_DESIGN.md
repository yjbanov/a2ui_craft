# Research: animation across adapters

Status: **research / proposal** (no code). The question: A2UI Craft renders one
template on Flutter and the web, behaviorally identical within a tolerance band
(DESIGN.md §7). What must the **primitives**, the **template language**, the
**theming system**, and the **conformance harness** grow so that surface can
*move* — fades, slides, cross-fades, enter/exit, spinners — without betraying the
cross-adapter doctrine? Animation is the first feature whose very substance is
*time and continuity*, which our render model was built to ignore. This note
surveys the space, grounds it in what we already have, and recommends a phased
feature set. It does not implement anything.

## 1. Thesis

Three ideas organize everything below.

**(a) Animation is the one feature that fights the core render model — and the
reconciler is where it makes peace.** A2UI describes "what the UI should look like
for the current inputs; it **ignores prior UI state**" (DESIGN.md §4/§5). Animation
is the exact opposite: it is *entirely about the transition between the prior
render and the current one*. The reconciliation seam we already built — retained
host components **keyed by A2UI id**, surviving rebuilds so a checkbox value or
scroll offset carries across (§6) — is precisely the machinery that gives an
animation its **"from."** Implicit animation is definable as: *when a retained
component's animatable property differs between two rebuilds, interpolate instead
of snap.* So animation is not bolted onto the model; it is a reading of the diff
the reconciler already computes. This is the spine.

**(b) We already ship the hardest animations, and the doctrine already says they
live in adapter code.** Control micro-interactions — the button's ink splash and
pressed-fade, the hover wash, the focus ring, the switch thumb slide, the checkbox
check (§8's four-layer paint model) — are animations, written once per framework
with the platform's full power, **never templatized** ("there is no templatizing a
thumb drag, or an ink splash spreading under a label", §8). That is animation
Phase 0, exactly as intrinsic flexbox was responsive Phase 0. The new work is the
*author-directed, content-level* motion the template can ask for.

**(c) Behavioral identity for animation is endpoint-and-envelope identity, never
frame identity.** Layout conformance is already "geometry with a tolerance band,
not pixel identity" (Pillar C, §7). Animation forces that band wider along a new
axis — *time*. Flutter drives motion from a vsync `Ticker` with its own `Curve`
math; the web runs a CSS `transition` on the compositor with its own cubic-bezier
and frame cadence. "Same pixel at the same millisecond" is even less achievable
than static pixel-identity and just as much a non-goal. The contract that *is*
enforceable: both adapters animate the **same property**, from the **same start**
to the **same end**, over the **same nominal duration and named curve** — and we
assert the endpoints and that motion was *declared*, not the frames between. This
is the direct analogue of "the framework must never be visible; the platform may
be" (§8): both must move, to the same spec, from and to the same values; the exact
easing shape and frame pacing are platform latitude.

## 2. What we have today

- **Control-owned micro-interactions (§8).** Every control primitive already owns
  its state-layer animation in the active idiom: Material ink splash, Cupertino
  pressed-fade, web hover/active brightness and `:focus-visible` ring, the switch's
  moving thumb. Adapter code, conformance-pinned on *role* and *endpoint state*
  (checked/unchecked, pressed/idle), not on the in-flight frames.
- **Reconciliation that preserves identity (§6).** Host components reconcile keyed
  by A2UI id, so a component *persists* across rebuilds — the precondition for
  animating a change rather than remounting. §6 already names "animation" among the
  retained state that must reconcile onto the right node.
- **Immutable-snapshot re-render in place.** A theme flip (`CraftTheme`) or a size
  class change (`MediaContext`) re-resolves the tree **without remounting** —
  today it *snaps*. Every such in-place re-render is a latent cross-fade waiting for
  a transition wrapper. The theme light↔dark flip is the ready-made proving demo.
- **A shared value-type discipline (Pillar B).** `Dimension`/`CornerRadius`/`Rgba`
  parse total (unknown → safe default), decode identically on both adapters, and are
  conformance-pinned. A `Duration` and an `Easing` enum slot straight into that mold.
- **What is absent:** no notion of time anywhere — no duration, no easing/curve, no
  transition, no enter/exit, no `prefers-reduced-motion`, no motion tokens. A
  template cannot ask for a fade. The only motion is the adapter-owned kind above.

## 3. Prior art (condensed)

| System | Implicit (state→state) | Enter / exit | Explicit / ongoing | Tokens |
| --- | --- | --- | --- | --- |
| **CSS** | `transition` on any animatable property | `@starting-style` + `transition-behavior: allow-discrete` (new, uneven); classic two-frame enter/leave dance | `@keyframes` + `animation`; Web Animations API; scroll-driven animations | custom-property durations/easings; `prefers-reduced-motion` media query |
| **Flutter** | implicit widgets (`AnimatedContainer`, `AnimatedOpacity`, `AnimatedAlign`…) | `AnimatedSwitcher`, `AnimatedList` | `AnimationController` + `Ticker`; `TweenSequence`; `CurvedAnimation` | `ThemeData` durations; `MediaQuery.disableAnimations` |
| **Material 3** | — | container transform, shared axis, fade-through patterns | — | **motion system**: duration tokens (short/medium/long/extra-long) + **easing** tokens (standard, emphasized, decelerate, accelerate) |
| **SwiftUI** | `.animation(_:value:)` — animate on a value change | `.transition(.opacity/.scale/.slide)` | `withAnimation`, `.repeatForever`, phase animators | `.accessibilityReduceMotion` environment value |
| **Web (a11y)** | — | — | — | `prefers-reduced-motion` is a first-class, widely-honored user setting |

Convergences worth stealing:

- **Everyone separates *implicit* (animate on a value change) from *explicit*
  (imperative timeline).** Implicit is declarative, maps to both our adapters
  cleanly (Flutter implicit widgets ↔ CSS `transition`), and rides a value diff —
  which is exactly what our reconciler produces. It is the high-leverage first tool.
  Explicit timelines (spinners, keyframes) need a driver the template shouldn't
  express and are the later, narrower tool.
- **Motion is a *token system*, not per-instance magic numbers.** M3's duration +
  easing tokens are the direct analogue of our color roles and type scale. Fast/slow
  and which-curve are design-system proportioning, not template literals — the same
  argument that put spacing and type in theming (§9.3).
- **Quantize easing to *named curves*, don't expose raw cubic-beziers.** Raw
  `cubic-bezier(.17,.67,.83,.67)` is the animation analogue of the raw-pixel hazard
  responsive avoided: unportable, magic-number-shaped, and a curve-shape mismatch is
  invisible-framework-variance. A small enum (`standard`/`emphasized`/`decelerate`/
  `accelerate`/`linear`) maps per adapter to the platform's real curve.
- **`prefers-reduced-motion` is table stakes, not a nicety.** Every mature platform
  honors a user "reduce motion" setting that collapses animation to instant. It is an
  accessibility MUST and — being a host-supplied render-time preference — fits our
  environment-input model exactly (it is shaped like a `MediaContext` field).
- **Reordering/enter/exit of *lists* is the hard case everywhere**, and it is
  identity-bound: you cannot animate the move of an item you cannot name. On the web
  it is the FLIP technique; in Flutter it is `AnimatedList` with keys. For us it is
  **gated on the list-item identity gap** (§13, a2ui#1745) — §6 already warns that
  without per-item keys, "animation reconciles onto the wrong item or is dropped."

## 4. The design space, mapped to the subsystems

### 4.1 A taxonomy of animation, in leverage order

1. **Micro-interactions — already have, adapter-owned (§8).** Ink, pressed-fade,
   hover, focus, thumb slide. Not templatized, not touched by this proposal except to
   make them honor reduced-motion. *Phase 0.*
2. **Implicit / state-transition — the highest-leverage new thing.** A retained
   component's animatable property (theme color, a `Dimension`, opacity, offset,
   alignment) changes between two rebuilds; the engine tweens old→new over a named
   duration/curve instead of snapping. Declarative, both-adapter-native (Flutter
   implicit widgets ↔ CSS `transition`), and it rides the reconciler's diff. *Phase 1.*
3. **Enter / exit (mount / unmount) transitions.** When reconciliation *adds* or
   *removes* a keyed component, fade/scale/slide it in or out instead of popping.
   Harder cross-adapter: the web cannot transition an element that has left the DOM,
   so exit needs the keep-alive-until-done dance (or the new `@starting-style` /
   `allow-discrete`, still uneven) — a genuine adapter asymmetry to absorb once.
   *Phase 2.*
4. **Ongoing / explicit — spinners, shimmer, pulse.** Motion *not* tied to a state
   change (a spinner rotates forever). No from→to diff to ride, so it needs a driver.
   Recommend a **small set of adapter-owned named canned effects** (a
   `ProgressIndicator` primitive that owns its own animation, plus maybe
   `pulse`/`shimmer`) — *not* a general keyframe language, which is the CSS-reimpl
   cliff. *Phase 3.*
5. **Gesture-driven / interruptible / physics.** Drag-to-dismiss, springs,
   scroll-linked, velocity retargeting. Flutter has interruptible controllers and
   spring simulations; the web's Web Animations API + scroll-driven animations reach
   only part of it, with poor parity. This is the **escape-hatch / drop-to-raw-
   framework** tier (§2) — a bespoke gesture is exactly what §8 sends to adapter code
   or a replacement primitive. *Flagged, not planned.*

### 4.2 Primitives — a `Transition` wrapper (adapter-owned, no language change)

Mirror the responsive playbook: the ergonomic first consumer is a **primitive that
moves the "which framework am I / how do I animate" decision into adapter code**,
needing no language change.

- **`Transition` / `Animated` wrapper** — wraps a child and animates its property
  changes (and, in Phase 2, its appearance/disappearance): `Transition(motion:
  motion.standard, child: <box>)`. Any animatable prop change on the subtree tweens.
  Flutter renders it with the implicit-animation family; Jaspr sets the CSS
  `transition` shorthand on the wrapper. This is the animation analogue of the
  `Responsive` primitive — declarative, adapter-owned, conformance-pinnable.
- **An `animate` modifier on sizing primitives** — the finer-grained form, e.g.
  `Box(animate: motion.standard, …)` so a `Box`'s own `Dimension`/color/corner
  changes tween. Analogous to how `Box` grew `minWidth`/`maxWidth` as sibling props
  rather than folding them into `Dimension`. Open modeling choice: wrapper vs.
  per-primitive modifier vs. both.
- **No new reference scope** (unlike responsive's `media.`). Animation is not a value
  you *branch on*; it is a behavior you *attach*. So it is markedly lighter on the
  template language than responsiveness was — mostly primitive + token work.

### 4.3 Theming — a motion token system (durations + easings)

Animation *proportioning* — how fast, what curve — is a design-system concern,
exactly like color and type (§9.3). Add a **motion axis** to the semantic contract,
alongside `color.*` and `type.*`:

- **New roles:** `motion.duration.short|medium|long` and
  `motion.easing.standard|emphasized|decelerate|accelerate` (M3's motion system as
  the ready-made vocabulary, as its color/type systems already are).
- **New Pillar-B value types:** a `Duration` (scalar ms, total decode, unknown → a
  safe default) and an `Easing` enum (named curves → each adapter's real curve:
  Flutter `Curves.*` / CSS `cubic-bezier`), same discipline as `CornerRadius`.
- Primitives read `motion.*` roles the way `Text` reads `type.body.size` — so a theme
  can make an entire surface calmer or snappier without touching a template, and the
  **default theme** ships a sensible motion scale. This also composes with the
  existing cascade: motion could vary per size class (looser on a TV) exactly as the
  type scale does (RESPONSIVE_DESIGN.md §4.4), though that is a later refinement.

### 4.4 The environment input — `prefers-reduced-motion` (accessibility, MUST)

A host-supplied render-time boolean that collapses **all** author-directed animation
to instant (micro-interactions too, where the platform allows). It is shaped exactly
like a `MediaContext` field — a quantized, host-measured, render-time preference the
agent never sees — so the cleanest home is **growing `MediaContext` with a
`reducedMotion` flag** (or a sibling render-time input beside it), reusing the same
immutable-snapshot reactivity: toggling the OS setting re-renders in place with
motion off. Strong candidate to land *with* the Phase-1 spine, not after — shipping
animation without a reduced-motion path is an accessibility regression.

## 5. Conformance — the load-bearing, animation-specific problem

Because time is continuous and the two engines tick differently, the harness must
assert **endpoint + declaration + reduced-motion**, never intermediate frames:

- **Endpoint identity.** After the animation settles, both adapters land the same
  value — this is what we already test statically; animation only adds "and it was
  continuous getting there." Testable by pumping the Flutter clock / awaiting the
  web `transitionend`, then probing the destination with the existing painted-probe
  pattern (§9.6).
- **"Motion was declared" probe.** Assert the animated variant is present (Flutter: an
  implicit-animation widget / a running controller; Jaspr: the element carries the
  `transition` property with the mapped duration/curve) — a structural probe, not a
  pixel one.
- **Reduced-motion collapses to instant.** With the flag set, both adapters reach the
  endpoint with *no* transition declared — a clean, frame-free conformance case.
- **Deliberately out of scope:** intermediate frame values, exact easing-curve shape,
  frame cadence, compositor behavior. This is an explicit widening of the §7
  tolerance band along the time axis — stated up front so "the platform may be
  visible" clearly covers *when* and *how smoothly*, not just *what idiom*.
- *Optional stronger check (open question):* a single coarse midpoint sample — assert
  that at ~50% the value is strictly between start and end — to catch an adapter that
  "declares motion but effectively snaps." Cheap insurance; still not frame identity.

## 6. Guard rails (the doctrine applied)

- **Endpoint-and-envelope identity, not frame identity.** The framework must never be
  visible = both animate, same property, same endpoints, same nominal duration/curve;
  the platform may be visible = exact curve shape, frame pacing, compositor path.
- **Not a keyframe/CSS reimplementation.** A small motion vocabulary (named durations
  + named easings) attached declaratively; arbitrary `@keyframes`/imperative timelines
  and physics are the escape hatch (§2) — the same line responsive drew against a
  query language and theming drew against "no CSS in JSON" (§9.4).
- **The agent is not responsible for animation.** Like theming and responsiveness,
  motion is design-system + host render-time config. The model never emits frames or
  per-tick messages; the template encodes motion intent *once*. If anything this
  *strengthens* the templatize bias (§4).
- **Micro-interactions stay adapter-owned (§8).** We are not lifting ink splashes or
  pressed-fades into templates; the proposal adds content-level motion above them and
  makes them honor reduced-motion.
- **Totality (Pillar B).** `Duration`/`Easing`/motion tokens and the reduced-motion
  flag parse total; unknown → a safe default (and "reduce motion" is the safe default
  when the host says nothing definite? — open, see §8).
- **Accessibility is first-class.** `prefers-reduced-motion` ships with the spine, not
  as a follow-up.

## 7. Recommended phasing

- **Phase 0 — already have.** Control micro-interactions (§8). Document them as the
  first, adapter-owned tier; make them honor reduced-motion when it lands.
- **Phase 1 — the motion vocabulary + implicit transitions + reduced-motion. ✅
  SHIPPED** (see `PHASE_1_PLAN.md` for the as-built slices). `Motion` + `MotionEasing`
  value types (Pillar B, total; renamed from `Duration`/`Easing` to avoid colliding
  with dart:core `Duration` and Flutter Material's `Easing`), `motion.*` tokens in the
  semantic contract + default theme, and the `prefers-reduced-motion` render-time
  input on `MediaContext`. The implicit-animation deliverable turned out to be a
  **`Box(animate:)` per-property modifier**, not a generic wrapper: Flutter's implicit
  animations are per-property (`AnimatedContainer` tweens *its own* decoration; nothing
  animates an opaque child) and CSS `transition` mirrors that — so the wrapper (for
  enter/exit) moves to Phase 2, and Phase 1 ships the modifier where the leverage is.
  The decoration (color/border/corner/shadow) and the definite width/height animate
  in Phase 1 (padding/margin are a later phase). **Proving demo: the `motion` sample
  races a width change through every easing curve, and the theme light↔dark flip
  cross-fades** the sample's card instead of
  snapping (verified live: dark→light interpolation over 250 ms on the Jaspr pane, both
  panes identical). Conformance: endpoint identity + "declares motion" +
  reduced-motion-collapses-to-instant, on both adapters (the coarse midpoint case
  skipped — the Jaspr VM tester renders no CSS motion to sample). *No language change.*
- **Phase 2 — enter / exit transitions.** Animate reconciliation add/remove of keyed
  components (fade/scale/slide), riding keyed reconciliation (§6). Solve the web
  exit-animation asymmetry once (keep-in-DOM-until-done, or `@starting-style` /
  `allow-discrete`).
- **Phase 3 — ongoing / canned effects.** A `ProgressIndicator` primitive that owns
  its spinner animation, plus a tiny named-effect set (`pulse`/`shimmer`) for
  attention/loading motion that has no state diff to ride. Adapter-owned; not a
  keyframe language.
- **Flagged / later.** **List reorder animation — blocked on list-item identity**
  (§13, a2ui#1745); it cannot be correct before per-item keys exist. Gesture-driven /
  interruptible / spring / scroll-linked physics — escape-hatch tier. A general
  keyframe/timeline language — rejected as the CSS-reimplementation cliff. Each is
  additive on the Phase-1 spine.

## 8. Open questions

- **Endpoint-only vs. midpoint conformance.** Is "declares motion + lands the
  endpoint" a strong enough contract, or do we add the coarse t≈50% "strictly between"
  sample to catch declares-but-snaps? The latter is the only real defense against an
  adapter faking motion.
- **Where reduced-motion lives.** A new `MediaContext.reducedMotion` field (it is
  environment/preference-shaped and reuses that reactivity) vs. a separate render-time
  flag. And its safe default when the host is silent — off (motion on) matches
  platform defaults, but "reduce" is the safer accessibility failure mode; which wins?
- **The web exit-animation problem.** `@starting-style` + `transition-behavior:
  allow-discrete` is new and unevenly supported; is a JS-driven keep-alive the
  portable Phase-2 path, and does it stay within "adapter-owned, no template cost"?
- **Interruption / retarget semantics.** If a property changes mid-flight, both
  adapters must retarget from the current interpolated value — Flutter and CSS both
  do, but the *curve re-entry* differs. Is "retarget from current value" the spec, and
  is it even observable under endpoint-only conformance?
- **Wrapper vs. per-primitive modifier.** Is motion a `Transition` wrapper, an
  `animate:` prop on sizing primitives, or both? (Mirrors the `Box` min/max
  "sibling-prop vs. fold-into-`Dimension`" modeling choice, §13.)
- **How much physics, if any, is portable.** Is there a spring/`linear()`-easing
  subset both engines can approximate within tolerance, or is *all* physics the escape
  hatch?
- **Interaction with style isolation (§9.7).** CSS transitions and `@keyframes` live in
  the same scoped-stylesheet/shadow-root context that theming's embedding problem
  already flags — enter/exit and canned effects couple to that unknown.

## 9. One-paragraph recommendation

Treat animation as **a reading of the diff the reconciler already computes**, not a
new state channel: implicit, declarative motion that tweens a retained component's
property change old→new. Ship it in leverage order behind a motion **token** system
(durations + named easings, M3's motion vocabulary as color/type already are): first
the `Duration`/`Easing` value types, `motion.*` tokens, a `prefers-reduced-motion`
render-time input, and a `Transition` wrapper primitive — with the existing theme
light↔dark flip cross-fading as the proof — then enter/exit on reconciliation
add/remove, then a small set of adapter-owned canned effects (spinner/pulse/shimmer)
for motion that has no state diff to ride. Make conformance **endpoint-and-envelope,
never frame-by-frame** — an explicit widening of the tolerance band along time, so
"the platform may be visible" covers *when* and *how smoothly*. Keep raw
cubic-beziers and keyframes out of templates, keep the agent out of the loop, ship
reduced-motion with the spine, and let the escape hatch — not a growing timeline
language — absorb gestures, springs, and the exotic. List-reorder animation is real
but **gated on list-item identity (a2ui#1745)**; the physics/gesture tier is additive
and deferred behind the implicit-motion spine.
