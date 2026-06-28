// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `33_financial-data-grid` — a `Card`
/// with a header row and a `...for` list of asset rows. The spec's per-column
/// `weight` (flex-grow) is realized with the `Expanded(flex:)` primitive, so the
/// columns line up. Currency/percentages are supplied already formatted.
SampleSpec financialDataGridSpec(String framework) => SampleSpec(
      label: 'Data Grid',
      catalogSource: '''
import core;

widget HeaderRow = Row(crossAxisAlignment: "center", children: [
  Expanded(flex: 4, child: Text(text: "Asset", variant: "caption")),
  Expanded(flex: 2, child: Text(text: "Price", variant: "caption")),
  Expanded(flex: 2, child: Text(text: "24h", variant: "caption")),
  Expanded(flex: 3, child: Text(text: "Mkt Cap", variant: "caption")),
]);

widget AssetRow = Row(crossAxisAlignment: "center", children: [
  Expanded(flex: 4, child: Row(gap: 6.0, crossAxisAlignment: "center",
    children: [
      Icon(icon: "payment"),
      Column(gap: 1.0, children: [
        Text(text: args.name),
        Text(text: args.symbol, variant: "caption"),
      ]),
    ])),
  Expanded(flex: 2, child: Text(text: args.price)),
  Expanded(flex: 2, child: Text(text: args.change)),
  Expanded(flex: 3, child: Text(text: args.marketCap, variant: "caption")),
]);

widget FinancialGrid = Card(child: Column(crossAxisAlignment: "stretch",
  gap: 6.0, children: [
    HeaderRow(),
    Divider(),
    ...for asset in args.assets: AssetRow(name: asset.name, symbol: asset.symbol,
      price: asset.price, change: asset.change, marketCap: asset.marketCap),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'FinancialGrid': <String, Object?>{
            'properties': <String, Object?>{
              'assets': <String, Object?>{
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
              'component': 'FinancialGrid',
              'assets': <Object?>[
                <String, Object?>{
                  'name': 'Bitcoin',
                  'symbol': 'BTC',
                  'price': r'$43,500.25',
                  'change': '+1.2%',
                  'marketCap': r'$850.0B',
                },
                <String, Object?>{
                  'name': 'Ethereum',
                  'symbol': 'ETH',
                  'price': r'$2,250.50',
                  'change': '-0.5%',
                  'marketCap': r'$270.0B',
                },
                <String, Object?>{
                  'name': 'Solana',
                  'symbol': 'SOL',
                  'price': r'$95.80',
                  'change': '+5.4%',
                  'marketCap': r'$40.0B',
                },
              ],
            },
          ],
        ),
      ],
    );
