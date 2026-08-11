# Drivers Phase 1 — the reference implementation

> **Status: plan (2026-08-09), shovel-ready.** Companion to
> [BUSINESS_LOGIC.md](BUSINESS_LOGIC.md) (the design). This phase builds the
> **reference driver stack** — protocol, two runners, one mini-app — shipped
> in-repo: it proves the design's hypotheses, and it is the thing interested
> people copy. Repo pattern applies throughout: thin end-to-end slices, each
> conformance-tested on both adapters before the next begins, `check.sh` green
> at every landing.

## What this phase must prove

| # | Hypothesis | Proven by |
|---|---|---|
| H1 | **Language neutrality**: the coupling surface is the protocol, so logic can be written in a language the engine isn't | the same mini-app runs with its driver in **Dart** (in-process) and in **JavaScript** (web worker), one conformance suite passing against both |
| H2 | **Asynchrony is livable**: always-async handlers + two-way echo keep the UX correct at any latency, and the in-process ↔ sandboxed swap is unobservable | slice 2's protocol-level conformance cases run **verbatim** against the worker runner in slice 6 — zero template or test edits |
| H3 | **Templates stay decoupled**: a template names only events and data paths | swapping the cart's driver implementation (Dart ↔ JS) requires zero template changes — enforced by the contract file, not by review |
| H4 | **The security posture holds at the channel**: budgets both directions, write partition, loud failure | slice 3 (contract enforcement) + slice 4 (budget halt, BSoD path) |

## The reference mini-app: `cart`

A small shopping cart, chosen because it exercises every tier of the latency
discipline (design §4) without being a toy *or* a product:

- **tier 1** — expand/collapse an item's details: template `state`, never
  crosses the wire;
- **tier 2** — price *formatting*: template functions;
- **tier 3** — add/remove item, quantity change, `checkout`: driver events →
  data writes.

And the two protocol behaviors worth demonstrating on purpose:

- **optimistic echo + authoritative correction** — quantity is two-way bound
  (echoes instantly); the driver clamps it to stock and writes the clamped
  value back;
- **a driver-backed action in the contract** — `checkout` is declared as an
  inference-catalog entry (design §8). No live agent in this phase; the
  declaration proves the contract shape, not mediation.

The project ships the *same driver twice*: `drivers/cart.dart` and
`drivers/cart.js`, observably identical. That pair **is** the H1 exhibit.

## Scope guards (MVP, per the design's staging)

No restoration (kill both sides, cold-boot — design §10). Failure is the BSoD
card (§11). No dynamic catalog (§8). No coalescing — floods halt (§4). Runner
matrix is in-process Dart + Jaspr-host web worker only; webview, server, and
Wasm runners deferred. `capabilities: []`. No agent mediation.

## Slices

### 0. Grounding test — pin the programmatic drive path

Before designing types, pin where the session layer clips in: a pure-Dart test
(no UI) that plays a Transport stream into the bridge/`a2ui_core` surface and
receives a user action + a two-way write back out. This is the repo's
cheapest-empirical-step-first pattern: it documents today's exact seam
(`A2uiComponentBinding`/`GenericBinder` on one side, the action/setter
callbacks on the other) and becomes the harness every later slice drives
through.

**Test:** the grounding test itself; it lands with slice 1 if trivial alone.

### 1. Protocol — envelope + session state machine (pure Dart)

In `a2ui_craft_bridge` under `src/driver/`, **dependency-light by design** so
it can later split into a published `a2ui_craft_driver` package for driver
authors without dragging the host half along.

- Message envelope: `hello`, `init`, `event`, `update`, `error`, `terminate`,
  heartbeat. (`suspend`/`resume`/`snapshot` are *named* in the version doc as
  reserved, not implemented — design §10.)
- Monotonic sequence numbers, ordered-delivery assertion, last-write-wins per
  root key.
- Version negotiation in `hello`; skew fails the handshake loudly.
- JSON codec over the `DynamicContent` value vocabulary.

**Tests:** codec round-trips; state-machine legal/illegal transitions;
version-skew handshake failure; ordering violations detected.

### 2. Host session + in-process runner + the driver dimension in conformance

- `DriverSession`: binds the envelope to an `a2ui_core` surface — outbound
  user actions/two-way writes become `event` messages; inbound `update`
  messages feed Transport ingest.
- The Dart driver API: `abstract class Driver { onInit(ctx); onEvent(e); }`
  emitting messages — the shape `cart.dart` and the JS SDK both mirror.
- `InProcessDriverRunner`: runs a Dart driver behind **zero-length timers**,
  not microtasks — the design's turn-boundary rule (§5): a worker's
  `postMessage` reply cannot arrive within the turn that dispatched the
  event, so neither may this runner's, or it is observably *more prompt* than
  what it stands in for and code grows a same-turn-delivery dependency the
  worker then breaks. Both directions (event out, update in) cross a turn
  boundary.
