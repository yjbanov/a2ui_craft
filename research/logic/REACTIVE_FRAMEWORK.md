# A reactive framework over A2UI — research note

> **Status: research (2026-08-09).** Follows BUSINESS_LOGIC.md (the driver
> design) and its authoring-API discussion. Prompted by promising prototypes:
> a React/Flutter-like reactive framework can be built **on top of** the A2UI
> protocol, with the protocol playing the role of the DOM — the retained UI
> CRUD vocabulary a reconciler needs to apply widget-rebuild deltas remotely.
> This note researches the idea in depth, with special attention to the
> question the model raises: *render functions return UI — so where do data
> updates fit?*

## 1. The idea, and what it does not change

A driver-side framework in the author's language (JavaScript, Dart, Kotlin):
components with build/render functions, familiar state management, one
codebase for UI and logic. The framework holds a retained tree; state changes
re-render subtrees; the reconciler diffs and emits A2UI Transport messages —
`updateComponents` as element CRUD, `updateDataModel` as value pokes — down
the driver channel. The a2ui-craft engine on the client is the "browser."

The payoff is idiomatic familiarity: developers have mixed UI and logic in one
language for a decade (React, Flutter, React Native, Compose), with mature
patterns for app state, update localization (`setState`, inherited widgets /
context), and testing. The two-language split — templates for UI, a driver for
logic — becomes an *option* (see §7) rather than the only shape.

Crucially, **nothing below the authoring layer changes**:

- The wire still carries A2UI Transport inside the session envelope
  (BUSINESS_LOGIC.md §5). The framework is a *compiler onto the L1 SDK*: its
  flush is the L1 transactional turn, its handlers ride the serialized event
  queue, its output drains the same channel budgets.
- The trust model is untouched: the framework runs in the driver's sandbox,
  in the author's trust domain, under the catalog ceiling (§7–§8 of the
  design). A framework cannot express anything the protocol forbids.
- "Logic is a driver, not a library" survives intact — this is a better way
  to *write* a driver, not a new attachment point.

This is the L2/L3 rung the authoring-API discussion deliberately deferred with
"design the seams so L2 compiles down." The prototypes are evidence that the
seams are in the right place.

## 2. Prior art: this architecture has shipped, repeatedly

