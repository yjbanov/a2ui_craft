# Prior art — native platform theming (Flutter · Apple HIG / SwiftUI)

> **Status: research note (uncommitted).** Part of the theming prior-art survey;
> see [PRIOR_ART.md](PRIOR_ART.md) for the index and verdicts. These two matter for
> different reasons: **Flutter** is the *substrate one adapter renders into* (§13.6
> — so its theming API is the literal carrier for our resolved tokens, not a design
> choice), and **Apple HIG/SwiftUI** is the most mature *semantic + adaptive +
> accessible* role model on any platform (the gold standard for the vocabulary and
> mode questions in §13.7).

---

## 1. Flutter — `ThemeData`, the `InheritedWidget` cascade, and `ThemeExtension`

The Flutter adapter already gets §13.1's zero-config baseline *for free* because
Flutter theming *is* an ambient cascade:

- **`Theme.of(context)` is the cascade.** `ThemeData` is provided via an
  `InheritedWidget`; a widget reads the nearest ancestor theme and rebuilds when it
  changes. This is Flutter's `var()` — the exact "inherit the host look for free"
  mechanism of §13.1, and the native home for §13.4's *ambient role-defaults* tier.
  Wrapping a subtree in a new `Theme(data: …)` re-themes just that subtree — the
  cascade/override semantics we want, already there.

- **`ThemeExtension<T>` — the native carrier for our token bag.** Since Flutter
  2.10 you can attach arbitrary typed objects to `ThemeData.extensions` and read
  them via `Theme.of(context).extension<T>()`. You subclass `ThemeExtension<T>` and
  implement two methods:
  - `copyWith(...)` — return a modified instance (how overrides layer), and
  - `lerp(other, t)` — interpolate between two instances, which gives Flutter
    **animated theme transitions for free**.

  ```dart
  @immutable
  class CraftTokens extends ThemeExtension<CraftTokens> {
    const CraftTokens({required this.action, required this.surface, required this.radius});
    final Color action;
    final Color surface;
    final double radius;

    @override CraftTokens copyWith({Color? action, Color? surface, double? radius}) =>
      CraftTokens(action: action ?? this.action, surface: surface ?? this.surface, radius: radius ?? this.radius);

    @override CraftTokens lerp(CraftTokens? other, double t) => other == null ? this :
      CraftTokens(
        action: Color.lerp(action, other.action, t)!,
        surface: Color.lerp(surface, other.surface, t)!,
        radius: lerpDouble(radius, other.radius, t)!,
      );
  }
  // read: final tokens = Theme.of(context).extension<CraftTokens>();
  ```

  This is *precisely* the mechanism the Flutter adapter would use to carry our
  resolved token map into the ambient theme so primitives read roles the Flutter
  way. And `lerp` means §13.4's "reactive re-theme when the host flips dark mode"
  can be a smooth animated transition, not a hard cut — a nice, free win.

- **`ColorScheme` + `TextTheme` — the M3 semantic layer, native.** Flutter's own
  `ColorScheme` (roles) and `TextTheme` (the M3 type scale: display/headline/title/
  body/label × L/M/S) are where our color + type roles map when they line up with
  M3 names — reinforcing the M3-name-compatibility recommendation
  ([PRIOR_ART_MATERIAL3.md](PRIOR_ART_MATERIAL3.md)). `CupertinoTheme` is the iOS
  counterpart.

**Implication for §13.6 (cross-adapter mapping) — now concrete.** One resolved
token, two native carriers:

| Resolved token | Flutter adapter maps to | Jaspr adapter maps to |
|---|---|---|
| color role | `ColorScheme` field / `ThemeExtension` `Color` | CSS custom property (`--…`) |
| type role | `TextTheme` `TextStyle` / `ThemeExtension` | CSS `font`/`--font-*` |
| spacing / radius | `ThemeExtension` `double` / `Dimension` | CSS `var(--space-*)` / `--radius-*` |
| dark mode | swap `ThemeData` (light/dark) — reactive via `InheritedWidget` | `color-scheme` + `light-dark()` / `.dark` scope |

Both sides already have a cascade with fallback and reactivity; the shared,
framework-neutral piece is just the *resolved token map* (produced once in
`a2ui_craft`), and each adapter binds it to its native theming primitive. This is
the same architecture as the primitives themselves (§11) and the function library.

**Verdict:** `ThemeExtension` is **adopt** — but as an *implementation fact* of the
Flutter adapter, not a portable design. It's how tokens become ambient on Flutter,
it gives typed reads + animated transitions, and it slots under §13.4's cascade
with zero friction.

