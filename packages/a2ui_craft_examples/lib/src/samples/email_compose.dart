// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `02_email-compose` — a `Card` with
/// from/to/subject label rows, a `Divider`, the message body, and Send/Discard
/// `Button`s. A fixed width lets the body wrap.
SampleSpec emailComposeSpec(String framework) => SampleSpec(
      label: 'Email Compose',
      catalogSource: '''
import core;

widget Field = Column(gap: 1.0, children: [
  Text(text: args.label, variant: "caption"),
  Text(text: args.value),
]);

widget EmailCompose = SizedBox(width: 360.0, child: Card(child: Column(
  crossAxisAlignment: "stretch", gap: 6.0, children: [
    Field(label: "FROM", value: args.from),
    Field(label: "TO", value: args.to),
    Field(label: "SUBJECT", value: args.subject),
    Divider(),
    Column(gap: 6.0, children: [
      Text(text: args.greeting),
      Text(text: args.body),
      Text(text: args.closing),
      Text(text: args.signature),
    ]),
    Row(gap: 12.0, children: [
      Button(child: Text(text: "Send email")),
      Button(child: Text(text: "Discard")),
    ]),
  ])));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'EmailCompose': <String, Object?>{
            'properties': <String, Object?>{
              'from': <String, Object?>{r'$ref': 'DynamicString'},
              'to': <String, Object?>{r'$ref': 'DynamicString'},
              'subject': <String, Object?>{r'$ref': 'DynamicString'},
              'greeting': <String, Object?>{r'$ref': 'DynamicString'},
              'body': <String, Object?>{r'$ref': 'DynamicString'},
              'closing': <String, Object?>{r'$ref': 'DynamicString'},
              'signature': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'EmailCompose',
              'from': 'alex@acme.com',
              'to': 'jordan@acme.com',
              'subject': 'Q4 Revenue Forecast',
              'greeting': 'Hi Jordan,',
              'body': 'Following up on our call. Please review the attached Q4 '
                  'forecast and let me know if you have questions before the '
                  'board meeting.',
              'closing': 'Best,',
              'signature': 'Alex',
            },
          ],
        ),
      ],
    );
