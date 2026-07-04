# Theming prior art — survey & synthesis

> **Status: research note (uncommitted).** You asked me to look beyond the W3C
> DTCG format at other prior art we could **adopt as-is** or **draw inspiration
> from** (especially things people are *in love with*), and not to rush toward
> adopting anything. This is the index + synthesis; the deep-dives are separate
> files. Nothing here is committed, and it doesn't touch the §13 DESIGN.md draft.

## The deep-dives

| File | Covers | One-line takeaway |
|---|---|---|
| [DESIGN_TOKENS.md](DESIGN_TOKENS.md) | **W3C DTCG** (already written) | Adopt the *format*; the tooling is all build-time, we build a runtime parser. |
| [PRIOR_ART_MATERIAL3.md](PRIOR_ART_MATERIAL3.md) | **Material 3** dynamic color + `material_color_utilities` | Adopt the *algorithm* as an optional generator — it's already a shared pure-Dart dep of one adapter. |
| [PRIOR_ART_WEB_TOKEN_SYSTEMS.md](PRIOR_ART_WEB_TOKEN_SYSTEMS.md) | **Radix · Tailwind v4 · shadcn/ui · Open Props** | The small, loved *semantic role set* + "tokens are CSS variables" delivery. Inspiration. |
| [PRIOR_ART_RUNTIME_RESOLUTION.md](PRIOR_ART_RUNTIME_RESOLUTION.md) | **CSS custom properties** + **JS runtime theme objects** (System UI spec, Panda, vanilla-extract) | The *mechanism*: cascade + fallback + dark-mode-as-condition. Adopt the model. |
| [PRIOR_ART_NATIVE_PLATFORMS.md](PRIOR_ART_NATIVE_PLATFORMS.md) | **Flutter** `ThemeExtension` + **Apple HIG/SwiftUI** | The Flutter adapter's native carrier; Apple's semantic/adaptive/accessible vocabulary. |
| [PRIOR_ART_COMPARISON.md](PRIOR_ART_COMPARISON.md) | **Side-by-side comparison tables** | Overview, capability coverage, cost/risk, and recommended role per option. |

## The two lenses

For each system I asked: **(1) adopt as-is, or draw inspiration?** and **(2) which
§13 open question does it inform?** The relevant §13.7 open questions are: *token
vocabulary* (M3 roles vs minimal neutral), *dark mode* (second map vs mode flag),
*how tokens reach primitives* (the cascade mechanism), *how much per-component
surface*, plus *style isolation* and *fonts*.

---

## A. The landscape at a glance

| System | Loved for | Adopt / inspire | Best idea to take | Informs §13 |
|---|---|---|---|---|
| **W3C DTCG** | interop standard | **Adopt (format)** | on-the-wire token format + aliases + resolver modes | 13.3, 13.5, 13.7 |
| **Material 3** | theme-from-a-seed, "Material You" | **Adopt (algorithm, optional)** | seed → accessible light+dark roles, pure-Dart | 13.7 vocab + dark + a11y, 13.6 |
| **shadcn/ui** | the default look of modern web apps | Inspire | small neutral role set + surface/foreground pairing | 13.4, 13.7 vocab |
| **Radix Colors** | principled, accessible color | Inspire | 12-step scale where *position encodes role* | 13.7 vocab + dark |
| **Tailwind v4** | ergonomics, ubiquity | Inspire | tokens **are** runtime CSS variables; flat namespaces | 13.4, 13.6 |
| **CSS custom props / `light-dark()`** | the platform itself | **Adopt (model)** | cascade + `var(,fallback)` + inline dark value | 13.4, 13.5, 13.7 dark |
| **Panda / Chakra semantic tokens** | clean DX | Inspire | semantic token value keyed by *condition* (`_dark`) | 13.7 dark |
| **System UI theme spec** | simple, portable | Inspire | ordinal **scales** for space + type | 13.3 |
| **vanilla-extract** | type safety | Inspire | a *contract* of token paths, separate from values | 13.4 (our semantic contract) |
| **Flutter `ThemeExtension`** | native fit | **Adopt (adapter carrier)** | typed token bag on the ambient theme + `lerp` | 13.4, 13.6 |
| **Apple HIG / SwiftUI** | invisible, trustworthy | Inspire | intent-named adaptive roles; *modes are plural* | 13.7 vocab + dark + a11y |
| **Open Props** | free, neutral, framework-agnostic | Reference | a ready-made neutral default token set | 13.5 base layer |

*(Deliberately not deep-dived, and why: **Style Dictionary / Terrazzo** — covered
in the DTCG note as build-time compilers; **Salesforce Theo / Lightning** — the
historical origin of the "design token" term, now subsumed by DTCG; **Carbon /
Primer / Adobe Spectrum** — enterprise systems whose contribution is the three-tier
taxonomy in §B.1; **Chakra/DaisyUI theme presets** — covered via the runtime-object
family.)*

---

## B. What (almost) everyone converged on — the strongest signal

