// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

/// A surface with a bound label, a two-way-bound quantity field, and a button.
(MessageProcessor<ComponentApi>, SurfaceModel<ComponentApi>) _surface() {
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(catalogs: <Catalog<ComponentApi>>[
    MinimalCatalog(),
  ]);
  processor.processMessages(<A2uiMessage>[
    CreateSurfaceMessage(surfaceId: 's', catalogId: MinimalCatalog().id),
    UpdateDataModelMessage(surfaceId: 's', path: '/label', value: 'start'),
    UpdateDataModelMessage(surfaceId: 's', path: '/qty', value: 1),
    UpdateComponentsMessage(surfaceId: 's', components: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'label',
        'component': 'Text',
        'text': <String, dynamic>{'path': '/label'},
      },
      <String, dynamic>{
        'id': 'qty',
        'component': 'TextField',
        'label': 'Quantity',
        'value': <String, dynamic>{'path': '/qty'},
      },
      <String, dynamic>{'id': 'lbl', 'component': 'Text', 'text': 'Go'},
      <String, dynamic>{
        'id': 'btn',
        'component': 'Button',
        'child': 'lbl',
        'action': <String, dynamic>{
          'event': <String, dynamic>{
            'name': 'bump',
            'context': <String, dynamic>{'by': 2},
          },
        },
      },
    ]),
  ]);
  return (processor, processor.groupModel.getSurface('s')!);
}

/// Records what it was told, and answers `bump` by writing twice.
class _RecordingDriver extends Driver {
  final List<DriverEvent> events = <DriverEvent>[];
  String? seenSurfaceId;
  Map<String, Object?> seenHostContext = const <String, Object?>{};
  int total = 0;

  @override
  void onInit(DriverContext context) {
    seenSurfaceId = context.surfaceId;
    seenHostContext = context.hostContext;
    context.write('/label', 'ready');
  }

  @override
  void onEvent(DriverContext context, DriverEvent event) {
    events.add(event);
    switch (event.name) {
      case 'bump':
        total += (event['by'] as int?) ?? 1;
        // Two writes in one handler: they must land together.
        context
          ..write('/total', total)
          ..write('/label', 'total $total');
      case 'setQuantity':
        // The authoritative correction of an optimistic echo: clamp to stock.
        final int requested = (event.values['/qty'] as int?) ?? 0;
        context.write('/qty', requested > 5 ? 5 : requested);
      case 'boom':
        throw StateError('handler exploded');
    }
  }
}

/// Leaks a write out of its handler by not awaiting the future that makes it —
/// the mistake `unawaited_futures` catches in Dart and nothing catches in
/// JavaScript.
class _LeakyDriver extends Driver {
  @override
  void onEvent(DriverContext context, DriverEvent event) {
    switch (event.name) {
      case 'leak':
        context.write('/inTurn', 'batched');
        unawaited(
          Future<void>.delayed(Duration.zero)
              .then((_) => context.write('/late', 'escaped')),
        );
      case 'later':
        context.write('/later', 'ran');
    }
  }
}

/// Identical to [InProcessDriverRunner] except that it schedules on the
/// **microtask** queue.
///
/// Exists only so the turn-boundary conformance case can be shown to have
/// teeth: the guard must fail against this runner. If it ever passes here, the
/// guard has stopped testing anything.
class _MicrotaskRunner implements DriverTransport {
  _MicrotaskRunner(Driver driver) {
    _runtime = DriverRuntime(driver, send: _fromDriver);
  }

  late final DriverRuntime _runtime;
  void Function(Map<String, Object?> frame)? _onFrame;
  bool _closed = false;

  @override
  set onFrame(void Function(Map<String, Object?> frame)? handler) =>
      _onFrame = handler;

  @override
  set onCrash(void Function(String reason)? handler) {}

  @override
  void start() => _defer(() => _runtime.start());

  @override
  void send(Map<String, Object?> frame) {
    final Map<String, Object?> copy = _copy(frame);
    _defer(() => _runtime.receive(copy));
  }

  @override
  void close() {
    _closed = true;
    _onFrame = null;
  }

  void _fromDriver(Map<String, Object?> frame) {
    final Map<String, Object?> copy = _copy(frame);
    _defer(() => _onFrame?.call(copy));
  }

  void _defer(void Function() action) => scheduleMicrotask(() {
        if (!_closed) action();
      });