- A conformance case pins the rule: after dispatching an event, a microtask
  queued *later* in the same turn must still run before the driver's reply is
  observable. Prove the guard fails against a microtask-scheduled runner.
- **Conformance gains a driver dimension**: protocol-level cases (event in →
  write out → rendered result) written once in `a2ui_craft_testing`,
  **parameterized by runner**, initially bound to the in-process runner, run
  on both adapters. Fixture: a counter driver.

**Tests:** the new conformance cases on Flutter + Jaspr; session lifecycle
unit tests.

### 3. Contract file + enforcement

- `contract.json` schema: declared events (name + argument shape), owned data
  keys (name + value shape), inference-catalog entries (exposed templates +
  driver-backed actions — `checkout`'s declaration lands here).
- Host-side enforcement in `DriverSession`: an out-of-contract write is
  rejected *before* touching the model and faults the session; an undeclared
  event name is refused at template-bind time.

**Tests:** a violation matrix (undeclared key write, host-key write,
undeclared event, wrong-shaped argument), each proven to fault; the
guard-fails-against-pre-fix-code rule applies — assert the violations pass
silently with enforcement stubbed out, then that they fault with it on.

### 4. Channel budgets + the failure path (BSoD MVP)

- Token buckets on the channel, both directions (design §5): driver `update`
  spam and upstream event floods each drain one; exhaustion faults the
  session.
- Threshold calibrated to clear any humanly-produceable event rate by a wide
  margin (design §13) — the calibration constant lives in one named place.
- Faulted session = terminal state exposing a reason; the reference hosts
  (site, example apps) render the host-owned full-surface failure card with a
  restart affordance that cold-boots (kills both sides, replays `app.json`).

**Tests:** synthetic flood trips the halt; a generous-but-human interaction
rate does not (pins the threshold from both sides); fault reason surfaces;
restart re-runs `init` from scratch.

### 5. The cart mini-app on the Dart driver, both adapters

Project files (`template.craft`, `schema.json`, `contract.json`, `app.json`
cold-boot stream, manifest) + `drivers/cart.dart`, rendered through the
existing sample infrastructure on **both** adapters.

**Tests:** scripted end-to-end conformance — add item, change quantity past
stock (assert echo *then* clamp-back), checkout (assert confirmation state) —
identical on Flutter and Jaspr via the in-process runner.

### 6. JS worker runner + `cart.js` — the language-neutrality proof

- A single-file, zero-dependency ES-module driver SDK (`driver.js`): wraps
  `postMessage`, exposes the same `onInit`/`onEvent` shape as the Dart API,
  speaks the slice-1 envelope verbatim.
- `WorkerDriverRunner` in `a2ui_craft_jaspr`: spawns the worker, bridges
  `postMessage` to `DriverSession`. The package already runs
  `@TestOn('browser')` tests, so the worker executes for real in Chrome under
  CI — no simulation.
- Port the cart driver to `cart.js`.

**Tests:** the slice-2 conformance cases and the slice-5 cart script run
**against the worker runner with no edits** — that unmodified re-run is H1
and H2's proof, so resist any urge to fork the suite. Plus worker-specific
cases: worker crash → fault → BSoD; heartbeat loss → same.

### 7. Manifest + loader + site + CLI

- `ProjectManifest` gains the `logic` slot (`kind`, `entry`, `contract`,
  `capabilities`); `CraftProjectLoader` fetches contract + driver source;
  unsupported `kind` refuses to load with a reason (design §6).
- The site gallery ships the cart mini-app — Jaspr pane on the **worker**
  runner, Flutter pane on the **in-process Dart** runner: one mini-app, two
  languages, two runners, side by side. That pane pair is the public
  demonstration of the whole design.
- `craft create` gains a driver-bearing variant scaffolding both drivers.
- Docs: DESIGN.md §10's manifest slot updated from "empty for now";
  BUSINESS_LOGIC.md status flips to *implementing*; README pointer.

**Tests:** loader round-trip incl. the refusal path; site build; existing
sample tests stay green.

## Sequencing notes & risks

- **The central architectural risk is per-adapter drift** (NEXT_THREADS
  grounding #2). Mitigation is structural: the protocol, session, contract
  enforcement, and budgets live *once* in the bridge; adapters contribute only
  runners. Nothing in slices 1–4 is written twice.
- **Slice order is dependency order**, but 3 and 4 commute; pull 4 earlier if
  flood-halt wiring turns out to be needed for 3's fault plumbing.
- **Flutter-host sandboxed runner is deliberately absent** — the Flutter pane
  proving in-process Dart is enough for this phase; webview/isolate runners
  are the next phase's opening question.
- **Protocol version starts at `0.x`** with handshake enforcement live from
  slice 1, so breaking the envelope during the phase is cheap and *visible*.
