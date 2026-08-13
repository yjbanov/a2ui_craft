// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

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

  final LogicSessionMachine _machine =
      LogicSessionMachine(role: LogicRole.host);
  final Completer<void> _ready = Completer<void>();
  final EventNotifier<SessionFault> _onFault = EventNotifier<SessionFault>();
  final List<EventMessage> _queuedEvents = <EventMessage>[];

  bool _started = false;
  bool _disposed = false;

  /// The session's lifecycle state.
  LogicSessionState get state => _machine.state;

  /// Why the session failed, or `null` if it has not.
  SessionFault? get fault => _machine.fault;

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
  }

  /// Ends the session in an orderly way and releases everything it holds.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    processor.groupModel.onAction.removeListener(_handleAction);
    if (_machine.isOpen) {
      _trySend(const TerminateMessage(reason: 'host disposed the session'));
    }
    transport
      ..onFrame = null
      ..onCrash = null
      ..close();
    _onFault.dispose();
  }

  void _receive(Map<String, Object?> frame) {
    if (_disposed) return;
    if (!_machine.isOpen) return;
    final LogicMessage message;
    try {
      message = _machine.receiveJson(frame);
    } on SessionFault catch (fault) {
      _fault(fault);
      return;
    }
    switch (message) {
      case HelloMessage():
        _trySend(InitMessage(surfaceId: surfaceId, context: hostContext));
        if (_machine.isReady) {
          if (!_ready.isCompleted) _ready.complete();
          _flushQueuedEvents();
        }
      case UpdateMessage(:final List<A2uiMessage> messages):
        // One token per message, not per frame: ten thousand writes in one
        // batch is the flood, and charging it as a single frame would let it
        // through.
        if (!budgets.inbound.tryConsume(
          messages.isEmpty ? 1 : messages.length,
        )) {
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
      case TerminateMessage():
        // The machine already latched to `terminated`; nothing further to do.
        break;
      case ErrorMessage():
        // The machine already latched to `faulted` with the driver's reason.
        _fault(_machine.fault!);
      case PongMessage():
      case InitMessage():
      case EventMessage():
      case PingMessage():
        break;
    }
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
    }
  }

  /// Whether the driver is allowed to send [message], faulting the session if
  /// not.
  ///
  /// Two ceilings, both structural. A driver drives *one* surface, so a message
  /// aimed anywhere else is out of scope no matter what it says. And the data
  /// model has one writer per key, so a write into the host's own namespace —
  /// or a write to the root, which would swallow it — is refused before it can
  /// touch the model.
  bool _isPermitted(A2uiMessage message) {
    final String target = switch (message) {
      CreateSurfaceMessage(:final String surfaceId) => surfaceId,
      UpdateComponentsMessage(:final String surfaceId) => surfaceId,
      UpdateDataModelMessage(:final String surfaceId) => surfaceId,
      DeleteSurfaceMessage(:final String surfaceId) => surfaceId,
      _ => surfaceId,
    };
    if (target != surfaceId) {
      _raise(
        SessionFaultCode.scopeViolation,
        "The driver of surface '$surfaceId' addressed surface '$target'.",
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
  Map<String, Object?> _boundValues() {
    final SurfaceModel<ComponentApi>? surface =
        processor.groupModel.getSurface(surfaceId);
    if (surface == null) return const <String, Object?>{};
    final Set<String> paths = <String>{};
    for (final ComponentModel component in surface.componentsModel.all) {
      _collectPaths(component.properties, paths);
    }
    final List<String> sorted = paths.toList()..sort();
    return <String, Object?>{
      for (final String path in sorted) path: surface.dataModel.get(path),
    };
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
      _fault(fault);
    }
  }

  void _trySend(LogicMessage message) {
    try {
      transport.send(_machine.send(message).toJson());
    } on SessionFault catch (fault) {
      _fault(fault);
    }
  }

  void _fault(SessionFault fault) {
    if (!_ready.isCompleted) {
      _ready.completeError(fault);
      // `ready` is a convenience, not an obligation — a host that listens on
      // `onFault` instead must not be punished with an unhandled async error.
      unawaited(_ready.future.catchError((Object _) {}));
    }
    _onFault.emit(fault);
    // Kill both sides. Closing the transport is what stops the driver: a
    // faulted host has no use for it, and a worker left running would keep
    // burning CPU with nobody listening.
    transport
      ..onFrame = null
      ..onCrash = null
      ..close();
  }
}