  Map<String, Object?> _copy(Map<String, Object?> frame) =>
      jsonDecode(jsonEncode(frame)) as Map<String, Object?>;
}

/// Yields to the **microtask** queue only. Zero-length timers cannot run here:
/// the loop never lets control return to the event loop.
Future<void> _flushMicrotasks([int rounds = 20]) async {
  for (var i = 0; i < rounds; i++) {
    await null;
  }
}

/// Yields to the event loop, letting zero-length timers fire.
Future<void> _settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('handshake', () {
    test('the driver learns its surface and the host context', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final _RecordingDriver driver = _RecordingDriver();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(driver),
        hostContext: const <String, Object?>{'locale': 'en-US'},
      );
      addTearDown(session.dispose);

      session.start();
      await session.ready;
      await _settle();

      expect(driver.seenSurfaceId, 's');
      expect(driver.seenHostContext, <String, Object?>{'locale': 'en-US'});
      expect(session.isReady, isTrue);
    });

    test("onInit's writes reach the surface", () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(_RecordingDriver()),
      );
      addTearDown(session.dispose);

      expect(surface.dataModel.get('/label'), 'start');
      session.start();
      await _settle();
      expect(surface.dataModel.get('/label'), 'ready');
    });
  });

  group('the loop closes: event out, write in', () {
    test('a user action reaches the driver and its write re-renders', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final _RecordingDriver driver = _RecordingDriver();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(driver),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      final A2uiComponentBinding label = A2uiComponentBinding(surface, 'label');
      addTearDown(label.dispose);
      final A2uiComponentBinding button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);

      (button.resolvedProps!['action']! as Function)();
      await _settle();

      expect(driver.events.single.name, 'bump');
      expect(driver.events.single.sourceComponentId, 'btn');
      expect(driver.events.single.context, <String, Object?>{'by': 2});
      expect(surface.dataModel.get('/total'), 2);
      expect(label.resolvedProps!['text'], 'total 2');
    });

    test('one handler\'s writes arrive as one update', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final InProcessDriverRunner runner =
          InProcessDriverRunner(_RecordingDriver());
      final List<String> types = <String>[];
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _Spy(runner, types),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();
      types.clear();

      final A2uiComponentBinding button = A2uiComponentBinding(
        processor.groupModel.getSurface('s')!,
        'btn',
      );
      addTearDown(button.dispose);
      (button.resolvedProps!['action']! as Function)();
      await _settle();

      // Two writes, one frame — a handler's effects land all at once or not at
      // all, never half-applied.
      expect(types.where((String t) => t == 'update'), hasLength(1));
    });

    test('events dispatched before the handshake are held, not dropped',
        () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final _RecordingDriver driver = _RecordingDriver();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(driver),
      );
      addTearDown(session.dispose);
      session.start();

      // The control was enabled, so something must answer it — even though the
      // driver has not finished booting.
      final A2uiComponentBinding button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);
      (button.resolvedProps!['action']! as Function)();
      expect(session.isReady, isFalse);

      await _settle();
      expect(driver.events.single.name, 'bump');
      expect(surface.dataModel.get('/total'), 2);
    });
  });

  group('turn-boundary delivery', () {
    test('a reply is never observable in the turn that caused it', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(_RecordingDriver()),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      final A2uiComponentBinding button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);
      (button.resolvedProps!['action']! as Function)();

      // Draining the microtask queue — everything the dispatching turn had
      // queued — must not reveal the driver's answer. A worker's postMessage
      // reply physically cannot arrive this soon, so neither may the runner
      // that stands in for one.
      await _flushMicrotasks();
      expect(surface.dataModel.get('/total'), isNull);

      // A turn of the event loop, and it is there.
      await _settle();
      expect(surface.dataModel.get('/total'), 2);
    });

    test('the guard fails against a microtask-scheduled runner', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _MicrotaskRunner(_RecordingDriver()),
      );
      addTearDown(session.dispose);
      session.start();
      await _flushMicrotasks();

      final A2uiComponentBinding button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);
      (button.resolvedProps!['action']! as Function)();
      await _flushMicrotasks();

      // Same probe, opposite result: microtask scheduling makes the in-process
      // driver observably more prompt than any sandbox could be, which is
      // exactly what the guard above exists to forbid. If this ever starts
      // reporting null, the guard has stopped testing anything.
      expect(surface.dataModel.get('/total'), 2);
    });
  });

  group('optimistic echo and authoritative correction', () {
    test('a two-way write echoes at once, then the driver clamps it back',
        () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      // Rewire the button to submit the quantity rather than bump a total.
      processor.processMessages(<A2uiMessage>[
        UpdateComponentsMessage(
            surfaceId: 's',
            components: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'btn',
                'component': 'Button',
                'child': 'lbl',
                'action': <String, dynamic>{
                  'event': <String, dynamic>{'name': 'setQuantity'},
                },
              },
            ]),
      ]);
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(_RecordingDriver()),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      final A2uiComponentBinding qty = A2uiComponentBinding(surface, 'qty');
      addTearDown(qty.dispose);
      final A2uiComponentBinding button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);

      // The echo: the control moves at tier-1 latency, with no round trip.
      (qty.resolvedProps!['setValue']! as Function)(42);
      expect(qty.resolvedProps!['value'], 42);

      (button.resolvedProps!['action']! as Function)();
      await _settle();

      // The correction: the driver clamps to stock and the surface reconciles.
      expect(qty.resolvedProps!['value'], 5);
    });

    test('an event carries the current value of every absolute binding',
        () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final _RecordingDriver driver = _RecordingDriver();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(driver),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      final A2uiComponentBinding qty = A2uiComponentBinding(surface, 'qty');
      addTearDown(qty.dispose);
      (qty.resolvedProps!['setValue']! as Function)(9);

      final A2uiComponentBinding button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);
      (button.resolvedProps!['action']! as Function)();
      await _settle();

      // The driver never saw the echo happen; the event is how it finds out.
      expect(driver.events.single.values['/qty'], 9);
      expect(driver.events.single.values, contains('/label'));
    });
  });

  group('liveness', () {
    test('a driver that stops answering is detected, not awaited', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _MuteAfterInit(),
        heartbeat: const Duration(milliseconds: 20),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await session.ready;

      // A crashed worker fires an error event; a hung one fires nothing at
      // all, so without the probe this surface would sit looking healthy.
      await Future<void>.delayed(const Duration(milliseconds: 120));
      expect(faults.single.code, SessionFaultCode.heartbeatLost);
      expect(session.state, LogicSessionState.faulted);
    });

    test('a live driver is never faulted for being idle', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(_RecordingDriver()),
        heartbeat: const Duration(milliseconds: 10),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();

      // Many probe intervals with no traffic at all: answering pings is the
      // whole of what keeps a session alive.
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(faults, isEmpty);
      expect(session.isReady, isTrue);
    });
  });

  group('a write that escapes its handler', () {
    test('is reported and sent on its own, not folded into a later batch',
        () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final List<String> reported = <String>[];
      final List<String> types = <String>[];
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _Spy(
          InProcessDriverRunner(_LeakyDriver(), diagnostics: reported.add),
          types,
        ),
        heartbeat: null,
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();
      types.clear();

      await surface.dispatchAction(
        <String, dynamic>{
          'event': <String, dynamic>{'name': 'leak'},
        },
        'btn',
      );
      await _settle();

      // The handler's own write lands in the handler's batch...
      expect(surface.dataModel.get('/inTurn'), 'batched');
      // ...and the one that escaped lands too, rather than waiting in the
      // batch for some later, unrelated handler to flush it.
      expect(surface.dataModel.get('/late'), 'escaped');
      expect(types.where((String t) => t == 'update'), hasLength(2),
          reason: 'two turns, two updates — the late write is not smuggled '
              "into anyone else's batch");

      // And the author is told, because a silent divergence between the
      // driver's model and the surface's is the worst possible outcome here.
      expect(reported.single, contains('outside any handler turn'));
    });

    test('the guard has teeth: without it the write would ride along later',
        () async {
      // The failure this prevents, made concrete. The escaped write is
      // observable *before* the next event, so it cannot have been carried by
      // that event's batch — which is exactly what would happen if `_inTurn`
      // were never consulted.
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(
          _LeakyDriver(),
          diagnostics: silentDiagnostics,
        ),
        heartbeat: null,
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      await surface.dispatchAction(
        <String, dynamic>{
          'event': <String, dynamic>{'name': 'leak'},
        },
        'btn',
      );
      await _settle();
      expect(surface.dataModel.get('/late'), 'escaped');
      expect(surface.dataModel.get('/later'), isNull,
          reason: 'no second event has happened yet');
    });
  });

  group('failure is loud', () {
    test('a handler that throws faults the session with its reason', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      processor.processMessages(<A2uiMessage>[
        UpdateComponentsMessage(
            surfaceId: 's',
            components: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'btn',
                'component': 'Button',
                'child': 'lbl',
                'action': <String, dynamic>{
                  'event': <String, dynamic>{'name': 'boom'},
                },
              },
            ]),
      ]);
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(_RecordingDriver()),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      final A2uiComponentBinding button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);
      (button.resolvedProps!['action']! as Function)();
      await _settle();

      expect(faults, hasLength(1));
      expect(faults.single.code, SessionFaultCode.driverError);
      expect(faults.single.message, contains('handler exploded'));
      expect(session.state, LogicSessionState.faulted);
    });

    test('a frame no sandbox could carry is a crash, not a silent drop',
        () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(_UnencodableDriver()),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.driverCrash);
      expect(faults.single.message, contains('JSON-encodable'));
    });

    test(
        'an update carrying a malformed A2UI message faults the session, '
        'not the zone', () async {
      // `ctx.send()` in JavaScript hands author-built objects straight to the
      // wire, so this is easy to hit — and A2UI decode errors are not
      // LogicProtocolError, so an unwrapped decode would escape every catch
      // in the session machinery as an unhandled async error, leaving the
      // machine `ready` and the surface impersonating a working app.
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _ScriptedTransport(<Map<String, Object?> Function(int)>[
          (int seq) => <String, Object?>{
                'seq': seq,
                'type': 'update',
                'body': <String, Object?>{
                  'messages': <Object?>[
                    <String, Object?>{
                      'version': 'v0.9',
                      'noSuchMessage': <String, Object?>{},
                    },
                  ],
                },
              },
        ]),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.malformed);
      expect(session.state, LogicSessionState.faulted);
    });
  });

  group('the session ends', () {
    test("a driver's goodbye takes the surface out of service", () async {
      // An orderly `terminate` is not a failure, but silence about it would
      // be: the machine latches, the host is never told, and the user goes on
      // tapping enabled controls nothing will ever answer.
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _ScriptedTransport(<Map<String, Object?> Function(int)>[
          (int seq) => LogicFrame(
                seq: seq,
                message: const TerminateMessage(reason: 'done for the day'),
              ).toJson(),
        ]),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.driverTerminated);
      expect(faults.single.message, contains('done for the day'));
      expect(session.fault, isNotNull,
          reason: 'a host that polls instead of listening sees it too');
      expect(session.state, LogicSessionState.terminated);
    });

    test('a driver that never says hello is faulted, not awaited forever',
        () async {
      // The heartbeat cannot cover this window — pings are only legal on a
      // ready session — and nothing crashed, so nothing reports. Without a
      // deadline the surface says "Connecting…" forever while events queue
      // without bound.
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _NeverSpeaks(),
        heartbeat: null,
        handshakeTimeout: const Duration(milliseconds: 30),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();

      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(faults.single.code, SessionFaultCode.handshakeTimedOut);
      expect(session.state, LogicSessionState.faulted);
    });

    test('disposing before the handshake settles ready, never hangs it',
        () async {
      // `dispose` cancels the handshake timer — the one thing left that would
      // have completed this future. A host that awaits `ready` and then tears
      // the surface down (a widget disposed while a worker is still booting)
      // would otherwise wait for a handshake nobody is still watching for.
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: _NeverSpeaks(),
        heartbeat: null,
      );
      session.start();
      final Future<void> ready = session.ready;
      session.dispose();

      await expectLater(ready, throwsA(isA<StateError>()));
      expect(session.fault, isNull,
          reason: 'the host ended it on purpose; that is not a fault');
    });

    test('disposing the session stops the in-process driver', () async {
      // The close contract is "stop the driver": a worker runner terminates
      // its worker outright, so the runner that stands in for one must not
      // leave a live runtime behind. In-process, author-opened timers are the
      // one thing nothing else can stop — which is what onTerminate is for.
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final _TickingDriver driver = _TickingDriver();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(driver),
      );
      session.start();
      await session.ready;
      await _settle();
      expect(driver.ticks, greaterThanOrEqualTo(0));

      session.dispose();
      await _settle();

      expect(driver.terminations, hasLength(1),
          reason: 'told once, with the reason');
      expect(driver.terminations.single, contains('disposed'));

      final int ticksAtDisposal = driver.ticks;
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(driver.ticks, ticksAtDisposal,
          reason: 'the periodic timer is cancelled — N restarts must not '
              'leave N drivers burning CPU for surfaces out of service');
    });
  });
}

