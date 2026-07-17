# Phase 1 implementation plan — motion vocabulary + implicit transitions

Companion to [ANIMATION_DESIGN.md](ANIMATION_DESIGN.md). This is the concrete,
code-grounded build plan for **Phase 1**: the motion token vocabulary, the
`prefers-reduced-motion` render-time input, and the first implicit-animation
primitive — with the theme light↔dark flip cross-fading as the proving demo. No
enter/exit, no keyframes, no gestures (those are Phases 2–3 / escape hatch).

Every slice ends green on `./tool/check.sh` (all adapter/conformance/geometry
tests, both drift guards) and, where it renders, is verified live in the browser
on both panes before commit — the same discipline as the responsive phases.

## The one design decision that shapes the plan

The research doc floated a `Transition` *wrapper* as the Phase-1 consumer.
Grounding it in the two frameworks changes the recommendation: **the faithful
implicit-animation primitive for Phase 1 is an `animate` modifier on `Box`, not a
generic wrapper.**

- Flutter's implicit animations are **per-property** (`AnimatedContainer` tweens
  *its own* color/decoration/constraints/padding/alignment). There is no single
  widget that "animates whatever changes about an opaque child." So the adapter has
  to own the property set it tweens — which is exactly the set `Box` already owns.
- Jaspr/CSS is the mirror image: a `transition` shorthand on the `Box` element
  animates precisely those same properties (`background-color`, `border-color`,
  `width`, `padding`, …) natively.
- `Box` is *already* the primitive whose props (`color`, `border`, `cornerRadius`,
  `width`/`height`, `padding`, `alignment`) change on a retheme — so `Box(animate:)`
  **is** the theme cross-fade, with no reconciliation subtlety (same element,
  property changes) and clean endpoint conformance.

A generic opacity `Transition` wrapper (fade a subtree in/out on an identity swap)
is really the *enter/exit* story — it needs `AnimatedSwitcher`/`@starting-style` —
so it moves to **Phase 2**. Phase 1 ships `Box(animate:)`, which is where the
leverage is.

Bonus conformance win: we map each named `Easing` to the **same cubic-bezier
control points** on both adapters (Flutter `Cubic(...)` ↔ CSS `cubic-bezier(...)`),
so the interpolation curve is genuinely *identical* — only frame cadence differs,
which is exactly the platform latitude §7 already permits.

## Slice 1 — the motion value types (core, no rendering)

**File:** `packages/a2ui_craft/lib/src/value_types.dart` (+ export if needed in
`lib/a2ui_craft.dart`).

Add two Pillar-B types following the `CornerRadius`/`BorderSpec` mold (`final
class`, `const` ctor, static defaults, total `decode`, `==`/`hashCode`/`toString`):

- **`enum Easing`** — the quantized curve vocabulary, each carrying its id **and
  its four cubic-bezier control points** (the single source both adapters read, so
  the curve is identical):
  ```
  enum Easing {
    linear('linear', 0, 0, 1, 1),
    standard('standard', 0.2, 0, 0, 1),      // M3 standard
    emphasized('emphasized', 0.2, 0, 0, 1),  // (distinct points TBD in slice)
    decelerate('decelerate', 0, 0, 0, 1),
    accelerate('accelerate', 0.3, 0, 1, 1);
    // id + (x1,y1,x2,y2); Easing.decode(raw, {fallback = standard}) — total.
  }
  ```
- **`final class Motion`** — the carrier the primitive consumes (a `Duration`
  value type is deliberately *not* introduced — Dart core's `Duration` would
  collide the way `Border`/`BorderSpec` did, and duration is never used without an
  easing here):
  ```
  final class Motion {
    const Motion({required this.durationMs, this.easing = Easing.standard});
    static const Motion none = Motion(durationMs: 0);   // instant / no animation
    final int durationMs;      // >= 0
    final Easing easing;
    bool get isInstant => durationMs <= 0;
    // decode(Object? raw, {Motion fallback = none}):
    //   false / absent            -> fallback (typically none)
    //   true                      -> fallback (caller passes the theme default)
    //   num n                     -> Motion(durationMs: n, easing: standard)
    //   { "duration": ms, "easing": "standard" }  -> explicit
    //   (a theme.motion.* reference resolves to one of the above before decode)
  }
  ```

**Tests:** `packages/a2ui_craft/test/value_types_test.dart` (or a new
`motion_test.dart`) — decode totality (each accepted form + garbage → fallback),
`Easing.decode` unknown → standard, equality/hash, `isInstant`. **Test-the-test:**
one guard asserting a bad decode does *not* silently become a non-zero duration.

