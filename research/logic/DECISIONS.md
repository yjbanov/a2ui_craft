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
