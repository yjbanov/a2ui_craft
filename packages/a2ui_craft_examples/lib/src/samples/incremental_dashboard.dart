// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `31_incremental-dashboard` — a
/// `Heading` over two side-by-side panels (`weight: 1` each → `Expanded`): an
/// analytics `Card` and a `...for` logs `Card`. The spec streams each panel in
/// to replace a loading placeholder; the template renders the resolved state.
SampleSpec incrementalDashboardSpec(String framework) => SampleSpec(
      label: 'Dashboard',
      catalogSource: '''
import core;

widget Dashboard = Column(crossAxisAlignment: "stretch", gap: 10.0, children: [
  Heading(text: args.title, level: 2),
  Row(gap: 12.0, crossAxisAlignment: "start", children: [
    Expanded(child: Card(child: Column(crossAxisAlignment: "stretch", gap: 4.0,
      children: [
        Heading(text: args.analyticsTitle, level: 4),
        Text(text: args.analyticsText),
      ]))),
    Expanded(child: Card(child: Column(crossAxisAlignment: "stretch", gap: 4.0,
      children: [
        Heading(text: args.logsTitle, level: 4),
        ...for log in args.logs: Text(text: log.message, variant: "caption"),
      ]))),
  ]),
]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Dashboard': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'analyticsTitle': <String, Object?>{r'$ref': 'DynamicString'},
              'analyticsText': <String, Object?>{r'$ref': 'DynamicString'},
              'logsTitle': <String, Object?>{r'$ref': 'DynamicString'},
              'logs': <String, Object?>{
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
              'component': 'Dashboard',
              'title': 'System Dashboard',
              'analyticsTitle': 'Analytics',
              'analyticsText': 'Analytics are ready.',
              'logsTitle': 'Logs',
              'logs': <Object?>[
                <String, Object?>{'message': 'System boot complete.'},
                <String, Object?>{'message': 'All services healthy.'},
                <String, Object?>{'message': 'Waiting for user input.'},
              ],
            },
          ],
        ),
      ],
    );
