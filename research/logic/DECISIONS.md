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

---

# Amendments after review (2026-08-13)

Review of the entries above overturned three of them and found one bug. The
originals are left standing so the record shows what changed and why.

## A1. **D21 and D30 corrected** — the manifest names a *language*, not a runtime

The reviewed objection: *the app doesn't choose the runtime, the host does.* The
same bundle has to run on a page, in an iframe, in a web worker, in a webview,
and inside an embedded engine like QuickJS. A project that declares
`"kind": "worker"` has made itself un-portable across web and mobile in exchange
for nothing.

The slot is now:

```json
"logic": { "entry": "cart.js", "language": "javascript", "capabilities": [] }
```

and `requireSupported` asks *can this host run JavaScript?* rather than *does
this host support workers?* A `HostLogicSupport` value carries what a host can
do; nothing in it names a sandbox, and a test pins that there is no key a
project could use to name one.

Two things survive as genuinely app-level. **Bundled-versus-remote** is the
project's to declare — "my logic lives on my server" is a fact only the author
knows — so `url` and `entry` are mutually exclusive shapes. And the one
runtime-adjacent thing an app can legitimately demand (origin isolation for
logic handling a payment token) is a **capability**, a requirement rather than a
preference about mechanism.

`builtin` is gone from the schema entirely, which makes the code consistent with
D21's own stated reasoning: a Dart driver compiled into a host is a **host
substitution**, not something a project declares. The site's Flutter pane does
exactly that and always did — it passes `CartDriver.new` directly, having read a
manifest that asks for JavaScript.

## A2. **D31 withdrawn** — there was no exception to make

D31 amended DESIGN.md §10 to read "data only — with one deliberate exception"
and then argued the exception was contained. That was wrong, and it is the way a
clean invariant erodes: once "data only, except…" exists, the second exception
argues from the first.

From the renderer's side **there is no exception**. A renderer receives A2UI
Transport messages and cannot tell whether they came from an agent, a recorded
stream, or a driver. The driver is on the far side of an asynchronous boundary.
Nothing about the templating system's data-only constraint is weakened by its
existence.

What is genuinely shared is only the *bundle format*, and the honest statement
about that is much weaker: **the manifest is an open map**; the engine reads the
keys it owns and ignores the rest; a layer above may claim keys of its own. That
was already true in code — `ProjectManifest.parse` ignores unknown keys, which
is why the slot needed no change there — so §10 now says that and nothing more.
The `logic` key's schema, semantics, and sandbox argument live entirely in
BUSINESS_LOGIC.md §6.

The reviewed suggestion to split the templating design doc from the logic design
doc is the same instinct one level up, and it is right for the same reason. Not
done here (it is a large doc reorganization), but recorded as the direction.

## A3. A real bug: **writes could escape their handler's turn**

Not a design question — a defect, found in review. Given:

```dart
void onEvent(ctx, event) {
  fetchSomething().then((v) => ctx.write('/x', v));   // not awaited
}
```

the handler returned, `_flush()` shipped its (empty) batch, and the late write
landed in `_pending` where it **sat until the next handler flushed it** —
arriving out of order, attributed to an unrelated later event, or never at all
if no further event came. The driver's model and the surface's would then
disagree with nothing to say so, which is the worst failure shape available
here.

Fixed on both sides: a turn flag, and a write arriving outside a turn is
reported loudly *and flushed immediately as its own update*. Shipping it alone
is honest about when it happened and cannot corrupt anyone else's batch, and the
driver plainly meant the write. A guard pins both halves and was shown to fail
against the pre-fix code.

This matters more in **JavaScript**, where there is no `unawaited_futures` lint
and the runtime check is the only defense — which is most of the argument for
doing it at runtime rather than leaving it to tooling.

## A4. D1 and D13 are one gap, not two

Review sharpened what D1 actually settled. "The driver speaks first" answers
*who sends the first frame on an already-established channel*. It does **not**
answer *who initiates the experience*, which this implementation answers the
same way every time: the host. `MiniAppRunner` builds the processor, replays
`app.json`, then connects.

