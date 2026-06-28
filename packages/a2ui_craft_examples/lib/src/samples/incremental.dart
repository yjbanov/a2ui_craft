// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `00_incremental` — a `...for` list of
/// restaurant `Card`s. The spec streams the cards in over several messages; the
/// template renders the final list (the data is what changes, not the template).
SampleSpec incrementalSpec(String framework) => SampleSpec(
      label: 'Incremental',
      catalogSource: '''
import core;

widget RestaurantItem = Card(child: Column(gap: 4.0, children: [
  Heading(text: args.title, level: 3),
  Text(text: args.subtitle, variant: "caption"),
  Text(text: args.address, variant: "caption"),
  Button(child: Text(text: "Book now")),
]));

widget Incremental = Column(crossAxisAlignment: "stretch", gap: 10.0,
  children: [
    ...for r in args.restaurants: RestaurantItem(title: r.title,
      subtitle: r.subtitle, address: r.address),
  ]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Incremental': <String, Object?>{
            'properties': <String, Object?>{
              'restaurants': <String, Object?>{
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
              'component': 'Incremental',
              'restaurants': <Object?>[
                <String, Object?>{
                  'title': 'The Golden Fork',
                  'subtitle': 'Fine Dining & Spirits',
                  'address': '123 Gastronomy Lane',
                },
                <String, Object?>{
                  'title': "Ocean's Bounty",
                  'subtitle': 'Fresh Daily Seafood',
                  'address': '456 Shoreline Dr',
                },
                <String, Object?>{
                  'title': 'Pizzeria Roma',
                  'subtitle': 'Authentic Wood-Fired Pizza',
                  'address': '789 Napoli Way',
                },
                <String, Object?>{
                  'title': 'Spice Route',
                  'subtitle': 'Exotic Flavors from the East',
                  'address': '101 Silk Road St',
                },
              ],
            },
          ],
        ),
      ],
    );