/// Writes a value that cannot cross a sandbox boundary.
class _UnencodableDriver extends Driver {
  @override
  void onInit(DriverContext context) =>
      context.write('/when', DateTime(2026, 8, 12));

  @override
  void onEvent(DriverContext context, DriverEvent event) {}
}

/// Wraps a transport, recording the type of every frame the host sends and
/// receives.
class _Spy implements DriverTransport {
  _Spy(this._inner, this._types);

  final DriverTransport _inner;
  final List<String> _types;

  @override
  set onFrame(void Function(Map<String, Object?> frame)? handler) =>
      _inner.onFrame = handler == null
          ? null
          : (Map<String, Object?> frame) {
              _types.add(frame['type']! as String);
              handler(frame);
            };

  @override
  set onCrash(void Function(String reason)? handler) =>
      _inner.onCrash = handler;

  @override
  void start() => _inner.start();

  @override
  void send(Map<String, Object?> frame) => _inner.send(frame);

  @override
  void close() => _inner.close();
}

/// A driver-side stand-in that answers the handshake and then plays back
/// scripted frames verbatim — for wire shapes no real SDK would (or could)
/// produce.
class _ScriptedTransport implements DriverTransport {
  _ScriptedTransport(this.afterInit);

  /// Frame builders, each given the next sequence number, played after `init`.
  final List<Map<String, Object?> Function(int seq)> afterInit;

