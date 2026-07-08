# Theming options — comparison tables

> **Status: research note (uncommitted).** A side-by-side comparison of the
> theming/design-token options surveyed in [PRIOR_ART.md](PRIOR_ART.md) and its
> deep-dives. Everything here is condensed from those files; follow the links for
> the reasoning. Nothing is committed; the §13 `DESIGN.md` draft is untouched.

**Legend:** ✅ strong / native · 🟡 partial / indirect · ❌ absent — · n/a not
applicable. "Ephemeral-safe" = it's *pure data* (no code execution) that can load
over the untrusted transport per the §13.2 trust model. "Pure-Dart" = a runtime
Dart implementation exists we could share across both adapters for identical output.

---

## Table A — options at a glance

| Option | Category | Adopt / inspire | Runtime or build-time | Portable / framework-neutral | Pure-Dart | Ephemeral-safe (pure data) | Users love it | Best single idea |
|---|---|---|---|---|---|---|---|---|
| **W3C DTCG** | Token *format* | **Adopt (format)** | build-time tooling; format is runtime-parseable | ✅ | ❌ (we write the parser) | ✅ | 🟡 (design-eng / tooling) | standard on-the-wire tokens + aliases + resolver modes |
| **Material 3** (`material_color_utilities`) | Color *algorithm* + roles | **Adopt (optional generator)** | ✅ runtime | ✅ (Dart + ports) | ✅ | 🟡 (input=seed is data; algo is host code) | ✅✅ ("Material You") | seed → accessible light+dark role set |
| **shadcn/ui** | Semantic role *set* | Inspire | ✅ runtime (CSS vars) | ❌ (web convention) | ❌ | 🟡 (CSS) | ✅✅ | small neutral roles + surface/foreground pairing |
| **Radix Colors** | Color *scale* | Inspire | ✅ runtime (CSS/JS) | 🟡 (palette data + web dist) | ❌ | ✅ (palette is data) | ✅ | 12-step scale where *position encodes role*; auto dark |
| **Tailwind v4** | Token *delivery* + utilities | Inspire | tokens runtime (CSS vars); utilities build-time | ❌ (web) | ❌ | 🟡 (CSS) | ✅✅ | tokens **are** runtime CSS variables; flat namespaces |
| **CSS custom props / `light-dark()`** | Platform *mechanism* | **Adopt (model)** | ✅ native runtime | ❌ (web platform) | n/a (native on Jaspr) | ✅ | platform | cascade + `var(,fallback)` + inline dark value |
| **Panda / Chakra** semantic tokens | Runtime object + *conditions* | Inspire | ✅ runtime | ❌ (JS) | ❌ | 🟡 (config) | ✅ | semantic value keyed by *condition* (`_dark`) |
| **System UI theme spec** | Runtime object *shape* | Inspire | ✅ runtime | 🟡 (JS convention) | ❌ | ✅ (plain object) | 🟡 (foundational) | ordinal **scales** for space + type |
| **vanilla-extract** | Typed *contract* | Inspire | build-time (zero-runtime) | ❌ (TS) | ❌ | n/a | 🟡 | a *contract of token paths* decoupled from values |
| **Flutter `ThemeExtension`** | Platform *mechanism* (native carrier) | **Adopt (adapter carrier)** | ✅ native runtime | ❌ (Flutter) | ✅ | n/a (host code) | 🟡 | typed token bag on the ambient theme + `lerp` |
| **Apple HIG / SwiftUI** | Semantic *vocabulary* | Inspire | native runtime | ❌ (Apple) | ❌ | n/a (guidance) | ✅✅ (invisibly trusted) | intent-named adaptive roles; *modes are plural* |
| **Open Props** | Ready-made token *set* | Reference | ✅ runtime (CSS vars) | ✅ | ❌ | ✅ (data) | 🟡 | neutral default token set as plain variables |

---

## Table B — capability coverage (which piece *we need* does it provide?)

The columns are the pieces our theming layer needs. No option covers all of them —
which is the point: **we compose the stack from the best-of-each.**

