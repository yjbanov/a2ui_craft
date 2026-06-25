// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// A high-level `Counter` widget. The count lives in the surface's data model;
/// pressing the button dispatches `increment`, which reads the current count,
/// adds one, and writes it back — the bound text re-renders reactively.
SampleSpec counterSpec(String framework) => SampleSpec(
      label: 'Counter',
      catalogSource: '''
import core;

widget Counter = Column(children: [
  Text(text: args.label),
  Text(text: args.count),
  Button(onPressed: args.action, child: Text(text: args.buttonLabel)),
]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Counter': <String, Object?>{
            'properties': <String, Object?>{
              'label': <String, Object?>{r'$ref': 'DynamicString'},
              'count': <String, Object?>{r'$ref': 'DynamicString'},
              'buttonLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'action': <String, Object?>{r'$ref': 'Action'},
            },
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateDataModelMessage(
          surfaceId: surfaceId,
          path: '/',
          value: <String, Object?>{'count': '0'},
        ),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'Counter',
              'label': 'You have pushed the button this many times:',
              'count': <String, dynamic>{'path': '/count'},
              'buttonLabel': 'Increment',
              'action': <String, dynamic>{
                'event': <String, dynamic>{
                  'name': 'increment',
                  'context': <String, dynamic>{},
                },
              },
            },
          ],
        ),
      ],
      onAction: (A2uiClientAction action, SampleHost host) {
        if (action.name == 'increment') {
          final int current =
              int.tryParse(host.read('/count') as String? ?? '0') ?? 0;
          host.updateData('/count', '${current + 1}');
        }
      },
    );
