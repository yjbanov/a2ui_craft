# Semantic contract v1 (the roles our primitives read)

> **Status: accepted 2026-07-07 (all four §7 recommendations); implemented in
> slice 3** — `ThemeRoles` in `a2ui_craft`, the `CraftTheme` snapshot carrier,
> the per-primitive wiring on both adapters, and the theming-conformance
> dimension. The prior-art survey settled the *strategy* (small neutral role
> set, surface/foreground pairing, M3-name-compatible where free —
> [PRIOR_ART.md](PRIOR_ART.md) §E). This document adds the piece strategy
> can't give: a **crosswalk against our actual primitive inventory** — what
> each primitive hardcodes or inherits today, and therefore which token paths
> the contract must name.

## 1. What the inventory says (facts, not choices)

Reading `core_components.dart` on both adapters (they mirror each other):

| Primitive | Styling surface today | Theme-relevant? |
|---|---|---|
| `Text` | `variant` body/caption; **caption hardcodes** `fontSize 12, color #5F6368`; body inherits host | ✅ caption color+size; body color |
| `Heading` | **hardcoded ramp** `[24,22,20,18,16,14]` + bold | ✅ the type scale |
| `Markdown` | shares the heading ramp; **link hardcodes** `#1A73E8` + underline; `code` → monospace | ✅ ramp + link color |
| `Box` | `color`/`padding`/`margin`/size props — **explicit only**, no defaults | ❌ deliberately neutral (explicit-prop tier) |
| `Button` | **a bare `GestureDetector` — zero visuals**; the child is the look | ❌ *reads no roles* (see §2) |
| `Card` | Material `Card` (host surface/elevation/radius) + **hardcoded 16px inset** | ✅ surface color, radius |
| `Divider` | Material `Divider` (host color) | ✅ separator color |
| `Icon` | inherits host `IconTheme` | ✅ foreground color |
| `TextField` | host-styled input | ✅ border/outline (v1: color only) |
| `Checkbox` / `Slider` / `Radio` | Material accent (host primary) | ✅ the accent role |
| `Row`/`Column`/`Flex`, `Align`, `Wrap`, `SizedBox`, `Opacity`, `ScrollView`, `List`, `Image` | pure layout/media | ❌ |

Two structural facts fall out:

1. **The consumed surface is small** — ~7 color roles and a type ramp cover
   every hardcoded or host-inherited visual decision in the catalog. The
   "keep the vocabulary small" bet is not just aesthetic; it's literally what
   the inventory needs.
2. **Every hardcoded literal above is a bug from theming's perspective** —
   `#5F6368`, `#1A73E8`, the `[24..14]` ramp, the 16px inset are decisions the
   author's theme should own. The contract names them; the default theme (slice
   4) restates today's exact values so unthemed rendering is unchanged.

## 2. `Button` proves the three-tier model (and reads nothing)

