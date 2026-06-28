// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `03_calendar-day` — a `Card` with a
/// day/number column beside a `...for` list of events, a `Divider`, and
/// Add/Discard `Button`s. Dates are supplied already formatted. A fixed width
/// gives the `Expanded` events column room.
SampleSpec calendarDaySpec(String framework) => SampleSpec(
      label: 'Calendar Day',
      catalogSource: '''
import core;

widget EventItem = Column(gap: 1.0, children: [
  Text(text: args.title),
  Text(text: args.time, variant: "caption"),
]);

widget CalendarDay = Card(child: Column(crossAxisAlignment: "stretch", gap: 8.0,
  children: [
    Row(gap: 16.0, crossAxisAlignment: "start", children: [
      Column(crossAxisAlignment: "center", gap: 2.0, children: [
        Text(text: args.dayName, variant: "caption"),
        Heading(text: args.dayNumber, level: 1),
      ]),
      Expanded(child: Column(gap: 6.0, children: [
        ...for e in args.events: EventItem(title: e.title, time: e.time),
      ])),
    ]),
    Divider(),
    Row(gap: 12.0, children: [
      Button(child: Text(text: "Add to calendar")),
      Button(child: Text(text: "Discard")),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'CalendarDay': <String, Object?>{
            'properties': <String, Object?>{
              'dayName': <String, Object?>{r'$ref': 'DynamicString'},
              'dayNumber': <String, Object?>{r'$ref': 'DynamicString'},
              'events': <String, Object?>{
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
              'component': 'CalendarDay',
              'dayName': 'Sunday',
              'dayNumber': '28',
              'events': <Object?>[
                <String, Object?>{
                  'title': 'Lunch',
                  'time': '12:00 - 12:45 PM',
                },
                <String, Object?>{
                  'title': 'Q1 roadmap review',
                  'time': '1:00 - 2:00 PM',
                },
                <String, Object?>{
                  'title': 'Team standup',
                  'time': '3:30 - 4:00 PM',
                },
              ],
            },
          ],
        ),
      ],
    );
