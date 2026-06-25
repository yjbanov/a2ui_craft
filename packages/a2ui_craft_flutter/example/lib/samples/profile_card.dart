// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample.dart';

const String _avatar1 =
    'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=50&h=50&fit=crop';
const String _avatar2 =
    'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=50&h=50&fit=crop';

/// A high-level `ProfileCard` widget — a template composing `Card`, `Image`,
/// `Row`, `Text`, `Icon`, and `Divider`. The agent passes a name/avatar/bio and
/// arranges several of them with the layout `Column`.
class ProfileCardSample extends Sample {
  const ProfileCardSample({super.key});

  @override
  String get catalogSource => '''
import core;

widget ProfileCard = Card(child: Column(children: [
  Image(url: args.avatarUrl),
  Row(children: [
    Text(text: args.name),
    Icon(icon: "check"),
  ]),
  Divider(),
  Text(text: args.bio),
]));
''';

  @override
  Map<String, Object?> get catalogSchema => <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Column': <String, Object?>{
            'properties': <String, Object?>{
              'children': <String, Object?>{r'$ref': 'ChildList'},
            },
            'required': <Object?>['children'],
          },
          'ProfileCard': <String, Object?>{
            'properties': <String, Object?>{
              'name': <String, Object?>{r'$ref': 'DynamicString'},
              'avatarUrl': <String, Object?>{r'$ref': 'DynamicString'},
              'bio': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
        },
      };

  @override
  List<A2uiMessage> buildMessages() => <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'Column',
              'children': <Object?>['p1', 'p2'],
            },
            <String, dynamic>{
              'id': 'p1',
              'component': 'ProfileCard',
              'name': 'Flutter Framework',
              'avatarUrl': _avatar1,
              'bio': 'Build apps for any screen.',
            },
            <String, dynamic>{
              'id': 'p2',
              'component': 'ProfileCard',
              'name': 'Dart',
              'avatarUrl': _avatar2,
              'bio':
                  'A client-optimized language for fast apps on any platform.',
            },
          ],
        ),
      ];
}