| Option | Wire **format** | Semantic **vocabulary** | **Dark-mode** model | Runtime **cascade / mechanism** | **Generation** from seed | Type / spacing **scales** | Cross-adapter **determinism** aid |
|---|---|---|---|---|---|---|---|
| **W3C DTCG** | ✅ | ❌ *(structure, not meaning)* | 🟡 *(resolver, unstable)* | ❌ *(tools are build-time)* | ❌ | 🟡 *(types, no scale opinion)* | 🟡 *(data → our parser)* |
| **Material 3** | ❌ | ✅ *(M3 roles)* | ✅ *(`isDark`)* | ❌ | ✅✅ | 🟡 *(type/shape names; pkg is color-only)* | ✅ *(shared pure-Dart)* |
| **shadcn/ui** | ❌ | ✅✅ *(best small neutral)* | ✅ *(same names, `.dark`)* | 🟡 *(CSS vars)* | ❌ | 🟡 *(radius)* | ❌ |
| **Radix Colors** | ❌ | ✅ *(step-roles)* | ✅ *(paired scales)* | ❌ | ❌ | ✅ *(12-step ramp)* | ❌ |
| **Tailwind v4** | 🟡 *(`@theme` CSS)* | ❌ *(you define)* | 🟡 *(variants)* | ✅ *(CSS vars)* | ❌ | ✅ *(namespaced scales)* | ❌ |
| **CSS props / `light-dark()`** | ❌ | ❌ | ✅ *(inline light-dark)* | ✅✅ *(the cascade)* | ❌ | ❌ | n/a |
| **Panda / Chakra** | 🟡 *(config)* | 🟡 *(you define)* | ✅✅ *(conditions)* | ✅ *(runtime object)* | ❌ | ✅ | ❌ |
| **System UI spec** | 🟡 *(object shape)* | 🟡 | 🟡 *(`colors.modes`)* | ✅ *(runtime object)* | ❌ | ✅✅ | ❌ |
| **vanilla-extract** | ❌ | 🟡 *(contract shape)* | ✅ *(theme swap)* | ✅ | ❌ | 🟡 | ❌ *(but: contract discipline)* |
| **Flutter `ThemeExtension`** | ❌ | 🟡 *(you define)* | ✅ *(theme swap)* | ✅✅ *(native carrier)* | ❌ | 🟡 | ✅ *(Dart)* |
| **Apple HIG** | ❌ | ✅✅ *(gold standard)* | ✅ *(adaptive)* | ✅ *(native)* | ❌ | ✅ *(Dynamic Type)* | ❌ |
| **Open Props** | ❌ | 🟡 *(some semantic)* | ✅ *(adaptive props)* | ✅ *(CSS vars)* | ❌ | ✅ *(ready-made)* | ❌ |

**Reading the columns:** the only **format** worth adopting is DTCG. The best
**vocabulary** references are Apple / shadcn / M3. **Dark mode** is solved the same
way everywhere (condition-selected — Panda/CSS/DTCG/M3). The **cascade mechanism**
is native on both our adapters (CSS props / `ThemeExtension`). **Generation** is
uniquely M3, and uniquely pure-Dart for us. **Scales** come from System UI /
Tailwind / Radix. **Determinism** favors the pure-Dart options (M3, Flutter).

---

## Table C — cost / risk / main caveat

| Option | Main caveat to weigh |
|---|---|
| **W3C DTCG** | CG report, still shifting (color/dimension just became objects); resolver module is "do not implement." Hedge with a *liberal, total* parser. |
| **Material 3** | Bakes a *Material* aesthetic + ~26 roles; must stay *optional* (allow explicit token maps). Pin HCT float math with a determinism test. |
| **shadcn/ui** | A CSS convention, not a portable format; web-flavored. Take the role names, not the delivery. |
| **Radix Colors** | A palette dataset + web distribution, not a runtime format; adds a per-hue 12-step surface. |
| **Tailwind v4** | Ships *utilities* we don't want; web-only. Take the "tokens = CSS vars" model, drop the framework. |
| **CSS `light-dark()`** | `light-dark()` is Baseline "newly available" (May 2024), "widely available" ~Nov 2026 — fine for the Jaspr adapter; no meaning on Flutter. |
| **Panda / Chakra** | Build-time codegen + JS ecosystem; take the *condition-token* idea only. |
| **System UI spec** | Untyped JS convention, ad-hoc color modes; superseded as a *format* by DTCG. Take the *scale* idea. |
| **vanilla-extract** | Zero-*runtime* (compile-time) + TS; its "implement contract completely" errors — ours must *degrade* to host fallback instead. |
| **Flutter `ThemeExtension`** | Flutter-only (it's the adapter carrier, not a portable design); requires `copyWith` + `lerp` boilerplate per token bag. |
| **Apple HIG** | No portable artifact — pure design guidance; Apple-platform semantics. Inspiration only. |
| **Open Props** | A values *dataset*, not a system; useful as a seed for a neutral default, not a decision. |

---

## Bottom line — recommended role in our stack

| Option | Recommended role for A2UI Craft |
|---|---|
| **W3C DTCG** | **The authored format** — `.tokens.json`, read by a small runtime Dart parser. |
| **Material 3** | **Optional generator** — seed + style → role set (shared pure-Dart, identical on both adapters). |
| **shadcn/ui + Radix + Apple** | **Vocabulary references** — a small neutral, surface/foreground-paired, M3-name-compatible role set + named type scale. |
| **CSS custom props + Flutter `ThemeExtension`** | **The runtime cascade** — the two native carriers resolved tokens map onto. |
| **Panda / CSS `light-dark()` / DTCG resolver** | **Dark-mode model** — semantic value selected per (n-ary) mode input; same role names. |
| **vanilla-extract** | **Discipline** — a contract of token paths separate from values (but *total*). |
| **System UI spec / Open Props** | **Seeds** — scale shapes and a neutral default token set. |

See [PRIOR_ART.md §F](PRIOR_ART.md) for how these compose into a strawman v1, and
[PRIOR_ART.md §E](PRIOR_ART.md) for the mapping onto §13.7's open questions.