The most useful research output isn't any single system; it's the handful of
choices that *independent* ecosystems all made. These are the safe bets.

### B.1 Three tiers, not two: global → semantic/alias → component

§13.3 frames tokens as a *two-layer* split (primitive → semantic). Every mature
enterprise system (Carbon, Adobe Spectrum, Primer, M3, Salesforce) actually uses
**three** tiers:

1. **Global / primitive** — raw values (`blue.500`, `space.4`). No meaning.
2. **Semantic / alias** — roles that reference primitives (`color.action →
   blue.500`). *This is the re-skin layer: remap here, names stay, output changes.*
3. **Component** — component-scoped tokens (`button.background → color.action`).

For us, **tier 3 is our catalog templates** (§13.3 item 2): a branded `Button`
template references the semantic role, exactly as a component token does. So the
correction to §13.3 is small but real — we already *have* all three tiers; naming
them as such clarifies that "component tokens" = "branded catalog templates," and
that the semantic (alias) tier is the load-bearing one to get right.

### B.2 Semantic-role indirection is the whole game

DTCG aliases, Radix's fixed step-roles, shadcn's `--primary`, M3's `onSurface`,
Apple's `label`, Panda's `semanticTokens` — all the same move: **primitives carry
values, a thin semantic layer carries *meaning*, and re-skinning/dark-mode/branding
all happen by remapping the semantic layer.** §13.3's instinct to "keep the
indirection" is unanimously validated. Get the *semantic vocabulary* right and
everything else is plumbing.

### B.3 Dark mode = same role names, values selected by an ambient input

Four independent mechanisms say the identical thing:

- **CSS** `light-dark(a, b)` — the token carries both, `color-scheme` selects.
- **Panda/Chakra** `semanticTokens: { fg: { base: …, _dark: … } }` — condition-keyed.
- **DTCG** Resolver Module — modifier *contexts* selected by `inputs: {theme:'dark'}`.
- **M3** — `isDark` flips *tone selection* on one tonal palette.

None of them is "author a second, parallel token vocabulary." So §13.7's dark-mode
question has a clear answer: **the semantic layer selects a different value per mode
input; role names never change.** And Apple + M3 add: make the mode input *n-ary*
(light/dark/high-contrast/…), not a boolean, even if v1 only ships light/dark.

### B.4 Runtime resolution = a cascade of variable scopes with fallback

Our "theme as a 4th ambient reactive scope" (§13.4) is the same idea as CSS custom
properties and Flutter's `InheritedWidget` — nearest scope wins, inherits down,
`var(--x, fallback)` degrades to the host default. Both adapters *already have this
substrate natively* ([PRIOR_ART_RUNTIME_RESOLUTION.md](PRIOR_ART_RUNTIME_RESOLUTION.md),
[PRIOR_ART_NATIVE_PLATFORMS.md](PRIOR_ART_NATIVE_PLATFORMS.md)), so §13.5's cascade
isn't something we build from scratch — it's something we *map onto* two existing
cascades. Totality (§13.6) is `var()`'s fallback, for free.

### B.5 Keep the vocabulary small; push bespoke into the component layer

Every *loved* system is deliberately small (shadcn ~20 roles; Radix 12 steps;
Apple a compact hierarchy) and shoves one-off styling into components. This
directly validates §13.7's "don't reimplement CSS in JSON" worry and §13.3's
catalog-template escape hatch as the pressure valve. **The token set should be
small and semantic; bespoke goes in templates.**

### B.6 Generation-from-seed is the frontier, and it's pure-Dart for us

M3 shrinks the *authored* surface to nearly nothing: one seed color → a full,
accessible, light+dark role set. Because `material_color_utilities` is pure Dart, we
can run the *same* generator on both adapters for identical output — a genuinely
differentiated capability ("brand from one color, or from a photo") that most token
systems can't offer at runtime.

---

## C. Adopt-as-is candidates (ranked)

1. **DTCG format** — the on-the-wire token format (already the recommendation).
2. **CSS custom-property resolution model** — not a choice on Jaspr; it's the
   native substrate. Mirror its cascade/fallback/`light-dark()` semantics.
3. **Flutter `ThemeExtension`** — not a choice on Flutter; the native carrier for
   our resolved token bag (typed reads + animated transitions via `lerp`).
4. **Material 3 color *algorithm*** (`material_color_utilities`) — an *optional*
   seed→scheme generator; already a shared pure-Dart dependency, near-zero risk.
   Adopt as one path to a token set, never the only path.

## D. Inspiration candidates + the one idea to steal from each

- **shadcn/ui** → a small *neutral* semantic role set with **surface/foreground
  pairing** (the "on-color" convention, contrast baked in). The closest existing
  thing to our semantic contract.
- **Radix Colors** → a **step scale where position encodes role** (bg → border →
  solid → text), giving automatic dark mode by construction.
- **Apple HIG** → **intent-named adaptive roles + a compact emphasis hierarchy**
  (primary/secondary/tertiary), and **"modes are plural"** (a11y is a mode axis).
