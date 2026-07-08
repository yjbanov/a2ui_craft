# Prior art — runtime token resolution (CSS custom properties + JS runtime theme objects)

> **Status: research note (uncommitted).** Part of the theming prior-art survey;
> see [PRIOR_ART.md](PRIOR_ART.md) for the index and verdicts. This file is about
> the *mechanism* question of §9.4 — **how do tokens reach primitives at runtime,
> and how do the cascade + dark mode actually resolve** — because that is where our
> design differs most from the build-time DTCG ecosystem
> ([DESIGN_TOKENS.md](DESIGN_TOKENS.md)). Two lineages matter: the **CSS platform**
> (the model §9.4 explicitly mirrors) and **JS runtime theme objects** (the family
> that most resembles our "theme is a 4th ambient reactive scope" idea).

---

## 1. CSS custom properties + the cascade — the reference model

§9.4 already frames our token delivery as "the CSS model." It's worth being
precise about *why* CSS custom properties are the right mental model for a
**runtime, ephemeral, total** theme layer — every property we want, the platform
already has:

- **`var(--x, fallback)` — totality with host fallback, natively.** A custom
  property lookup that misses returns its fallback. That is exactly §9.4's "an
  unset role falls back to the host default" and §9.6's totality discipline —
  built into the resolution primitive, no branching.
- **The cascade *is* the ambient-role-default tier.** A custom property resolves
  from the **nearest ancestor scope** that defines it and inherits down the tree.
  Redefining `--brand` on a subtree re-themes only that subtree. This is precisely
  §9.5's layered cascade (host defaults → author system → host mode config →
  per-widget) — each layer just redefines variables at a deeper scope.
- **Runtime-reactive by construction.** Change a variable at `:root` and every
  `var()` consumer updates live — no rebuild. That is our "host flips dark mode and
  a live surface re-themes through the existing resolution path" (§9.4), for free
  on the web adapter.
- **`light-dark()` — a per-token, value-level dark encoding.** The newer
  `light-dark(lightValue, darkValue)` function returns one or the other based on
  the active `color-scheme`, with **no media query and no JS**. Set
  `:root { color-scheme: light dark }` and write
  `--surface: light-dark(#fff, #111)`. It reached **Baseline "newly available" in
  May 2024** (Chrome/Edge 123, Firefox 120, Safari 17.5) and is projected
  **"widely available" ~Nov 2026**. This is a concrete data point for §9.7's dark
  mode question: *a single token can carry both mode values inline*, selected by an
  ambient input — the same shape as Panda's condition-tokens (below) and DTCG's
  resolver modifiers.

**Verdict:** **adopt the model** — it's not even a choice on the Jaspr adapter,
it's the native substrate (map resolved tokens → CSS custom properties at a scope;
map dark mode → `color-scheme` + `light-dark()` or a `.dark` scope). The value for
*design* is that CSS has already worked out the exact resolution semantics we
described in §9.4/§9.5; we should mirror them rather than invent.

---

## 2. JS runtime theme objects — the family closest to what we need

Unlike the DTCG *compilers*, this lineage keeps the theme as a **live object read
at runtime**. That's our situation: an ephemeral token set loaded and interpreted
on the client, read by primitives as an ambient scope.

### 2.1 System UI Theme Specification / styled-system / Theme UI — *scales*

