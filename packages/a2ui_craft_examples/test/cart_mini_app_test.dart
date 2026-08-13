// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The cart mini-app, driven through its **real project files** — the shipped
/// `app.json`, `schema.json`, and `CartDriver` — with no renderer involved.
///
/// This is the behavioral half of the reference implementation's proof: that
/// the loop closes and the tiers land where the design says they do. The
/// rendered half (the same cart on Flutter and on Jaspr) lives in the driver
/// conformance suite.
library;

import 'dart:async';
import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

/// A small, pinned shop, so the assertions are about behavior rather than
/// about whatever the shipped inventory happens to sell.
const List<CartProduct> _shop = <CartProduct>[
  CartProduct(
    sku: 'kbd',
    name: 'Keyboard',
    detail: 'Clicky.',
    priceCents: 5000,
    stock: 2,
  ),
  CartProduct(
    sku: 'mug',
    name: 'Mug',
    detail: 'Holds coffee.',
    priceCents: 1000,
    stock: 9,
  ),
];

Future<void> _settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

MiniAppRunner _cart() => MiniAppRunner(
      surfaceId: 'cart',
      createProcessor: () => MessageProcessor<ComponentApi>(
        catalogs: <Catalog<ComponentApi>>[
          loadCatalog(
            jsonDecode(cartMiniApp.schema) as Map<String, Object?>,
          ),
        ],
      ),
      coldBoot: () => <A2uiMessage>[
        for (final Object? m
            in jsonDecode(cartMiniApp.messages) as List<Object?>)
          A2uiMessage.fromJson(m! as Map<String, dynamic>),
      ],
      createTransport: () => InProcessDriverRunner(
        CartDriver(inventory: _shop),
        diagnostics: silentDiagnostics,
      ),
    );

/// Fires the action bound to [componentId], the way a rendered control would.
Future<void> _act(
  MiniAppRunner runner,
  String componentId, {
  String? itemPath,
}) async {
  final SurfaceModel<ComponentApi> surface = runner.surface!;
  final ComponentModel component = surface.componentsModel.get(componentId)!;
  // Row components live under a ChildList, so their action's arguments resolve
  // against the item's own data context — which is how a driver learns which
  // row was tapped.
  final GenericBinder binder = GenericBinder(
    ComponentContext(surface, component, basePath: itemPath),
    surface.catalog.components[component.type]!.schema,
  );
  addTearDown(binder.dispose);
  final Object? action = binder.resolvedProps.value['apply'] ??
      binder.resolvedProps.value['remove'];
  await (action! as Function)();
}

List<Object?> _items(MiniAppRunner runner) =>
    (runner.surface!.dataModel.get('/cart/items') as List<Object?>?) ??
    const <Object?>[];

String _status(MiniAppRunner runner) =>
    runner.surface!.dataModel.get('/cart/status')! as String;