- **Panda/Chakra** → **condition-keyed semantic tokens** — the cleanest runtime
  encoding of dark mode.
- **vanilla-extract** → a **contract of token paths** decoupled from any theme (our
  semantic contract, but *total* — missing ⇒ host fallback, not a compile error).
- **Tailwind v4** → **tokens as runtime CSS variables** + flat namespaces
  (`--color-*`, `--space-*`, `--radius-*`) that map 1:1 onto DTCG dot-paths.
- **System UI theme spec** → **ordinal scales** for spacing rhythm + type scale.
- **Open Props** → a ready-made **neutral default token set** to seed the base
  layer of the §13.5 cascade.

---

## E. How the prior art answers §13's open questions

| §13.7 open question | What the prior art says |
|---|---|
| **Token vocabulary** — M3 roles or minimal neutral? | Offer **both**: a *small neutral* semantic set (shadcn-shaped, surface/foreground pairing) that is **M3-name-compatible where obvious**, so a hand-authored neutral theme *and* an M3/DTCG export both map on. Small + semantic beats large + appearance-named (unanimous). |
| **Dark mode** — second map or mode flag? | **Neither a second vocabulary nor a bare flag:** the semantic layer **selects a different value per mode input** (CSS `light-dark()` / Panda conditions / DTCG modifiers / M3 `isDark`). Make the mode input **n-ary** (light/dark/contrast). |
| **How tokens reach primitives** | A **cascade of ambient variable scopes with fallback** — map onto CSS custom properties (Jaspr) and `InheritedWidget`/`ThemeExtension` (Flutter). The §13.4 "4th reactive scope" is exactly this. |
| **How much per-component surface** | **Keep it small**; push bespoke into the component tier = branded catalog templates (§13.3 item 2). Every loved system does this. |
| **Style isolation (web)** | Prior art here is CSS scoping/shadow DOM (still the §13.7 hard problem — none of these token systems solves cross-tree leakage; that's a delivery concern, tracked separately). |
| **Fonts** | Named family roles + Apple's *named type scale* (Dynamic Type) support §13.7's "reference by name, host-resolved" v1; ephemeral font files remain future work. |

---

## F. A synthesized shape (not a decision — a strawman to react to)

Pulling the convergent bets together, a defensible v1 would be:

1. **Format:** a **DTCG `.tokens.json`** as the authored artifact (interop), read by
   a small **runtime Dart parser** in `a2ui_craft` (framework-neutral, total).
2. **Semantic contract:** a **small neutral role set** — surface/foreground pairs +
   `action`/`accent`/`muted`/`destructive`/`border`/`ring`, a **named type scale**
   (body/title/…), a spacing **scale**, a radius scale — M3-name-compatible where
   it costs nothing. This is the one thing we author; keep it tiny.
3. **Dark mode:** **condition-selected semantic values** (one mode input, n-ary),
   resolved at load; hosts supply the active mode (§13.2 trust model — never the
   agent).
4. **Optional generator:** authors may ship a **seed color + style** instead of a
   full token map; `material_color_utilities` expands it to the role set (same
   pure-Dart code on both adapters → identical output).
5. **Delivery / cascade:** resolved tokens → CSS custom properties (Jaspr) /
   `ThemeExtension` (Flutter); host defaults → author tokens → host mode config →
   per-widget props, each layer overriding via the native cascade with `var()`-style
   fallback (totality).
6. **Determinism:** a "theming conformance" case pins a token (and a seed→role
   generation) to the same landed value on both adapters — same discipline as the
   function library.

This keeps §13's architecture intact and slots each piece of prior art where it's
strongest: **DTCG for the format, M3 for optional generation, shadcn/Radix/Apple
for the vocabulary, CSS/Flutter for the runtime cascade, Panda/CSS for dark mode,
vanilla-extract for the contract discipline.** Nothing here needs to be adopted
now — it's the menu, with the trade-offs marked.

## Sources

Consolidated in each deep-dive. Primary anchors:
[DTCG Format Module](https://www.designtokens.org/tr/drafts/format/) ·
[`material_color_utilities`](https://pub.dev/documentation/material_color_utilities/latest/) ·
[shadcn/ui theming](https://ui.shadcn.com/docs/theming) ·
[Radix Colors scale](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale) ·
[Tailwind v4](https://tailwindcss.com/blog/tailwindcss-v4) ·
[MDN `light-dark()`](https://developer.mozilla.org/en-US/docs/Web/CSS/color_value/light-dark) ·
[Panda semantic tokens](https://panda-css.com/docs/theming/tokens#semantic-tokens) ·
[vanilla-extract theming](https://vanilla-extract.style/documentation/theming/) ·
[Flutter `ThemeExtension`](https://api.flutter.dev/flutter/material/ThemeExtension-class.html) ·
[Apple HIG Color](https://developer.apple.com/design/human-interface-guidelines/color) ·
[System UI theme spec](https://github.com/system-ui/theme-specification) ·
[Open Props](https://open-props.style/)