## Slice 2 — motion tokens in the semantic contract + default theme

**Files:**
- `packages/a2ui_craft/lib/src/semantic_contract.dart` — add roles to `ThemeRoles`:
  `motionDurationShort/Medium/Long` (`'motion.duration.short'` …) and
  `motionEasingStandard/Emphasized/Decelerate/Accelerate` (`'motion.easing.*'`),
  plus doc-table rows naming `Box` (via `animate`) as the consumer. Add a
  `motionDefault` convenience pair (medium + standard) documented as what
  `animate: true` resolves to.
- `packages/a2ui_craft/lib/src/design_tokens.dart` — add
  `double? duration(String path)` to `ResolvedTokens` mirroring `dimension()`:
  accept DTCG `duration` type as `{ "value": 200, "unit": "ms"|"s" }` **or** a
  `"200ms"`/`"0.2s"` string → milliseconds as a double; extend `toTemplateValues`
  so `duration` canonicalizes to a plain ms number (so `theme.motion.duration.*`
  reads as a number a template/`animate` prop accepts). **Easing stays a named
  string** read via the existing `raw()` — deliberately *not* DTCG `cubicBezier`,
  to keep raw beziers out of tokens (the quantized-vocabulary guard rail; cubic
  arrays are the future escape hatch).
- `packages/a2ui_craft/lib/src/themes/default/base.tokens.json` — add a `motion`
  group: `duration.short/medium/long` (≈150/250/400 ms) and
  `easing.standard/emphasized/decelerate/accelerate` (named-string values).
- Regenerate `default_theme.g.dart` via
  `packages/a2ui_craft/tool/gen_default_theme.dart` and stage it (check.sh drift
  guard).

**Tests:** `packages/a2ui_craft/test/design_tokens_test.dart` — `duration()`
parses ms/s/map/string, total on garbage; `default_theme_test.dart` — the default
theme exposes the motion roles with expected values. Confirm `dart format` before
commit (check.sh format guard).

## Slice 3 — `prefers-reduced-motion` (the accessibility input)

**Files:**
- `packages/a2ui_craft/lib/src/media_context.dart` — add
  `final bool reducedMotion` (default `false`) to `MediaContext`: thread through
  the constructor, `==`, `hashCode`, `toString`, and `toContent()` (expose as
  `media.reducedMotion` → a bool the `media.` scope and `switch` can read). Keep it
  `const`-constructible.
- Both runtimes (`packages/a2ui_craft_{flutter,jaspr}/lib/src/runtime.dart`) —
  no structural change (the `MediaContext` already flows through `_MediaScope` /
  the media marker); just confirm `reducedMotion` rides `toContent()` and the
  ambient read. A helper `bool ambientReducedMotion(BuildContext)` on each side
  (`ambientMediaContext(context)?.reducedMotion ?? false`) for primitives.

**Tests:** `packages/a2ui_craft/test/media_context_test.dart` — equality/hash
include the flag, `toContent()` carries `reducedMotion`; add a `media.` conformance
case in `packages/a2ui_craft_testing/lib/src/conformance.dart`
(`switch media.reducedMotion { true: …, default: … }`) so both adapters read it.

## Slice 4 — `Box(animate:)` on both adapters (the deliverable)

**Files:**
- `packages/a2ui_craft/lib/src/primitive_specs.dart` — document the `animate` prop
  on the `Box` spec (Pillar A: the spec is the source of truth); note the default
  pairing and the reduced-motion collapse.
- `packages/a2ui_craft_flutter/lib/src/primitives/layout.dart` (`buildBox`) —
  decode `animate` → `Motion` (a bare `true` resolves to the theme's
  `motion.duration.medium` + `motion.easing.standard` via `ambientCraftTheme`;
  a `theme.motion.*` reference arrives pre-resolved). When `Motion` is non-instant
  **and** `ambientReducedMotion` is false, render the decorated box as an
  `AnimatedContainer(duration: …, curve: Cubic(easing.points))` (and
  `AnimatedPadding`/`AnimatedAlign` as needed); otherwise the current static
  `Container`. Easing → `Cubic(x1,y1,x2,y2)` from the enum.
- `packages/a2ui_craft_jaspr/lib/src/primitives/layout.dart` (`buildBox`) — when
  animating, add `'transition': '<props> ${ms}ms cubic-bezier(x1,y1,x2,y2)'` to the
  inner border-box style map, listing the animatable properties Box owns
  (`background-color`, `border-color`, `border-width`, `border-radius`, `width`,
  `height`, `padding`, …). Reduced-motion or instant → omit `transition`.

