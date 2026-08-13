# Business logic for templates — the mini-app design

> **Status: proposal (2026-08-08).** Fills in the "Later — ephemeral sandboxed
> logic" slot in ROADMAP.md's template-computation arc, and the empty `logic`
> manifest slot reserved in DESIGN.md §10. Workstream B (template functions /
> logic blocks) is the *sibling* layer — pure, local, in-template computation —
> and is not re-designed here; §4 defines the boundary between them.

## 1. The problem

Templates render; they do not decide. A template is a pure function
`(data, state) → UI` (DESIGN.md §4): it can bind data, hold ephemeral widget
state, and dispatch events — and nothing else. Today a surface is driven by one
of two things sitting on the far side of those events:

- a live **agent**, speaking A2UI Transport, or
- **`app.json`**, a canned Transport stream the host replays (DESIGN.md §10).

A **mini-app** — a complete embedded experience with real behavior — needs a
third option: author-written **business logic**. Two constraints pin the
design:

1. **No coupling between the template language and any logic language.** A
   `.craft` template must not name, import, or type-check against constructs
   of JavaScript, Dart, Kotlin, or anything else.
2. **Communication is asynchronous, always.** Logic must be runnable in
   sandboxes (web workers, iframes, webviews) and on servers; nothing in the
   contract may assume a synchronous call is possible.

## 2. Prior art, and what the constraints eliminate

| System | UI ↔ logic coupling | Call model | Verdict for us |
|---|---|---|---|
| React, Flutter | co-located, one language | sync, in-process | eliminated by both constraints |
| Angular | separate files, but template expressions bind to component members | sync, same process | *file* separation without *language* separation — templates type-check against TypeScript classes; eliminated by constraint 1 |
| Elm / MVU | messages + pure update function | in-process, but message-shaped | the right *loop*, wrong process model |
| Phoenix LiveView | events up, state diffs down | async, over a network | the right *transport posture*; proves the UX works at real latency |
| Android RemoteViews / Glance | declarative UI, `PendingIntent` events to the app process | async, cross-process | the right *trust posture*: UI is data, logic is elsewhere |
| A2UI itself | declarative surface, `userAction` events to the agent | async, cross-anything | already the shape we need |

The lesson of the table: Angular's separation is the *wrong kind* — separating
files while templates still name members of a TypeScript class keeps the
language coupling and the synchronous call model. The viable lineage is
**MVU-over-a-wire**: Elm's loop, stretched across LiveView's transport, with
RemoteViews' trust posture. And the last row says we already ship that shape.

## 3. The central decision: logic is a driver, not a library

Define a **surface driver**: anything on the far side of the async channel that
receives a surface's user events and sends it A2UI Transport messages (data
model updates and, when structure must change, component updates).

Under that definition:

- the **agent** is a driver (the live, LLM-authored one);
- **`app.json`** is a *recorded* driver (a replayed message log — DESIGN.md
  §10 already calls it a canned stream);
- **business logic** is the new, *programmatic* driver.

**Business logic attaches to the surface, not to the template.** The template
never names a function, class, or module in any logic language. It names
*events* and binds *data paths* — both plain strings over the data-only value
vocabulary (maps, lists, ints, doubles, bools, strings; content.dart's
`DynamicContent` types, deliberately JSON-isomorphic). The entire coupling
surface between a template and its logic is therefore the **protocol**, which
any language that can hold state and read/write JSON can implement. Constraint
1 is satisfied structurally, not by discipline. Constraint 2 is inherited: A2UI
Transport is already async and already designed to cross process and network
boundaries.

Security falls out too: a driver gets **exactly the agent's power** — the
catalog remains the capability ceiling (DESIGN.md §11), and the engine-side
machinery (bridge, budgets, reconciliation) neither knows nor cares which kind
of driver is connected. One protocol, three drivers.

### Considered and rejected: an RPC / function-registry seam

"Templates call `validateEmail(state.email)` and the call is routed to the
logic host." Rejected on four counts: (a) value positions re-evaluate
reactively, so remote calls in expressions are unboundedly chatty; (b) an async
result has no home in a synchronous expression grammar — every value position
would grow a loading state; (c) it couples the template to a specific logic
API, re-creating Angular's problem with extra steps; (d) it violates the pinned
refinement that handlers are always-async and effects arrive **via data
writes**, never a return value. Functions stay pure and local (workstream B).
Logic never computes values *in place*; it observes events and writes data.

### Considered and rejected: a new, data-only protocol