void main() {
  test('cold-boots to an empty cart before the driver connects', () async {
    final MiniAppRunner runner = _cart();
    addTearDown(runner.dispose);
    runner.start();

    // First paint comes from the recorded stream: an empty cart, honestly
    // labelled as not yet connected.
    expect(_items(runner), isEmpty);
    expect(runner.surface!.dataModel.get('/cart/totalCents'), 0);
    expect(_status(runner), contains('Connecting'));

    await _settle();
    expect(_status(runner), 'Cart ready. Add something.');
  });

  test('adding items accumulates a total the surface never computed', () async {
    final MiniAppRunner runner = _cart();
    addTearDown(runner.dispose);
    runner.start();
    await _settle();

    await runner.surface!.dispatchAction(
      <String, dynamic>{
        'event': <String, dynamic>{'name': 'addItem'},
      },
      'root',
    );
    await _settle();
    expect(_items(runner), hasLength(1));
    expect(runner.surface!.dataModel.get('/cart/totalCents'), 5000);
    expect(_status(runner), 'Added Keyboard.');

    await runner.surface!.dispatchAction(
      <String, dynamic>{
        'event': <String, dynamic>{'name': 'addItem'},
      },
      'root',
    );
    await _settle();
    expect(_items(runner), hasLength(2));
    expect(runner.surface!.dataModel.get('/cart/totalCents'), 6000);
  });

  test('a quantity echoes locally, then the driver clamps it to stock',
      () async {
    final MiniAppRunner runner = _cart();
    addTearDown(runner.dispose);
    runner.start();
    await _settle();
    await runner.surface!.dispatchAction(
      <String, dynamic>{
        'event': <String, dynamic>{'name': 'addItem'},
      },
      'root',
    );
    await _settle();

    // The echo: a two-way binding writes the local model at tier-1 latency,
    // and the driver is not told.
    runner.surface!.dataModel.set('/cart/items/0/qty', '7');
    expect(
      (_items(runner).first! as Map<String, Object?>)['qty'],
      '7',
      reason: 'the field shows what the user typed, immediately',
    );

    // The correction: the event carries that echoed value in its arguments —
    // resolved against the row — and the driver answers with what the shop
    // will honour.
    await _act(runner, 'row', itemPath: '/cart/items/0');
    await _settle();

    final Map<String, Object?> line =
        _items(runner).first! as Map<String, Object?>;
    expect(line['qty'], '2', reason: 'clamped to the 2 in stock');
    expect(line['lineCents'], 10000);
    expect(runner.surface!.dataModel.get('/cart/totalCents'), 10000);
    expect(_status(runner), 'Only 2 Keyboard in stock.');
  });

  test('a quantity of zero removes the row', () async {
    final MiniAppRunner runner = _cart();
    addTearDown(runner.dispose);
    runner.start();
    await _settle();
    await runner.surface!.dispatchAction(
      <String, dynamic>{
        'event': <String, dynamic>{'name': 'addItem'},
      },
      'root',
    );
    await _settle();

    runner.surface!.dataModel.set('/cart/items/0/qty', '0');
    await _act(runner, 'row', itemPath: '/cart/items/0');
    await _settle();

    expect(_items(runner), isEmpty);
    expect(runner.surface!.dataModel.get('/cart/totalCents'), 0);
  });

  test('checkout empties the cart and reports the order', () async {
    final MiniAppRunner runner = _cart();
    addTearDown(runner.dispose);
    runner.start();
    await _settle();
    for (var i = 0; i < 2; i++) {
      await runner.surface!.dispatchAction(
        <String, dynamic>{
          'event': <String, dynamic>{'name': 'addItem'},
        },
        'root',
      );
      await _settle();
    }

    await runner.surface!.dispatchAction(
      <String, dynamic>{
        'event': <String, dynamic>{'name': 'checkout'},
      },
      'root',
    );
    await _settle();

    expect(_status(runner), 'Ordered 2 item(s) for \$60.00.');
    expect(_items(runner), isEmpty);
    expect(runner.surface!.dataModel.get('/cart/totalCents'), 0);
  });

  test('the driver implements every action it advertises to an agent', () {
    final InferenceCatalog catalog = InferenceCatalog.parse(
      jsonDecode(cartMiniApp.schema) as Map<String, Object?>,
    );
    expect(catalog.actionNames, <String>{'addItem', 'checkout'});
    expect(
      catalog.unimplementedActions(CartDriver().handledEvents),
      isEmpty,
      reason: 'an agent told it can `checkout`, and then met with silence, is '
          'worse off than one never told at all',
    );
  });

  test("the project's logic slot names the driver the host must supply", () {
    final Map<String, Object?> logic =
        jsonDecode(cartMiniApp.logic) as Map<String, Object?>;
    expect(logic['kind'], 'builtin');
    expect(logic['entry'], 'cart');
    expect(logic['capabilities'], isEmpty);
  });
}
