# Design tokens for A2UI Craft — adopting W3C DTCG?

> **Status: research note (uncommitted).** Question posed: can we adopt the W3C
> Design Tokens format *as-is* — rather than invent our own — so A2UI Craft themes
> interoperate with existing design-system tooling? Short answer: **yes, adopt the
> format; no, don't adopt the tooling** (it's all build-time; we need runtime). The
> reasoning, the format primer, the fit analysis, and an API sketch are below. This
> feeds §13 of DESIGN.md.

---

## 0. TL;DR / recommendation

1. **Adopt the DTCG core format (2025.10) as our on-the-wire token format.** It
   reached its *first stable version* in Oct 2025, it's JSON, and it's what Figma
   Variables / Tokens Studio / Style Dictionary / Terrazzo all read and write. A
   design-system author can export their tokens from tools they already use and
   ship them to us. **Do not invent a competing format.**
2. **Build our own small *runtime* Dart parser + resolver** (framework-neutral, in
   `a2ui_craft`, total). This is the key insight: **the entire DTCG ecosystem is
   build-time** — it *compiles* tokens JSON into generated CSS/Dart/Swift ahead of
   time. Our §13 requirement is the opposite: **load the tokens ephemerally over
   the network and interpret them at runtime**, because the design system is not
   part of the AOT-compiled host. So we take the format, not the toolchain.
3. **Layer one small thing DTCG does *not* give us: a semantic contract** — the
   fixed set of token *paths* our primitives read for ambient role-defaults (e.g.
   `color.action`, `color.surface`, a type scale). DTCG standardizes token
   *structure*, never token *meaning*; the meaning is ours to define. This is the
   only "standard" we author, and it's tiny.
4. **Modes (light/dark)** are covered by a companion **Resolver Module**, which is
   still an unstable *preview draft* ("do not implement"). Adopt its *model*
   conceptually; ship a minimal version; keep our modes layer swappable.
5. **Scope v1 to a type subset**: `color` (sRGB), `dimension`, `fontFamily`,
   `fontWeight`, `number`. Defer composites (`shadow`, `border`, `typography`,
   `gradient`, `transition`, `cubicBezier`) to later phases.

Net: adopting DTCG **strengthens** the §13 design — it slots in exactly where §13
said "a token set (data)", it gives us aliasing and modes for free (conceptually),
and it buys ecosystem interop at the cost of a small runtime parser we were going
to write anyway.

---

## 1. What DTCG is (and isn't)

- **Who:** the W3C **Design Tokens Community Group** (DTCG). A *Community Group*
  report, not a formal W3C Recommendation — but the de-facto industry standard,
  with reference implementations in Style Dictionary, Tokens Studio, and Terrazzo.
- **Status:** the **core Format Module reached its first stable version, 2025.10**
  (announced 2025-10-28). The **Resolver Module** (modes/themes) is a **preview
  draft** and explicitly says "do not implement anything in this document."
- **File:** plain **JSON**; extensions `.tokens` / `.tokens.json`; media type
  `application/design-tokens+json` (fallback `application/json`).
- **What it is:** a serialization format for **design tokens** — named values
  (colors, sizes, font settings, durations, …) and references between them.
- **What it is NOT:** it is **not** a component-styling language. There is no
  "Button.background = {color.action}" in DTCG. It defines the *token layer* only.
  *(This is a feature for us — it matches §13.3's decomposition exactly: tokens are
  data (DTCG's job); component styling is our catalog templates referencing
  tokens.)*

---

## 2. Format primer (the parts that matter to us)

### 2.1 A token

An object with a **`$value`** is a token:

```json
{
  "color": {
    "$type": "color",
    "primary": {
      "$value": { "colorSpace": "srgb", "components": [0, 0.4, 0.8], "hex": "#0066cc" },
      "$description": "Primary brand color"
    }
  }
}
```

- `$value` — **required**. Primitive, object, array, or a **reference**.
- `$type` — optional on the token; may be **inherited from the nearest ancestor
  group** that sets `$type` (here `primary` inherits `"color"` from the `color`
  group). If neither the token nor any ancestor sets a type, the token is invalid.
- `$description`, `$extensions` (reverse-DNS-keyed vendor metadata), `$deprecated`,
  `$extends` — optional.

### 2.2 Groups & naming

- A **group** is any object *without* `$value`; groups nest arbitrarily.
- **Naming rules that constrain us:** a token/group name must **not start with
  `$`** and must **not contain `{`, `}`, or `.`** (those are reserved for the
  reference syntax). Names are case-sensitive.

### 2.3 Aliases / references — *this is our semantic layer*

A token's `$value` can be a **reference to another token** using the curly-brace
dot path:

```json
{
  "color": {
    "base":     { "blue":    { "$type": "color", "$value": { "colorSpace": "srgb", "components": [0, 0.4, 0.8] } } },
    "semantic": { "action":  { "$type": "color", "$value": "{color.base.blue}" } }
  }
}
```

- A reference always resolves to the target's **`$value`**.
- There's also a JSON-Pointer form (`"$ref": "#/color/base/blue/$value/components/0"`)
  for property-level access — niche; we can ignore it initially.
- References may chain; tools **must** detect cycles as errors.
- **Why this matters:** DTCG's primitive-vs-semantic token split (§13.3 called it
  out) *is* just aliasing — `semantic.action → base.blue`. Re-skinning = swap the
  base. We get it for free.