Prior art assumes "button reads the primary role." Our `Button` primitive has
**no background, text, or border of its own** — branding a button is already a
*catalog template* over `Box` + `Text` (see the calculator sample's `Key`).
That is exactly tier 3 of the taxonomy ([PRIOR_ART.md](PRIOR_ART.md) §B.1):
component-level styling lives in templates referencing semantic tokens
(`Box(color: theme.color.primary)`), not in the ambient contract. So:

> **v1 contract rule: `Button` consumes no roles.** The roles a branded button
> *template* references (`color.primary`, `color.onPrimary`) are still in the
> contract — supplied for tier 3, not wired into tier 2.

This keeps the ambient tier honest: it only carries roles a primitive actually
reads when a prop is unset.

## 3. Naming: take the M3 ∩ shadcn intersection

§13.4's draft used `color.action`. Recommend replacing it with **`primary`** —
the one name Material 3 *and* shadcn/ui agree on, so both an M3 DTCG export and
a shadcn-shaped hand theme map on with zero translation. The full v1 set keeps
M3's names wherever M3 has one (`onSurface`, `onSurfaceVariant`, `outline`)
because that's the naming a Flutter-adjacent audience already knows, and it
costs nothing against shadcn (whose `muted-foreground`/`border` are synonyms,
not conflicts).

| Ours (proposed) | Material 3 | shadcn/ui | Apple |
|---|---|---|---|
| `color.primary` | `primary` | `--primary` | tint |
| `color.onPrimary` | `onPrimary` | `--primary-foreground` | — |
| `color.surface` | `surface` | `--card` / `--background` | `systemBackground` |
| `color.onSurface` | `onSurface` | `--foreground` | `label` |
| `color.onSurfaceVariant` | `onSurfaceVariant` | `--muted-foreground` | `secondaryLabel` |
| `color.outline` | `outline` | `--border` / `--input` | `separator` |
| `color.link` | — (M3 has none) | — | `link` |

`color.link` is the one role with no M3 analogue (HTML/Apple have it, and
`Markdown` needs it). In the **default theme** it's just an alias
`{color.primary}` — the contract names the role; the alias keeps it one
decision for authors who don't care.

## 4. The proposed contract v1

**Consumed in v1** (each row = a token path + which primitive reads it +
today's value, which the default theme will restate):

| Token path | Type | Read by (when unset) | Today's value / fallback |
|---|---|---|---|
| `color.surface` | color | `Card` background | Material/host card color |
| `color.onSurface` | color | `Text` (body), `Heading`, `Markdown` body, `Icon` | host text/icon color |
| `color.onSurfaceVariant` | color | `Text` (caption) | `#5F6368` |
| `color.primary` | color | `Checkbox`, `Slider`, `Radio` accent | host accent (Material blue) |
| `color.outline` | color | `Divider`, `TextField` border | host divider/border |
| `color.link` | color | `Markdown` links | `#1A73E8` |
| `type.heading.1.size` … `type.heading.6.size` | dimension | `Heading`, `Markdown` headings | `24, 22, 20, 18, 16, 14` |
| `type.body.size` | dimension | `Text` (body), `Markdown` body | host default |
| `type.caption.size` | dimension | `Text` (caption) | `12` |

**Named now, consumed later** (in the contract so tier-3 templates and themes
can target them without a future rename; no primitive reads them yet):

- `color.onPrimary` — for branded button/badge templates (tier 3).
- `color.error`, `color.onError` — validation states (TextField, future).

**Deliberately absent from v1** (flagged, not forgotten):

- **Radius / spacing** (`shape.radius.*`, `space.*`): only `Card` would consume
  them today (its radius + 16px inset). One consumer doesn't justify a scale
  shape yet — and choosing the *scale structure* (Radix-style steps vs named
  sm/md/lg) is better made with more consumers. Card keeps its current values;
  revisit when a second consumer appears.
- **Font family / weight / full `typography` composites**: the DTCG composite
  type is deferred (DESIGN_TOKENS.md §2.4 — phase 3), and family loading is a
  §13.7 hard problem. Sizes-only is the honest v1.
- **`color.background`** (page behind surfaces): an A2UI surface renders into
  host chrome; the host owns the page. Skip until the mini-app/project mode
  (slice 5) makes a surface own its page.

**Fallback semantics (unchanged from §13.4):** explicit prop → ambient role →
host default. A theme omitting a role degrades to exactly today's rendering;
an *unthemed* surface must render **identically to today** — that's a
regression guard slice 3 should test explicitly, not a hope.

## 5. Where the contract lives

A constant in `a2ui_craft` next to the primitive spec (§11) — proposed shape:
a documented list of `(path, type, consumers)` entries (usable by tooling and
the conformance suite to iterate roles), plus doc-table in DESIGN.md §13.4.
The default theme file (slice 4) is its executable documentation; contract
changes are versioned like primitive-vocabulary changes (additive preferred).

## 6. Implementation notes for slice 3 — including one design wrinkle

**Where reads happen.** Primitives are `LocalWidgetBuilder`s with a
`BuildContext` — so ambient reads are a public `CraftTheme.of(context)`-style
lookup (the slice-2 `_ThemeScope` made public, or a thin accessor over it) with
typed, total getters and the host fallback inline:
`theme?.color('color.onSurface') ?? hostDefault`.

**The wrinkle: reactivity of ambient reads.** Slice 2's `theme.` references are
reactive through the *subscription* machinery (`DynamicContent`). Ambient reads
via an inherited scope are reactive through *scope-instance change* instead —
`updateAll` on the same content would **not** rebuild a primitive that read the
theme through `of(context)`. Rather than run two reactivity regimes, propose
unifying on the inherited-scope model:

- The host-facing carrier becomes an **immutable resolved-theme snapshot**
  (`ResolvedTokens`), not a mutable `DynamicContent`: re-theming = handing the
  scope a new snapshot (cheap — resolution is a map build), which notifies both
  regimes: dependents rebuild, and the runtime rebuilds the internal
  `DynamicContent` it derives for `theme.` references.
- Slice 2's public API (`RemoteWidget(theme: DynamicContent?)`) would refine to
  `theme: ResolvedTokens?` (or a tiny `CraftTheme` value object wrapping it +
  the active mode). The slice-2 conformance cases keep passing with the swap
  expressed as "provide a new snapshot" instead of `updateAll` — the observable
  behavior (live re-theme, alias re-pointing) is identical.

This is the only piece of slice 2 the contract work would revise, it's
API-shape only, and better now than after the default theme ships against it.

**Conformance dimension.** Slice 3 starts the painted-probe dimension the
text-based trick can't cover: assert a themed role *lands* on the primitive —
Flutter: read the effective color off the widget (e.g. `Text.style.color`,
`ColoredBox.color`); Jaspr: the rendered style attribute/computed value. Same
geometry-harness philosophy (§13.6): assert the *decision* landed on both
adapters, never pixel equality. Plus the regression guard: unthemed output
byte-identical to pre-theming rendering.

## 7. The decision actually being asked

1. **Role names:** the M3 ∩ shadcn intersection above (drops §13.4's `action`
   for `primary`). *(Recommended as written.)*
2. **v1 scope:** the consumed table in §4 — 6 color roles + the size-only type
   scale; radius/spacing/fonts deferred with reasons. *(Recommended as
   written.)*
3. **`Button` reads nothing** — branding stays in tier-3 templates.
   *(Recommended; it's what the code already says.)*
4. **The reactivity unification** (§6) — immutable snapshot as the host-facing
   theme carrier, refining slice 2's API. *(Recommended; the alternative is
   maintaining two reactivity regimes forever.)*

If these four hold, slice 3 is mechanical: publish the contract constant,
wire the §4 table into both adapters' primitives with fallbacks, make the
carrier swap, add the painted-color conformance cases + the unthemed
regression guard.
