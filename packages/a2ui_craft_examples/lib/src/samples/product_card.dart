// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `05_product-card` — a `Card` with a
/// product image, name, rating, price (with a struck-through original), and an
/// "Add to Cart" `Button`.
///
/// The spec formats the prices and review count with `formatCurrency`/
/// `formatNumber`/`pluralize`; a template renders strings, so the already
/// formatted values are supplied in the data. The image uses an `example.com`
/// URL, which renders a placeholder (no network in tests).
SampleSpec productCardSpec(String framework) => SampleSpec(
      label: 'Product Card',
      catalogSource: '''
import core;

widget ProductCard = Card(child: Column(gap: 8.0, children: [
  Image(url: args.imageUrl, variant: "mediumFeature", fit: "cover"),
  Text(text: args.name),
  Row(gap: 6.0, crossAxisAlignment: "center", children: [
    Text(text: args.stars),
    Text(text: args.reviews, variant: "caption"),
  ]),
  Row(gap: 8.0, crossAxisAlignment: "center", children: [
    Text(text: args.price),
    Text(text: args.originalPrice, variant: "caption"),
  ]),
  Button(child: Text(text: args.cta)),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'ProductCard': <String, Object?>{
            'properties': <String, Object?>{
              'imageUrl': <String, Object?>{r'$ref': 'DynamicString'},
              'name': <String, Object?>{r'$ref': 'DynamicString'},
              'stars': <String, Object?>{r'$ref': 'DynamicString'},
              'reviews': <String, Object?>{r'$ref': 'DynamicString'},
              'price': <String, Object?>{r'$ref': 'DynamicString'},
              'originalPrice': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'ProductCard',
              'imageUrl': 'https://example.com/headphones.jpg',
              'name': 'Wireless Headphones Pro',
              'stars': '★★★★★',
              'reviews': '(2,847 reviews)',
              'price': r'$199.99',
              'originalPrice': r'$249.99',
              'cta': 'Add to Cart',
            },
          ],
        ),
      ],
    );
