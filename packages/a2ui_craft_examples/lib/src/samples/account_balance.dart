// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `15_account-balance` — a `Card` with
/// an icon header, the balance, a "last updated" caption, a `Divider`, and a
/// `Row` of two action `Button`s.
///
/// The spec formats the balance with `formatCurrency`; the template renders the
/// already formatted string supplied in the data.
SampleSpec accountBalanceSpec(String framework) => SampleSpec(
      label: 'Account Balance',
      catalogSource: '''
import core;

widget AccountBalance = Card(child: Column(gap: 8.0, children: [
  Row(gap: 8.0, crossAxisAlignment: "center", children: [
    Icon(icon: "payment"),
    Text(text: args.accountName),
  ]),
  Text(text: args.balance),
  Text(text: args.lastUpdated, variant: "caption"),
  Divider(),
  Row(gap: 12.0, children: [
    Button(child: Text(text: args.transferLabel)),
    Button(child: Text(text: args.payLabel)),
  ]),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'AccountBalance': <String, Object?>{
            'properties': <String, Object?>{
              'accountName': <String, Object?>{r'$ref': 'DynamicString'},
              'balance': <String, Object?>{r'$ref': 'DynamicString'},
              'lastUpdated': <String, Object?>{r'$ref': 'DynamicString'},
              'transferLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'payLabel': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'AccountBalance',
              'accountName': 'Primary Checking',
              'balance': r'$12,458.32',
              'lastUpdated': 'Updated just now',
              'transferLabel': 'Transfer',
              'payLabel': 'Pay Bill',
            },
          ],
        ),
      ],
    );
