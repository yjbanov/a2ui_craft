// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// Builds the transport for the named conformance fixture.
///
/// The suite names a *behavior* ('counter', 'clamp') rather than handing over an
/// implementation, so the same cases can run against a driver written in
/// another language: an in-process factory maps the name to a Dart [Driver]; a
/// worker factory maps it to a script. That is what makes re-running this suite
/// against a sandboxed runner a proof rather than a second suite.
typedef DriverRunnerFactory = DriverTransport Function(String fixtureName);

/// The Dart implementations of the conformance fixtures.
Driver conformanceDriver(String fixtureName) => switch (fixtureName) {
      'counter' => _CounterDriver(),
      'clamp' => _ClampDriver(),
      'cart' => CartDriver(inventory: cartConformanceShop),
      _ => throw ArgumentError.value(
          fixtureName,
          'fixtureName',
          'Unknown conformance driver fixture',
        ),
    };

/// The default factory: the fixtures as Dart drivers behind the in-process
/// runner.
DriverTransport inProcessConformanceRunner(String fixtureName) =>
    InProcessDriverRunner(conformanceDriver(fixtureName));

/// A one-product shop, so the cart case's assertions are about behavior and
/// every control on screen is unambiguous — one row means one "Update" button.
const List<CartProduct> cartConformanceShop = <CartProduct>[
  CartProduct(
    sku: 'kbd',
    name: 'Keyboard',
    detail: 'Clicky, and loud about it.',
    priceCents: 5000,
    stock: 2,
  ),
];

/// Answers `go` by counting, and seeds a status line at init.
class _CounterDriver extends Driver {
  int _count = 0;

  @override
  void onInit(DriverContext context) => context.write('/status', 'ready');

  @override
  void onEvent(DriverContext context, DriverEvent event) {
    if (event.name != 'go') return;
    _count += 1;
    context.write('/status', 'go $_count');
  }
}

/// Reads the two-way value the surface echoed locally, reports it, and then
/// overrides it — the authoritative correction half of optimistic echo.
class _ClampDriver extends Driver {
  @override
  void onInit(DriverContext context) => context.write('/status', 'ready');

  @override
  void onEvent(DriverContext context, DriverEvent event) {
    if (event.name != 'submit') return;
    context
      ..write('/status', 'agreed: ${event.values['/agreed']}')
      ..write('/agreed', false);
  }
}

/// The A2UI surface both cases render: a status line, a checkbox, and a button.
List<A2uiMessage> _messages(String eventName) => <A2uiMessage>[
      CreateSurfaceMessage(
        surfaceId: 'conformance',
        catalogId: a2uiDemoCatalogId,
      ),
      UpdateDataModelMessage(
        surfaceId: 'conformance',
        path: '/status',
        value: 'idle',
      ),
      UpdateDataModelMessage(
        surfaceId: 'conformance',
        path: '/agreed',
        value: false,
      ),
      UpdateComponentsMessage(
        surfaceId: 'conformance',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Stack',
            'children': <Object?>['status', 'agree', 'act'],
          },
          <String, dynamic>{
            'id': 'status',
            'component': 'Label',
            'text': <String, dynamic>{'path': '/status'},
          },
          <String, dynamic>{
            'id': 'agree',
            'component': 'Check',
            'value': <String, dynamic>{'path': '/agreed'},
          },
          <String, dynamic>{
            'id': 'act',
            'component': 'Tappable',
            'label': 'Go',
            'action': <String, dynamic>{
              'event': <String, dynamic>{'name': eventName},
            },
          },
        ],
      ),
    ];

