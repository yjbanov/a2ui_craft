// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `00_complex-layout` — a `Heading`, a
/// two-field `Row` (each field `weight: 1` → `Expanded`), and a footer caption.
/// Wrapped in a fixed width so the side-by-side fields have room to divide.
SampleSpec complexLayoutSpec(String framework) => SampleSpec(
      label: 'Complex Layout',
      catalogSource: '''
import core;

widget Labelled = Column(gap: 4.0, children: [
  Text(text: args.label, variant: "caption"),
  TextField(value: args.value),
]);

widget ComplexLayout = SizedBox(width: 360.0, child: Column(
  crossAxisAlignment: "stretch", gap: 12.0, children: [
    Heading(text: args.title, level: 2),
    Row(gap: 12.0, crossAxisAlignment: "start", children: [
      Expanded(child: Labelled(label: args.firstLabel, value: args.firstValue)),
      Expanded(child: Labelled(label: args.lastLabel, value: args.lastValue)),
    ]),
    Text(text: args.footer, variant: "caption"),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'ComplexLayout': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'firstLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'firstValue': <String, Object?>{r'$ref': 'DynamicString'},
              'lastLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'lastValue': <String, Object?>{r'$ref': 'DynamicString'},
              'footer': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'ComplexLayout',
              'title': 'User Profile Form',
              'firstLabel': 'First Name',
              'firstValue': '',
              'lastLabel': 'Last Name',
              'lastValue': '',
              'footer': 'Please fill out all fields.',
            },
          ],
        ),
      ],
    );
