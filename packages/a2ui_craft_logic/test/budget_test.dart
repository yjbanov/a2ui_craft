// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

/// A clock the test moves by hand, so a flood can be produced without waiting
/// for one and a *human* rate can be produced without taking four real seconds.
class _FakeClock {
  Duration now = Duration.zero;
  Duration call() => now;
  void advance(Duration d) => now += d;
}

(MessageProcessor<ComponentApi>, SurfaceModel<ComponentApi>) _surface() {
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(
    catalogs: <Catalog<ComponentApi>>[MinimalCatalog()],
  );
  processor.processMessages(<A2uiMessage>[
    CreateSurfaceMessage(surfaceId: 's', catalogId: MinimalCatalog().id),
  ]);
  return (processor, processor.groupModel.getSurface('s')!);
}

Future<void> _settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Writes [count] values in a single handler — the async-amplification attack,
/// arriving as one enormous batch.
class _FloodDriver extends Driver {
  _FloodDriver(this.count);

  final int count;

  @override
  void onInit(DriverContext context) {
    for (var i = 0; i < count; i++) {
      context.write('/spam/$i', i);
    }
  }

  @override
  void onEvent(DriverContext context, DriverEvent event) {}
}

class _QuietDriver extends Driver {
  int events = 0;

  @override
  void onEvent(DriverContext context, DriverEvent event) => events++;
}

Future<void> _tap(SurfaceModel<ComponentApi> surface) => surface.dispatchAction(
      <String, dynamic>{
        'event': <String, dynamic>{'name': 'tap'},
      },
      'btn',
    );

void main() {
  group('the bucket itself', () {
    test('starts full, drains, and refuses when empty', () {
      final _FakeClock clock = _FakeClock();
      final TokenBucket bucket =
          TokenBucket(capacity: 3, refillPerSecond: 1, clock: clock.call);

      expect(bucket.tryConsume(), isTrue);
      expect(bucket.tryConsume(), isTrue);
      expect(bucket.tryConsume(), isTrue);
      expect(bucket.tryConsume(), isFalse);
    });

    test('a refusal takes nothing', () {
      final _FakeClock clock = _FakeClock();
      final TokenBucket bucket =
          TokenBucket(capacity: 3, refillPerSecond: 1, clock: clock.call);

      expect(bucket.tryConsume(5), isFalse);
      expect(bucket.available, 3);
    });

    test('refills over time, and never past capacity', () {
      final _FakeClock clock = _FakeClock();
      final TokenBucket bucket =
          TokenBucket(capacity: 10, refillPerSecond: 4, clock: clock.call);

      expect(bucket.tryConsume(10), isTrue);
      expect(bucket.available, closeTo(0, 0.001));

      clock.advance(const Duration(milliseconds: 500));
      expect(bucket.available, closeTo(2, 0.001));

      clock.advance(const Duration(hours: 1));
      expect(bucket.available, 10);
    });
  });

  group('the driver direction', () {
    test('a flood halts the session', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(
          // One batch, comfortably past the burst allowance.
          _FloodDriver(defaultChannelBurst * 3),
          diagnostics: silentDiagnostics,
        ),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.budgetExhausted);
      expect(faults.single.message, contains('looping, not responding'));
      expect(session.state, LogicSessionState.faulted);
    });

    test('a batch is charged per message, not per frame', () async {
      // The point of the previous case: it arrives as ONE frame. Charging per
      // frame would let ten thousand writes through for the price of one.
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(
          _FloodDriver(defaultChannelBurst - 1),
          diagnostics: silentDiagnostics,
        ),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      // One under the allowance: the same single frame goes through.
      expect(faults, isEmpty);
      expect(surface.dataModel.get('/spam/0'), 0);
    });
  });

  group('the surface direction', () {
    test('an event flood halts the session', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(
          _QuietDriver(),
          diagnostics: silentDiagnostics,
        ),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      for (var i = 0; i < defaultChannelBurst * 2; i++) {
        await _tap(surface);
      }
      expect(faults.single.code, SessionFaultCode.budgetExhausted);
      expect(faults.single.message, contains('No person produces'));
    });

    test('a generous human rate never trips it', () async {
      final _FakeClock clock = _FakeClock();
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final _QuietDriver driver = _QuietDriver();
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport:
            InProcessDriverRunner(driver, diagnostics: silentDiagnostics),
        budgets: ChannelBudgets(clock: clock.call),
      );
      addTearDown(session.dispose);
      final List<SessionFault> faults = <SessionFault>[];
      session.onFault.addListener(faults.add);
      session.start();
      await _settle();

      // Ten actions a second for a full minute — a fast tapper who never once
      // pauses. The threshold has to clear this by a wide margin or it is
      // calibrated against users rather than against loops.
      for (var i = 0; i < 600; i++) {
        clock.advance(const Duration(milliseconds: 100));
        await _tap(surface);
      }
      await _settle();

      expect(faults, isEmpty);
      expect(driver.events, 600);
    });
  });
}