That excludes a real case — a server deciding a chat answer is better expressed
as a template, and pushing one. And it is the *same* limitation D13 registers
from the other side, because both come from one fact: **a session is pinned to
exactly one host-chosen surface.** A driver can send `createSurface` today, but
only for the id the host handed it in `init`.

Closing it is one change, not two: `init` grants a *set* of surfaces (possibly
empty, with the driver permitted to create), and the scope guard becomes
`granted.contains(target)` instead of `target == surfaceId`. The guard stays
exactly as meaningful. Nothing in the envelope blocks this — `surfaceId` is
already on `init` and on every `event`.

One distinction worth keeping separate, because the motivating example hides
two different needs. *One driver, N concurrent surfaces* is multiplexing. *A
shop remembering the cart was not empty last time* is state surviving surface
teardown — sequential, not concurrent — which is much closer to the
snapshot/restoration question (§10, deliberately unbuilt) than to multiplexing.
Agent-partitioning needs the first; continuity needs the second. Different
costs, different failure modes, plan separately.

## A5. Known smell: `a2ui_craft_testing` depends on `a2ui_craft_examples`

Not fixed, recorded. The shared conformance suite now knows about one specific
demo project, so that the driver dimension can render the *shipped* cart rather
than a look-alike (D22). Both packages are unpublished and nothing ships wrong,
but a suite that is supposed to specify the framework should probably not import
a particular app.

Related and milder: `mini_app_worker_conformance_test.dart` lives in the Jaspr
package because rendering needs a renderer and that is the only browser-capable
harness here — a practical reason, not an architectural one. The published
adapter libraries have no logic dependency (verified); the edge is dev-only, via
this same testing package. Renaming the file (it was `driver_worker_test.dart`,
which reads like WebDriver) removed the worst of the confusion, but the
placement is worth revisiting alongside the dependency above.

---

## Hardening pass (2026-08-21) — what the pre-merge review found, and what changed

Before merging `logic` into `main`, a multi-angle review of the whole branch
diff surfaced a cluster of genuine holes — most of them in the **fault
taxonomy**, which is exactly the part whose design promise is "a dead driver
must say so." Each fix below is pinned by a test that was verified to fail
against the pre-fix code (or is new behavior with its own guard).

## A6. Every decode failure is a `malformed` fault — the A2UI codec's included

`LogicFrame.fromJson`'s `update` case delegated to `A2uiMessage.fromJson`,
whose validation and cast errors are not `LogicProtocolError` — so a bad A2UI
payload inside a well-formed frame sailed past `receiveJson`'s catch *and*
`DriverSession._receive`'s, surfacing as an unhandled async error while the
session stayed `ready`. Trivial to hit from JavaScript, where `ctx.send()`
hands author-built objects straight to the wire. The envelope now converts
every decode failure into `LogicProtocolError`; nothing downstream has to
remember to.

## A7. Terminal means *told*: terminate, handshake timeout, and JS faults

Three ways a session could end (or fail to start) without the host learning:

- **An inbound driver `terminate` latched the machine and told nobody.** The
  user kept tapping a fully-enabled dead cart; the heartbeat cancelled itself.
  Now surfaced through `onFault` as `driverTerminated` — not a failure, but
  the host's obligation (take the surface out of service) is identical, so it
  travels the same channel. `DriverSession.fault` covers it too.
- **No handshake deadline.** A worker that loads cleanly but never calls the
  SDK produces no crash event, and pings are only legal on a ready session —
  so the surface said "Connecting…" forever while events queued without bound
  (the production flaky-network case). `handshakeTimeout` (default 10s) faults
  with the new `handshakeTimedOut` code; the queue is bounded by it.
- **The JS SDK's `fault()` discarded its reason and posted nothing** — a
  driver that detected out-of-order framing or version skew just went quiet,
  which a heartbeat-less host waits on forever and a heartbeat host misreports
  as `heartbeatLost`. It now posts an `error` frame naming the real code
  before latching, mirroring the Dart runtime.