### 2.4 The type system (2025.10) — note the recent shift to structured values

The stable version moved several values from **strings to objects**. A parser
should accept **both** the new object form and the legacy string form still common
in the wild.

| `$type` | `$value` shape (2025.10) | Legacy form still seen | v1? |
|---|---|---|---|
| `color` | `{ colorSpace, components: number[], alpha?, hex? }` | `"#0066cc"` | ✅ (sRGB + hex) |
| `dimension` | `{ value: number, unit: "px" \| "rem" }` | `"16px"` | ✅ |
| `fontFamily` | `string` or `string[]` | same | ✅ |
| `fontWeight` | `number` (1–1000) or keyword (`"bold"`, …) | same | ✅ |
| `number` | JSON number | same | ✅ |
| `duration` | `{ value, unit: "ms" \| "s" }` | `"200ms"` | later |
| `cubicBezier` | `[x1, y1, x2, y2]` (x∈[0,1]) | same | later |
| `strokeStyle` | `"solid"…` or `{ dashArray, lineCap }` | same | later |
| `border` | `{ color, width, style }` | — | later |
| `shadow` | shadow-object or array of them (`{ color, offsetX, offsetY, blur, spread }`) | — | later |
| `transition` | `{ duration, delay, timingFunction }` | — | later |
| `gradient` | (array of stops; composite) | — | later |
| `typography` | `{ fontFamily, fontSize, fontWeight, lineHeight, … }` | — | phase 3 |

**Fit with our value types (§11):** `color` and `dimension` map directly onto what
our primitives already parse (hex color; `Dimension`). `typography` is exactly the
"type token" §13 imagined. So the DTCG data model lands cleanly on our existing
framework-neutral value layer — no impedance mismatch.

### 2.5 Modes / light-dark — the **Resolver Module**

The core format is a **single** set of tokens; it has **no** built-in light/dark.
Two realities today:

- **Interim convention:** modes stuffed into `$extensions`, e.g.
  `"$extensions": { "modes": { "dark": "{color.neutral.1000}" } }`. Tokens Studio
  uses "sets", Style Dictionary uses "themes" — three incompatible conventions.
- **Emerging standard:** the **Design Tokens *Resolver* Module** standardizes it:
  - **sets** — collections of tokens (inline or `$ref` to files),
  - **modifiers** — named axes with **contexts** (e.g. `theme: {light, dark}`),
    each context pointing at token sources, with a `default`,
  - **resolutionOrder** — an explicit array; later entries override earlier ones,
  - **inputs** — the runtime selection, e.g. `{ "theme": "dark" }`.

  ```json
  {
    "sets": { "foundation": { "sources": [{ "$ref": "foundation.json" }] } },
    "modifiers": {
      "theme": {
        "contexts": { "light": [{ "$ref": "light.json" }], "dark": [{ "$ref": "dark.json" }] },
        "default": "light"
      }
    },
    "resolutionOrder": [ { "$ref": "#/sets/foundation" }, { "$ref": "#/modifiers/theme" } ]
  }
  ```

  Resolve = validate inputs → flatten sets + selected contexts in order (later wins)
  → resolve aliases → final token set.

- **Caveat:** this module is a **preview draft** — "do not implement." So: adopt the
  *shape* (sets + modifiers + resolutionOrder + `inputs`) as our mental model and
  ship a minimal version, but **don't** hard-commit to its exact wire format yet.
  This directly answers §13's open "dark mode: second map or a mode flag?" — the
  industry answer is *modifier contexts layered by resolution order*, driven by a
  runtime `inputs` selection. That matches §13's cascade (host supplies the active
  mode as render-time config).

---

## 3. The decisive fit question: build-time vs. runtime

**Every mature DTCG tool is a build-time compiler.**

- **Style Dictionary** (Amazon; v4 added DTCG-as-source, v5 builds platform outputs
  for CSS/SCSS/iOS/Android/Compose/**Flutter**/JS from DTCG 2025.10). Its model is
  *source tokens → parsers → transforms (per-token value transforms) → formats
  (file generators)*. It emits **Dart `ThemeData` files at build time.**
