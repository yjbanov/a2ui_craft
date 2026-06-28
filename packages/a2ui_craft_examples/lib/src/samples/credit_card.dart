// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `22_credit-card` — a `Card` styled as
/// a payment card: a type `Row` (icon + brand), the (masked) number, and a
/// holder/expiry `Row`.
SampleSpec creditCardSpec(String framework) => SampleSpec(
      label: 'Credit Card',
      catalogSource: '''
import core;

widget CreditCard = Card(child: Column(gap: 12.0, children: [
  Row(mainAxisAlignment: "spaceBetween", crossAxisAlignment: "center",
    width: "fill", children: [
      Icon(icon: "payment"),
      Text(text: args.cardType),
    ]),
  Text(text: args.cardNumber),
  Row(mainAxisAlignment: "spaceBetween", width: "fill", children: [
    Column(gap: 2.0, children: [
      Text(text: "CARD HOLDER", variant: "caption"),
      Text(text: args.holderName),
    ]),
    Column(crossAxisAlignment: "end", gap: 2.0, children: [
      Text(text: "EXPIRES", variant: "caption"),
      Text(text: args.expiryDate),
    ]),
  ]),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'CreditCard': <String, Object?>{
            'properties': <String, Object?>{
              'cardType': <String, Object?>{r'$ref': 'DynamicString'},
              'cardNumber': <String, Object?>{r'$ref': 'DynamicString'},
              'holderName': <String, Object?>{r'$ref': 'DynamicString'},
              'expiryDate': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'CreditCard',
              'cardType': 'VISA',
              'cardNumber': '•••• •••• •••• 4242',
              'holderName': 'SARAH JOHNSON',
              'expiryDate': '09/27',
            },
          ],
        ),
      ],
    );
