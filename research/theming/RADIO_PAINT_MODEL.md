# Proposal: grooming the `Radio` — specified defaults, conformance

Status: **proposal** (implemented alongside). Sibling to
[CHECKBOX_PAINT_MODEL.md](CHECKBOX_PAINT_MODEL.md); read that first — the Radio is
the same painted-glyph model with one fewer role, so this note only records where
it *differs*.

## 1. The role mapping (settled) and where the radio differs from the checkbox

DESIGN.md §8 pins it: **`primary` inks the selected glyph (ring + dot), `outline`
rings the unselected circle.** Both adapters already implement that. Unlike the
checkbox there is **no `onPrimary`**: a radio's selected indicator is the accent
dot itself, not content drawn *on* an accent fill — the dot and ring are both
`primary`. So the radio is layers 1 (the **circle**: `outline` ring unselected,
`primary` ring when selected) and 3 (the **dot**, `primary`, selected-only), with
no layer-3 `onPrimary` ink.

Like the checkbox, the radio has a perfectly good host rendering, so **unthemed it
blends into the host** (§9.1) — the web returns the native UA radio, Flutter its
glyph — and only a theme with `primary` paints the spec glyph.

## 2. What needs grooming

- **Geometry drift.** The Jaspr glyph hardcodes `18px` / `2px`; the Flutter
  `_CoreRadio` draws `Icon(Icons.radio_button_checked)` at the **default 24px**.
  So the web radio and the Flutter radio are visibly different sizes, and nothing
  in the core states the intended size — the same drift `CheckboxDefaults` fixed.
- **No painted-decision conformance.** Only a behavioral case exists ("Radio
  reflects selection and fires its event on tap"). Nothing asserts `primary` inks
  the selected glyph or `outline` the ring, or that a re-theme re-inks them.
- **Contract** already reconciled in the checkbox pass (Radio named under
  `primary` and `outline`).

## 3. Decisions (recommendations)

- **D1 — unthemed: blend in.** Same as the checkbox: the host has a real radio,
  so unthemed we defer to it. **Recommend: keep blend-in.**
- **D2 — Flutter native vs custom: keep custom, honor the shared size.** The
  Flutter radio is *already* custom (an `Icon` glyph, not the native `Radio<T>`)
  — but not by preference: `Radio<T>`'s `groupValue`/`onChanged` API is
  mid-deprecation (Flutter 3.46, moving to `RadioGroup`), so going native now
  would mean building against an API about to change. **Recommend: keep the
  custom glyph for now, but honor `RadioDefaults.size`** (so the Flutter radio is
  18px, matching the web and the checkbox), and fold the move-to-native into the
  same later sibling pass as the checkbox's D2 — once `RadioGroup` lands, all
  three controls converge on native. The radio is the reason that pass is
  *blocked*, not optional.
- **D3 — disabled dimming: deferred**, with the checkbox (one cross-control
  slice).

## 4. `RadioDefaults`

```dart
abstract final class RadioDefaults {
  /// The glyph's diameter (logical px) — matches CheckboxDefaults.size so the
  /// two selection controls read the same on a form.
  static const double size = 18;

  /// The unselected ring's width. Honored by the painted (web) glyph; the
  /// Flutter Icon glyph bakes its own ring width (idiom latitude, §8).
  static const double borderWidth = 2;
}
```

Both adapters read it: the Jaspr glyph stops hardcoding `18`/`2` (CSS unchanged),
and the Flutter `Icon` takes `size: RadioDefaults.size` (24 → 18, closing the
drift). As with the checkbox, these are *specified defaults* governing the
painted glyph, not roles and not per-instance props.

## 5. Conformance

Two painted-decision probes mirroring the checkbox's: `radioSelectedColorOf()`
(the selected glyph — expect `primary`) and `radioRingColorOf()` (the unselected
ring — expect `outline`), plus a light+dark re-ink case rendering one selected +
one unselected radio, on both adapters.