The [System UI Theme Specification](https://github.com/system-ui/theme-specification)
(the shape behind styled-system, Theme UI, and early Chakra) is a plain object of
**scales**, keyed by the CSS property they feed, with a plural-naming convention:

```js
{
  colors:    { text: '#111', background: '#fff', primary: '#07c', modes: { dark: {…} } },
  space:     [0, 4, 8, 16, 32, 64],        // ordinal -> array, referenced by index
  fontSizes: [12, 14, 16, 20, 24, 32],     // a type scale as an array
  radii:     { sm: 2, md: 6, lg: 12 },     // named -> object
  fonts:     { body: 'Inter, sans-serif' },
  fontWeights: { body: 400, bold: 700 },
  shadows:   { card: '0 1px 3px rgba(0,0,0,.2)' },
}
```

**What to steal:** the **scale** concept — `space` and `fontSizes` as *ordered
scales referenced by step*, rather than a pile of named sizes. A compact spacing
rhythm and type scale (§9.3 item 1) is exactly an ordinal scale; "the 3rd space
step" is a smaller, more consistent vocabulary than a dozen named paddings. Also
notable: this was an early attempt at *one canonical theme-object shape as a
contract* — the same instinct as our semantic contract, predating DTCG.

**Caveat:** it's a JS-object convention, color-mode support (`colors.modes`) is
ad hoc, and it has no formal type system — DTCG is the better *format*. Take the
scale idea, leave the format.

### 2.2 Chakra / Panda CSS — *semantic tokens with conditions* (the clean dark-mode answer)

Panda CSS (and Chakra v3) split tokens into two layers and — crucially — let a
**semantic token's value be condition-keyed**:

```ts
tokens: {                                   // raw / primitive
  colors: { gray: { 900: { value: '#171717' }, 50: { value: '#fafafa' } } }
},
semanticTokens: {                           // meaning + per-condition value
  colors: {
    fg: { value: { base: '{colors.gray.900}', _dark: '{colors.gray.50}' } },
    bg: { value: { base: '{colors.gray.50}',  _dark: '{colors.gray.900}' } },
  }
}
```

**What to steal:** this is **the single cleanest runtime answer to §9.7's dark
mode question**. The *semantic* token (`fg`) references a *different primitive* per
condition (`base` vs `_dark`); the primitive palette is never duplicated, and
consumers just read `fg`. It's the runtime-object analogue of CSS `light-dark()`
(§1) and of DTCG's resolver modifiers ([DESIGN_TOKENS.md](DESIGN_TOKENS.md) §2.5) —
three independent systems converging on the *same* shape:

> **Dark mode = the semantic layer selects a different primitive per ambient mode
> input. Same role names; values swapped. Never a second vocabulary.**

Conditions also generalize beyond dark (`_hover`, `_highContrast`, …), which lines
up with the Apple insight that *modes are plural*
([PRIOR_ART_NATIVE_PLATFORMS.md](PRIOR_ART_NATIVE_PLATFORMS.md)).

### 2.3 vanilla-extract — a *typed theme contract* decoupled from any theme

vanilla-extract's `createThemeContract` defines the **shape** of a theme — the set
of token paths — *without* any values or CSS, as a typed structure. Concrete themes
(`createTheme(contract, {…})`) must then implement that contract **completely and
correctly**, checked at compile time; multiple themes share the same contract (and
thus the same underlying variables).

**What to steal:** the discipline of a **contract separate from any implementation**
— which is *exactly* what our "semantic contract" is (the DTCG note §5): the fixed
set of token *paths* primitives read, independent of any particular theme's values.
vanilla-extract validates "implement it completely"; **our analogue degrades
instead of erroring** — a theme that omits a role falls back to the host default
(§9.4/§9.6 totality) rather than failing to compile. Same idea (a contract of
paths), different failure mode (graceful, because our themes are untrusted-shaped
ephemeral data, not trusted source).

---

## Synthesis for §9

- **Mechanism (§9.4):** our proposed "theme = a 4th ambient reactive value scope,
  parallel to `args`/`data`/`state`" *is* the runtime-theme-object model, and it
  maps onto the two native substrates directly: **CSS custom properties** on Jaspr,
  **`InheritedWidget`/`ThemeExtension`** on Flutter
  ([PRIOR_ART_NATIVE_PLATFORMS.md](PRIOR_ART_NATIVE_PLATFORMS.md)). Both give the
  cascade + reactivity + fallback semantics for free.
- **Dark mode (§9.7):** strong, cross-system convergence — CSS `light-dark()`,
  Panda condition-tokens, DTCG resolver modifiers all say *same role names, value
  chosen by an ambient mode input*. Recommend the **semantic-token-selects-per-mode**
  model over "a second full token map."
- **The contract (§9.4/§5 of DTCG note):** vanilla-extract confirms the value of
  an explicit *contract of token paths* separate from theme values; our version is
  the same but total (missing ⇒ host fallback, never an error).
- **Scales (§9.3):** styled-system's ordinal scales (`space`, `fontSizes`) are a
  compact way to encode spacing rhythm + type scale — a good shape for our non-color
  tokens.

## Sources

- [MDN — `light-dark()`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/light-dark) · [Baseline status (web-features)](https://web-platform-dx.github.io/web-features-explorer/features/light-dark/) · [Can I use — light-dark()](https://caniuse.com/mdn-css_types_color_light-dark)
- [MDN — Using CSS custom properties](https://developer.mozilla.org/en-US/docs/Web/CSS/CSS_cascading_variables/Using_CSS_custom_properties)
- [System UI Theme Specification](https://github.com/system-ui/theme-specification) · [Theme UI — theme spec](https://theme-ui.com/theme-spec)
- [Panda CSS — semantic tokens](https://panda-css.com/docs/theming/tokens#semantic-tokens) · [Chakra UI — semantic tokens](https://www.chakra-ui.com/docs/theming/semantic-tokens)
- [vanilla-extract — theming](https://vanilla-extract.style/documentation/theming/) · [`createThemeContract`](https://vanilla-extract.style/documentation/api/create-theme-contract/)
