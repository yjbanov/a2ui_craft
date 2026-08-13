// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:a2ui_core/a2ui_core.dart';

import 'envelope.dart';
import 'fault.dart';
import 'session_machine.dart';

/// A user action that reached the driver.
final class DriverEvent {
  /// Creates an event describing one user action.
  const DriverEvent({
    required this.name,
    required this.sourceComponentId,
    required this.context,
    required this.values,
  });

  /// The event name the template dispatched.
  final String name;

  /// The id of the component that dispatched it.
  final String sourceComponentId;

  /// The arguments the template attached to the event.
  ///
  /// A template may bind data into these arguments, and the bindings resolve at
  /// the moment of the action — including *relative* to a list item, which is
  /// how a driver learns which row was tapped.
  final Map<String, Object?> context;

  /// Current values of the surface's absolutely-bound data paths, keyed by
  /// path.
  ///
  /// Two-way bindings write the surface's data model immediately, without
  /// telling the driver; this is how a submit handler reads the whole form
  /// without the template having to enumerate every field in [context].
  final Map<String, Object?> values;

  /// Reads [context], falling back to [values] at the same key.
  Object? operator [](String key) => context.containsKey(key)
      ? context[key]
      : (values.containsKey(key) ? values[key] : null);

  @override
  String toString() => 'DriverEvent($name from $sourceComponentId, $context)';
}

/// What a [Driver] may do to the surface it drives.
///
/// Writes made during one handler are batched and delivered as a single update
/// — a handler's effects land on the surface all at once, never half-applied.
abstract interface class DriverContext {
  /// The surface this driver drives.
  String get surfaceId;

  /// Host-owned context — locale, display mode, theme selection. Read-only:
  /// the host defends these keys and faults a driver that writes them.
  Map<String, Object?> get hostContext;

  /// Writes [value] at the JSON-pointer [path] in the surface's data model.
  ///
  /// This is the ordinary way a driver changes what the user sees. Prefer it to
  /// [send]: data-driven change is cheap, and a template that binds data
  /// already knows how to react.
  void write(String path, Object? value);

  /// Sends A2UI Transport [messages] verbatim.
  ///
  /// The escape hatch for genuinely *structural* change — composing new
  /// components, removing them, replacing a surface. Templates own variation
  /// within a shape; drivers own composition of shapes.
  void send(List<A2uiMessage> messages);

  /// Reports a failure to the host. Terminal: the session ends and the host
  /// takes the surface out of service.
  void fail(String code, String message, {Object? details});

  /// Reports a development-time problem — something wired wrong rather than
  /// something gone wrong.
  ///
  /// Loud in development, silent in production. This is what stands in for the
  /// build-time refusal a declared event list would have bought: a control
  /// whose event no handler answers is a dead control, and a dead control must
  /// at least be a *diagnosed* one while the author is still at the keyboard.
  void diagnostic(String message);
}

/// Where a driver's development-time diagnostics go.
typedef DriverDiagnosticSink = void Function(String message);

/// A diagnostic sink that reports nothing — the production posture, stated
/// explicitly.
void silentDiagnostics(String message) {}

/// One named handler in a [HandlerDriver].
typedef DriverHandler = FutureOr<void> Function(
  DriverContext context,
  DriverEvent event,
);

/// A [Driver] that dispatches events to handlers by name.
///
/// The recommended shape, because naming the handlers is what makes the
/// mismatches visible: an event with no handler is reported through
/// [DriverContext.diagnostic], and [unusedHandlers] names the other half of the
/// same mistake — a handler nothing ever dispatches to.
///
/// It is also the surface [InferenceCatalog.unimplementedActions] checks
/// against, so a mini-app can assert in its own tests that it implements every
/// action it advertises to an agent.
abstract class HandlerDriver extends Driver {
  late final Map<String, DriverHandler> _handlers = handlers;
  final Set<String> _fired = <String>{};

  /// The handlers this driver implements, keyed by event name. Read once.
  Map<String, DriverHandler> get handlers;

  /// The event names this driver answers.
  Set<String> get handledEvents => _handlers.keys.toSet();

  /// Handlers that have not received an event yet.
  ///
  /// A development aid, not an assertion: early in a session most handlers are
  /// legitimately unused. It earns its keep in a test that drives every path
  /// and expects the set to empty out.
  Set<String> get unusedHandlers => handledEvents.difference(_fired);

  @override
  FutureOr<void> onEvent(DriverContext context, DriverEvent event) {
    final DriverHandler? handler = _handlers[event.name];
    if (handler == null) {
      context.diagnostic(
        "No handler for event '${event.name}', dispatched by "
        "'${event.sourceComponentId}'. This driver handles: "
        '${(handledEvents.toList()..sort()).join(', ')}.',
      );
      return null;
    }
    _fired.add(event.name);
    return handler(context, event);
  }
}

/// The default diagnostic sink: loud in development, silent in production.
///
/// Asserts are enabled in JIT/debug builds and stripped from release builds, so
/// this reports exactly where a developer is watching and nowhere else.
DriverDiagnosticSink? _developmentDiagnostics() {
  DriverDiagnosticSink? sink;
  assert(() {
    sink = (String message) => developer.log(message, name: 'a2ui.driver');
    return true;
  }());
  return sink;
}

