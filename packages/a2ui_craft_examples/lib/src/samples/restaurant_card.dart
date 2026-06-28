// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `20_restaurant-card` — a `Card` with
/// a header image and a content `Column`: a name/price-range `Row`
/// (`spaceBetween`), a cuisine caption, a star rating `Row`, and a details
/// `Row`. The image uses an `example.com` URL (placeholder; no network).
SampleSpec restaurantCardSpec(String framework) => SampleSpec(
      label: 'Restaurant Card',
      catalogSource: '''
import core;

widget RestaurantCard = Card(child: Column(gap: 8.0, children: [
  Image(url: args.image, variant: "header", fit: "cover"),
  Column(gap: 6.0, children: [
    Row(mainAxisAlignment: "spaceBetween", crossAxisAlignment: "center",
      width: "fill", children: [
        Text(text: args.name),
        Text(text: args.priceRange),
      ]),
    Text(text: args.cuisine, variant: "caption"),
    Row(gap: 6.0, crossAxisAlignment: "center", children: [
      Icon(icon: "star"),
      Text(text: args.rating),
      Text(text: args.reviewCount, variant: "caption"),
    ]),
    Row(gap: 12.0, children: [
      Text(text: args.distance, variant: "caption"),
      Text(text: args.deliveryTime, variant: "caption"),
    ]),
  ]),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'RestaurantCard': <String, Object?>{
            'properties': <String, Object?>{
              'image': <String, Object?>{r'$ref': 'DynamicString'},
              'name': <String, Object?>{r'$ref': 'DynamicString'},
              'priceRange': <String, Object?>{r'$ref': 'DynamicString'},
              'cuisine': <String, Object?>{r'$ref': 'DynamicString'},
              'rating': <String, Object?>{r'$ref': 'DynamicString'},
              'reviewCount': <String, Object?>{r'$ref': 'DynamicString'},
              'distance': <String, Object?>{r'$ref': 'DynamicString'},
              'deliveryTime': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'RestaurantCard',
              'image': 'https://example.com/restaurant.jpg',
              'name': 'The Italian Kitchen',
              'priceRange': r'$$$',
              'cuisine': 'Italian • Pasta • Wine Bar',
              'rating': '4.8',
              'reviewCount': '(2,847 reviews)',
              'distance': '0.8 mi',
              'deliveryTime': '25-35 min',
            },
          ],
        ),
      ],
    );
