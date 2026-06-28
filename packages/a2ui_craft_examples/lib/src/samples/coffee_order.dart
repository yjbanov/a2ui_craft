// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `13_coffee-order` — a `Card` with a
/// store header, a `...for` list of order items (name/size + price), a
/// `Divider`, a subtotal/tax/total block, and two action `Button`s. Currency is
/// supplied already formatted (the spec uses `formatCurrency`).
SampleSpec coffeeOrderSpec(String framework) => SampleSpec(
      label: 'Coffee Order',
      catalogSource: '''
import core;

widget CoffeeOrder = Card(child: Column(gap: 8.0, children: [
  Row(gap: 6.0, crossAxisAlignment: "center", children: [
    Icon(icon: "favorite"),
    Text(text: args.storeName),
  ]),
  Column(gap: 6.0, children: [
    ...for item in args.items: Row(mainAxisAlignment: "spaceBetween",
      crossAxisAlignment: "start", width: "fill", children: [
        Column(children: [
          Text(text: item.name),
          Text(text: item.size, variant: "caption"),
        ]),
        Text(text: item.price),
      ]),
  ]),
  Divider(),
  Column(gap: 4.0, children: [
    Row(mainAxisAlignment: "spaceBetween", width: "fill", children: [
      Text(text: "Subtotal", variant: "caption"),
      Text(text: args.subtotal),
    ]),
    Row(mainAxisAlignment: "spaceBetween", width: "fill", children: [
      Text(text: "Tax", variant: "caption"),
      Text(text: args.tax),
    ]),
    Row(mainAxisAlignment: "spaceBetween", width: "fill", children: [
      Text(text: "Total"),
      Text(text: args.total),
    ]),
  ]),
  Row(gap: 12.0, children: [
    Button(child: Text(text: "Purchase")),
    Button(child: Text(text: "Add to cart")),
  ]),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'CoffeeOrder': <String, Object?>{
            'properties': <String, Object?>{
              'storeName': <String, Object?>{r'$ref': 'DynamicString'},
              'subtotal': <String, Object?>{r'$ref': 'DynamicString'},
              'tax': <String, Object?>{r'$ref': 'DynamicString'},
              'total': <String, Object?>{r'$ref': 'DynamicString'},
              'items': <String, Object?>{
                'type': 'array',
                'items': <String, Object?>{'type': 'object'},
              },
            },
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'CoffeeOrder',
              'storeName': 'Sunrise Coffee',
              'subtotal': r'$10.70',
              'tax': r'$0.96',
              'total': r'$11.66',
              'items': <Object?>[
                <String, Object?>{
                  'name': 'Oat Milk Latte',
                  'size': 'Grande, Extra Shot',
                  'price': r'$6.45',
                },
                <String, Object?>{
                  'name': 'Chocolate Croissant',
                  'size': 'Warmed',
                  'price': r'$4.25',
                },
              ],
            },
          ],
        ),
      ],
    );