"Logic only ever needs to write the data model, so define a narrower
events-up / patches-down protocol." The narrower protocol is a strict subset of
what Transport's data channel already does, so defining it separately just
creates a second protocol to version, secure, and keep conformant. Instead:
the *simple* driver is one that only ever sends data updates — a usage
pattern, not a protocol. (Authoring guidance, §4: prefer data-driven UI change;
recompose components only for genuinely structural change.)

### Considered and rejected: logic embedded in the template language

Growing `.craft` into a scripting language would couple UI and logic back into
one artifact *and* one language, forfeit the data-only security invariant
(§11's whole premise is that the ephemeral payload composes a vetted catalog
rather than executing code), and still not satisfy authors who want to bring
their own language. The template language stays declarative; in-template
computation is capped at workstream B's pure functions and blocks.

## 4. The loop, and the latency discipline

A driver is a state machine: `(state, event) → (state, messages)`. Downstream:
data model writes (occasionally component updates). Upstream: user events with
their arguments. Elm's update function, at a distance.

Asynchrony is only tolerable because most interaction never crosses the wire.
Three tiers, cheapest first:

| Tier | Mechanism | Latency | Belongs here |
|---|---|---|---|
| 1 | template `state` + `set` | none | ephemeral interaction state: open tab, draft text, hover/expand |
| 2 | template functions (workstream B) | none | pure derivation: formatting, arithmetic, visibility conditions |
| 3 | driver event → data write | round-trip | decisions with consequences: validate, submit, fetch, persist |

Rule of thumb: **if it must survive the surface, or have effects beyond it, it
is tier 3.** Everything else should be pulled down a tier until the template
can't express it.

### Two-way binding is the optimistic echo

The classic remote-logic failure is the control that doesn't move until the
server answers. We don't have it: A2UI's two-way bindings write the **local**
data model immediately — the control echoes the user's action at tier-1
latency — and the driver is informed asynchronously. If the driver disagrees
(clamps a value, rejects an edit), its authoritative data write flows back and
the surface reconciles. This is LiveView's hard-won lesson, and we get it from
machinery that already exists.

The complement also already exists: a control whose event has no listener is
**disabled**, not silently inert (the Checkbox/Radio/Switch/Slider/Button
rule). A surface only *looks* interactive where something is actually wired to
respond.

### High-frequency events are a fault, not a feature

A dragged slider or a per-keystroke stream over a WebSocket is a firehose —
and the design position is that **business events are never high-frequency**.
Continuous interaction is tier-1/tier-2 territory by construction: the drag
echoes locally through two-way binding, and the driver hears about the
*outcome* (a value committed, a form submitted), not the trajectory. A
template wired to fire a business event per intermediate value is mis-tiered,
the same way business logic in a template would be.

So the channel does not coalesce, throttle, or otherwise accommodate floods —
it **treats them as overload**, accidental or malicious, and halts the
session: an event stream that drains the channel budget (§5) trips the same
kind of engine-level budget that degenerate templates (deep/broad widget
trees, DESIGN.md §11) already do, and recovery goes through the ordinary
failure path (§11 below). If a legitimate high-frequency case ever appears
(collaborative cursors, say), coalescing gets designed then, carefully, as an
opt-in — not baked into the protocol preemptively for every driver to depend
on.

## 5. The protocol: a session envelope around A2UI Transport

The steady-state messages exist (Transport down, user events up). The new work
is the **session layer** wrapped around them — the part a bare agent
integration gets to leave implicit because a human is watching:

- **Handshake.** `hello` exchanges protocol version and requested/granted
  capabilities. Versioned from day one; version skew fails loudly at handshake,
  never silently mid-session.
- **Init.** Host → driver: host context (locale, media/mode, the data keys the
  host itself maintains) and, when resuming, the last **snapshot** (§10).
- **Steady state.** Driver → host: Transport messages. Host → driver: user
  events (name, source component, arguments, current two-way values) plus
  change notifications for host-owned context keys.
- **Ordering.** Both directions are ordered per session; events carry a
  monotonic sequence number. Data writes are last-write-wins per root key —
  no CRDTs; there is exactly one writer per key (§7).
- **Lifecycle.** `suspend`/`resume` (surface hidden / restored),
  `snapshot` request → response (§10; reserved-only in the MVP), `terminate`.
- **Health & budgets.** Heartbeat with a deadline; a hung or crashed driver is
  detected, not merely awaited. DESIGN.md §11's budget machinery applies **to
  the channel, in both directions**: driver-sent messages drain a token bucket
  (a driver spamming updates is the async-amplification attack arriving over a
  wire), and upstream events drain one too (§4 — a flood is overload, and
  halts the session).
