// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The worker runner, in a real browser: a driver written in JavaScript, in a
/// sandbox with no DOM and nothing but the channel.
///
/// The behavioral cases (a driver answers, the loop closes, the echo is
/// corrected) live in the shared conformance suite, which the Jaspr package
/// re-runs unmodified against this runner. What is here is what only a real
/// sandbox can be asked: what happens when it dies.
@TestOn('browser')
library;

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:a2ui_craft_logic/web.dart';
import 'package:test/test.dart';

(MessageProcessor<ComponentApi>, SurfaceModel<ComponentApi>) _surface() {
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(
    catalogs: <Catalog<ComponentApi>>[MinimalCatalog()],
  );
  processor.processMessages(<A2uiMessage>[
    CreateSurfaceMessage(surfaceId: 's', catalogId: MinimalCatalog().id),
    UpdateDataModelMessage(surfaceId: 's', path: '/status', value: 'cold'),
    UpdateComponentsMessage(surfaceId: 's', components: <Map<String, dynamic>>[
      <String, dynamic>{
        'id': 'status',
        'component': 'Text',
        'text': <String, dynamic>{'path': '/status'},
      },
    ]),
  ]);
  return (processor, processor.groupModel.getSurface('s')!);
}

/// Lets the worker boot, handshake, and answer — a real thread, a real
/// `postMessage`, so this is wall-clock time rather than a pumped queue.
Future<void> _settle() =>
    Future<void>.delayed(const Duration(milliseconds: 50));

void main() {
  test('a JavaScript driver drives a Dart surface', () async {
    final (
      MessageProcessor<ComponentApi> processor,
      SurfaceModel<ComponentApi> surface,
    ) = _surface();
    final DriverSession session = DriverSession(
      processor: processor,
      surfaceId: 's',
      transport: WorkerDriverRunner.fromSource(r'''
        a2uiDriver({
          onInit: function (ctx) { ctx.write('/status', 'hello from JS'); },
          handlers: {},
        });
      '''),
    );
    addTearDown(session.dispose);

    session.start();
    await session.ready;
    await _settle();

    expect(surface.dataModel.get('/status'), 'hello from JS');
  });

  test('a worker that dies on load is a crash, not a silent nothing', () async {
    final (MessageProcessor<ComponentApi> processor, _) = _surface();
    final DriverSession session = DriverSession(
      processor: processor,
      surfaceId: 's',
      transport: WorkerDriverRunner.fromSource(
        "throw new Error('the driver refused to start');",
      ),
    );
    addTearDown(session.dispose);
    final List<SessionFault> faults = <SessionFault>[];
    session.onFault.addListener(faults.add);

    session.start();
    await _settle();

    expect(faults.single.code, SessionFaultCode.driverCrash);
  });

  test('a worker that hangs is detected by the heartbeat', () async {
    final (MessageProcessor<ComponentApi> processor, _) = _surface();
    final DriverSession session = DriverSession(
      processor: processor,
      surfaceId: 's',
      // A driver that completes the handshake and then stops listening: no
      // crash event will ever come, so only the probe can tell.
      transport: WorkerDriverRunner.fromSource(r'''
        a2uiDriver({ onInit: function (ctx) {}, handlers: {} });
        self.onmessage = function () {};
      '''),
      heartbeat: const Duration(milliseconds: 50),
    );
    addTearDown(session.dispose);
    final List<SessionFault> faults = <SessionFault>[];
    session.onFault.addListener(faults.add);

    session.start();
    await Future<void>.delayed(const Duration(milliseconds: 400));

    expect(faults.single.code, SessionFaultCode.heartbeatLost);
  });

  test('the SDK is what makes a one-file driver possible', () {
    // The runner prepends the SDK, so a mini-app's logic is exactly one file
    // and needs nothing hosted alongside it.
    expect(driverSdkJs, contains('global.a2uiDriver = a2uiDriver;'));
  });

  test('a JavaScript driver that detects a protocol failure says so', () async {
    // A driver that latches silently is indistinguishable from a hung one: a
    // host with a heartbeat would misreport this seconds later as a lost
    // heartbeat, and a host without one would wait forever. The SDK must
    // post an error frame naming the real cause before it latches.
    final WorkerDriverRunner runner = WorkerDriverRunner.fromSource(
      'a2uiDriver({ handlers: {} });',
    );
    addTearDown(runner.close);
    final List<Map<String, Object?>> frames = <Map<String, Object?>>[];
    runner.onFrame = frames.add;
    runner.start();
    await _settle();
    expect(frames.last['type'], 'hello');

    // A frame from nowhere: seq 7 when the driver expects 1.
    runner.send(
      LogicFrame(
        seq: 7,
        message: const InitMessage(surfaceId: 's'),
      ).toJson(),
    );
    await _settle();

    final Map<String, Object?> error = frames.lastWhere(
      (Map<String, Object?> f) => f['type'] == 'error',
      orElse: () => fail('the driver went silent instead of reporting'),
    );
    final Map<String, Object?> body = error['body']! as Map<String, Object?>;
    expect(body['code'], 'outOfOrder');
    expect('${body['message']}', contains('Expected frame #1'));
  });

  test(
      'a driver that posts non-frames on the channel is reported, not '
      'silently dropped', () async {
    // A third-party library in logic.js, a debug postMessage, an emscripten
    // shim: anything else speaking on the default channel means the protocol
    // stream can no longer be trusted. Dropped silently, this would surface
    // later as a baffling out-of-order fault — or never.
    final WorkerDriverRunner runner = WorkerDriverRunner.fromSource(
      "a2uiDriver({ handlers: {} });\npostMessage('loaded!');",
    );
    addTearDown(runner.close);
    final List<String> crashes = <String>[];
    runner.onFrame = (Map<String, Object?> _) {};
    runner.onCrash = crashes.add;
    runner.start();
    await _settle();

    expect(crashes, isNotEmpty);
    expect(crashes.single, contains('not a JSON frame'));
  });
}
