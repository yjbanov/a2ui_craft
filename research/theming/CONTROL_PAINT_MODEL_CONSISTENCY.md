# Cross-check: are Checkbox, Radio, and Switch consistent?

A verification pass after grooming all three (and `Button` before them) to the
DESIGN.md §8 paint model. The per-control rationale lives in
[CHECKBOX_PAINT_MODEL.md](CHECKBOX_PAINT_MODEL.md),
[RADIO_PAINT_MODEL.md](RADIO_PAINT_MODEL.md), and
[SWITCH_PAINT_MODEL.md](SWITCH_PAINT_MODEL.md); this is the "do they line up"
check. **One divergence was found and fixed** (the switch's `outline`); the rest
line up, and the differences that remain are justified by the controls' nature,
not drift.

## The shared model (all three follow it)

| Axis | Checkbox | Radio | Switch |
| --- | --- | --- | --- |
| **Specified defaults** (core, both adapters read) | `CheckboxDefaults` (size 18, corner 4, border 2) | `RadioDefaults` (size 18, border 2) | `SwitchDefaults` (track 36×20, thumb 14, inset 4) |
| **Layer 1 (surface)** | box: `outline` border / `primary` fill | circle: `outline` ring / `primary` ring | track: `outline` inactive / `primary` active |
| **Layer 3 (content)** | mark ← `onPrimary` | dot ← `primary` (no onPrimary) | thumb ← `onPrimary` on / neutral off |
| **Unthemed (D1)** | blend into host (native) | blend into host (native) | **always paint** (no native web switch) |
| **Flutter idiom (D2)** | native `Checkbox.adaptive` | **custom** `Icon` (blocked on `RadioGroup`) | native `Switch.adaptive` |
| **Geometry Flutter honors** | border width | glyph size | none (fully native) |
| **Conformance** | fill / mark / border probes + light-dark re-ink | selected / ring probes + re-ink | active-track / thumb / inactive-track probes + re-ink |
| **Disabled (D3)** | deferred | deferred | deferred |

Everything above is uniform: each control has one `*Defaults` class in
`primitive_specs.dart` that both adapters read (no per-adapter geometry
hardcodes), each reads the same semantic roles the reconciled contract names,
each has painted-decision probes with a light+dark re-ink case, and disabled
dimming is deferred for all three as one future slice.

## The divergence found and fixed

**Switch `outline`.** The two adapters were inking `outline` onto *different
parts*: the Jaspr glyph filled the inactive **track**, while Flutter put `outline`
on the inactive **thumb + track border**. DESIGN.md §8 forbids exactly this — "an
idiom must never repurpose a role onto a different part." Normalized so **both
fill the inactive track** (Flutter: `inactiveTrackColor`), with the off-thumb a
contrasting neutral. Verified live: themed on/off switches now match across the
Jaspr and Flutter panes, and the switch conformance case pins it.

(The checkbox and radio had no such divergence — their role→part mapping already
agreed on both adapters; the pass only added defaults + conformance.)

## Differences that are *intentional*, not drift

- **Radio has no `onPrimary`.** A checkbox/switch draws light content *on* an
  accent fill (the mark, the on-thumb) → `onPrimary`. A radio's indicator is the
  accent dot *itself* → `primary`. So the radio maps two roles, not three. This
  is inherent to the control, and the contract/DESIGN table reflect it.
- **The radio's primary-inked part is its `border`, not `background-color`.** The
  checkbox fill and switch active track are solid surfaces (`background-color`);
  the radio's selected indicator is a ring (`border`) plus a dot
  (`background-image`). Same *layer-1* role (`primary`), different CSS property
  because a ring is not a fill. The conformance probe reads each where it lands.
- **The switch always paints; the checkbox and radio blend in unthemed.** Not a
  per-control whim: the split is **"does an adequate native control exist?"** The
  web has a real `<input type=checkbox|radio>` but **no switch element**, so the
  switch (like `Button`, which has no look-free pressable) must always paint,
  falling back to a scheme-adaptive palette. On *Flutter*, which does have a
  native switch, the switch blends in unthemed like the others — so this is a
  web-idiom fact, not a cross-adapter rule.
- **Flutter renders the radio custom while the checkbox/switch are native.** Also
  forced, not chosen: `Radio<T>` is mid-migration to `RadioGroup`, so the radio
  is an `Icon` glyph for now. The radio is what *blocks* the shared "move the
  three to native" pass (D2), which is why that pass is deferred rather than
  done here.

## Deferred, uniformly

- **D2 — native-vs-custom convergence.** Target: all three native once
  `RadioGroup` lands. Today: checkbox + switch native, radio custom.
- **D3 — disabled composite dimming.** None of the three (nor `Button`) dims a
  handler-less control yet; one cross-control slice with a sample sweep, since
  samples use handler-less controls as static decoration.

## Verdict

Consistent. The three share one paint model, one defaults pattern, one contract,
and one conformance shape; the one real divergence (switch `outline`) is fixed and
regression-pinned; the remaining differences are each a consequence of the
control's own nature or an upstream constraint, documented in DESIGN.md §8 and the
per-control proposals.
