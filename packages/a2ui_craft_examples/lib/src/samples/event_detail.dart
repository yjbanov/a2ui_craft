// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `17_event-detail` — a `Card` with a
/// `Heading` title, time and location `Icon`+`Text` rows, a description, a
/// `Divider`, and Accept/Decline `Button`s. The date/time string is supplied
/// already formatted (the spec composes it with `formatDate`).
SampleSpec eventDetailSpec(String framework) => SampleSpec(
      label: 'Event Detail',
      catalogSource: '''
import core;

widget EventDetail = Card(child: Column(gap: 8.0, children: [
  Heading(text: args.title, level: 2),
  Row(gap: 6.0, crossAxisAlignment: "center", children: [
    Icon(icon: "calendarToday"),
    Text(text: args.time),
  ]),
  Row(gap: 6.0, crossAxisAlignment: "center", children: [
    Icon(icon: "locationOn"),
    Text(text: args.location),
  ]),
  Text(text: args.description),
  Divider(),
  Row(gap: 12.0, children: [
    Button(child: Text(text: args.acceptLabel)),
    Button(child: Text(text: args.declineLabel)),
  ]),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'EventDetail': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'time': <String, Object?>{r'$ref': 'DynamicString'},
              'location': <String, Object?>{r'$ref': 'DynamicString'},
              'description': <String, Object?>{r'$ref': 'DynamicString'},
              'acceptLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'declineLabel': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'EventDetail',
              'title': 'Product Launch Meeting',
              'time': 'Fri, Dec 19 • 2:00 PM - 3:30 PM',
              'location': 'Conference Room A, Building 2',
              'description':
                  'Review final product specs and marketing materials '
                      'before the Q1 launch.',
              'acceptLabel': 'Accept',
              'declineLabel': 'Decline',
            },
          ],
        ),
      ],
    );
