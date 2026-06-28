// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `11_purchase-complete` — a centered
/// confirmation `Card`: a check `Icon`, a title, a product `Row` (image + name +
/// price), a `Divider`, delivery/seller details, and a `Button`. The image uses
/// an `example.com` URL (placeholder; no network).
SampleSpec purchaseCompleteSpec(String framework) => SampleSpec(
      label: 'Purchase Complete',
      catalogSource: '''
import core;

widget PurchaseComplete = Card(child: Column(crossAxisAlignment: "center",
  gap: 8.0, children: [
    Icon(icon: "check"),
    Text(text: args.title),
    Row(gap: 10.0, crossAxisAlignment: "center", children: [
      Image(url: args.productImage, variant: "smallFeature", fit: "cover"),
      Column(gap: 2.0, children: [
        Text(text: args.productName),
        Text(text: args.price),
      ]),
    ]),
    Divider(),
    Column(gap: 4.0, children: [
      Row(gap: 6.0, crossAxisAlignment: "center", children: [
        Icon(icon: "arrowForward"),
        Text(text: args.delivery),
      ]),
      Row(gap: 6.0, children: [
        Text(text: "Sold by:", variant: "caption"),
        Text(text: args.seller),
      ]),
    ]),
    Button(child: Text(text: args.cta)),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'PurchaseComplete': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'productImage': <String, Object?>{r'$ref': 'DynamicString'},
              'productName': <String, Object?>{r'$ref': 'DynamicString'},
              'price': <String, Object?>{r'$ref': 'DynamicString'},
              'delivery': <String, Object?>{r'$ref': 'DynamicString'},
              'seller': <String, Object?>{r'$ref': 'DynamicString'},
              'cta': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'PurchaseComplete',
              'title': 'Purchase Complete',
              'productImage': 'https://example.com/headphones.jpg',
              'productName': 'Wireless Headphones Pro',
              'price': r'$199.99',
              'delivery': 'Arrives Dec 18 - Dec 20',
              'seller': 'TechStore Official',
              'cta': 'View Order Details',
            },
          ],
        ),
      ],
    );
