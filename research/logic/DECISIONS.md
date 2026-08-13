# Phase 1 implementation decisions — for review

> Running log of decisions taken **while building** that the design docs did not
> settle, or settled differently. Each entry says what was decided, what forced
> it, and what it would cost to reverse. Read alongside
> [BUSINESS_LOGIC.md](BUSINESS_LOGIC.md) (design) and
> [PHASE_1_PLAN.md](PHASE_1_PLAN.md) (plan). Entries are append-only and dated.

## Slice 1 — envelope + session state machine (2026-08-12)

### D1. The driver speaks first

The design says `hello` "exchanges protocol version and requested/granted
capabilities" without saying who opens. **Decided: driver → host `hello`, then
host → driver `init`.**

Forced by the sandboxed transports. A worker, iframe, or webview is not
addressable until it has booted, and the host cannot observe that moment. Having
the driver announce itself makes readiness an event rather than a poll, and
`init` doubles as the host's grant (version accepted, context delivered) so the
handshake stays two messages.

Reversing is cheap while the protocol is at `0.x` — it is two message orderings
in one state machine.

### D2. Package dependencies: `a2ui_core` only

The plan allowed `a2ui_core` + `a2ui_craft`, flagging the second as "an
allowance, not a proven requirement". **It was not needed.** The envelope's
payloads are plain JSON values, and the only imported type is `A2uiMessage`
(which `UpdateMessage` carries verbatim). `a2ui_craft_logic` therefore has no
dependency on the template engine at all — which is the right shape, because a
driver never sees a template.

### D3. Sequence numbers live on the frame, not the message

Messages are values an author constructs; ordering is the channel's business.
`LogicFrame` pairs a message with its sequence number, and each end numbers its
own outbound stream from 1 without gaps. A receiver detects loss, duplication,
and reorder by arithmetic alone — no timestamps, no acks.

Consequence worth noting: this makes the codec independently testable (round-trip
a frame through real JSON text) and keeps the driver-side SDK's job small, which
matters for slice 6's zero-dependency JavaScript SDK.

### D4. Frames carry no per-frame protocol version

Only `hello` and `init` carry `protocolVersion`. Version skew is a handshake
failure, so stamping every frame would be noise that no receiver acts on.

### D5. A received `error` message is terminal

The design says driver exceptions "surface as protocol messages, not silence"
but does not say whether the session survives one. **Decided: it does not.**

A driver whose handler threw has indeterminate state. Continuing would let the
user keep building up work that tier 3 will never persist — precisely the
"betray" half of the design's *freeze beats betray* rule. So an `error` latches
the session into `faulted` with `SessionFaultCode.driverError`, and the MVP
failure card takes the surface out of service.

This is the harshest reading, and it is deliberate for the MVP. If real drivers
turn out to want recoverable per-event errors, the escape hatch is a *new*
message type (`warning`, say) rather than softening `error` — the loud path
should stay loud.

### D6. Sending an illegal message faults this end, too

`send` validates just as strictly as `receive`. Sending something illegal is a
defect on our own side, and letting it through would put the peer into a state
this end cannot reason about. The machine faults symmetrically, so a driver SDK
bug surfaces at the SDK, not three hops later as a mystery on the host.

## Slice 2 — session, driver API, in-process runner (2026-08-12)

### D7. How a driver learns a two-way value: **two** mechanisms, split by scope

The design said an `event` carries "current two-way values" without saying how
the session knows which they are. Building it surfaced that there are really two
different questions, with two different answers:

- **Which row did the user act on?** Answered by the template, in the action's
  own arguments. A2UI resolves an action payload's bindings *at dispatch time
  and in the acting component's data context* — so inside a `ChildList` item,
  `{"sku": {"path": "sku"}}` resolves per row. This already worked; it needed
  only to be recognized and documented.
- **What is on the form right now?** Answered by the session, in
  `EventMessage.values`. It walks the surface's own component properties for
  `{"path": …}` bindings and snapshots each one's current value. No declaration
  from anyone: a template that binds `/cart/total` *is* the statement that
  `/cart/total` matters.

`values` deliberately carries **only absolute paths**. A relative binding inside
a list template has no single value — one component template stands for every
row — so reporting one would be a lie. Those are the first mechanism's job.

The practical effect: a submit handler reads the whole form without the template
enumerating every field, and a per-row handler still gets its row. Neither needs
a contract file.

### D8. The in-process runner encodes frames through real JSON