| System | Sandbox/remote side | Wire | Host side | What it proves |
|---|---|---|---|---|
| **React Native** | React + JS thread, shadow tree | batched view mutations over the bridge (now Fabric/JSI) | native views | the whole model at massive scale — a reactive framework whose "DOM" is an async mutation protocol to another realm |
| **Shopify remote-ui → [Remote DOM](https://github.com/Shopify/remote-dom)** | third-party extension code in a web worker | serialized DOM mutations over `postMessage` | a **vetted host component set** | the sandboxed-worker variant *with our trust posture*, in production for Shopify UI extensions ([their write-up](https://shopify.engineering/remote-rendering-ui-extensibility)) |
| **React Server Components** | server-rendered element tree | streamed tree (Flight) | client React materializes; **client components** mark the local-interactivity boundary | the server variant, and the boundary concept §7 borrows |
| **Phoenix LiveView** | server-held socket state | events up, minimal diffs down | browser patches DOM | latency UX at real network distance |
| **Jetpack Glance** | Compose runtime | RemoteViews | launcher/system process | a declarative runtime retargeted at a remote, restricted surface (the Kotlin path: Compose's `Applier` is explicitly retargetable) |
| **SolidJS / Svelte 5 / preact signals** | — (in-process) | — | — | **fine-grained reactivity**: structure built once, value "holes" poked in place — the shape §4 argues fits our wire exactly |

Two observations from the table:

1. Every serious "declarative UI over a wire" system independently converged
   on the same skeleton: a retained remote tree, batched deltas, and a
   *boundary* below which interaction stays local. We should expect to need
   all three.
2. Shopify's evolution is instructive: remote-ui began with a custom
   serialized component tree and a bespoke `react-reconciler`; they rebuilt it
   as Remote DOM — *make the protocol literally be the DOM*, then any
   DOM-rendering framework (or none) works unmodified. The lesson for us is
   not "expose the DOM" (our protocol is better than a DOM — see §3) but
   "make the mutation vocabulary complete and framework-shaped, and the
   framework layer above becomes swappable."

## 3. The mapping made precise — and where A2UI is *more* than a DOM

The "A2UI as DOM" claim, element by element:

| DOM concept | A2UI Transport |
|---|---|
| `createElement` / `appendChild` / reorder | `updateComponents` (id'd components, children arrays) |
| `removeChild` | component deletion |
| `setAttribute` | prop change via `updateComponents` — **or a data write, if the prop is bound** |
| text node update | `Text` prop change — or a data write through a binding |
| `addEventListener` | `action` props → user events up the channel |
| rAF batching / layout flush | the L1 transactional turn: one envelope message per handler turn |

The load-bearing difference: **the DOM has one channel; A2UI has two.**
Structure (components) and values (the data model) are separate, and the
client is not a dumb rasterizer — it evaluates bindings, functions, `checks`,
`ChildList` unrolling, and template-internal `switch`/`...for`/`state`
locally. A DOM with a built-in spreadsheet. A framework that ignores this and
routes everything through structure diffs (§4.1) throws away exactly the part
of the protocol that keeps the wire quiet and the interaction local. The
framework design problem is therefore not "diff efficiently" — it is **"decide,
for every dynamic value, which channel it rides."** That is the data-updates
question, and it gets its own section.

## 4. The central question: where do data updates fit?

In React/Flutter, `build()` returns UI with values *embedded* — `Text('Total:
$42')`. Change detection happens by diffing the returned tree; the framework
*discovers* that only a value changed. A2UI natively separates the two: a
component prop is either a literal or a binding (`{'path': '/cart/total'}`)
into the data model. Three strategies for a framework sitting on top:

### 4.1 Inline everything (ignore the data model)

Render embeds concrete values as literal props; every change is a re-render +
structure diff. **Rejected as the general mode**, on three grounds:

- **Two-way binding dies.** A `TextField` needs a `{path}` to echo keystrokes
  locally (the design's optimistic echo). Inlined, every keystroke is a
  round-trip — the exact firehose the design classifies as a fault.
- **Client-side variation dies.** Template `switch` on data, `checks`
  validation, `ChildList` unrolling all key off data paths.
- **The wire gets loud.** A component update is heavier than a data poke, and
  every scalar change now ships structure.

Inlining remains correct for *genuinely static* props — which is exactly what
"literal" means. The degenerate case, not the design.

### 4.2 Fine-grained: signals become bindings (the recommended shape)

Author-side state is **signals** (cells). The rule that makes the whole model
click:

> **Pass a signal into a prop and the framework allocates a data-model path,
> emits the prop as a binding, and pokes the path when the signal changes —
> no re-render, no diff. Pass a plain value and it is a literal. Re-render
> and diff happen only when *structure* changes** (conditionals flip, lists
> change shape, component types swap).

This is precisely the architecture SolidJS and Svelte 5 arrived at
in-process: compile the template once into real DOM, then run tiny effects
that poke text and attributes in place. **The A2UI protocol's two channels
are the structure/value split that fine-grained frameworks discovered
independently** — `updateComponents` is "compile the structure once,"
`updateDataModel` is "poke the holes." The framework doesn't have to invent
the distinction; it inherits it from the wire format, and diffing becomes
rare (structural changes only) and small.

What falls out for free:

- **Two-way binding, without the author thinking about it.** A signal handed
  to `TextField.value` becomes a `{path}` binding → the client echoes
  keystrokes at tier-1 latency → the event carries the value → the framework
  writes it back into the signal → everything reading the signal reacts. The
  signal is the author-facing façade of an owned data-model path, and the
  design's echo/reconcile loop (§4 of BUSINESS_LOGIC.md) is the signal's
  *implementation*, invisible at the call site.
- **Derived state has a home on either side of the wire.** `computed(() =>
  ...)` evaluates driver-side and pokes its path. Later, simple computeds
  could compile to A2UI *functions* so derivation happens client-side
  (tier 2) — an optimization slot the inline model doesn't even have.
- **Language mirrors exist and are already in the stack.** preact signals
  (JS), `preact_signals` Dart — which `a2ui_core` already uses internally —
  and Compose snapshot state (Kotlin). No compiler required, unlike Solid:
  the discipline is API-visible (pass the signal, not `signal.value`).

The honest cost: authors must learn one rule — *passing a signal wires a live
hole; reading `.value` inside `build` takes a snapshot and subscribes the
build*. The saving grace is graceful degradation: reading `.value` isn't
wrong, it just routes the change through re-render + diff (coarse), and §4.3's
machinery can still turn the resulting scalar prop delta into a data poke.

### 4.3 Coarse: VDOM diff with automatic binding promotion

Plain `setState`-style re-rendering with tree diffing, plus a framework trick:
scalar prop deltas are routed to framework-owned data paths ("auto-binding") —
either bind-everything-up-front (components become pure structure; all values
live in the data model keyed per component/prop) or promote-on-first-change.
This is the shape a `react-reconciler`-based compatibility layer would take
(remote-ui's legacy path proves it works). Costs: data-model bloat and path
churn (lists especially), diff cost on every update, and a noisier wire than
§4.2 — but a 100%-familiar API with zero new concepts.

### 4.4 Recommendation

**Signals-first for the reference framework** — it is the shape the protocol
itself has; the wire stays quiet; two-way and client-side evaluation come
free. Keep §4.3 as the documented degradation path inside the same framework
(reads-in-build still work, just coarser), and leave a React-compat
reconciler as a thing the ecosystem can build on the L1 SDK — the protocol is
indifferent, which is rather the point.

## 5. Lists: the choice of channel, writ large

Lists sharpen the two-channel decision because A2UI has *two list
representations*:

- **Explicit children** — the framework unrolls the list into id'd components
  and diffs with author-supplied keys (our keyed-reconciliation work applies
  directly). Right for heterogeneous lists. Cost: structural messages per
  add/remove/move.
- **`ChildList` + a data array** — one template component + the list *as
  data*; the client unrolls. Adds, removes, and reorders become **data
  pokes**; zero structural traffic. Right for homogeneous lists — and a wire
  win unavailable to DOM-shaped systems, because the DOM has no "the ul's
  items are an array over there" concept. (Per-item identity rides on
  [a2ui#1745](https://github.com/a2ui-project/a2ui/issues/1745); our
  keyed-when-present fallback already handles both worlds.)

The framework API should offer one list construct and pick the
representation: `each(items, key: ..., builder: ...)` compiles to `ChildList`
when the item view resolves to a single catalog component over item data, and
explodes into explicit children otherwise. Authors think "list"; the
framework thinks "which channel."

## 6. Events and the contract under a framework

A tension to resolve honestly: the contract file's strength is **static
verifiability** — declared events, checked on both ends. But a reactive
framework attaches *closures*: `onPressed: () => cart.add(sku)` wants an
auto-generated event name per component instance, unknowable at
contract-authoring time.

Resolution: split the event space by audience, mirroring the catalog tiers:

- **Business actions** — author-named, contract-declared,
  inference-catalog-eligible (`checkout`). These stay statically verified;
  they are the agent- and host-facing API surface.
- **UI wiring events** — framework-allocated names on a designated framework
  channel the contract enables as a unit (`"frameworkChannel": true`). Never
  agent-visible, never in the inference catalog, but fully subject to
  budgets, ordering, and the serialized handler queue — a closure-dispatched
  event is still an event; the framework compiles it onto the same L1 queue.

The cost, stated plainly: per-event static verifiability narrows to the
business tier. That is the tier where it mattered — the host/platform rules
and the agent API — while UI wiring was never meaningfully auditable as a
name list anyway.

## 7. Templates become the client-component boundary

The framework does not obsolete templates; it gives them a sharper job. The
RSC analogy is exact:

> server components : driver components :: client components : **templates**

A template is the unit that keeps interaction *local*: internal
`state`/`set`, `switch`/`...for` variation, functions, two-way echo — the
design's tiers 1–2. A framework-rendered surface composed of well-chosen
template leaves does its continuous, latency-sensitive interaction entirely
client-side and reserves the wire for decisions. The author chooses the
boundary's altitude: bigger templates → more local latitude, less chatter;
primitive-level composition → maximum driver control, maximum wire traffic.
DESIGN.md §4's "bias to templatize" thereby graduates from an authoring
guideline to a **performance** guideline.

Speculative but attractive follow-on: **static-subtree extraction.** Build
functions often return subtrees that are invariant across states; the
framework can detect them (build-count instrumentation, or explicit
memoization) and register them as synthetic templates at session start
(catalog loading is already data) — after which structure messages shrink to
references. Measure the prototypes' diff traffic before building this.

## 8. The hazard: familiarity hides the wire

The framework's selling point — a remote surface that *feels* like local
`setState` — is also its principal risk: nothing in the code's shape warns
the author that a slider's `onChanged` wired to a driver handler is a
per-pixel network round-trip. React Native carries exactly this scar tissue
(JS-driven animation jank → Reanimated moving animation back to the native
side). Our equivalents, most of which already exist:

- **Two-way-first components**: value props of input primitives are bindings
  by default (§4.2 makes this the path of least resistance) — the echo is
  local before the author does anything.
- **Motion stays client-side** by design (DESIGN.md §9.8) — the framework
  must not grow a driver-side animation API.
- **Flood budgets halt** (BUSINESS_LOGIC.md §4): the failure mode is loud,
  not slow.
- **Authoring lints** (later): a continuous-gesture prop wired to a
  framework-channel handler is statically detectable.

The framework should make the fast path the default path, and the docs should
teach the tiers with the same bluntness as the design doc.

## 9. Implications for the plan

**Unchanged:** the protocol, the session envelope, budgets, the trust model,
and all of Phase 1. The L1 SDK is now *load-bearing twice over* — it is both
the hand-authoring API and the framework's compile target, and the prototypes
are evidence the "L2 compiles down" seam placement was right. The cart
mini-app stays hand-written L1 in Phase 1 (it must exercise the raw seam).

**Added (Phase 2 candidates, in rough order):**

1. Measure the prototypes: diff sizes, messages per interaction, data-model
   growth, list churn — the §4.2-vs-§4.3 and §5 decisions want numbers.
2. Reference reactive framework, signals-based (§4.2), Dart first, JS mirror
   — compiled onto the L1 SDK, no protocol changes.
3. Contract v2: the framework channel (§6) and the `owned`/`bound` key
   distinction the authoring discussion already surfaced.
4. Rewrite the cart as a framework showcase *alongside* (not replacing) the
   L1 version — the pair documents the layering.
5. Static-subtree extraction and computed-to-function compilation (§7, §4.2)
   only if the Phase-2 measurements say structure traffic matters.

**One protocol-design pressure worth registering now:** DESIGN.md §13's open
question on reactivity granularity ("is component-granular rebuild enough?")
gains a concrete customer — a signals framework poking single paths wants
per-binding client updates eventually. No action yet; the open question just
stops being hypothetical.

## 10. Open questions

- **Deterministic component ids.** Restart/cold-boot replay (and any future
  reconnect) needs ids stable across driver runs — derive from tree position
  + author keys, never from allocation counters.
- **Data-model garbage.** Unmounting a component must free its
  framework-allocated paths; a leak here is invisible until the model bloats.
  Ties into budget accounting.
- **Snapshot for a signals graph.** When restoration (design §10) lands, is
  the snapshot the owned data subtree (observable, already serialized) plus
  named driver state, or the signal graph itself? The former is simpler and
  matches the "state you published is state you keep" instinct.
- **The Kotlin path.** Compose's `Applier` retargeting (Glance precedent)
  would make Compose itself the authoring layer — the strongest test of the
  claim that the protocol, not the framework, is the contract.
- **`checks` and validation** authored from the framework side — who owns
  validation UI state when the driver re-renders?
- **Multi-surface drivers** (already open in the design) get more attractive
  under a framework — one app, several surfaces — but stay deferred.

Sources consulted: [Shopify Remote DOM](https://github.com/Shopify/remote-dom)
and the [remote rendering write-up](https://shopify.engineering/remote-rendering-ui-extensibility);
the rebuild-on-DOM discussion at
[remote-dom#267](https://github.com/Shopify/remote-dom/discussions/267).
