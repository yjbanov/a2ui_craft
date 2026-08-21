// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:math' as math;

import 'package:a2ui_core/a2ui_core.dart';

import 'budget.dart';
import 'envelope.dart';
import 'fault.dart';
import 'session_machine.dart';
import 'transport.dart';

/// The data-model namespace the host keeps for itself.
///
/// A session publishes its `hostContext` here — locale, display mode, whatever
/// else the host maintains — so templates can bind `/host/locale` like any
/// other data, and refuses any driver write that lands inside it. The host
/// knows its own keys, so nothing has to be declared: enforcement is by
/// namespace, by the party that owns it.
const String hostReservedNamespace = '/host';

/// The host-side half of a driver session.
///
/// Binds a [DriverTransport] to a rendered surface: user actions leaving the
/// surface become `event` messages, and the driver's `update` messages are fed
/// straight into A2UI Transport ingest.
///
/// It layers entirely on public API — `MessageProcessor.processMessages`
/// inbound, `SurfaceGroupModel.onAction` outbound, `DataModel.get` for
/// event-time binding snapshots — so no engine package knows drivers exist and
/// a host that never loads one pays nothing.
class DriverSession {
  /// Creates a session driving [surfaceId] within [processor]'s surface group,
  /// talking to a driver over [transport].
  DriverSession({
    required this.processor,
    required this.surfaceId,
    required this.transport,
    this.hostContext = const <String, Object?>{},
    ChannelBudgets? budgets,
    this.heartbeat = const Duration(seconds: 5),
    this.handshakeTimeout = const Duration(seconds: 10),
  }) : budgets = budgets ?? ChannelBudgets();

  /// The processor whose surface group holds the driven surface.
  final MessageProcessor<ComponentApi> processor;

  /// The surface this session drives.
  final String surfaceId;

  /// The channel to the driver.
  final DriverTransport transport;

  /// Host-owned context handed to the driver at init — locale, display mode,
  /// theme selection.
  final Map<String, Object?> hostContext;

  /// The rate ceilings on the channel, both directions. Draining either halts
  /// the session.
  final ChannelBudgets budgets;

  /// How often to probe the driver for life, and how long it has to answer.
  ///
  /// A driver that stops answering is *detected*, not merely awaited — a hung
  /// worker produces no crash event, so without this a surface would sit
  /// looking healthy forever. One knob: the deadline is one interval, so a
  /// probe that goes unanswered by the next tick faults the session.
  ///
  /// `null` disables the probe, for hosts that have a better liveness signal of
  /// their own.
  final Duration? heartbeat;

  /// How long the driver has to say `hello` after [start].
  ///
  /// The heartbeat cannot cover this window — pings are only legal on a ready
  /// session — and a driver that boots cleanly but never speaks produces no
  /// crash event either. Without a deadline, that driver leaves the surface
  /// saying "Connecting…" forever while user events queue without bound; this
  /// is the flaky-network case a production host meets first.
  ///
  /// `null` disables the deadline, for hosts that manage connection
  /// establishment themselves.
  final Duration? handshakeTimeout;

  final LogicSessionMachine _machine =
      LogicSessionMachine(role: LogicRole.host);
  final Completer<void> _ready = Completer<void>();
  final EventNotifier<SessionFault> _onFault = EventNotifier<SessionFault>();
  final List<EventMessage> _queuedEvents = <EventMessage>[];

  bool _started = false;
  bool _disposed = false;
  Timer? _heartbeatTimer;
  Timer? _handshakeTimer;
  int _pingNonce = 0;
  bool _awaitingPong = false;
  SessionFault? _terminalFault;
  List<String>? _boundPathsCache;

  /// The session's lifecycle state.
  LogicSessionState get state => _machine.state;

  /// Why the session stopped, or `null` while it is running.
  ///
  /// Covers both endings: a machine-level fault, and the driver's own orderly
  /// [TerminateMessage] (surfaced as [SessionFaultCode.driverTerminated],
  /// because the host's obligation — take the surface out of service — is the
  /// same either way).
  SessionFault? get fault => _terminalFault ?? _machine.fault;

  /// Whether the handshake completed and events are flowing.
  bool get isReady => _machine.isReady;

  /// Completes when the handshake completes; completes with a [SessionFault] if
  /// the session fails first.
  Future<void> get ready => _ready.future;

