# Proposal: grooming the `Checkbox` — paint model, specified defaults, conformance

Status: **proposal** (no code yet). Sibling to the `Button` four-layer paint
model (DESIGN.md §8) and the `Card`/`Box` decoration grooming. The goal is to
give `Checkbox` the same rigor `Button` got: a stated paint model, framework-
neutral specified defaults, a reconciled role mapping, and painted-decision
conformance — so the checkbox is *specified*, not hand-mirrored, and can't drift
between the Flutter and Jaspr adapters.

## 1. Why the checkbox needs grooming

The role mapping is already pinned and correct (DESIGN.md §8 control table):
**`primary` fills the checked box, `onPrimary` draws the mark, `outline` inks the
unchecked box.** Both adapters implement that mapping today. What is *not* pinned
— and is quietly drifting — is everything around it:

- **Geometry is hardcoded per-adapter.** The Jaspr painted glyph hardcodes
  `18px` size, `4px` corner radius, `2px` border
  ([checkbox.dart](../../packages/a2ui_craft_jaspr/lib/src/primitives/checkbox.dart)).
  The Flutter side is `Checkbox.adaptive`, whose native Material box uses its own
  (~`2px`) radius and sizing
  ([checkbox.dart](../../packages/a2ui_craft_flutter/lib/src/primitives/checkbox.dart)).
  So the two web-vs-Material corners **do not match**, and nothing in the core
  says what they *should* be. This is exactly the "a padding hard-coded
  independently on each side" drift §8 warns against — the same problem
  `CardDefaults` and the button's `_kButtonCornerRadius` were created to kill.

- **The semantic contract is stale about what the checkbox reads.** The contract
  table
  ([semantic_contract.dart](../../packages/a2ui_craft/lib/src/semantic_contract.dart))
  lists `primary` as read by "Checkbox, Slider, Radio accents", but says
  `outline` is read only by "Divider, TextField, Card, Box border" and that
  `onPrimary` has "no primitive consumer yet." The checkbox code reads **both**
  `outline` (box) and `onPrimary` (mark) right now. The file's own design note
  says "a primitive must not read a role this file does not name (add it here
  first — the contract is the source of truth)." So the implementation currently
  violates its own contract; the contract must be reconciled.

