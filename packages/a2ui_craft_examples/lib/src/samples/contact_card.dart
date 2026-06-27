// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// A `ContactCard` high-level widget, modeled on the A2UI Basic Catalog gallery's
/// Contact Card: a `Card` wrapping a centered `Column` of an avatar `Image`, a
/// name, a caption title, a `Divider`, and `Icon`+`Text` rows. It exercises the
/// atoms slice (Text variants, Image variant/fit, Icon, Divider) composed over
/// the layout primitives.
SampleSpec contactCardSpec(String framework) => SampleSpec(
      label: 'Contact Card',
      catalogSource: '''
import core;

widget ContactCard = Card(
  child: Column(crossAxisAlignment: "center", gap: 8.0, children: [
    Image(url: args.avatar, variant: "avatar", fit: "cover"),
    Text(text: args.name),
    Text(text: args.title, variant: "caption"),
    Divider(),
    Column(gap: 6.0, children: [
      Row(gap: 8.0, children: [Icon(icon: "phone"), Text(text: args.phone)]),
      Row(gap: 8.0, children: [Icon(icon: "email"), Text(text: args.email)]),
      Row(gap: 8.0,
          children: [Icon(icon: "location"), Text(text: args.location)]),
    ]),
  ]),
);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'ContactCard': <String, Object?>{
            'properties': <String, Object?>{
              'name': <String, Object?>{r'$ref': 'DynamicString'},
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'avatar': <String, Object?>{r'$ref': 'DynamicString'},
              'phone': <String, Object?>{r'$ref': 'DynamicString'},
              'email': <String, Object?>{r'$ref': 'DynamicString'},
              'location': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'ContactCard',
              'name': 'Ada Lovelace',
              'title': 'Mathematician',
              // example.com renders a placeholder avatar (no network in tests).
              'avatar': 'https://example.com/ada.jpg',
              'phone': '+1 555 0100',
              'email': 'ada@example.com',
              'location': 'London, UK',
            },
          ],
        ),
      ],
    );
