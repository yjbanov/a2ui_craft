# a2ui_craft_logic

Business logic for [A2UI Craft](https://github.com/yjbanov/a2ui_craft) mini-apps.

A2UI Craft templates render; they do not decide. A template binds data, holds
ephemeral widget state, and dispatches events — and nothing else. Something on
the far side of an asynchronous channel answers those events: a live agent, a
recorded message stream, or — with this package — an author-written program.

That third thing is a **driver**, and this package defines the session protocol
it speaks, plus the host-side session and the reference runners.

## Why a protocol and not an API

Two constraints shape the whole design:

1. **No coupling between the template language and any logic language.** A
   `.craft` template must not name, import, or type-check against constructs of
   JavaScript, Dart, or Kotlin.
2. **Communication is asynchronous, always** — so logic can run in a web worker,
   an iframe, a webview, or on a server.

Making logic a *driver* satisfies both structurally rather than by discipline.
The template names events and data paths, both plain strings over a
JSON-isomorphic value vocabulary; the entire coupling surface is the wire
format. Any language that can hold state and read and write JSON can implement
it.

## Latency, and why asynchrony is livable

Most interaction never crosses the wire:

| Tier | Mechanism | Latency | Belongs here |
|---|---|---|---|
| 1 | template `state` + `set` | none | open tab, draft text, expand/collapse |
| 2 | template functions | none | formatting, arithmetic, visibility conditions |
| 3 | driver event → data write | round-trip | validate, submit, fetch, persist |

Rule of thumb: **if it must survive the surface, or have effects beyond it, it
is tier 3.** Two-way bindings write the local data model immediately — the
control echoes the user at tier-1 latency — and the driver corrects it
afterwards if it disagrees.

## Status

Early development. The envelope is versioned from day one and version skew
fails the handshake loudly, so breaking it while it is at `0.x` is cheap and
visible.
