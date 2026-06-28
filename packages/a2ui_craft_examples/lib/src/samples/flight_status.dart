// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `01_flight-status` — a `Card` with a
/// header `Row` (flight number + date), an origin → destination route, a
/// `Divider`, and a three-column departs/status/arrives `Row`. Dates/times are
/// supplied already formatted (the spec uses `formatDate`).
SampleSpec flightStatusSpec(String framework) => SampleSpec(
      label: 'Flight Status',
      catalogSource: '''
import core;

widget FlightStatus = Card(child: Column(crossAxisAlignment: "stretch",
  gap: 8.0, children: [
    Row(mainAxisAlignment: "spaceBetween", crossAxisAlignment: "center",
      width: "fill", children: [
        Row(gap: 6.0, crossAxisAlignment: "center", children: [
          Icon(icon: "send"),
          Text(text: args.flightNumber),
        ]),
        Text(text: args.date, variant: "caption"),
      ]),
    Row(gap: 8.0, mainAxisAlignment: "center", crossAxisAlignment: "center",
      children: [
        Text(text: args.origin),
        Text(text: "→"),
        Text(text: args.destination),
      ]),
    Divider(),
    Row(mainAxisAlignment: "spaceBetween", width: "fill", children: [
      Column(crossAxisAlignment: "start", gap: 2.0, children: [
        Text(text: "Departs", variant: "caption"),
        Text(text: args.departure),
      ]),
      Column(crossAxisAlignment: "center", gap: 2.0, children: [
        Text(text: "Status", variant: "caption"),
        Text(text: args.status),
      ]),
      Column(crossAxisAlignment: "end", gap: 2.0, children: [
        Text(text: "Arrives", variant: "caption"),
        Text(text: args.arrival),
      ]),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'FlightStatus': <String, Object?>{
            'properties': <String, Object?>{
              'flightNumber': <String, Object?>{r'$ref': 'DynamicString'},
              'date': <String, Object?>{r'$ref': 'DynamicString'},
              'origin': <String, Object?>{r'$ref': 'DynamicString'},
              'destination': <String, Object?>{r'$ref': 'DynamicString'},
              'departure': <String, Object?>{r'$ref': 'DynamicString'},
              'status': <String, Object?>{r'$ref': 'DynamicString'},
              'arrival': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'FlightStatus',
              'flightNumber': 'OS 87',
              'date': 'Mon, Dec 15',
              'origin': 'Vienna',
              'destination': 'New York',
              'departure': '10:15 AM',
              'status': 'On Time',
              'arrival': '2:30 PM',
            },
          ],
        ),
      ],
    );