---

## 2. Apple HIG / SwiftUI — semantic, adaptive, accessible (the vocabulary gold standard)

Apple's system is the most disciplined answer to "what should a role vocabulary
be" — and it's a system users *trust* precisely because they never think about it.

- **Semantic, purpose-named, adaptive colors.** Every system color is named by
  *purpose*, not appearance, and adapts automatically:
  - **Labels (foreground hierarchy):** `label`, `secondaryLabel`, `tertiaryLabel`,
    `quaternaryLabel` — four levels of text emphasis from *one* idea.
  - **Backgrounds (surface hierarchy):** `systemBackground`, `secondarySystemBackground`,
    `tertiarySystemBackground` — plus a parallel *grouped* set
    (`systemGroupedBackground`, …) for grouped layouts.
  - **Separators / fills / tints:** `separator`, `opaqueSeparator`, fill colors,
    `link`, and the `systemBlue`/`systemRed`/… accent set.
  - **One token resolves to *four* values** — light × dark × normal-contrast ×
    increased-contrast — automatically. Apple's rule: **"Don't hardcode system
    color values; they may change between releases. Use the semantic API."**

- **Dynamic Type — a *named* type scale, not fixed sizes.** Text uses named styles
  (`largeTitle`, `title1/2/3`, `headline`, `subheadline`, `body`, `callout`,
  `footnote`, `caption1/2`) that **rescale system-wide** when the user changes their
  preferred text size. The scale is defined as *roles*, not pixels, specifically so
  accessibility scaling works. This is a strong argument that **our type scale
  should be named roles** (body/title/…) resolved to sizes, not raw pixel tokens.

- **Materials / vibrancy** (blur, translucency) — out of scope for us: they need
  real render code, which §13.3 puts in the "cannot be ephemeral" bucket.

**What to steal (all inspiration — Apple ships no portable format):**

1. **Roles encode *intent*, not appearance, and are adaptive by design.** This is
   the philosophical core of §13.4's role-defaults and §13.6's "a design system
   encodes *decisions*, not pixels." Name a role for what it's *for* (`action`,
   `onSurface`), and modes/contrast/accessibility become *resolution details* of
   that role rather than separate tokens.
2. **Hierarchy as a compact depth mechanism.** `primary/secondary/tertiary/
   quaternary` labels + backgrounds give visual depth from *very few* tokens —
   exactly the "keep the token set small" pressure of §13.7. Worth considering a
   small emphasis hierarchy (`onSurface` / `onSurfaceVariant` / muted) rather than
   many bespoke greys.
3. **Modes are *plural*.** Apple treats **increased-contrast** (and reduce-
   transparency, bold-text, larger-text) as first-class axes *alongside* light/dark.
   This is a forward-looking note for §13.7: whatever mode mechanism we pick
   (semantic-token-selects-per-condition — see
   [PRIOR_ART_RUNTIME_RESOLUTION.md](PRIOR_ART_RUNTIME_RESOLUTION.md)) should be
   *n-ary in the mode input*, not hardwired to a single light/dark boolean — even
   if v1 only ships light/dark. (M3's `contrastLevel` input agrees —
   [PRIOR_ART_MATERIAL3.md](PRIOR_ART_MATERIAL3.md).)
4. **Named type scale ⇒ accessibility-scalable.** Adopt named type roles so a host
   could later apply a text-scale factor globally.

**Verdict:** Apple's model is **inspiration** for (a) the role vocabulary
(purpose-named, adaptive, with a compact hierarchy), (b) the named type scale, and
(c) the "modes are plural" design of the mode input. It's the strongest evidence
that a *small, semantic, intent-named* set beats a large appearance-named one — the
same conclusion the shadcn/Radix cluster reaches from the web side
([PRIOR_ART_WEB_TOKEN_SYSTEMS.md](PRIOR_ART_WEB_TOKEN_SYSTEMS.md)).

## Sources

- [Flutter — `ThemeExtension` API](https://api.flutter.dev/flutter/material/ThemeExtension-class.html) · [Flutter cookbook — using themes](https://docs.flutter.dev/cookbook/design/themes)
- [Flutter — `ThemeData`](https://api.flutter.dev/flutter/material/ThemeData-class.html) · [`ColorScheme`](https://api.flutter.dev/flutter/material/ColorScheme-class.html)
- [Apple HIG — Color](https://developer.apple.com/design/human-interface-guidelines/color) · [Apple HIG — Typography / Dynamic Type](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Apple — UIColor semantic/adaptive colors](https://developer.apple.com/documentation/uikit/uicolor/ui_element_colors)
