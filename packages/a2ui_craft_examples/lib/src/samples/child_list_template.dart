// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `34_child-list-template` — a `Card`
/// with a `List` whose rows are generated from an array arg via `...for`, the
/// RFW-template form of A2UI's `children: {path, componentId}` child templating.
SampleSpec childListTemplateSpec(String framework) => SampleSpec(
      label: 'Child List Template',
      catalogSource: '''
import core;

widget ItemList = Card(child: Column(crossAxisAlignment: "stretch", gap: 8.0,
  children: [
    Text(text: args.title),
    List(direction: "vertical", children: [
      ...for item in args.items: Row(gap: 4.0, children: [
        Text(text: item.name),
        Text(text: " - Qty: "),
        Text(text: item.quantity),
      ]),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'ItemList': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'ItemList',
              'title': 'Dynamic Item List',
              'items': <Object?>[
                <String, Object?>{'name': 'Apple', 'quantity': '10'},
                <String, Object?>{'name': 'Banana', 'quantity': '5'},
                <String, Object?>{'name': 'Cherry', 'quantity': '20'},
              ],
            },
          ],
        ),
      ],
    );