Not just a deep copy — `jsonEncode`/`jsonDecode`. Two things fall out that a
by-reference in-process channel would have hidden until someone swapped in a
worker: a driver cannot reach a host object by reference, and a value no sandbox
could carry (a `DateTime`, a closure) fails *here*, in development, as a
`driverCrash` with a readable message.

Cost is real — every frame is serialized even when both ends share a heap. It is
the right trade for a runner whose entire job is to be indistinguishable from
the sandboxed one it stands in for, and a future "trusted, same-isolate, no
encoding" runner can be added as a separate class if the cost ever bites.

### D9. Events dispatched before the handshake are held, not dropped

A surface can be tapped while the driver is still booting. Dropping the event
would make an enabled control silently inert — the exact failure the
disabled-when-unwired rule exists to prevent. The session queues pre-handshake
events and flushes them on init. (Slice 4's budget is what bounds this queue.)

### D10. A driver's writes are batched per handler

Every `write` inside one handler accumulates and flushes as a **single** update
frame after the handler's future completes. A handler's effects land on the
surface all at once or not at all — never half-applied — and a handler that
throws discards its writes entirely rather than leaving a partial state behind.

This also means handler ordering is observable and total: handlers are chained,
so a driver never sees two of its own handlers interleave.

### D11. The conformance dimension names a *fixture*, not a driver instance

`runDriverConformance` takes a factory keyed by a fixture **name**
(`'counter'`, `'clamp'`), not a `Driver` object. The in-process factory maps the
name to a Dart class; slice 6's worker factory will map the same name to a
JavaScript file. That is what makes "re-run the suite against the worker" a
proof of language neutrality rather than a second suite that happens to look
similar.

`CraftTester` gained one probe, `settleDriver()`, because a driver's answer is
deliberately *not* available in the turn that caused it: Flutter elapses its
fake clock, Jaspr yields to the real event loop, and neither adapter contains
any other driver-aware code.

## Slice 3 — guardrails and the agent-facing declaration (2026-08-12)

### D12. The reserved namespace is `/host`, and it is *published*, not just defended

The design called for "a reserved namespace the host refuses driver writes to"
but left it abstract. Made concrete: the session writes its `hostContext` into
the surface's data model at **`/host`**, and refuses any driver write that lands
inside it.

Publishing it is the part worth arguing for. It turns host context from a
one-shot payload the driver receives at init into ordinary bound data a
*template* can read — `{"path": "/host/locale"}` works like any other binding,
with no new mechanism. The namespace then defends itself for the obvious
reason: there is exactly one writer per key, and this one is the host.

Two writes are refused, not one: anything under `/host`, and a write to the
**root path**, which would swallow the namespace wholesale. The second is easy
to miss and would have quietly defeated the first.

### D13. Scope is a ceiling too: a driver may address only its own surface

Not in the design, but it falls out of the same principle and cost nothing.
A driver is given one surface; a message aimed at any other is refused with
`scopeViolation`. Without this, `DeleteSurfaceMessage(surfaceId: 'someone
else')` was reachable from any driver, which makes the "a driver gets exactly
the agent's power" claim weaker than it sounds.

### D14. Vetting is per-batch, not per-message

A batch containing one illegal message is refused **whole**. This preserves the
all-or-nothing property the driver's own per-handler batching already provides:
a refusal must not be able to leave the surface in a state no handler ever
intended. The test puts the offending write *second* precisely so that
per-message enforcement would fail it.

### D15. The dev-mode diagnostic needs a named-handler shape to exist at all

"Report events that arrived with no handler" is undetectable inside a `switch`
statement — the driver silently falls through and nothing knows. So the SDK
gains `HandlerDriver`, a driver that dispatches from a name→handler map. That is
what makes both halves of the mistake visible: an event with no handler is
reported through `DriverContext.diagnostic`, and `unusedHandlers` names handlers
nothing ever dispatched to.

`HandlerDriver.handledEvents` is also exactly the set
`InferenceCatalog.unimplementedActions` checks against, so "the driver
implements every action it advertises" becomes a one-line assertion in a
mini-app's own tests rather than a hope.

Diagnostics route to a `DriverDiagnosticSink`; the default is assert-gated
(loud in JIT/debug, stripped from release), and `silentDiagnostics` states the
production posture explicitly.

### D16. An unhandled event is a diagnostic, not a fault

A dead control is a wiring mistake, not a crash. Faulting would take down a
working mini-app over one mistyped event name. The session stays up and the
author gets told.

## Slice 4 — channel budgets and the failure path (2026-08-12)

### D17. Calibration: 30 frames/second sustained, 120 of burst

The design left this an open question ("where 'energetic user' ends and
'overload' begins"). Picked, and both sides of the threshold are pinned by
tests: a synthetic flood halts, and **ten taps a second for a full minute** does
not.

The asymmetry of the two errors decides it. Guessing low means a real user hits
a wall; guessing high means a runaway loop takes a few hundred milliseconds
longer to stop. So the ceiling sits far above any person — a fast tapper manages
perhaps ten a second, a tremor or stuck key maybe treble that — and still stops
a `while (true) write()` in well under a second. Both constants live in one
named place, `budget.dart`.

### D18. A driver's batch is charged **per message**, not per frame

Not in the design, and it matters more than the rate does: per-handler batching
(D10) means a driver's writes arrive as one frame, so charging per frame would
let ten thousand writes through for the price of one. The inbound bucket takes
one token per A2UI message carried, which is what actually makes the
async-amplification attack cost what it costs.

### D19. The failure path is a *runner*, not a widget

The plan put the BSoD card in this slice. Building it revealed that the card is
the easy half and the wrong half to generalize — it is host chrome, and each
adapter draws its own. What every host needs identically is the lifecycle
underneath it, because `DriverSession` is deliberately one-shot: every terminal
state latches, so something has to hold the *next* session.

`MiniAppRunner` is that something. It owns create-processor → replay `app.json`
→ connect driver → fault → **restart**, so a host answers one question when it
renders: is `fault` null? Draw the surface, or draw your own failure state with
`restart` behind its button.

Restart is a genuine cold start — new processor, replayed recorded stream, new
driver with no memory of the old one — and a test asserts the second driver
starts at zero. That is the MVP restoration policy stated as behavior rather
than as an omission: a half-restored mini-app that *looks* recovered is worse
than one that plainly starts over.

The rendered failure card lands with the first real host (slice 5's cart), where
there is a surface to actually take out of service.

## Slice 5 — the cart mini-app (2026-08-12)

### D20. Mini-apps live outside `samples/`, and outside the gallery

A sample is renderable on its own; a mini-app is not. Put the cart in the
gallery and it becomes exactly what the design warns against — "a lie shaped
like an app", every control wired and nothing answering — for any host that
doesn't load its driver.

So the project data lives in `mini_apps/cart/` and is baked by the same
generator into `rawMiniApps` / `cartMiniApp`, keeping the code-free-data-is-the-
source-of-truth property. The Dart driver lives in `lib/src/mini_apps/` because
code cannot live in the data tree.

### D21. `kind: "builtin"` means "the host compiles this driver in"

The manifest's `logic.kind` vocabulary already had the slot; the cart uses it.
A Dart driver cannot be *fetched* — it has to be linked — so `builtin` names a
driver the host resolves from its own registry, and `entry` is the registry key
rather than a file path. The JavaScript port in slice 6 will use
`kind: "worker"` with `entry` as a real relative path, which is the case the
loader has to handle for real.

### D22. Conformance renders the *shipped* project, not a look-alike

`CraftTester.buildAdapter` gained an optional `templateSource`, registering a
project's own `.craft` under a `project` library instead of the demo catalog.
Small change, large consequence: the cart case exercises the real
`template.craft`, the real `schema.json`, and the real recorded boot stream, so
the conformance suite can no longer pass while the shipped project is broken.

`activateButton(label)` came along with it, because a real screen renders
several buttons under one A2UI component and keying by component id cannot say
which control the user pressed.

### D23. Cold boot is asserted on the model, not on the screen

The first version of the cart case asserted the pre-connect status text after
mounting, and failed on Jaspr — mounting is itself a turn of the event loop
there, so the driver had already answered. The fix is not a longer wait but a
better question: cold-boot completeness is a property of the *surface*, so
assert it on the data model before mounting, and assert only post-connect state
on screen. A test that depends on out-racing the driver is testing the harness.

### D24. Finding: templates cannot format numbers

Writing the cart surfaced a real gap. The standard function library has
`divide`, `floor`, `mod` — but nothing that turns a number into a *string*, so
there is no way to render `8900` cents as `"89.00"` in a template. Currency
display is limited to whole units.

The cart prices in whole dollars and says so in a comment rather than hiding it.
The gap belongs to workstream B (template computation): a `format`/`toString`
function with a precision argument would close it, and it is exactly the kind of
pure, local derivation tier 2 is for — pushing it to the driver would make every
price change a round trip.

## Slice 6 — the JavaScript worker runner (2026-08-13)

### D25. The worker channel carries JSON **text**, not structured-cloned objects

Structured clone would have worked and been marginally faster. Text won on three
counts: it is what a socket or a platform channel carries anyway, so the JS SDK
makes no assumption about which host is on the other end; it makes a
non-serializable value fail at the author's desk rather than at some later
transport boundary; and it keeps the SDK free of `dartify`/`jsify` asymmetries
that would otherwise leak into the protocol's definition.

### D26. The runner prepends the SDK, so a mini-app's logic is **one file**

`WorkerDriverRunner.fromSource` concatenates `driverSdkJs` with the driver's own
source and starts the worker from a blob. An ephemeral, CDN-delivered mini-app
should not have to host, resolve, and version a second file just to speak the
protocol. `fromUrl` remains for the production shape, where the script loads the
SDK itself.

`js/driver.js` is the source of truth — real JavaScript with real tooling — and
a generator bakes it into a Dart constant, with a `check.sh` drift guard, the
same pattern the sample and theme generators already use.

### D27. H1 and H2 are proven, and the proof is that nothing was edited

`packages/a2ui_craft_jaspr/test/driver_worker_test.dart` re-runs the **entire**
driver conformance suite — including the shipped cart — against drivers written
in JavaScript running in a web worker. It imports the suite's entry point and a
different runner factory, and nothing else: no case redefined, relaxed, or
skipped.

That required extracting the Jaspr conformance harness out of
`conformance_test.dart` into `conformance_harness.dart`, since two suites now
run through it.

### D28. The heartbeat exists now, and it is a real knob

The protocol reserved ping/pong from slice 1 but the session never sent one. A
crashed worker fires an error event; a *hung* one fires nothing at all, so
without a probe a surface would sit looking healthy forever. `DriverSession`
now probes on an interval with a one-interval deadline — one knob, not two —
and `null` disables it.

### D29. Finding: a periodic timer is a leak inside a Flutter widget test

Adding the probe broke the Flutter driver conformance immediately: fake-async
rightly reports a pending periodic timer as a leak, and `addTearDown` runs after
that check. Worth knowing for any host embedding a mini-app in widget tests —
dispose the session inside the test body, or pass `heartbeat: null`.

The conformance suite takes the second option, and `MiniAppRunner` gained a
`heartbeat` parameter to forward. Liveness is proven where a driver can actually
hang: `a2ui_craft_logic`'s browser test, against a real worker that stops
listening.

## Slice 7 — manifest, loader, site, CLI (2026-08-13)

### D30. The `logic` slot parses **strictly**, unlike the rest of the manifest

`ProjectManifest.parse` is deliberately total: a malformed theme block leaves a
project unthemed. `LogicManifest` cannot work that way. An *absent* slot is
fine — that is an ordinary pure-UI project — but a slot that is present and
unreadable throws, because the alternative is loading a mini-app with its logic
quietly missing.

Totality is the rule for **untrusted, agent-supplied data**. A project's own
declaration about itself is a different thing, and it gets to be wrong out loud.

Same reasoning behind refusing a project that requests a capability this version
cannot grant: running it with less power than it says it needs fails exactly
like running it with none, only later and less legibly.

### D31. The driver's source is data-only's one exception, and it is contained

DESIGN.md §10 said a project contains "data only — no code". A mini-app ships a
driver, so §10 now names the exception and bounds it: the driver never executes
in the host's context. It runs in a sandbox granted nothing but an asynchronous
channel, over which it may only send A2UI Transport messages — so §11's
no-arbitrary-code-in-the-payload invariant holds where it matters, at the
surface.

### D32. The failure card is per-host chrome, and now there are two of it

D19 predicted this: the runner generalizes, the card does not. The site has two
— a Flutter `_StoppedCard` and a Jaspr `_stoppedCard` — saying the same thing
("This mini-app stopped", the fault, a *Start over* button wired to
`MiniAppRunner.restart`). That duplication is correct: each is drawn in its own
framework's idiom, and neither belongs in a published package.

### D33. Verified live, not just under test

The site's `/mini-app/cart` route runs the shipped project twice, side by side:
the Jaspr pane starts the project's own `cart.js` in a **web worker**, the
Flutter pane runs the Dart port compiled in. Checked in a browser:

- both cold-boot to "Connecting to the cart…" and both drivers replace it;
- "Add an item" produces the same row, total, and status in both panes;
- typing `7` into the quantity field echoes instantly, and the JavaScript
  driver's authoritative write clamps it back to the 3 in stock, with the
  status reading "Only 3 Mechanical keyboard in stock."

The two panes hold independent sessions, so acting on one leaves the other
alone — which is the separate-surfaces topology (design §9.1) on screen.