- **No painted-decision conformance.** `Card`, `Box`, and `Button` have
  painted-decision probes (`surfaceColorOf`, `borderColorOf`,
  `buttonSurfaceColorOf`) that assert "re-theming a role re-inks the mapped
  part" in light and dark (DESIGN.md §8 "Control conformance", §9.6). The
  checkbox has **only behavioral** conformance ("a two-way Checkbox writes its
  bound value") — nothing asserts that `primary` actually fills the box or that
  re-theming re-inks it. The mapping is untested.

- **Sibling inconsistency.** The Flutter `Radio` already renders a *custom
  glyph* (`_CoreRadio`), while the Flutter `Checkbox` uses the *native adaptive*
  widget. Both are described in-code as interim. Whatever we decide for the
  checkbox sets the pattern Radio and Switch should follow.

## 2. The paint model, applied to a checkbox

`Button` established "four layers, one owner." A checkbox is a tiny control but
the same four layers apply — naming them is what lets both adapters order and
ink the parts identically:

| # | Layer | Checkbox specifics | Role / default |
| --- | --- | --- | --- |
| 1 | **Box (surface)** | the square: border when unchecked, fill when checked, corner radius, size | unchecked border ← `outline`; checked fill ← `primary`; radius + size ← `CheckboxDefaults` |
| 2 | **State layer** | hover / focus / pressed feedback around the box | idiom latitude: Material ripple halo; web hover tint + `:focus-visible` ring |
| 3 | **Mark (content)** | the checkmark, shown only when checked | ← `onPrimary` |
| 4 | **Composite** | disabled dimming over the whole glyph | specified opacity (see D3) |

Two invariants fall out of this and should be stated in the spec:

- **Checked box has no separate outline.** In the checked state the `primary`
  fill *is* the box; `outline` only inks the unchecked border. (Both adapters
  already do this; pin it so neither "improves" it into a double border.)
- **The mark never shows unchecked.** Layer 3 is checked-only. (Indeterminate is
  a reserved third state — D5.)

## 3. Specified defaults: `CheckboxDefaults`

Add to
[primitive_specs.dart](../../packages/a2ui_craft/lib/src/primitive_specs.dart),
next to `CardDefaults`, so both adapters read one source instead of two
hardcodes:

```dart
abstract final class CheckboxDefaults {
  /// The box's edge length (logical px). Pinned by control conformance.
  static const double size = 18;

  /// The box corner radius — the neutral Craft default, shared so the web and
  /// Material corners agree (today: web 4px vs Material ~2px — a visible drift).
  static const CornerRadius cornerRadius = CornerRadius(4);

  /// The unchecked box border width.
  static const double borderWidth = 2;
}
```

These are *specified defaults, not themeable roles* — exactly like
`CardDefaults.cornerRadius`. Radius/size stay out of the semantic contract (v1
defers radius/spacing scales); they are not per-instance props either (a
checkbox is not a button — see D2/§8 "no `shape` prop"). Both adapters import
these; the Jaspr glyph stops hardcoding `18/4/2`, and — if we adopt D2 — the
Flutter glyph honors the same numbers.

## 4. Role mapping + contract reconciliation

Mapping is unchanged (it's correct); we only make the contract tell the truth.
Update the `semantic_contract.dart` table so the real consumers are named:

- `outline` — add `Checkbox` / `Radio` box + ring (they already read it).
- `onPrimary` — change from "no primitive consumer yet" to naming `Checkbox`
  mark, `Radio` dot, `Switch` on-thumb (all already read it).

This is a documentation fix with no behavior change, but it unblocks the
conformance additions (§6) from being "reading an unnamed role."

## 5. The load-bearing decisions

The mapping and defaults above are mechanical. These are the real judgment
calls; each has a recommendation.

### D1 — Unthemed: blend into the host, or always paint? **(Recommend: blend in.)**

`Button` *always* paints its surface (even unthemed, via `kButtonSurfaceFallback`)
because there is no look-free pressable. A checkbox is different: unthemed, the
host already has a perfectly good checkbox (the UA `<input type=checkbox>` on the
web, Material/Cupertino on Flutter). DESIGN.md §9.1 keeps "blend into the host"
as the zero-config baseline, and the Jaspr checkbox already honors it (returns
`null` styles → native UA glyph when no `primary`).

**Recommendation: keep blend-in when fully unthemed.** Consequence to accept and
document: theming a role flips the web glyph from the UA look (native, ~13px) to
the painted spec glyph (18px, 4px) — so enabling a theme changes the checkbox
*geometry*, not only its color. That is acceptable under the doctrine ("the
platform may be visible" unthemed; the *spec* glyph governs once themed), but it
should be stated so it's a decision, not a surprise. The alternative
(always-paint for stable geometry) trades away the native unthemed feel §9.1
prizes; I don't recommend it for the checkbox.

### D2 — Flutter themed path: native `Checkbox.adaptive`, or a custom glyph? **(Recommend: keep native adaptive for now; revisit with Radio/Switch.)**

Today Flutter themes the *native* `Checkbox.adaptive` via `activeColor` /
`checkColor` / `side`. That honors the role mapping and gives real Material/
Cupertino idioms + state layer + a11y for free — but it **cannot honor
`CheckboxDefaults.cornerRadius`/`size`** (the native widget owns its own
geometry). So under D2-native, the shared `CheckboxDefaults` govern the **web**
glyph and the **Cupertino/Material** boxes keep their platform geometry — which
is legitimate idiom variance (§8: "two idioms rendering the same template must
agree on behavior and role *semantics*", not geometry), but it means
`CheckboxDefaults.cornerRadius` is effectively a *web-and-custom-glyph* default,
not a truly universal one.

The alternative (D2-custom) paints the glyph on Flutter too — like `_CoreRadio`
already does — so all adapters share `CheckboxDefaults` geometry exactly, at the
cost of re-implementing the Material/Cupertino state layer and a11y by hand and
losing true native idiom.

**Recommendation: keep `Checkbox.adaptive` on Flutter for this pass**, and scope
`CheckboxDefaults.cornerRadius`/`size` as "the painted-glyph default (web today;
any adapter that paints its own glyph)." Note the asymmetry with `_CoreRadio`
and fold the native-vs-custom decision into a **single later pass across
Checkbox + Radio + Switch**, so the three siblings converge on one strategy
instead of each picking differently (which is the current mess). Trying to
settle native-vs-custom for the checkbox alone would pre-commit the siblings.

### D3 — Disabled state (composite layer). **(Recommend: specify, but as its own small slice.)**

Neither adapter dims a handler-less checkbox today (support.dart: "Disabled
buttons get no visual dimming yet"). The paint model's layer 4 is composite
dimming. Proposal: a specified disabled treatment — `opacity: 0.38` over the
glyph (Material's disabled token; renders identically as a CSS `opacity` and a
Flutter `Opacity`/`Theme` disable). **Caveat:** several samples use handler-less
controls as static decoration, so turning on dimming will visibly change them —
which is why this should be its own slice with a sample sweep, not bundled into
the mapping/defaults work.

### D4 — Web state layer (hover). **(Recommend: minimal, optional.)**

The web checkbox currently has no hover state layer (only cursor + UA focus
ring); Material's has a ripple halo. That's allowed idiom variance. A subtle
`:hover` (e.g. a faint `outline`-tinted halo via a pseudo-element, or just a
border brighten) would close the gap cheaply. Low priority; include only if it's
free in the glyph rewrite.

### D5 — Indeterminate / tristate. **(Recommend: reserve, don't build.)**

A checkbox's third visual state (a dash, `value == null`) is real but A2UI's
`Checkbox` is boolean (`value: bool`) today. Reserve the mark slot for an
indeterminate dash as a future additive extension; out of scope now.

## 6. Conformance additions (Pillar C)

Add painted-decision probes to `CraftTester`
([conformance.dart](../../packages/a2ui_craft_testing/lib/src/conformance.dart)),
mirroring `surfaceColorOf`/`borderColorOf`:

- `checkboxFillColorOf()` — the checked box fill (expect `primary`).
- `checkboxBorderColorOf()` — the unchecked box border (expect `outline`).
- `checkboxMarkColorOf()` — the checkmark ink (expect `onPrimary`).

Flutter reads them off the `Checkbox`/custom-glyph properties; Jaspr reads the
computed styles / the SVG stroke — the same split the existing probes use. Then
one theming case per the §8 "control conformance" recipe: **the default look
reads its mapped roles, and re-theming a role re-inks the mapped part**, asserted
in light and dark. This is the coverage the checkbox is missing entirely.

## 7. Proposed slices (implementation order, once accepted)

1. **`CheckboxDefaults` + contract reconciliation** — add the defaults; both
   adapters read them (Jaspr stops hardcoding 18/4/2); fix the
   `semantic_contract.dart` table (outline/onPrimary consumers). Pure
   consolidation + doc; no visible change beyond the web corner going 4→4 (or to
   whatever we pick). Update DESIGN.md §8 with the checkbox paint-layer table.
2. **Checkbox painted-decision conformance** — the three probes + the
   light/dark re-ink theming case on both adapters.
3. *(separate)* **Disabled composite layer** (D3) across controls + sample sweep.
4. *(separate, later)* **Checkbox + Radio + Switch native-vs-custom convergence**
   (D2) — the one pass that settles all three siblings together.

## 8. What stays out

- No new `Checkbox` props (no `cornerRadius`/`size`/`shape` prop — see §8 "no
  `shape` prop"; the checkbox is spec-governed, not per-instance-styled).
- No tristate, no label-composition (a label is the template's job, a `Row` of
  `Checkbox` + `Text`).
- The Flutter native-vs-custom glyph decision is explicitly deferred to the
  sibling pass, not settled here.
