# Prior art — the web token systems developers love (Radix · Tailwind v4 · shadcn/ui · Open Props)

> **Status: research note (uncommitted).** Part of the theming prior-art survey;
> see [PRIOR_ART.md](PRIOR_ART.md) for the index and verdicts. These four are the
> systems web developers are *actually in love with* right now. None is an
> adopt-as-is *format* (that's DTCG — see [DESIGN_TOKENS.md](DESIGN_TOKENS.md)),
> but each contributes a proven idea for our **semantic contract** (§9.4/§9.7)
> and delivery model. There is a clean through-line: **Radix** gives the color
> science, **Tailwind v4** gives the delivery (tokens *are* CSS variables), and
> **shadcn/ui** gives the small semantic role set everyone now copies.

---

## 1. Radix Colors — the principled 12-step scale

Radix Colors is a palette *dataset* where **every hue has exactly 12 steps, and
each step number encodes a fixed UI role** — the same across every hue and in both
light and dark:

| Step | Role |
|---|---|
| 1 | App background |
| 2 | Subtle background |
| 3 | UI element background |
| 4 | Hovered UI element background |
| 5 | Active / selected UI element background |
| 6 | Subtle borders & separators (non-interactive) |
| 7 | UI element border, focus ring |
| 8 | Hovered UI element border |
| 9 | Solid background (highest chroma — the "brand" fill) |
| 10 | Hovered solid background |
| 11 | Low-contrast text |
| 12 | High-contrast text |

Because **step number = role**, you theme by *swapping the hue*, not by rewiring
which color goes where — `blue.9` and `red.9` are both "the solid fill." Radix
ships **paired light/dark** scales (same step semantics), **alpha** variants (for
overlays on any background), and **P3** wide-gamut variants.

**What to steal:** the idea that *position in a small scale encodes meaning*. A
12-step ramp per semantic hue is a tiny, learnable vocabulary that gives you
backgrounds, borders, solids, and text — *and automatic dark mode by construction*
(the dark scale is engineered to the same step roles). This is a much smaller,
more principled surface than "define 40 named colors."

**Fit / caveat:** Radix is a *palette* + a JS/CSS distribution, not a runtime
token format — so it's **inspiration, not adopt**. But its step-role table is an
excellent candidate structure for *how our color tokens are organized* under a
neutral semantic contract, and it composes beautifully with DTCG (each step is
just a primitive token; our semantic roles alias into steps).

---

## 2. Tailwind CSS v4 — tokens *are* CSS variables (`@theme`)

Tailwind v4's headline change is **CSS-first configuration**: you define design
tokens directly in CSS with the `@theme` directive instead of a JS config file.

```css
@theme {
  --color-primary: oklch(0.55 0.2 255);
  --spacing:       0.25rem;      /* base unit; utilities derive multiples */
  --radius-lg:     0.5rem;
  --font-sans:     "Inter", sans-serif;
}
```

Two things happen from that one declaration: (a) Tailwind generates utility
classes (`bg-primary`, `rounded-lg`, …), **and** (b) the token is emitted as a
**native CSS custom property** available at runtime via `var(--color-primary)`.
Tokens live in **namespaces** (`--color-*`, `--spacing`, `--radius-*`, `--font-*`,
`--text-*` (font-size), `--shadow-*`, `--breakpoint-*`, `--ease-*`, …), and the
namespace determines which utilities/variants exist.

**What to steal:**

- **Tokens as runtime variables by default.** Tailwind v4 makes the token layer
  *live CSS variables*, not a build-only artifact. That is exactly our
  "theme = a reactive ambient scope" (§9.4) on the Jaspr adapter — flip a variable
  at `:root` and everything re-themes. It's a strong vote for our web adapter
  mapping resolved tokens → CSS custom properties (see
  [PRIOR_ART_RUNTIME_RESOLUTION.md](PRIOR_ART_RUNTIME_RESOLUTION.md)).
- **Flat, namespaced token paths.** `--color-*`, `--spacing`, `--radius-*` is a
  clean, flat naming scheme that maps 1:1 onto DTCG dot-paths (`color.*`,
  `spacing`, `radius.*`) and onto our `theme.<path>` references (§9.4).
- **"A few scales, not a thousand colors."** Tailwind's whole ergonomic is a small
  set of constrained scales — the same discipline §9.7 wants ("keep the token set
  small").

**Fit / caveat:** Tailwind is a *build-time utility generator*; we don't want the
utilities. But its **token-as-CSS-variable delivery model** is directly the web
adapter's mechanism, and it's *the* framework the audience knows. Inspiration.

---

## 3. shadcn/ui — the small semantic role set everyone copies

shadcn/ui is not a dependency; it's copy-paste components on top of Radix +
Tailwind. Its lasting contribution is a **tiny, opinionated, un-branded set of
semantic CSS variables** that a huge number of apps now use verbatim:

```
--background        --foreground
--card              --card-foreground
--popover           --popover-foreground
--primary           --primary-foreground
--secondary         --secondary-foreground
--muted             --muted-foreground
--accent            --accent-foreground
--destructive       (--destructive-foreground)
--border   --input   --ring
--chart-1 … --chart-5
--sidebar  --sidebar-foreground  --sidebar-primary  …  --sidebar-ring
--radius
```

Two conventions make this *the* reference for a semantic contract:

- **Surface/foreground pairing.** Almost every surface token has a matching
  `*-foreground` — the color of text/icons *on* that surface. This bakes
  contrast-correctness into the vocabulary: use `bg-card` and you already know
  `text-card-foreground` is legible on it. It's a compact way to encode "on-color"
  relationships (the same idea as M3's `onPrimary`/`onSurface`, but flatter).
- **Dark mode = same names, new values.** A `.dark { … }` block re-declares the
  *identical* variable names with new `oklch` values. There is **no second
  vocabulary** — components never branch on mode; they read `--primary` and the
  active scope decides its value. (See the convergence note in
  [PRIOR_ART_RUNTIME_RESOLUTION.md](PRIOR_ART_RUNTIME_RESOLUTION.md): CSS
  `light-dark()`, Panda condition-tokens, and DTCG resolver modifiers all say the
  same thing.)

**What to steal:** this is arguably **the best-loved small *neutral* role set** in
the industry — the closest existing thing to the "semantic contract" the DTCG note
(§5) says is the one piece we must author. Concretely:

- Adopt the **foreground-pairing convention** for our surface roles.
- Adopt the **flat, un-Material role names** as a candidate *neutral* vocabulary
  (an alternative/complement to leaning on M3 names) — `background/foreground`,
  `primary`, `muted`, `accent`, `destructive`, `border`, `ring`.
- Adopt the **same-names-across-modes** dark-mode model (§9.7 answer).

**Fit / caveat:** it's a convention expressed as CSS, not a portable format —
**inspiration**, and it maps trivially onto DTCG (each variable = one semantic
token aliasing a primitive). Note shadcn is deliberately *un-branded/neutral* where
M3 is *branded/generated*: the two are the two ends of §9.7's "M3 vocabulary vs
minimal neutral" question, and we can offer both.

---

## 4. Open Props — a ready-made neutral token set as plain variables

[Open Props](https://open-props.style/) is an open-source collection of
**framework-agnostic design tokens delivered as CSS custom properties** — colors
(`--gray-0..12`, hue ramps), sizes/spacing (`--size-*`), font sizes, radii
(`--radius-*`), shadows, easings, gradients, animations. Incrementally adoptable
(take all, or a subset, or import as JS), with adaptive light/dark built in.

**What to steal:** Open Props is *proof that a neutral, un-opinionated default
token set, shipped as plain variables, is genuinely useful across frameworks* — no
Material aesthetic, no utility framework, just good primitive tokens. It's a strong
**reference/seed for our own default token set** (the base layer of the §9.5
cascade the host supplies), and a sanity check on scale granularity (how many
sizes/radii/shadows are "enough").

**Fit / caveat:** reference material, not something to adopt wholesale — but if we
want a batteries-included neutral default theme, Open Props is the shape to copy
and its values are a reasonable starting point.

---

## How this cluster informs §9

- **Semantic contract (§9.4/§9.7):** shadcn's role set + Radix's step semantics
  are the two best small-vocabulary references; both are *neutral* alternatives to
  M3's *branded* roles ([PRIOR_ART_MATERIAL3.md](PRIOR_ART_MATERIAL3.md)). Likely
  answer: a small neutral role set (shadcn-shaped, with surface/foreground pairing)
  that is *also* M3-name-compatible where obvious, so both a hand-authored neutral
  theme and an M3 export map on.
- **Dark mode (§9.7):** all four say **same names, values selected by an ambient
  input** — not a second token vocabulary. Strong, consistent signal.
- **Delivery on the web adapter (§9.6):** tokens → CSS custom properties at
  `:root` is the native, loved, runtime-reactive mechanism (Tailwind v4, shadcn,
  Open Props all do exactly this).
- **Keep it small (§9.7):** every loved system here is *deliberately small* and
  pushes bespoke styling into components — validating the catalog-template escape
  hatch (§9.3 item 2) as the pressure valve.

## Sources

- [Radix Colors — understanding the 12-step scale](https://www.radix-ui.com/colors/docs/palette-composition/understanding-the-scale) · [Radix Colors](https://www.radix-ui.com/colors)
- [shadcn/ui — Theming (CSS variables)](https://ui.shadcn.com/docs/theming)
- [Tailwind CSS v4.0 announcement](https://tailwindcss.com/blog/tailwindcss-v4) · [Theme variables docs](https://tailwindcss.com/docs/theme)
- [Open Props](https://open-props.style/) · [argyleink/open-props](https://github.com/argyleink/open-props) · [Open Props — CSS-Tricks](https://css-tricks.com/open-props-and-custom-properties-as-a-system/)
