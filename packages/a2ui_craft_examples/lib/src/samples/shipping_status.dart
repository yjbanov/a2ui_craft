// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `21_shipping-status` — a `Card` whose
/// step list is **templated**: the agent passes an array of `{icon, label}` and
/// the template iterates it with `...for`, rendering one `Icon`+`Text` `Row`
/// per step. (The spec uses A2UI's `children: {path, componentId}` child-list
/// templating; here the same shape is expressed directly in the RFW template.)
SampleSpec shippingStatusSpec(String framework) => SampleSpec(
      label: 'Shipping Status',
      catalogSource: '''
import core;

widget ShippingStatus = Card(child: Column(gap: 8.0, children: [
  Row(gap: 8.0, crossAxisAlignment: "center", children: [
    Icon(icon: "info"),
    Text(text: args.title),
  ]),
  Text(text: args.trackingNumber, variant: "caption"),
  Divider(),
  Column(gap: 6.0, children: [
    ...for step in args.steps: Row(gap: 8.0, crossAxisAlignment: "center",
      children: [
        Icon(icon: step.icon),
        Text(text: step.label),
      ]),
  ]),
  Row(gap: 8.0, crossAxisAlignment: "center", children: [
    Icon(icon: "calendarToday"),
    Text(text: args.eta),
  ]),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'ShippingStatus': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'trackingNumber': <String, Object?>{r'$ref': 'DynamicString'},
              'eta': <String, Object?>{r'$ref': 'DynamicString'},
              'steps': <String, Object?>{
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
              'component': 'ShippingStatus',
              'title': 'Package Status',
              'trackingNumber': 'Tracking: 1Z999AA10123456784',
              'eta': 'Estimated delivery: Today by 8 PM',
              'steps': <Object?>[
                <String, Object?>{'icon': 'check', 'label': 'Order Placed'},
                <String, Object?>{'icon': 'check', 'label': 'Shipped'},
                <String, Object?>{'icon': 'send', 'label': 'Out for Delivery'},
                <String, Object?>{'icon': 'check', 'label': 'Delivered'},
              ],
            },
          ],
        ),
      ],
    );
