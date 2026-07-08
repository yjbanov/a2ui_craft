# Prior art — Material 3 dynamic color (and `material_color_utilities`)

> **Status: research note (uncommitted).** Part of the theming prior-art survey;
> see [PRIOR_ART.md](PRIOR_ART.md) for the index and the adopt-vs-inspire verdicts.
> The companion DTCG note is [DESIGN_TOKENS.md](DESIGN_TOKENS.md). This one asks:
> **can we adopt Material 3's color *algorithm* (not its look) as an optional token
> generator, and lean on its role *names* for our semantic contract?**

## Why M3 is special for us

Two reasons no other system on this list shares:

1. **One adapter *is* Flutter, and it already ships this.** Flutter's
   `ColorScheme.fromSeed(seedColor)` is built on the pub package
   **`material_color_utilities`** — a *pure-Dart*, dependency-free implementation
   of the M3 color science. We could import the exact same package into
   `a2ui_craft` and run it on **both** adapters (Flutter and Jaspr/dart2js),
   getting **identical resolved colors by construction** — the same
   consolidation-for-determinism move we already made for the function library.
2. **It answers three §9 open questions at once**: *token vocabulary* (a mature,
   battle-tested role set), *dark mode* (light + dark schemes fall out of one
   seed), and *accessibility* (contrast is a first-class input to the algorithm).

## What M3 color actually is

M3 replaced "pick a palette by hand" with "**derive a whole system from one seed
color**," in a perceptually-uniform color space.

- **HCT** — *Hue, Chroma, Tone*. A color space designed so that **Tone maps
  directly to WCAG contrast**: two colors at tones 40 and 100 have a predictable
  contrast ratio regardless of hue. This is the trick that makes generation
  *accessible by construction* rather than by manual checking.
- **Tonal palette** — from one hue+chroma, generate the full **0–100 tone ramp**
  (13 canonical tones). Light themes pick low-index surface tones and high-index
  text tones; dark themes invert. *Same palette, different tone selections per
  mode* — dark mode is not a second palette, it's a different read of the same one.
- **Core palette** — a seed expands to **five** tonal palettes: `primary`,
  `secondary`, `tertiary`, `neutral`, `neutral-variant`.
- **Scheme** — a strategy (`SchemeTonalSpot` is the M3 default) that, given the
  seed + `isDark` + a `contrastLevel`, decides *which tone* each role takes.
- **Roles** — the named semantic outputs (`primary`, `onPrimary`,
  `primaryContainer`, `surface`, `onSurface`, `outline`, `error`, …). Each is a
  `DynamicColor` that resolves to a concrete ARGB by evaluating tone functions +
  contrast curves against the scheme.

## The Dart API (`material_color_utilities`)

Pure Dart, no Flutter dependency, runs on VM + web. Key entry points a *runtime*
consumer calls:

```dart
import 'package:material_color_utilities/material_color_utilities.dart';

// Seed -> scheme (light or dark, with a contrast knob).
final scheme = SchemeTonalSpot(
  sourceColorHct: Hct.fromInt(0xFF0066CC),
  isDark: false,
  contrastLevel: 0.0,          // -1..1; higher = more contrast (accessibility)
);

// Resolve a role to a concrete ARGB.
final primaryArgb   = MaterialDynamicColors.primary.getArgb(scheme);
final onSurfaceArgb = MaterialDynamicColors.onSurface.getArgb(scheme);

// Lower-level, if you want the raw ramps:
final core = CorePalette.of(0xFF0066CC);   // 5 TonalPalettes
final tone40 = core.primary.get(40);        // ARGB at tone 40
```

Other pieces (not on our critical path, but notable):

- **9 scheme variants** — `SchemeTonalSpot` (default), `SchemeContent`,
  `SchemeVibrant`, `SchemeExpressive`, `SchemeFidelity`, `SchemeMonochrome`,
  `SchemeNeutral`, `SchemeRainbow`, `SchemeFruitSalad` — each a different aesthetic
  strategy from the same seed. A single "style" enum on our theme could expose
  these.
- **`Score` + `QuantizerCelebi`** — extract a good seed *from an image* (this is
  the "Material You wallpaper" magic). Out of our scope, but it's why users *love*
  this system: theme from a photo.