  /// Fires once, when the session faults.
  ///
  /// A host listens here to take the surface out of service: a surface whose
  /// driver is dead must say so, not impersonate a working app.
  EventListenable<SessionFault> get onFault => _onFault;

  /// Opens the channel and waits for the driver to announce itself.
  void start() {
    if (_started) return;
    _started = true;
    // `ready` is a convenience, not an obligation: a host that watches
    // `onFault` instead must not be punished with an unhandled async error if
    // the session fails before the handshake. The listener goes on before
    // anything can fail, because registering one afterwards is a race.
    unawaited(_ready.future.catchError((Object _) {}));
    transport
      ..onFrame = _receive
      ..onCrash = _handleCrash;
    processor.groupModel.onAction.addListener(_handleAction);
    if (hostContext.isNotEmpty) {
      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: surfaceId,
          path: hostReservedNamespace,
          value: hostContext,
        ),
      ]);
    }
    transport.start();
    final Duration? deadline = handshakeTimeout;
    if (deadline != null) {
      _handshakeTimer = Timer(deadline, () {
        if (_machine.isReady || !_machine.isOpen) return;
        _raise(
          SessionFaultCode.handshakeTimedOut,
          'The driver did not complete the handshake within '
          '${deadline.inMilliseconds}ms. Its runtime may have loaded without '
          'ever calling the SDK, or a remote endpoint accepted the connection '
          'and went silent.',
        );
      });
    }
  }

  /// Ends the session in an orderly way and releases everything it holds.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    if (_machine.isOpen) {
      _trySend(const TerminateMessage(reason: 'host disposed the session'));
    }
    _teardownChannel();
    _onFault.dispose();
  }

  /// Releases everything the session holds on the processor and the transport.
  ///
  /// Shared by [dispose] and [_halt] — the two must not drift, because a
  /// faulted session that keeps its `onAction` listener stays subscribed to a
  /// long-lived model, retaining the whole dead session for as long as the
  /// host keeps the processor.
  void _teardownChannel() {
    _handshakeTimer?.cancel();
    _heartbeatTimer?.cancel();
    processor.groupModel.onAction.removeListener(_handleAction);
    _queuedEvents.clear();
    transport
      ..onFrame = null
      ..onCrash = null
      ..close();
  }

  void _receive(Map<String, Object?> frame) {
    if (_disposed) return;
    if (!_machine.isOpen) return;
    final LogicMessage message;
    try {
      message = _machine.receiveJson(frame);
    } on SessionFault catch (fault) {
      _halt(fault);
      return;
    }
    switch (message) {
      case HelloMessage():
        _handshakeTimer?.cancel();
        _trySend(InitMessage(surfaceId: surfaceId, context: hostContext));
        if (_machine.isReady) {
          if (!_ready.isCompleted) _ready.complete();
          _flushQueuedEvents();
          _startHeartbeat();
        }
      case UpdateMessage(:final List<A2uiMessage> messages):
        // One token per message, not per frame: ten thousand writes in one
        // batch is the flood, and charging it as a single frame would let it
        // through. The charge is clamped at the burst capacity, though — a
        // bucket can never hold more than that, so an unclamped charge would
        // make any single batch larger than the burst *permanently*
        // undeliverable, no matter how long the channel sat idle. A
        // full-capacity batch is legal exactly once per drained-and-refilled
        // bucket, so the sustained rate still governs over time.
        final int charge = messages.isEmpty
            ? 1
            : math.min(messages.length, budgets.inbound.capacity);
        if (!budgets.inbound.tryConsume(charge)) {
          _raise(
            SessionFaultCode.budgetExhausted,
            'The driver exceeded the channel budget '
            '(${budgets.inbound.capacity} frames of burst, '
            '${budgets.inbound.refillPerSecond}/s sustained). A driver writing '
            'this fast is looping, not responding.',
          );
          return;
        }
        _applyUpdate(messages);
      case TerminateMessage(:final String reason):
        // The machine latched to `terminated`, but latching is not enough: the
        // host must take the surface out of service, or the user goes on
        // tapping enabled controls that nothing will ever answer.
        _halt(SessionFault(
          SessionFaultCode.driverTerminated,
          'The driver ended the session: $reason',
        ));
      case ErrorMessage():
        // The machine already latched to `faulted` with the driver's reason.
        _halt(_machine.fault!);
      case PongMessage():
        _awaitingPong = false;
      case InitMessage():
      case EventMessage():
      case PingMessage():
        break;
    }
  }

  void _startHeartbeat() {
    final Duration? interval = heartbeat;
    if (interval == null) return;
    _heartbeatTimer = Timer.periodic(interval, (Timer _) {
      if (!_machine.isReady) {
        _heartbeatTimer?.cancel();
        return;
      }
      if (_awaitingPong) {
        // A crashed worker fires an error event; a *hung* one fires nothing at
        // all. This is the only thing that tells the two apart from a dead
        // channel, and a surface that cannot tell is a surface that lies.
        _heartbeatTimer?.cancel();
        _raise(
          SessionFaultCode.heartbeatLost,
          'The driver did not answer a liveness probe within '
          '${interval.inMilliseconds}ms.',
        );
        return;
      }
      _pingNonce += 1;
      _awaitingPong = true;
      _trySend(PingMessage(nonce: _pingNonce));
    });
  }

  void _applyUpdate(List<A2uiMessage> messages) {
    // Vet the whole batch before applying any of it, so a refusal cannot leave
    // the surface half-updated — the same all-or-nothing property the driver's
    // own per-handler batching provides.
    for (final A2uiMessage message in messages) {
      if (!_isPermitted(message)) return;
    }
    try {
      processor.processMessages(messages);
    } catch (error) {
      // A driver whose messages the engine rejects is as dead as one that
      // crashed: the surface's state is now whatever the failing batch left
      // behind, which is exactly the half-applied condition the batching rule
      // exists to prevent.
      _raise(
        SessionFaultCode.driverError,
        'The driver sent an update the engine refused: $error',
      );
      return;
    }
    // Structural change may add or remove bindings; the next event re-walks.
    for (final A2uiMessage message in messages) {
      if (message is CreateSurfaceMessage ||
          message is UpdateComponentsMessage) {
        _boundPathsCache = null;
        break;
      }
    }
  }

  /// Whether the driver is allowed to send [message], faulting the session if
  /// not.
  ///
  /// Three ceilings, all structural. A driver drives *one* surface, so a
  /// message aimed anywhere else is out of scope no matter what it says. The
  /// surface's *lifecycle* belongs to the host — a driver recomposes within
  /// its surface, or replaces it wholesale with `createSurface`, but never
  /// removes it, because the host is rendering it and a surface that vanishes
  /// under the renderer takes the host down with it. And the data model has
  /// one writer per key, so a write into the host's own namespace — or a
  /// write to the root, which would swallow it — is refused before it can
  /// touch the model.
  bool _isPermitted(A2uiMessage message) {
    final String? target = switch (message) {
      CreateSurfaceMessage(:final String surfaceId) => surfaceId,
      UpdateComponentsMessage(:final String surfaceId) => surfaceId,
      UpdateDataModelMessage(:final String surfaceId) => surfaceId,
      DeleteSurfaceMessage(:final String surfaceId) => surfaceId,
      // A message with no surface target has nothing to scope-check — stated
      // as an explicit allow. (A wildcard that *computed* a passing
      // comparison here would be an invisible allow, and `A2uiMessage` is not
      // sealed: new message types must be considered, not waved through.)
      _ => null,
    };
    if (target != null && target != surfaceId) {
      _raise(
        SessionFaultCode.scopeViolation,
        "The driver of surface '$surfaceId' addressed surface '$target'.",
      );
      return false;
    }
    if (message is DeleteSurfaceMessage) {
      _raise(
        SessionFaultCode.scopeViolation,
        "The driver tried to delete surface '$surfaceId'. The surface's "
        'lifecycle belongs to the host: a driver may recompose its surface, '
        'or replace it with createSurface, but only the host removes it.',
      );
      return false;
    }
    if (message is! UpdateDataModelMessage) return true;

    final String path = message.path ?? '/';
    if (path == '/') {
      _raise(
        SessionFaultCode.hostKeyViolation,
        'The driver tried to replace the whole data model, which would take '
        'the host-owned $hostReservedNamespace namespace with it.',
      );
      return false;
    }
    if (path == hostReservedNamespace ||
        path.startsWith('$hostReservedNamespace/')) {
      _raise(
        SessionFaultCode.hostKeyViolation,
        "The driver tried to write '$path', inside the host-owned "
        '$hostReservedNamespace namespace.',
      );
      return false;
    }
    return true;
  }

  void _handleAction(A2uiClientAction action) {
    if (action.surfaceId != surfaceId || _disposed || !_machine.isOpen) return;
    if (!budgets.outbound.tryConsume()) {
      _raise(
        SessionFaultCode.budgetExhausted,
        'The surface exceeded the channel budget '
        '(${budgets.outbound.capacity} events of burst, '
        '${budgets.outbound.refillPerSecond}/s sustained). No person produces '
        'events at this rate; continuous interaction belongs in the template, '
        'not on the wire.',
      );
      return;
    }
    final EventMessage event = EventMessage(
      name: action.name,
      surfaceId: action.surfaceId,
      sourceComponentId: action.sourceComponentId,
      context: Map<String, Object?>.from(action.context),
      values: _boundValues(),
    );
    if (!_machine.isReady) {
      // The surface can be tapped before the driver finishes booting. Holding
      // the event is honest — the control was enabled, so something must
      // answer it — where dropping it would make a live control silently inert.
      _queuedEvents.add(event);
      return;
    }
    _trySend(event);
  }

  void _flushQueuedEvents() {
    final List<EventMessage> queued = List<EventMessage>.of(_queuedEvents);
    _queuedEvents.clear();
    for (final EventMessage event in queued) {
      _trySend(event);
    }
  }

  /// Snapshots the current value of every absolutely-bound data path on the
  /// surface.
  ///
  /// Discovered by walking the components' own properties, so it needs no
  /// declaration from anyone: a template that binds `/cart/total` is the
  /// statement that `/cart/total` matters. Paths *relative* to a list item are
  /// deliberately excluded — one component template stands for every row, so
  /// there is no single value to report; a template carries those in the
  /// action's own arguments, where they resolve per row.
  ///
  /// The walk is cached: the path *set* only changes when structure does, and
  /// this runs on the interaction path — per tap — where re-traversing every
  /// component's property tree would be paid by surfaces whose drivers never
  /// even read `event.values`. [_applyUpdate] invalidates on structural
  /// messages.
  Map<String, Object?> _boundValues() {
    final SurfaceModel<ComponentApi>? surface =
        processor.groupModel.getSurface(surfaceId);
    if (surface == null) return const <String, Object?>{};
    final List<String> paths = _boundPathsCache ??= _collectBoundPaths(surface);
    return <String, Object?>{
      for (final String path in paths) path: surface.dataModel.get(path),
    };
  }

  static List<String> _collectBoundPaths(SurfaceModel<ComponentApi> surface) {
    final Set<String> paths = <String>{};
    for (final ComponentModel component in surface.componentsModel.all) {
      _collectPaths(component.properties, paths);
    }
    return paths.toList()..sort();
  }

  static void _collectPaths(Object? node, Set<String> out) {
    if (node is Map) {
      final Object? path = node['path'];
      if (path is String && !node.containsKey('componentId')) {
        // A binding is a leaf: its `path` is the whole of it.
        if (path.startsWith('/')) out.add(path);
        return;
      }
      for (final Object? value in node.values) {
        _collectPaths(value, out);
      }
    } else if (node is List) {
      for (final Object? value in node) {
        _collectPaths(value, out);
      }
    }
  }

  void _handleCrash(String reason) {
    if (_disposed || !_machine.isOpen) return;
    _raise(SessionFaultCode.driverCrash, reason);
  }

  void _raise(SessionFaultCode code, String message, {Object? details}) {
    try {
      _machine.raise(code, message, details: details);
    } on SessionFault catch (fault) {
      _halt(fault);
    }
  }

  void _trySend(LogicMessage message) {
    try {
      transport.send(_machine.send(message).toJson());
    } on SessionFault catch (fault) {
      _halt(fault);
    }
  }

  /// Takes the session out of service: records [fault], releases everything —
  /// closing the transport is what stops the driver — and only then tells the
  /// host, so a listener that immediately restarts sees a fully torn-down
  /// session.
  void _halt(SessionFault fault) {
    _terminalFault ??= fault;
    if (!_ready.isCompleted) _ready.completeError(fault);
    _teardownChannel();
    _onFault.emit(fault);
  }
}