## A8. The scope check names its allowances; the surface's lifecycle is the host's

`_isPermitted`'s wildcard arm bound the *session's* `surfaceId`, making the
scope comparison vacuously true for any message type not enumerated — an
invisible allow, and `A2uiMessage` is not sealed. The arm is now an explicit
`null` ("no surface target — nothing to scope-check"). And a driver deleting
*its own* surface — in scope, and permitted — nulled `MiniAppRunner.surface`
while `fault` stayed null, so both site hosts died on `surface!` instead of
showing the stopped card. Deleting is now refused: a driver recomposes within
its surface or replaces it with `createSurface`; only the host removes it.

## A9. The budget charge is clamped at burst capacity

Per-message charging was right (a ten-thousand-write batch must not cost one
token), but unclamped it made any single batch larger than the burst (120)
**permanently** undeliverable — the bucket can never hold more — so a form
seeding 150 paths in `onInit` faulted as "looping, not responding" on the
session's first frame, deterministically, on every restart. The charge is now
`min(batch, capacity)`: a full-capacity batch is legal exactly once per
drained-and-refilled bucket, so the sustained rate still governs over time.

## A10. `close()` really stops the in-process driver; `Driver.onTerminate` exists

`InProcessDriverRunner.close()` dropped its handlers and nothing else — and
because `dispose()` queues the farewell `terminate` and then closes in the
same turn, the deferred frame was discarded by close's own guard. The runtime
stayed `ready` forever; every restart leaked a live driver, while
`WorkerDriverRunner.close()` really terminates its worker — precisely the
observable difference the in-process runner exists to not have. Now: frames
already in flight still deliver, and close schedules `DriverRuntime.stop()`
behind them. Author-opened timers are the one thing nothing else in the
isolate can cancel, so `Driver.onTerminate(reason)` (default no-op; also
`onTerminate` in the JS SDK) is where a driver lets go of what it holds.

## A11. One wire discipline for the JS SDK's own failures

`post()` claimed a sequence number before `JSON.stringify` ran, so a
non-serializable write burned a seq and desynchronized the stream — the host
then faulted with a misleading `outOfOrder`. Serialization now happens before
the seq is claimed, and an unencodable frame is reported as `driverCrash`
(matching both Dart runners). The worker runner's inbound path got the same
honesty: a message that is not a JSON frame (a library's stray `postMessage`,
a debug string) is reported through `onCrash` instead of being dropped to
surface later as a baffling ordering fault.

## A12. The carts now share their integer semantics — and the suite would notice

`parseInt` reads prefixes (`'2x'` → 2) and Dart's parser reads `0x` hex
(`'0x3'` → 3 where `parseInt` yields 0 — one cart deletes the row, the other
stocks three), so the "identical" drivers diverged on any non-clean input,
and the conformance suite only ever typed `'7'`. Both ports now guard with
the same regex (`^[+-]?[0-9]+$`; digits and nothing else), and the cart
conformance case types `'2x'` — the step that fails if the semantics ever
drift apart again.

## A13. The production load path runs (or refuses) logic projects