/// The shared behavioral specification for a surface driven by **business
/// logic** rather than by an agent or a recorded stream.
///
/// It asserts only what a user could see: an action leaves the surface, a
/// driver answers with data, and the rendered result changes. Protocol detail —
/// framing, ordering, turn-boundary scheduling — is unit-tested once in
/// `a2ui_craft_logic`; what this suite adds is that the whole loop closes
/// through each adapter's own renderer.
///
/// Pass [makeRunner] to re-run the identical cases against a different runner.
/// Re-running them *unmodified* is the point: if a sandboxed runner needs its
/// own copy of these cases, the abstraction has failed.
void runDriverConformance(
  CraftConformanceDriver driver, {
  DriverRunnerFactory makeRunner = inProcessConformanceRunner,
}) {
  driver.defineTest(
    'a driver answers a user action with a write that re-renders',
    (CraftTester tester) async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = tester.applyA2ui(_messages('go'));
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 'conformance',
        transport: makeRunner('counter'),
      );
      addTearDown(session.dispose);

      await tester.mountComponent(tester.buildAdapter(surface, 'root'));
      expect(tester.hasText('idle'), isTrue);

      // Nothing has connected yet; the surface shows only what it cold-booted
      // with.
      session.start();
      await tester.settleDriver();
      expect(tester.hasText('ready'), isTrue,
          reason: "the driver's init write reached the rendered surface");

      await tester.activate('act');
      await tester.settleDriver();
      expect(tester.hasText('go 1'), isTrue);

      // The driver is a state machine: the second action sees the first.
      await tester.activate('act');
      await tester.settleDriver();
      expect(tester.hasText('go 2'), isTrue);
      expect(tester.hasText('go 1'), isFalse);
    },
  );

  driver.defineTest(
    "a driver reads the surface's optimistic echo, then overrides it",
    (CraftTester tester) async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = tester.applyA2ui(_messages('submit'));
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 'conformance',
        transport: makeRunner('clamp'),
      );
      addTearDown(session.dispose);

      await tester.mountComponent(tester.buildAdapter(surface, 'root'));
      session.start();
      await tester.settleDriver();

      // The echo: a two-way binding writes the local data model immediately,
      // and the driver is never told.
      await tester.toggleCheckbox();
      await tester.pump();

      await tester.activate('act');
      await tester.settleDriver();

      // It learned the echoed value anyway — the event carried it.
      expect(tester.hasText('agreed: true'), isTrue);

      // And its authoritative write put the control back where it says it
      // belongs, so a second submit reports the corrected value.
      await tester.activate('act');
      await tester.settleDriver();
      expect(tester.hasText('agreed: false'), isTrue);
    },
  );

  driver.defineTest(
    'the cart mini-app runs identically on every adapter',
    (CraftTester tester) async {
      // The *shipped* project — its real template, its real schema, its real
      // recorded boot stream — not a fixture that resembles one.
      final MiniAppRunner runner = MiniAppRunner(
        surfaceId: 'cart',
        createProcessor: () => MessageProcessor<ComponentApi>(
          catalogs: <Catalog<ComponentApi>>[
            loadCatalog(jsonDecode(cartMiniApp.schema) as Map<String, Object?>),
          ],
        ),
        coldBoot: () => <A2uiMessage>[
          for (final Object? m
              in jsonDecode(cartMiniApp.messages) as List<Object?>)
            A2uiMessage.fromJson(m! as Map<String, dynamic>),
        ],
        createTransport: () => makeRunner('cart'),
      );
      addTearDown(runner.dispose);

      runner.start();
      // Cold boot: the recorded stream composes a complete, honest surface
      // before any driver connects — asserted on the model, because mounting
      // is itself a turn of the event loop on some adapters and the driver may
      // already have answered by the time anything is on screen.
      expect(
        runner.surface!.dataModel.get('/cart/status'),
        'Connecting to the cart…',
      );

      await tester.mountComponent(tester.buildAdapter(
        runner.surface!,
        'root',
        templateSource: cartMiniApp.template,
      ));
      await tester.settleDriver();
      expect(tester.hasText('Cart ready. Add something.'), isTrue);

      // Tier 3: a decision with consequences beyond the surface.
      await tester.activateButton('Add an item');
      await tester.settleDriver();
      expect(tester.hasText('Keyboard'), isTrue);
      expect(tester.hasText('Added Keyboard.'), isTrue);

      // Tier 1: expanding a row never reaches the driver, so a plain pump —
      // no channel turn at all — is enough to see it.
      expect(tester.hasText('Clicky, and loud about it.'), isFalse);
      await tester.activateButton('Details');
      await tester.pump();
      expect(tester.hasText('Clicky, and loud about it.'), isTrue);

      // The optimistic echo: a two-way binding writes the local model at
      // tier-1 latency and the driver is never told. Writing the bound path is
      // exactly what the injected setter does when a user types.
      runner.surface!.dataModel.set('/cart/items/0/qty', '7');
      await tester.pump();

      // The authoritative correction: the event carries the echoed value, and
      // what comes back is what the shop will honour.
      await tester.activateButton('Update');
      await tester.settleDriver();
      expect(tester.hasText('Only 2 Keyboard in stock.'), isTrue);

      // Tier 2: a threshold the surface evaluates for itself, from data the
      // driver wrote. Two keyboards at \$50 is \$100.
      expect(tester.hasText('Free shipping unlocked'), isTrue);

      await tester.activateButton('Check out');
      await tester.settleDriver();
      expect(tester.hasText(r'Ordered 2 item(s) for $100.00.'), isTrue);
      expect(tester.hasText('Keyboard'), isFalse,
          reason: 'the order emptied the cart, and the row went with it');
    },
  );
}