/// Author-written business logic for one surface.
///
/// A driver is a state machine — `(state, event) → (state, messages)` — living
/// on the far side of an asynchronous channel. It holds whatever state it likes
/// in its own language, and expresses every effect as a data write.
///
/// Implementations must not assume they run in the same process, isolate, or
/// language as the surface: everything crossing the boundary is JSON.
abstract class Driver {
  /// Called once, after the handshake, before any event.
  ///
  /// The place to seed the data model. The surface itself already exists — the
  /// host cold-boots structure from the project's recorded message stream — so
  /// a driver that only ever writes data never touches [DriverContext.send].
  FutureOr<void> onInit(DriverContext context) {}

  /// Called for each user action, one at a time, in order.
  ///
  /// Handlers are serialized: the next event waits for this one's future, so a
  /// driver never observes two handlers interleaving its state.
  FutureOr<void> onEvent(DriverContext context, DriverEvent event);
}

/// The driver-side half of a session: owns the state machine, decodes frames,
/// calls the [Driver], and batches its writes.
///
/// This is what a runner hosts. The in-process runner constructs one directly;
/// a worker runner's JavaScript SDK is the same object written in JavaScript.
class DriverRuntime implements DriverContext {
  /// Creates a runtime driving [driver], writing outbound frames to [send].
  ///
  /// Pass [diagnostics] to redirect development-time reports; the default is
  /// loud in development builds and silent in release ones. Pass
  /// [silentDiagnostics] to silence it unconditionally.
  DriverRuntime(
    this.driver, {
    required void Function(Map<String, Object?>) send,
    DriverDiagnosticSink? diagnostics,
  })  : _sendFrame = send,
        _diagnostics = diagnostics ?? _developmentDiagnostics();

  /// The author's logic.
  final Driver driver;

  final void Function(Map<String, Object?>) _sendFrame;
  final DriverDiagnosticSink? _diagnostics;
  final LogicSessionMachine _machine =
      LogicSessionMachine(role: LogicRole.driver);

  final List<A2uiMessage> _pending = <A2uiMessage>[];
  Future<void> _handlerChain = Future<void>.value();

  String? _surfaceId;
  Map<String, Object?> _hostContext = const <String, Object?>{};

  /// Whether the handshake completed.
  bool get isReady => _machine.isReady;

  @override
  String get surfaceId => _surfaceId ?? (throw StateError('Not initialized.'));

  @override
  Map<String, Object?> get hostContext => _hostContext;

  /// Announces this driver to the host. Call once, on boot.
  void start() => _emit(const HelloMessage());

  /// Handles one encoded frame from the host.
  void receive(Map<String, Object?> frame) {
    final LogicMessage message;
    try {
      message = _machine.receiveJson(frame);
    } on SessionFault {
      // The machine has latched; the host will notice the silence or already
      // knows. There is nothing useful left to say on a channel whose framing
      // we no longer trust.
      return;
    }
    switch (message) {
      case InitMessage(
          :final String surfaceId,
          :final Map<String, Object?> context
        ):
        _surfaceId = surfaceId;
        _hostContext = context;
        _run(() => driver.onInit(this));
      case final EventMessage event:
        _run(() => driver.onEvent(this, _toEvent(event)));
      case PingMessage(:final int nonce):
        _emit(PongMessage(nonce: nonce));
      case TerminateMessage():
      case ErrorMessage():
      case HelloMessage():
      case UpdateMessage():
      case PongMessage():
        break;
    }
  }

  @override
  void write(String path, Object? value) => _pending.add(
        UpdateDataModelMessage(
          surfaceId: surfaceId,
          path: path,
          value: value,
        ),
      );

  @override
  void send(List<A2uiMessage> messages) => _pending.addAll(messages);

  @override
  void fail(String code, String message, {Object? details}) {
    _pending.clear();
    _emit(ErrorMessage(code: code, message: message, details: details));
  }

  @override
  void diagnostic(String message) => _diagnostics?.call(message);

  /// Ends the session in an orderly way.
  void terminate(String reason) {
    if (!_machine.isOpen) return;
    _emit(TerminateMessage(reason: reason));
  }

  DriverEvent _toEvent(EventMessage message) => DriverEvent(
        name: message.name,
        sourceComponentId: message.sourceComponentId,
        context: message.context,
        values: message.values,
      );

  /// Runs one handler to completion, then flushes its writes as a single
  /// update. Handlers are chained so they never interleave.
  void _run(FutureOr<void> Function() handler) {
    _handlerChain = _handlerChain.then((_) async {
      try {
        await handler();
      } catch (error, stack) {
        _pending.clear();
        fail('handlerThrew', '$error', details: stack.toString());
        return;
      }
      _flush();
    });
  }

  void _flush() {
    if (_pending.isEmpty) return;
    final List<A2uiMessage> batch = List<A2uiMessage>.of(_pending);
    _pending.clear();
    _emit(UpdateMessage(batch));
  }

  void _emit(LogicMessage message) {
    if (!_machine.isOpen) return;
    try {
      _sendFrame(_machine.send(message).toJson());
    } on SessionFault {
      // Latched; see `receive`.
    }
  }
}
