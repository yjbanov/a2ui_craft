# Drivers Phase 2 — the reactive driver framework

> **Status: plan (2026-08-13), written as Phase 1's exit deliverable.**
> Companion to [REACTIVE_FRAMEWORK.md](REACTIVE_FRAMEWORK.md) (the research)
> and [PHASE_1_PLAN.md](PHASE_1_PLAN.md) (what this builds on). Phase 1 shipped
> the L0 protocol and the L1 SDK; this phase builds **L2** — a framework where
> UI and logic are one codebase in one language, compiled down onto L1 with
> **no protocol changes**.

## What Phase 1 settled

The four hypotheses, with verdicts, because a plan that reopens settled
questions wastes the phase:

| # | Hypothesis | Verdict |
|---|---|---|
| H1 | **Language neutrality** — the coupling surface is the protocol | **Proven.** The `cart` mini-app ships its logic twice, Dart and JavaScript, and `driver_worker_test.dart` re-runs the *entire* driver conformance suite against the JavaScript ports in a web worker with no case redefined, relaxed, or skipped. |
| H2 | **Asynchrony is livable**; the in-process ↔ sandboxed swap is unobservable | **Proven at worker latency.** Same suite, both runners, no edits. The turn-boundary rule is pinned by a guard shown to fail against a microtask-scheduled runner. **Not proven at network latency** — no remote runner exists, so "livable" currently means "livable across a worker boundary". |
| H3 | **Templates stay decoupled** | **Proven.** Swapping the cart's driver between languages requires zero template changes; the site's two panes render the same `template.craft` against different drivers. |
| H4 | **Security holds at the channel** | **Mostly.** Bidirectional budgets, the reserved `/host` namespace, surface scoping, and loud failure are built and tested. Untested: capabilities (none are grantable), and nothing has had an adversarial review. |

**The L1 API is ratified**, and it is the fuller shape REACTIVE_FRAMEWORK.md §1
left "under discussion": a handler map (`HandlerDriver`), writes buffered into
one transactional turn, handlers serialized so two never interleave. One piece
of that candidate design was **not** built and this phase will want it:

- **`ctx.post` self-events for long work.** A handler that awaits something slow
  currently blocks every later event, because handlers are chained. An L2
  framework running effects will hit this immediately.

Two Phase 1 findings bear directly on the design here:

