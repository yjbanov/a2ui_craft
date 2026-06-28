// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `12_chat-message` — a `Card` with a
/// channel `Heading` header, a `Divider`, and a `...for` list of messages, each
/// an avatar + (username, time) header + body. Avatars are `example.com`
/// placeholders; times are supplied already formatted.
SampleSpec chatMessageSpec(String framework) => SampleSpec(
      label: 'Chat',
      catalogSource: '''
import core;

widget ChatMessage = Card(child: Column(gap: 8.0, children: [
  Row(gap: 6.0, crossAxisAlignment: "center", children: [
    Icon(icon: "info"),
    Heading(text: args.channelName, level: 3),
  ]),
  Divider(),
  Column(gap: 10.0, children: [
    ...for msg in args.messages: Row(gap: 8.0, crossAxisAlignment: "start",
      children: [
        Image(url: msg.avatar, variant: "avatar", fit: "cover"),
        // A fixed width bounds the message body so it wraps, instead of forcing
        // the row as wide as the longest line.
        SizedBox(width: 240.0, child: Column(gap: 2.0, children: [
          Row(gap: 6.0, crossAxisAlignment: "center", children: [
            Text(text: msg.username),
            Text(text: msg.time, variant: "caption"),
          ]),
          Text(text: msg.text),
        ])),
      ]),
  ]),
]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'ChatMessage': <String, Object?>{
            'properties': <String, Object?>{
              'channelName': <String, Object?>{r'$ref': 'DynamicString'},
              'messages': <String, Object?>{
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
              'component': 'ChatMessage',
              'channelName': 'project-updates',
              'messages': <Object?>[
                <String, Object?>{
                  'avatar': 'https://example.com/mike.jpg',
                  'username': 'Mike Chen',
                  'time': '10:32 AM',
                  'text': 'Just pushed the new API changes. Ready for review.',
                },
                <String, Object?>{
                  'avatar': 'https://example.com/sarah.jpg',
                  'username': 'Sarah Kim',
                  'time': '10:45 AM',
                  'text': "Great! I'll take a look after standup.",
                },
              ],
            },
          ],
        ),
      ],
    );
