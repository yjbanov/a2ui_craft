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