- **Templates cannot format numbers** (DECISIONS D24). No number→string
  function exists, so the cart prices in whole dollars. A framework that
  compiles computeds to A2UI functions (§4.2's optimization slot) inherits the
  same ceiling.
- **Per-row identity already works, via the action's own arguments**
  (DECISIONS D7). A framework generating list rows gets per-row event
  arguments for free by emitting relative bindings — it does not need to invent
  a row-identity mechanism.

## What this phase must prove

| # | Hypothesis | Proven by |
|---|---|---|
| H5 | **L2 needs no protocol surface.** A reactive framework compiles entirely onto L1 | the framework package depends on `a2ui_craft_logic`'s public API only, and `logicProtocolVersion` does not change |
| H6 | **Signals-as-bindings is cheaper than diffing**, on real interactions | slice 1's instrument, measuring the same scripted cart interactions under L1 (baseline), §4.2, and §4.3 |
| H7 | **The familiar API does not hide the wire.** An author writing idiomatic framework code does not accidentally produce a flood | the mis-tiered case (a signal poked per keystroke) is *visible* in the measurements and *diagnosed* in dev mode, not silently expensive |
| H8 | **The layering is real, not aspirational.** Framework and hand-written L1 coexist | the cart exists twice — hand-written L1 and framework — and both pass the same conformance script |

## The instrument comes first

REACTIVE_FRAMEWORK.md §9 orders "measure the prototypes" first, and building
Phase 1 sharpened why: **there is nothing to compare against until the L1
baseline is measured.** The cart is hand-written L1 today, which makes it the
control.

So slice 1 is a `RecordingTransport` — a decorator over `DriverTransport` that
tallies, per session: frames each way, bytes each way, A2UI messages by type,
distinct data-model paths written, and messages per user interaction. It is
~80 lines, it needs no framework to be useful, and it turns every later
"cheaper" claim into a number.

Take the baseline from the shipped cart's conformance script. Then every
framework decision is measured against a real mini-app rather than a
micro-benchmark.

## Slices

### 1. The instrument + the L1 baseline

`RecordingTransport` in `a2ui_craft_logic`, and a baseline report for the cart's
scripted interactions (boot, add, quantity-clamp, checkout) under the
hand-written L1 driver.

Publish the numbers in this file as a table. They are the denominator for
everything after.

**Tests:** the recorder tallies a known script exactly (constructed frames, not
inferred); the baseline report is generated, not typed.

### 2. Signals over the L1 SDK, Dart first

The §4.2 core, and nothing else:

- a signal cell (`preact_signals`, already in `a2ui_core`);
- **the rule**: a signal passed into a prop allocates a data-model path, emits
  the prop as a binding, and pokes the path on change — no re-render, no diff;
  a plain value is a literal;
- `computed` evaluating driver-side and poking its path;
- structure emitted once, at mount.

No conditionals, no lists, no diffing yet — a fixed component tree with live
holes. That is deliberately less than a framework: it isolates the one claim
H6 rests on.

**Tests:** a poked signal produces exactly one `updateDataModel` and zero
`updateComponents`; the recorder proves it.

### 3. Structure: conditionals, lists, and the diff

Where re-render earns its keep. Structural change is the only thing that
diffs — conditionals flipping, lists changing shape, component types swapping.

The list-representation decision (§5: explicit children vs. `ChildList` + a
data array) is **made with slice 1's numbers**, not in advance. The `each(items,
key:, builder:)` shape the note proposes picks the representation; measure both
on a 100-row reorder before choosing which it picks by default.

**Tests:** a list reorder emits what the chosen representation says it should,
and no more; a conditional flip re-renders its subtree and nothing above it.

### 4. Two-way binding, and the echo the author never sees

A signal handed to `TextField.value` becomes a `{path}` binding: the client
echoes keystrokes at tier-1 latency, the event carries the value back, the
framework writes it into the signal. The design's echo/reconcile loop becomes
the signal's *implementation*, invisible at the call site.

This is the slice where H7 is decided. A framework that makes the wire
invisible must still make a *flood* visible: dev-mode diagnostics when a signal
bound to a business event is poked at keystroke rate, and the budget already
halts the pathological case.

**Tests:** an authored two-way field round-trips with no author-visible wiring;
a per-keystroke business event is diagnosed in dev mode before the budget
halts it.

### 5. The framework cart, alongside the L1 cart

The pair is the deliverable, not the replacement. Same project files, same
conformance script, two drivers: one hand-written against L1, one written in the
framework. Both must pass unmodified.

Then re-run slice 1's instrument and publish the comparison against the
baseline. If the framework is not cheaper on the wire than hand-written L1, say
so plainly — that is a finding about §4.2, not a bug to hide.

**Tests:** the driver conformance suite, parameterized by fixture name, gains a
`cart-framework` fixture and runs on both adapters.

### 6. The JavaScript mirror

The same framework in JavaScript, on preact signals, running in a worker — and
the slice-5 conformance script running against it unmodified, exactly as
Phase 1's slice 6 did for L1. This is what keeps H1 true one rung up: a
framework that only exists in Dart would quietly re-couple the stack to the
engine's language.

**Tests:** the framework cart's conformance cases pass against the JavaScript
framework in a worker.

### 7. Tooling metadata and the site

- `schema.json` action entries authored *from* framework apps (§6), and the
  `owned` / `bound` key distinction as **tooling metadata, not enforcement** —
  a two-way-bound key legitimately has two writers (the surface echoing the
  user, the driver correcting), unlike a purely driver-owned key.
- The site's mini-app screen gains a third pane, or a toggle: same cart, L1
  versus framework, with the wire tally visible. The measurement made public is
  the honest version of the claim.

**Tests:** loader round-trip for the metadata; site build.

## Scope guards

Deferred unless the measurements demand them: static-subtree extraction and
computed-to-function compilation (§7, §4.2 — only if structure traffic turns
out to matter); L3 concerns entirely (routing, effects systems, DI); the remote
runner and network-latency behavior, which is H2's untested half and belongs to
its own phase.

**No protocol changes.** If this phase finds it needs one, that is the most
important finding it can produce and it should stop and say so rather than
quietly widening the envelope. The one place pressure is already registered:
DESIGN.md §13's open question on reactivity granularity now has a concrete
customer, because a signals framework poking single paths eventually wants
per-binding client updates. Registering it is not permission to build it.

## Sequencing notes & risks

- **The instrument before the framework** is the whole discipline of this
  phase. §4.2-versus-§4.3 is an empirical question and has been since the
  research note; building the framework first would turn it into a taste
  question defended after the fact.
- **Slice 2 is deliberately not a framework.** Fixed structure with live holes
  isolates the claim H6 rests on. If the numbers are unconvincing there,
  slices 3–6 change shape and it is cheap to find that out.
- **The `ctx.post` gap (above) blocks effects.** Pull it forward into slice 2 if
  a framework effect needs to await anything slow, which it will.
- **Per-adapter drift is not a risk here** — the framework sits above the
  protocol, and the adapters still contribute nothing. The risk that replaces
  it is *per-language* drift between the Dart and JavaScript frameworks, which
  slice 6 exists to catch the same way Phase 1's slice 6 did.

## Exit criterion

This phase ends with a **decision, backed by numbers**: whether the reactive
framework is the recommended authoring altitude for mini-apps, or whether
hand-written L1 remains the default with the framework as an option. Either
answer is a result. What would not be a result is shipping the framework
without measuring it, because the entire argument for §4.2 over §4.3 is that
it is cheaper on a wire nobody can see.