- **Terrazzo** (formerly Cobalt UI; `@terrazzo/parser` with `parse` + `createResolver`)
  — DTCG-native parser/validator, then plugins generate CSS/Sass/JS/Tailwind.
- **Tokens Studio** — Figma authoring; DTCG + legacy export.
- **@styleframe/dtcg** — a spec-conformant parser/validator/serializer (Node/TS).
- **aloisdeniel/style-dictionary-figma-flutter** — build-time transforms → Dart theme.

**None of these is a runtime interpreter, and there is no pure-Dart runtime DTCG
parser I could find.** They all assume the tokens are known at *compile* time and
baked into the app.

**Our requirement is the exact opposite (§13.1, §13.5):** the design system loads
**ephemerally**, alongside the template — it is *not* compiled into the host. So:

- We **cannot** use Style Dictionary / Terrazzo in our runtime path. They'd be, at
  most, an **author-side convenience** (the theme author *may* build/validate their
  `.tokens.json` with them before shipping — their choice, not our dependency).
- We **must** write a **small runtime Dart parser + resolver** that ingests DTCG
  JSON and produces resolved, typed values *at load time on the client*.

This is not extra work forced by DTCG — §13 already required a runtime token
parser. Adopting DTCG just means that parser reads a **standard** shape instead of
a bespoke one. Same effort, more interop.

> **One-line framing:** the ecosystem *compiles* tokens into apps; we *interpret*
> tokens in an app. We share their **format**, not their **pipeline** — exactly as
> A2UI Craft already shares RFW's *format* while running its own runtime.

---

## 4. What DTCG gives us vs. what stays ours

| Concern (from §13) | DTCG provides? | Notes |
|---|---|---|
| Token structure & types | ✅ format + type system | color/dimension/typography map onto our value types |
| Primitive ↔ semantic tokens | ✅ via aliases `{a.b.c}` | resolve at load; cycle-detect |
| Ephemeral, JSON, safe-to-load | ✅ (pure data, no code) | parse **totally**: bad token → fall back (§13.6) |
| Light/dark & other modes | ~ (Resolver Module, unstable) | adopt model; minimal impl; swappable |
| **Which tokens the primitives read** (roles) | ❌ **not defined** | *our* semantic contract — see §5 |
| Binding tokens → component styles | ❌ (out of scope for DTCG) | our catalog templates + primitive role-defaults (§13.3–13.4) |
| Runtime interpretation | ❌ (all tooling is build-time) | our Dart parser/resolver (§3) |
| Cross-adapter determinism | n/a (it's data) | one **shared** parser in `a2ui_craft` → identical on both adapters |

**The single thing we must author is the semantic contract (§5).** Everything else
is either given by DTCG or already planned in §13.

---

## 5. The one piece DTCG can't give us: the semantic contract

DTCG says *how* to write `color.action`; it never says a button should *use*
`color.action`. That mapping — **which token paths our primitives consult for their
ambient role-defaults** — is ours to define, and it's the crux of §13.4's "ambient
role-defaults" tier.

Two sub-decisions (both were already open questions in §13.7):

1. **The role vocabulary.** Lean on **Material 3's** role names (`primary`,
   `onSurface`, `surface`, `outline`, a type scale, …) so existing M3 token sets map
   on with zero translation? Or a **minimal neutral** set of our own? Recommendation:
   start minimal and *neutral* but *name-compatible with M3 where obvious*, so an M3
   export mostly "just works" while we keep the surface small.
2. **How a primitive reads a role.** A primitive with an unset prop looks up a fixed
   token path in the active resolved theme (e.g. `Button` → `color.action`), falling
   back to the host default when absent (§13.4 cascade). The path list *is* the
   contract; it lives in `a2ui_craft` next to the primitive spec (§11).

This contract is small, versioned, and documented — the only "standard" we own. It's
the analogue of §11's primitive vocabulary, but for token roles.

---

## 6. API design — inspiration + a Dart sketch

**Inspiration taken:**

- **Terrazzo `@terrazzo/parser`**: `parse(json)` → validated token graph;
  `createResolver(...)` applies **modes/modifiers** to produce a resolved view. The
  two-step *parse → resolve(with inputs)* split is the right shape for us.
- **Style Dictionary utils**: `typeDtcgDelegate` pushes group `$type` down onto each
  token (we do the same in parse, so every token carries a concrete type);
  `resolveReferences` dereferences aliases with cycle detection.
- **Layering:** parse (structure + type inheritance + validation) is separate from
  resolve (alias + mode resolution), which is separate from *reading typed values*.

**Proposed Dart surface (framework-neutral, in `a2ui_craft`, all total):**

