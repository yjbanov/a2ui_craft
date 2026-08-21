// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

Future<void> _settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

List<A2uiMessage> _coldBoot() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 'app', catalogId: MinimalCatalog().id),
      UpdateDataModelMessage(surfaceId: 'app', path: '/status', value: 'cold'),
      UpdateComponentsMessage(
        surfaceId: 'app',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'status',
            'component': 'Text',
            'text': <String, dynamic>{'path': '/status'},
          },
        ],
      ),
    ];

MessageProcessor<ComponentApi> _createProcessor() =>
    MessageProcessor<ComponentApi>(
      catalogs: <Catalog<ComponentApi>>[MinimalCatalog()],
    );

/// Counts its own boots, so a restart can be told apart from a reset.
class _CountingDriver extends Driver {
  _CountingDriver(this.serial);

  final int serial;
  int taps = 0;

  @override
  void onInit(DriverContext context) =>
      context.write('/status', 'live #$serial');

  @override
  void onEvent(DriverContext context, DriverEvent event) {
    if (event.name == 'boom') throw StateError('driver gave up');
    taps++;
    context.write('/status', 'tap $taps of #$serial');
  }
}

MiniAppRunner _runner(List<_CountingDriver> built) {
  var serial = 0;
  // No surfaceId: the runner reads it from the boot stream's own
  // createSurface, the way every host should — a host that repeats the id out
  // of band is a host that can get it wrong.
  return MiniAppRunner(
    createProcessor: _createProcessor,
    coldBoot: _coldBoot,
    createTransport: () {
      final _CountingDriver driver = _CountingDriver(++serial);
      built.add(driver);
      return InProcessDriverRunner(driver, diagnostics: silentDiagnostics);
    },
  );
}

Future<void> _tap(MiniAppRunner runner, String name) =>
    runner.surface!.dispatchAction(
      <String, dynamic>{
        'event': <String, dynamic>{'name': name},
      },
      'btn',
    );

void main() {
  test('cold-boots the surface before any driver connects', () async {
    final MiniAppRunner runner = _runner(<_CountingDriver>[]);
    addTearDown(runner.dispose);

    runner.start();
    // The surface id came from the boot stream itself, not from the host.
    expect(runner.activeSurfaceId, 'app');
    // First paint comes from the recorded stream — no round trip.
    expect(runner.surface!.dataModel.get('/status'), 'cold');

    await _settle();
    expect(runner.surface!.dataModel.get('/status'), 'live #1');
    expect(runner.isRunning, isTrue);
    expect(runner.fault, isNull);
  });

  test('a boot stream that creates no surface is refused loudly', () async {
    // A mini-app with no surface is nothing to drive; running a driver
    // against it would be a session about nothing, ending in a null
    // dereference at whichever host renders first.
    final MiniAppRunner runner = MiniAppRunner(
      createProcessor: _createProcessor,
      coldBoot: () => <A2uiMessage>[],
      createTransport: () => InProcessDriverRunner(
        _CountingDriver(1),
        diagnostics: silentDiagnostics,
      ),
    );
    addTearDown(runner.dispose);
    runner.start();

    expect(runner.fault!.code, SessionFaultCode.malformed);
    expect(runner.fault!.message, contains('createSurface'));
    expect(runner.isRunning, isFalse);
    expect(runner.surface, isNull);
  });

  test('a driver failure stops the mini-app and says why', () async {
    final MiniAppRunner runner = _runner(<_CountingDriver>[]);
    addTearDown(runner.dispose);
    final List<MiniAppRunner> changes = <MiniAppRunner>[];
    runner.onChanged.addListener(changes.add);

    runner.start();
    await _settle();
    await _tap(runner, 'boom');
    await _settle();

    expect(runner.isRunning, isFalse);
    expect(runner.fault!.code, SessionFaultCode.driverError);
    expect(runner.fault!.message, contains('driver gave up'));
    // The host is told to re-render — boot, then fault.
    expect(changes, hasLength(2));
  });

  test('restart cold-boots from scratch, keeping nothing', () async {
    final List<_CountingDriver> built = <_CountingDriver>[];
    final MiniAppRunner runner = _runner(built);
    addTearDown(runner.dispose);

    runner.start();
    await _settle();
    await _tap(runner, 'tap');
    await _settle();
    expect(runner.surface!.dataModel.get('/status'), 'tap 1 of #1');

    await _tap(runner, 'boom');
    await _settle();
    expect(runner.fault, isNotNull);

    runner.restart();
    expect(runner.fault, isNull);
    // Back to the recorded stream, not to where the old session left off.
    expect(runner.surface!.dataModel.get('/status'), 'cold');
    await _settle();
    expect(runner.surface!.dataModel.get('/status'), 'live #2');

    // A second driver, with no memory of the first: there is no restoration,
    // and pretending otherwise is what "freeze beats betray" rules out.
    expect(built, hasLength(2));
    expect(built.last.taps, 0);

    await _tap(runner, 'tap');
    await _settle();
    expect(runner.surface!.dataModel.get('/status'), 'tap 1 of #2');
  });

  test('the old session is dead after a restart, not merely ignored', () async {
    final List<_CountingDriver> built = <_CountingDriver>[];
    final MiniAppRunner runner = _runner(built);
    addTearDown(runner.dispose);

    runner.start();
    await _settle();
    final DriverSession first = runner.session!;

    runner.restart();
    await _settle();

    expect(runner.session, isNot(same(first)));
    expect(first.state, LogicSessionState.terminated);
  });

  test('start is idempotent; restart is not', () async {
    final List<_CountingDriver> built = <_CountingDriver>[];
    final MiniAppRunner runner = _runner(built);
    addTearDown(runner.dispose);

    runner
      ..start()
      ..start();
    await _settle();
    expect(built, hasLength(1));

    runner.restart();
    await _settle();
    expect(built, hasLength(2));
  });
}