`CraftProjectLoader` ignored the manifest's `logic` slot entirely, so the
scaffolded README's own instructions — `craft create --logic`, deploy, paste
the URL — produced dead chrome frozen on "Connecting…": the exact inert-chrome
outcome the design forbids, with `requireSupported` having zero non-test
callers. The deeper cause was a **second parser**: `LogicManifest.parse`
existed beside `ProjectManifest.parse`, and callers spliced JSON strings to
reach it. Now one file has one parser (`ProjectManifest.logic`, populated by
`LogicManifest.read`; the logic slot is the one *non-total* part of manifest
parsing, by A1's own argument), the loader takes a `HostLogicSupport`
(default `none` — refuse with a reason), fetches a bundled driver's source as
text, and the site's `/load` screen runs it in a worker on both panes.
`WorkerDriverRunner.fromUrl` is demoted from "the production shape" to the
niche it is (scripts that import the SDK themselves); fetch-and-`fromSource`
is the production shape, because the published file then needs no import.

## A14. Sundry, from the same review

- The JS SDK's `PROTOCOL_VERSION` is a hand-copy of `logicProtocolVersion`;
  the SDK generator now fails if they disagree, so a version bump cannot
  silently strand every JavaScript driver.
- `_boundValues` re-walked every component's property tree per event; the
  path set only changes on structural updates, so it is cached and
  invalidated by `createSurface`/`updateComponents`.
- A faulted session now runs the same teardown as `dispose` (listener
  removed, queue cleared) instead of staying subscribed to the long-lived
  action notifier.
- `MiniAppRunner` reads the surface id from the boot stream's own
  `createSurface` (hosts stop repeating it out of band; the site's mini-app
  screen no longer hardcodes `'cart'`, and its Dart stand-in is a per-app
  registry), and its `fault` reads through to the session instead of
  mirroring it across four hand-synced sites. A boot stream that creates no
  surface is refused loudly.
- The driver conformance suite settles on the *session's own readiness*
  before its first assertion instead of a fixed eight turns — a worker's boot
  is wall-clock time no turn count guarantees; a loaded CI machine now slows
  the test instead of failing it.
- The publishing skill knows the fifth public package (dependency order,
  dry-run list, version-sync grep); DESIGN.md §5/§12 list `a2ui_craft_logic`
  and its depends-only-on-`a2ui_core` rule; `site/lib/flutter_host.dart`'s
  duplicate measuring render object folded into the existing one (the copy
  had already dropped the convergence guard).

- Live verification of the `/load` path surfaced one more real bug, in the
  new wiring itself: handing two runners (or one runner twice) the **same
  decoded message instances** leaks state between boots — the data model
  adopts the value objects a message carries, and a driver's writes mutate
  them in place, so the second boot starts from the first session's
  leftovers. The gallery path had masked this by re-decoding JSON per boot.
  `MiniAppRunner.coldBoot` now documents the freshly-decoded contract and the
  load screen decodes per boot.

### A15 — Second pre-merge pass (2026-08-21)

A second review, run after the first pass's fixes landed, found four things
the first missed — all of them guards that only held for the *spelling* they
were written against:

- The host-namespace guard compared raw strings, but the data model's parser
  is deliberately forgiving: a leading slash is optional, a trailing one is
  dropped, and `''` and `'//'` both mean the root. So `host/locale` walked
  into the host's namespace and `''` replaced the whole model — the two things
  the guard exists to prevent, reachable by writing them differently. It now
  compares *resolved segments*, and the reserved segment is derived from
  `hostReservedNamespace` rather than restated.
- `DriverSession.dispose` cancelled the handshake timer without completing
  `ready`, so a host that awaited it and then tore the surface down waited
  forever for a handshake nobody was still watching for — the same lie the
  handshake deadline exists to prevent, one layer up. Disposal completes it
  with a `StateError`: a deliberate ending by the host is not a fault (`fault`
  stays null), but it is still an ending.
- `MiniAppRunner._boot` let a bad boot stream throw out of `start` — and out
  of `restart`, i.e. out of the "Start over" button of the failure state that
  was rendering it. A project's `app.json` is only *decoded* by the loader;
  this is where it is first *applied*, and an escape left the runner in the
  one state it documents as impossible: no surface, no fault. It faults with
  `malformed` instead.
- The JS SDK called `onTerminate` synchronously from the message handler while
  `DriverRuntime` runs it on the handler chain. A JS driver suspended on a
  promise got its teardown run mid-handler; the Dart port of the same driver
  did not. The chain is now appended to directly (not via `run`, whose failure
  path would report a fault on a session that has already ended).

**Recorded, not done:** mini-app panes still bypass `SampleView`, so a themed
logic project renders unthemed — the right fix is an externally-owned-surface
mode on `SampleView`, deferred with A5. The JS SDK still trusts frame bodies
it decodes (no per-field validation like the Dart machine's) — the fault
*reporting* now matches, the legality table's rigor does not yet.