```dart
/// Parse DTCG JSON into a normalized token set: groups flattened to dot-paths,
/// `$type` inherited down to every token, aliases recorded but not yet resolved.
/// Total: malformed tokens are dropped/marked, never thrown.
TokenSet parseDesignTokens(Map<String, Object?> dtcgJson);

/// Resolve aliases and select modifier contexts (e.g. {'theme': 'dark'}),
/// producing a flat map of path -> concrete typed value. Cycles resolve to null.
ResolvedTokens resolve(TokenSet set, {Map<String, String> inputs = const {}});

/// Typed, total reads used by primitives + the `theme.` reference scope (§13.4).
abstract class ResolvedTokens {
  Color?      color(String path);      // sRGB/hex → our Color
  Dimension?  dimension(String path);  // {value,unit} or "16px" → Dimension
  double?     number(String path);
  String?     fontFamily(String path);
  int?        fontWeight(String path);
  Object?     raw(String path);        // escape hatch for composites, later
}
```

- One parser, in `a2ui_craft`, used by **both** adapters → resolved values are
  identical on Flutter and Jaspr by construction (§13.6 determinism).
- **Accept legacy + 2025.10 forms** (hex string *and* color object; `"16px"` *and*
  `{value,unit}`) — be liberal in what we read.
- **Totality**: unknown `$type`, unresolved alias, bad unit → `null` from the typed
  getter → the primitive falls back to the host default (§13.4/§13.6). Never throws.
- The resolved map's **dot-path keys are exactly our `theme.<path>` references**
  (§13.4) — so `theme.color.action` in a template is a lookup into `ResolvedTokens`.

---

## 7. How this updates §13 (proposed edits, for your review)

- §13.3 "**Design tokens** — pure data" → name it: **the W3C DTCG format**; tokens =
  a DTCG file; primitive/semantic split = DTCG aliases.
- §13.4 "**explicit token references** `theme.color.brand`" → the path is a DTCG
  token path; resolution is a `ResolvedTokens` lookup.
- §13.5 transport: the author bundles a **`.tokens.json`** (DTCG); host render-time
  config selects the **mode** (Resolver-Module `inputs`).
- §13.7 open questions largely **answered by the ecosystem**: dark mode =
  modifier-contexts + resolutionOrder; token vocabulary = *our* semantic contract
  layered on DTCG (the one bespoke bit).
- §13.8 phasing gains a concrete artifact: **Phase 1 = a runtime Dart DTCG parser +
  resolver for the `color`/`dimension`/`fontFamily`/`fontWeight`/`number` subset**,
  plus the semantic contract and ambient role-defaults.

---

## 8. Risks / watch-outs

- **Resolver Module is unstable** ("do not implement"). Track it; keep our modes
  layer behind our own interface so we can conform when it stabilizes.
- **Color as object (colorSpace/components)** is richer than our hex parsing. Start
  **sRGB + hex** only; wider gamut later. Accept the legacy hex string too.
- **`dimension` `rem`** needs a root font size to become logical pixels — decide a
  convention (fixed root, or host-provided). `px` → logical pixels directly.
- **DTCG defines no roles** — §5 is genuinely ours to design and is the highest-value
  decision. Don't let "we adopted a standard" obscure that the *meaningful* part
  (roles + primitive bindings) is still bespoke.
- **Composite types** (`typography`, `shadow`, `border`) are where "just adopt it"
  gets real work (nested refs, multi-field). Defer; they're phase 3+.
- **Spec drift**: DTCG is a CG report, still evolving (color/dimension just changed
  shape). Our *liberal, total* parser is the hedge — accept multiple forms, degrade
  gracefully.

---

## Sources

- [Design Tokens Format Module 2025.10 (draft)](https://www.designtokens.org/tr/drafts/format/)
- [Design Tokens Resolver Module 2025.10 (preview draft)](https://www.designtokens.org/tr/drafts/resolver/)
- [DTCG: first stable version announcement (2025-10-28)](https://www.w3.org/community/design-tokens/2025/10/28/design-tokens-specification-reaches-first-stable-version/)
- [Style Dictionary — DTCG support](https://styledictionary.com/info/dtcg/) · [DTCG utils (typeDtcgDelegate, convertToDTCG)](https://styledictionary.com/reference/utils/dtcg/)
- [Terrazzo (formerly Cobalt UI) — parser & JS API](https://terrazzo.app/docs/reference/js-api/) · [@terrazzo/parser](https://www.npmjs.com/package/@terrazzo/parser)
- [Tokens Studio — W3C DTCG vs legacy format](https://docs.tokens.studio/manage-settings/token-format)
- [@styleframe/dtcg — spec-conformant parser/validator/serializer](https://www.styleframe.dev/docs/getting-started/integrations/dtcg)
- [aloisdeniel/style-dictionary-figma-flutter (build-time Flutter output)](https://github.com/aloisdeniel/style-dictionary-figma-flutter)
- [W3C DTCG design tokens: a practical guide (Taste Profile)](https://tasteprofile.io/blog/w3c-dtcg-design-tokens-practical-guide)