Selection/decoding logic (a shared `Motion` decode + the `true → theme default`
resolution) lives in the **core** where possible so both adapters agree, mirroring
`WindowSizeClass.resolveResponsive`.

**Verification:** live browser — a `Box` with `animate: true` whose `color` is
`theme.color.surface`; flip the site's theme toggle and confirm both panes
cross-fade (not snap); toggle a reduced-motion control and confirm both snap.

## Slice 5 — conformance (endpoint + declares-motion + reduced-motion)

**Files:**
- `packages/a2ui_craft_testing/lib/src/conformance.dart` — add a probe to the
  `CraftTester` interface:
  `Future<MotionProbe?> boxMotionOf(String key)` returning `{ int durationMs,
  Easing easing }` or `null` when the box declares no transition (Flutter: inspect
  for `AnimatedContainer` + its `duration`/`curve`; Jaspr: parse the element's
  `transition` style). Add `runBoxMotionConformance(tester)` with cases:
  1. `animate: true` → both adapters report the same non-zero duration + same
     easing (the *declaration* is identical).
  2. **Endpoint after settle** — retheme surface color, `pump` past the duration,
     assert `surfaceColorOf` lands the new color on both (motion doesn't change the
     destination).
  3. **Reduced-motion collapses** — with `reducedMotion: true`, `boxMotionOf` is
     `null` (no transition declared) and the endpoint is reached immediately.
  4. *(optional)* coarse midpoint — pump to ~50% and assert the probed color is
     strictly between start and end (catches "declares motion but snaps"); gate
     behind a note if frame-sampling proves flaky on one adapter.
- Implement `boxMotionOf` in both testers
  (`packages/a2ui_craft_{flutter,jaspr}/.../testing` harness impls).
- Register `runBoxMotionConformance` in both adapters' conformance test entrypoints.

Explicitly **not** asserted: intermediate frame values (beyond the optional coarse
midpoint), exact frame cadence, compositor path — the §7 tolerance band widened
along the time axis, stated in the test file's header comment.

## Slice 6 — proving demo + docs

**Files:**
- A sample exercising `Box(animate:)` — either extend an existing themed sample or
  add `samples/motion/{template.craft,schema.json,app.json,manifest.json}` +
  register in `samples/manifest.json` and the Flutter example's icon list;
  regenerate `generated_samples.g.dart` (drift guard). The template: a card whose
  surface/border are `theme.*` with `animate: true`, so the existing theme toggle
  cross-fades it.
- Live-verify on both panes: theme flip cross-fades identically; reduced-motion
  (site control or `MediaContext`) makes both snap.
- **Docs:** DESIGN.md §8 (a short "motion" note — motion tokens + `animate` as the
  first author-directed animation, micro-interactions still adapter-owned) and
  §9 (motion roles in the semantic contract); mark **Phase 1 ✅** in
  ANIMATION_DESIGN.md §7 with the as-built notes (the `Box(animate:)`-over-wrapper
  decision, named-easing tokens, reduced-motion in `MediaContext`).

## Slice ordering & dependencies

```
1 value types ──▶ 2 tokens ──▶ 4 Box(animate:) ──▶ 5 conformance ──▶ 6 demo+docs
              └──▶ 3 reduced-motion ─────────────┘
```

Slices 1–3 are pure core/data (fast, fully unit-tested, low risk). Slice 4 is the
first rendering change and the main integration point. Each slice is independently
committable and green; 4–6 each get live browser verification before commit.

## Risks / open decisions carried in

- **`animate` prop vs. `Transition` wrapper.** Plan commits to the `Box` modifier
  for Phase 1 (faithful to both frameworks' implicit model); the wrapper returns in
  Phase 2 for enter/exit. If review prefers the wrapper first, slices 4–5 retarget
  but 1–3 are unchanged.
- **Which Box properties animate.** Start with the theme-driven set (color, border,
  corner) + size/padding/alignment; `Dimension` `flex`/`fill` transitions are the
  intrinsic-sizing edge case (§13) — exclude from v1, note it.
- **Named-easing tokens vs. DTCG `cubicBezier`.** Plan uses named strings to keep
  raw beziers out (guard rail); revisit if a design system needs a bespoke curve
  (escape hatch / future).
- **Midpoint conformance flakiness.** Frame sampling mid-flight may be unstable on
  one adapter; the optional case ships only if both adapters sample deterministically
  under the test clock, else endpoint + declaration stands.
- **reduced-motion default when host is silent.** Plan defaults `false` (matches
  platform defaults); the accessibility-safer `true` is noted as an open question in
  ANIMATION_DESIGN §8, not decided here.
```