- **`Blend.harmonize`** — nudge an arbitrary color toward the seed's hue so
  brand + accent stay coherent.

## Fit with A2UI Craft

| Concern (§9) | M3 offers | Verdict |
|---|---|---|
| Token vocabulary (§9.7) | mature role set (`primary`/`on*`/`*Container`/`surface`/`outline`/`error`…) | **strong** — and it's what the DTCG note (§5.1) already leaned toward naming-compatibly |
| Dark mode (§9.7) | `isDark` flips tone selection; light+dark from one seed | **strong** — best answer to "one seed, two modes" |
| Accessibility | `contrastLevel` as an input; HCT tone ⇒ WCAG contrast | **strong** — accessibility is *generated*, not hand-audited |
| Cross-adapter determinism (§9.6) | pure-Dart, share the package on both adapters | **strong** — identical ARGB by construction |
| Type scale | M3 type scale (display/headline/title/body/label × L/M/S) — exists in Flutter's `TextTheme`, but *not* in `material_color_utilities` (that's color-only) | partial — names yes, generation no |
| Spacing / shape | not covered by the color package | n/a |

## The catches (be honest)

- **It's color-only.** `material_color_utilities` generates colors. Type scale,
  spacing, shape/radius, elevation are *not* in it — we'd still author those (or
  borrow M3's *named* type/shape scales, which live in the Flutter framework, not
  this package).
- **It bakes a Material aesthetic.** Tonal-spot generation produces *Material*-
  flavored schemes (muted containers, specific tone relationships). A brand that
  wants flat, high-chroma, or a hand-tuned palette will fight the generator. So:
  **offer generation as one path, never the only one** — an author must be able to
  supply an explicit token map (DTCG) and skip generation entirely.
- **Determinism needs a test, not a promise.** ARGB outputs are integers (no
  `4.0`-vs-`4` `toString` hazard we hit before), but HCT involves float math; VM
  vs dart2js float behavior should be *pinned by a conformance case* (assert a seed
  → a known ARGB on both adapters) before we rely on it. This is the same
  discipline as the function library, and it's cheap.
- **Opinion cost.** Adopting M3 roles wholesale imports ~26+ color roles. That's a
  lot of surface for "keep the token set small" (§9.7). We can subset: expose a
  *minimal* neutral role set that happens to be M3-name-compatible, and let the M3
  generator fill a fuller set for authors who want it.

## Verdict

- **Adopt the *algorithm* as an optional generator** (`seed → scheme → roles`),
  by importing `material_color_utilities` into `a2ui_craft`. It's the single
  highest-leverage "adopt-as-is" candidate after DTCG *because it's already a
  shared pure-Dart dependency of one adapter* — near-zero integration risk, and it
  makes "give me a whole accessible light+dark theme from one brand color"
  a one-liner an author (or even a host) can drive.
- **Lean on M3 role *names* for the semantic contract** (as the DTCG note already
  proposed), so an M3/DTCG export maps on with zero translation — but keep the
  *required* set minimal and always allow an explicit token map instead of
  generation.
- **Borrow M3's *named* type + shape scales** (display/headline/title/body/label;
  a small radius scale) as inspiration for our non-color tokens — names, not the
  Flutter implementation.

This complements DTCG cleanly: **DTCG is the on-the-wire *format* for an explicit
token set; M3 is an optional *generator* that produces such a set (as resolved
roles) from a seed.** An author can ship either a hand-authored `.tokens.json` or
just a seed color + style; both land on the same resolved-token surface.

## Sources

- [`material_color_utilities` — Dart API docs](https://pub.dev/documentation/material_color_utilities/latest/)
- [`material_color_utilities` on pub.dev](https://pub.dev/packages/material_color_utilities) · [changelog](https://pub.dev/packages/material_color_utilities/changelog)
- [`ColorScheme.fromSeed` — Flutter API](https://api.flutter.dev/flutter/material/ColorScheme/ColorScheme.fromSeed.html)
- [material-foundation/material-color-utilities (source + DeepWiki)](https://deepwiki.com/material-foundation/material-color-utilities)
- [`DynamicScheme` — Flutter API](https://api.flutter.dev/flutter/package-material_color_utilities_dynamiccolor_dynamic_scheme/DynamicScheme-class.html)
- [Material 3 color system / roles](https://m3.material.io/styles/color/roles)
