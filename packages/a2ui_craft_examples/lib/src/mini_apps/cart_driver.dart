// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';

/// One product the cart can hold.
class CartProduct {
  const CartProduct({
    required this.sku,
    required this.name,
    required this.detail,
    required this.priceCents,
    required this.stock,
  });

  /// Stable identity — what an event carries to say *which row*.
  final String sku;

  /// Display name.
  final String name;

  /// The blurb a row reveals when it is expanded. Tier 1: it ships with the
  /// data whether or not the row is open, because opening a row must not cost
  /// a round trip.
  final String detail;

  /// Unit price in **cents**. Money stays integral on the wire; the surface
  /// divides for display.
  final int priceCents;

  /// How many the shop actually has. The reason a driver exists: the surface
  /// cannot know this, and a surface that pretended to would be lying.
  final int stock;
}

/// The reference mini-app's inventory.
const List<CartProduct> cartInventory = <CartProduct>[
  CartProduct(
    sku: 'kbd',
    name: 'Mechanical keyboard',
    detail: 'Tactile switches, no backlight, two-year warranty.',
    priceCents: 8900,
    stock: 3,
  ),
  CartProduct(
    sku: 'mug',
    name: 'Enamel mug',
    detail: 'Holds 350ml. Dishwasher safe, microwave regrettably not.',
    priceCents: 1500,
    stock: 12,
  ),
  CartProduct(
    sku: 'cbl',
    name: 'Braided USB-C cable',
    detail: 'Two metres, 100W, and it survives being wound round a laptop.',
    priceCents: 2200,
    stock: 2,
  ),
];

/// The cart mini-app's business logic.
///
/// The reference driver: it exercises all three tiers of the latency
/// discipline by *staying out of* the first two. Expanding a row and formatting
/// money never reach it; quantities, stock limits, and the order itself never
/// leave it.
///
/// It is deliberately written against nothing but `a2ui_craft_logic` — no
/// engine, no adapter, no template. The JavaScript port in the same project is
/// the same state machine, and the conformance script cannot tell them apart.
class CartDriver extends HandlerDriver {
  /// Creates a driver selling [inventory], defaulting to [cartInventory].
  ///
  /// Injectable so a test can pin prices and stock levels rather than depend on
  /// whatever the shipped shop happens to sell this week.
  CartDriver({this.inventory = cartInventory});

  /// What this cart sells.
  final List<CartProduct> inventory;

  final Map<String, int> _quantities = <String, int>{};

  @override
  void onInit(DriverContext context) {
    _publish(context, 'Cart ready. Add something.');
  }

  @override
  Map<String, DriverHandler> get handlers => <String, DriverHandler>{
        'addItem': _addItem,
        'removeItem': _removeItem,
        'setQuantity': _setQuantity,
        'checkout': _checkout,
      };

  void _addItem(DriverContext context, DriverEvent event) {
    final CartProduct? next = inventory
        .where(
          (CartProduct p) => !_quantities.containsKey(p.sku),
        )
        .firstOrNull;
    if (next == null) {
      _publish(context, 'That is everything the shop has.');
      return;
    }
    _quantities[next.sku] = 1;
    _publish(context, 'Added ${next.name}.');
  }

  void _removeItem(DriverContext context, DriverEvent event) {
    final String? sku = event['sku'] as String?;
    if (sku == null || _quantities.remove(sku) == null) {
      _publish(context, 'Nothing to remove.');
      return;
    }
    _publish(context, 'Removed ${_productFor(sku)?.name ?? sku}.');
  }

  /// The authoritative correction behind an optimistic echo.
  ///
  /// The quantity field is two-way bound, so the number the user typed is
  /// already on screen before this runs. What arrives here is that same value,
  /// carried in the event's arguments — and what leaves is the value the shop
  /// will actually honour.
  void _setQuantity(DriverContext context, DriverEvent event) {
    final String? sku = event['sku'] as String?;
    final CartProduct? product = sku == null ? null : _productFor(sku);
    if (product == null) {
      _publish(context, 'Unknown item.');
      return;
    }
    final int requested = _asInt(event['qty']) ?? _quantities[sku] ?? 1;
    final int allowed = requested.clamp(0, product.stock);
    if (allowed == 0) {
      _quantities.remove(sku);
      _publish(context, 'Removed ${product.name}.');
      return;
    }
    _quantities[sku!] = allowed;
    _publish(
      context,
      allowed == requested
          ? '${product.name}: $allowed.'
          : 'Only $allowed ${product.name} in stock.',
    );
  }

  void _checkout(DriverContext context, DriverEvent event) {
    if (_quantities.isEmpty) {
      _publish(context, 'The cart is empty.');
      return;
    }
    final int total = _totalCents();
    final int units = _quantities.values.fold(0, (int a, int b) => a + b);
    _quantities.clear();
    _publish(context, 'Ordered $units item(s) for ${_dollars(total)}.');
  }

  /// Writes the whole cart. Every write in one handler lands together, so the
  /// rows, the total, and the status line can never disagree on screen.
  void _publish(DriverContext context, String status) {
    context
      ..write('/cart/items', <Object?>[
        for (final CartProduct product in inventory)
          if (_quantities.containsKey(product.sku))
            <String, Object?>{
              'sku': product.sku,
              'name': product.name,
              'detail': product.detail,
              // A string, because the quantity field is a text field and its
              // optimistic echo writes back a string. The driver is the one
              // that has to be careful about types; the surface just shows
              // what it is given.
              'qty': '${_quantities[product.sku]}',
              'lineCents': product.priceCents * _quantities[product.sku]!,
            },
      ])
      ..write('/cart/totalCents', _totalCents())
      ..write('/cart/status', status);
  }

  int _totalCents() =>
      inventory.where((CartProduct p) => _quantities.containsKey(p.sku)).fold(0,
          (int sum, CartProduct p) => sum + p.priceCents * _quantities[p.sku]!);

  CartProduct? _productFor(String sku) =>
      inventory.where((CartProduct p) => p.sku == sku).firstOrNull;

  static int? _asInt(Object? value) => switch (value) {
        final int i => i,
        final num n => n.round(),
        final String s => int.tryParse(s.trim()),
        _ => null,
      };

  static String _dollars(int cents) =>
      '\$${(cents ~/ 100)}.${(cents % 100).toString().padLeft(2, '0')}';
}
