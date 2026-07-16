# Proposal: grooming the `Switch` — specified defaults, a role-semantics fix, conformance

Status: **proposal** (implemented alongside). Sibling to
[CHECKBOX_PAINT_MODEL.md](CHECKBOX_PAINT_MODEL.md). The switch is a track + thumb
rather than a box + mark, and it is the control that surfaces two cross-cutting
questions: *what does an always-painted control do unthemed*, and *do the two
adapters agree on which part a role inks*. The second one turned up a genuine
divergence to fix.

## 1. The role mapping and the divergence

DESIGN.md §8 pins: **`primary` fills the active track, `onPrimary` inks the
on-thumb, `outline` the inactive track.** The active side already agrees on both
adapters. The **inactive** side does **not**:

- **Jaspr** fills the inactive *track* with `outline`.
- **Flutter** puts `outline` on the inactive *thumb* and the track *border*
  (`inactiveThumbColor` + `trackOutlineColor`), leaving the track fill the host
  default.

That is precisely what §8 forbids — "an idiom must never *repurpose* a role onto
a different part." A theme setting `outline` gets a gray track on the web and a
gray thumb-with-border on Flutter. **This is the consistency bug the cross-check
was meant to catch.**

**Recommendation: `outline` inks the inactive track *fill*, on both adapters.** A
flat outline-colored pill is the most legible, adapter-neutral reading of "the
inactive track", and it is what the reference web glyph already does. So Flutter
changes to `inactiveTrackColor: outline` (dropping the thumb/border outline
usage); the off-thumb becomes a contrasting neutral (surface), matching the web
glyph's white thumb. The thumb neutral is *not* a role — neutrals are idiom
latitude, and only the on-thumb (`onPrimary`) is probed.

## 2. The paint model, and D1 (unthemed)

Layer 1 is the **track** (`primary` fill active, `outline` fill inactive), layer 3
the **thumb** (`onPrimary` on the active track; a neutral on the inactive one).

The switch answers the checkbox's D1 (blend-in vs always-paint) the **opposite**
way, and that is the principled part: **the web has no native switch element**,
so there is nothing to blend into — the switch is *always* adapter-painted, and
unthemed it uses a scheme-adaptive neutral palette (like the `Button`, which
likewise has no look-free fallback). The split across all four controls:

| Unthemed behavior | Controls | Why |
| --- | --- | --- |
| Blend into the host | `Checkbox`, `Radio` | a real native control exists |
| Always paint (fallback palette) | `Button`, `Switch` | no adequate native fallback |

**Recommend: keep always-paint** (it is forced, not chosen). The Flutter side
*does* have a native switch, so there it blends in unthemed like the checkbox —
the always-paint is a web-idiom fact, not a cross-adapter rule.

## 3. `SwitchDefaults`

The Jaspr glyph hardcodes the track and thumb geometry (`36×20`, radius `10`,
thumb `7`, positions `11`/`25`). Lift it into the core:

```dart
abstract final class SwitchDefaults {
  static const double trackWidth = 36;
  static const double trackHeight = 20;   // radius = height / 2 (a pill)
  static const double thumbDiameter = 14;
  static const double thumbInset = 4;      // horizontal gap track edge → thumb
}
```

The web glyph derives everything from these (radius `= trackHeight/2`, thumb
centers `= thumbInset + thumbRadius` and `trackWidth − thumbInset − thumbRadius`)
— reproducing today's exact pixels, now stated once. Like `CheckboxDefaults`
these govern the *painted* glyph; the native Flutter switch keeps its own
geometry (idiom latitude), so it reads none of them — that is expected, and the
same shape as the checkbox (native honors only what it exposes).

## 4. A structural tidy (testability + consistency)

The web glyph packs the thumb and track into one `background` shorthand (a
radial-gradient over a color). Split them: **`background-color` = the track**
(the `primary`/`outline` surface), **`background-image` = the thumb** (the
`onPrimary` gradient). That makes the switch's CSS map to the *same* properties
as the checkbox (fill = `background-color`, mark = `background-image`), which is
both a consistency win and what lets the painted-decision probes read one
property each instead of parsing a combined shorthand. Pixel-identical output.

## 5. Conformance

Three painted-decision probes: `switchActiveTrackColorOf` (`primary`),
`switchThumbColorOf` (`onPrimary`), `switchInactiveTrackColorOf` (`outline`),
plus a light+dark re-ink case rendering one on + one off switch, on both
adapters. This case is what *pins* the §1 normalization — without it the two
adapters could drift again.

## 6. Deferred (with the siblings)

Disabled dimming (D3) and any move in the native-vs-custom axis (D2) ride the
shared later pass. The switch is already native-on-Flutter / painted-on-web, the
same split as the checkbox.