- **Errors.** Driver exceptions surface as protocol messages, not silence.

Encoding: a JSON envelope; data payloads use the `DynamicContent` value
vocabulary. Transports carry the envelope verbatim — `postMessage`
(worker/iframe), platform channel (webview), WebSocket (server), and direct
function calls (in-process). The pinned "handlers are always-async"
refinement is what makes the in-process ↔ sandboxed swap unobservable to
templates — with one sharpening:

**Delivery is turn-boundary async, not merely microtask async.** Every
transport above except the in-process one delivers on the *event loop* — a
worker's `postMessage` reply physically cannot arrive within the turn that
dispatched the event. A microtask-scheduled in-process delivery *can*: it
lands mid-flush, before same-turn work queued earlier, making the in-process
runner observably **more prompt** than anything it stands in for — and
inviting code to grow a dependency on same-turn delivery that a sandboxed
runner then breaks. So the guarantee is stated as ordering, not
implementation: **a driver message is never observable in the event-loop turn
that produced its cause**, in either direction. In-process transports satisfy
it with zero-length timers (or equivalent event-loop scheduling), not
microtasks, and conformance pins it (the reply must not be visible until the
dispatching turn's microtask queue has fully flushed).

### Considered and demoted: a mandatory contract file

An earlier revision added a bundle-level **logic contract**: the events the
templates dispatch and the keys the driver owns, declared in a `contract.json`,
buying authoring-time checks on both sides, codegen'd per-language SDKs, and
host-side write validation. Demoted — it was over-architecture, on three
counts:

- **It was a third copy of the project's own sources.** In the common case
  the template author and the logic author are the same party, and the
  information already exists: templates *name* the events they dispatch and
  the paths they bind. Any codegen tool that wants to offer typed events and
  key accessors can derive them from the `.craft` sources directly — an
  opt-in DX layer, not an architectural artifact whose drift becomes a new
  failure mode.
- **The checks that guard trust boundaries work at runtime, without
  declarations.** The host protects *its own* keys — which it knows —
  structurally, via a reserved namespace; drivers never needed to declare
  theirs. Templates are already **total against bad data** (agent-supplied
  data is untrusted by design, so driver-written garbage changes nothing —
  it degrades only the driver's own surface). Budgets bound behavior. None
  of this reads a schema.
- **A framework makes it unworkable anyway.** Under an L2 authoring
  framework (REACTIVE_FRAMEWORK.md), UI and logic are one codebase and UI
  events are framework-allocated — a mandatory event enumeration fights the
  layer whose whole point is that no second artifact exists.

What we consciously give up: bind-time refusal of a typo'd event name — a
mismatch is now a dead control instead of a build error. The mitigation is a
**dev-mode diagnostic**: during development the SDK reports events that
arrived with no handler (and handlers that never receive events) loudly.
Runtime, cheap, declaration-free; opt-in codegen restores full static typing
for teams that want it.

What stays static: **the agent-facing surface, and only that.** The inference
catalog (§8) — exposed templates plus driver-backed actions — remains a
static declaration, but it lives in `schema.json`, which already is the
project's agent-facing file, and is needed only when the mini-app exposes
itself to inference at all. It is the app↔agent API, not a UI↔logic
contract, and its verifiability arguments (§8) are untouched by this
demotion.

## 6. Runtimes and transports

| Runtime | Transport | When |
|---|---|---|
| in-process Dart | function call behind a zero-length timer (§5's turn-boundary rule) | build-time-vetted apps compiled into the host; **also the reference runner** the conformance suite drives |
| web worker | `postMessage` | the web default: JS or Wasm logic, no DOM access, cheap |
| iframe | `postMessage` | when logic needs origin isolation or its own network identity |
| webview | platform channel | native (Flutter mobile/desktop) hosts running JS logic |
| server | WebSocket | LiveView-shaped deployments; logic never ships to the client at all |

Wasm in a worker is the language-neutrality endgame — one runner executing
logic compiled from Rust, Kotlin, Dart, Go — but it is a *runner*, not a
protocol concern, and not v1.

The manifest slot reserved in DESIGN.md §10 gets its shape:

```json
"logic": {
  "kind": "worker",            // worker | iframe | webview | remote | builtin
  "entry": "logic.js",         // or "url": "wss://…" for remote
  "capabilities": []           // §7; empty in v1
}
```

Hosts advertise which runners they support. An unsupported `kind` **refuses to
load, loudly** — a mini-app without its logic is not a degraded app, it is a
lie shaped like an app (every wired control disabled, nothing ever responding).
Refusal with a reason beats inert chrome.

## 7. Trust model and the write partition

A driver is **author-trusted code in host-untrusted execution**: more trusted
than agent *content* (the author wrote it, same trust domain as templates),
but the host still runs it sandboxed, because ephemeral delivery means the
host can't audit it. The sandbox grants nothing but the channel:

- **UI ceiling:** the full author catalog — templates **and** primitives (§8);
  still a vetted, declarative vocabulary, so DESIGN.md §11's
  no-arbitrary-code-in-the-payload invariant survives. The *agent's* ceiling
  is narrower: the inference catalog (§8).
- **Data ceiling:** namespace, enforced by the party that owns it. Host-owned
  context keys (locale, media, theme) live in a reserved namespace the host
  refuses driver writes to — the host knows its own keys and needs no
  declaration from the driver (§5). Everything else on the mini-app's surface
  is the driver's. In agent+driver coexistence (§9, deferred) each writer
  gets a disjoint namespace, which is when declared ownership earns its way
  back in. One writer per key is also what makes §5's last-write-wins
  ordering sufficient.
- **Compute/rate ceiling:** the channel token bucket (§5); the sandbox's own
  CPU is the platform's problem (a worker can spin, but it can't touch
  anything).
- **Network:** *not* a protocol concern in v1. Workers and iframes fetch
  subject to the deployment's CSP; a server driver has its own network. A
  proxied-fetch capability (host-mediated, allow-listed) is the v2 shape if
  hosts need to constrain driver traffic; `capabilities: []` reserves the slot.

## 8. The catalog model under drivers: the inference catalog

DESIGN.md §4's two-level model — template-private primitives, agent-facing
templates — was drawn for the LLM-only world, and both of its motivations are
trust-and-context motivations: separate the agent's trust domain from the
template author's, and keep the agent's vocabulary small enough to manage its
context and capabilities. Neither motivation says anything about hiding
primitives from the *author* — it just happened that only an agent ever sat on
the far side of the channel.

A driver sits in the **template author's trust domain** (§7), so hiding
primitives from it protects nothing. The model generalizes to three tiers:

| Audience | Sees | Why this scope |
|---|---|---|
| templates | primitives | unchanged (DESIGN.md §4) |
| driver | primitives **+** templates | same trust domain as the templates — hiding is pure friction |
| agent | the **inference catalog** | curated, small, schema'd — trust *and* context management |

The **inference catalog** is the agent-facing vocabulary a mini-app chooses to
expose: a subset of its templates, plus — the new expressive power —
**driver-defined entries**: higher-level components and *actions* whose
implementation is the driver's business, invisible to the agent. The agent's
capability ceiling stops being "whatever templates the project has" and
becomes "what the author curated for inference" — strictly tighter, and
semantically richer (an agent that can invoke `checkout` is better off than
one that can only compose a checkout-looking screen).

**The inference catalog is static**: declared in the bundle. `schema.json`
already *is* this file for templates; it grows entries for driver-backed
actions. No driver API needed, and a no-driver project degenerates to exactly
today's model — inference catalog = the project's templates. Static
declaration is what makes the catalog **verifiable on both ends before
anything runs**:

- the *host app author* can check the whole agent-facing surface against
  host/platform rules at load time (nothing appears mid-session that wasn't
  vetted);
- the *mini-app author* can check that the driver actually implements every
  declared action (and nothing undeclared) — the one place authoring-time
  declaration survives §5's demotion, because the counterparty is an agent,
  not the author's own code;
- the *agent side* gets a vocabulary that is fixed for the session — bakeable
  into prompts and tool lists once, no mid-session tool-churn.

### Considered and deferred: dynamic catalog mutation

A driver API for exposing/retracting inference-catalog entries at runtime was
considered and is deliberately **not** part of the design — not "later",
*maybe* later. The motivating example (no `checkout` action while the cart is
empty) turns out to be a category error: it is an **availability** question,
not a **vocabulary** question, and availability is data. A static entry can
carry an availability condition bound to driver-owned data — or, simpler
still, the driver rejects an inapplicable invocation with an error the agent
can read. Either keeps the *vocabulary* fixed and verifiable while the
*applicability* stays as dynamic as the data model already is. Mutating the
catalog itself would trade away static verifiability on all three ends for a
capability nothing yet demands. No message types are reserved for it: the
envelope is versioned (§5), so if a real case ever forces it, adding messages
is an ordinary protocol revision, not something to pre-wire.

One mechanical consequence for the bridge: today it resolves component names
against catalog *templates* only. Driver-sent component updates may reference
primitives directly, so the driver-facing resolution path must include the
primitive library — and the agent-facing path must **not**. Per-audience
resolution scope is the enforcement point for the tiers above.

## 9. Agent and logic together

Three topologies, in order of arrival:

1. **Separate surfaces** — the agent drives its surfaces, the mini-app drives
   its own. No interaction. Works the day drivers exist.
2. **Shared surface, partitioned keys** — e.g. the agent narrates into
   `assistant.*` while logic owns `cart.*`. The write partition (§7) already
   makes this safe.
3. **Driver as mediator** — the agent's messages route *through* the driver
   (validation, enrichment), and the driver exposes its actions to the agent
   through the inference catalog (§8). This is the MCP-shaped future — a
   mini-app whose business actions are agent-invocable. The *vocabulary* for
   it lands early (`schema.json`'s static inference catalog, §8); the
   mediation machinery stays out of scope until 1 and 2 are real.

## 10. State and restoration

Driver state must survive what the platform does to sandboxes: webview
teardown, tab discard, process death. Two candidate mechanisms:

- **Event-sourced replay** — re-run the driver over the event log, the way
  `app.json` replays Transport. Rejected as the primary mechanism: replay cost
  grows without bound, and drivers with external effects (a submitted order)
  must not re-execute them.
- **Explicit snapshot** — the host periodically (and at suspend) requests a
  snapshot; the driver returns a data-vocabulary value; init delivers it back
  on resume. **Chosen.** It puts serialization where the knowledge is (the
  driver knows what's worth keeping) and bounds restore cost. `app.json`
  remains the *cold-boot* story — the recorded driver plays until the live one
  connects, which also covers first-paint latency for remote drivers.

Staged: **the MVP does no restoration at all.** On driver loss or surface
teardown the session is killed on *both* sides and the mini-app cold-boots
from scratch. Snapshot is the designed mechanism — the lifecycle message
types are reserved in the envelope from day one — landed when a real host
needs restore, not before.

## 11. Failure and degradation

The disabled-when-unwired principle, scaled up: **a surface whose driver is
dead must say so, not impersonate a working app.** On heartbeat loss, crash,
or a budget halt (§4), the host — its chrome, not the template; the template
can't know — takes the surface out of service. Tier-1/tier-2 interactions
could technically keep working, but letting them invites the user to build up
work that tier-3 will never persist. Freeze beats betray.

Staged:

- **MVP: the simplest honest thing** — tear the surface down and show a
  host-owned, full-surface failure state (a small BSoD: "this mini-app
  stopped", plus a restart affordance that cold-boots per §10).
- **Later:** freeze the last-good frame, visibly mark it stale, and resume
  from the last snapshot on retry — strictly a refinement of the same policy,
  gated on §10's snapshot work.

## 12. Implementation sketch (slices, each conformance-tested on both adapters)

1. **Protocol + session state machine** — envelope types, handshake,
   ordering, heartbeat, in `a2ui_craft_bridge` (it already owns the
   driver-facing seam). Pure Dart, framework-free.
2. **In-process reference runner + conformance fixture** — a counter/cart
   mini-app as a Dart driver behind zero-length timers (§5's turn-boundary
   rule); the conformance suite drives the *protocol*, so the same suite
   later runs verbatim against sandboxed runners. (The suite is the defense against the per-adapter-drift risk
   NEXT_THREADS grounding #2 identifies.)
3. **Worker runner (Jaspr host) + a JS driver demo** on the site — the first
   proof of constraint 1: logic in a language the engine isn't written in.
4. **Manifest slot + `CraftProjectLoader`** wiring; `craft
   create` gains a logic-bearing variant.
5. **Flutter-host runner** — webview (mobile/desktop) or worker (Flutter
   web); the runner matrix per host platform is the open engineering here.
6. **Server runner spike** — WebSocket transport; optional, proves the
   LiveView-shaped deployment.

## 13. Open questions

- **Inference-catalog action schema** (§8): what a driver-backed *action*
  entry looks like to the agent — arguments, result shape, relationship to
  A2UI's existing function/`checks` machinery.
- **Budget calibration for event floods** (§4): where "energetic user" ends
  and "overload" begins; the halt threshold must clear any humanly-produceable
  rate by a wide margin.
- **Protocol versioning discipline**: what compatibility a host pins — likely
  co-designed with the catalog-versioning open question (DESIGN.md §13).
- **Multi-surface drivers**: one driver, several surfaces (an app with
  windows) — session-per-surface or multiplexed?
- **Driver-initiated template/catalog loading**: may a driver push a new
  catalog version mid-session, and what re-vetting that implies.
- **Snapshot cadence and size budget** (§10).