  void Function(Map<String, Object?> frame)? _onFrame;
  int _seq = 0;

  @override
  set onFrame(void Function(Map<String, Object?> frame)? handler) =>
      _onFrame = handler;

  @override
  set onCrash(void Function(String reason)? handler) {}

  @override
  void start() => Timer.run(() {
        _seq += 1;
        _onFrame?.call(
          LogicFrame(seq: _seq, message: const HelloMessage()).toJson(),
        );
      });

  @override
  void send(Map<String, Object?> frame) {
    if (frame['type'] != 'init') return;
    for (final Map<String, Object?> Function(int seq) build in afterInit) {
      Timer.run(() {
        _seq += 1;
        _onFrame?.call(build(_seq));
      });
    }
  }

  @override
  void close() => _onFrame = null;
}

/// A transport whose driver never boots far enough to say anything at all —
/// the entry-point typo, the hung top-level await, the remote endpoint that
/// accepts the connection and goes silent.
class _NeverSpeaks implements DriverTransport {
  @override
  set onFrame(void Function(Map<String, Object?> frame)? handler) {}

  @override
  set onCrash(void Function(String reason)? handler) {}

  @override
  void start() {}

  @override
  void send(Map<String, Object?> frame) {}

  @override
  void close() {}
}

/// Opens a periodic timer at init and cancels it at terminate — the author
/// obligation [Driver.onTerminate] exists for.
class _TickingDriver extends Driver {
  Timer? _timer;
  int ticks = 0;
  final List<String> terminations = <String>[];

  @override
  void onInit(DriverContext context) {
    _timer = Timer.periodic(
      const Duration(milliseconds: 5),
      (Timer _) => ticks++,
    );
  }

  @override
  void onEvent(DriverContext context, DriverEvent event) {}

  @override
  void onTerminate(String reason) {
    terminations.add(reason);
    _timer?.cancel();
  }
}

/// A transport that answers the handshake and then goes quiet — the hung
/// driver a crash event never reports.
class _MuteAfterInit implements DriverTransport {
  void Function(Map<String, Object?> frame)? _onFrame;
  int _seq = 0;

  @override
  set onFrame(void Function(Map<String, Object?> frame)? handler) =>
      _onFrame = handler;

  @override
  set onCrash(void Function(String reason)? handler) {}

  @override
  void start() => Timer.run(() {
        _seq += 1;
        _onFrame?.call(
          LogicFrame(seq: _seq, message: const HelloMessage()).toJson(),
        );
      });

  @override
  void send(Map<String, Object?> frame) {
    // Swallows everything, pings included.
  }

  @override
  void close() => _onFrame = null;
}
