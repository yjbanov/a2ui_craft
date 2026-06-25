// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample.dart';

const List<String> _images = <String>[
  'https://images.unsplash.com/photo-1507838153414-b4b713384a76?w=50&h=50&fit=crop',
  'https://images.unsplash.com/photo-1511379938547-c1f69419868d?w=50&h=50&fit=crop',
  'https://images.unsplash.com/photo-1470225620780-dba8ba36b745?w=50&h=50&fit=crop',
];

/// A high-level `Gallery` widget: the agent passes a list of image URLs and the
/// template iterates over them internally (`...for url in args.images`), so the
/// A2UI payload is a single component.
class GallerySample extends Sample {
  const GallerySample({super.key});

  @override
  String get catalogSource => '''
import core;

widget Gallery = ScrollView(child: Column(children: [
  ...for url in args.images: Image(url: url),
]));
''';

  @override
  Map<String, Object?> get catalogSchema => <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Gallery': <String, Object?>{
            'properties': <String, Object?>{
              'images': <String, Object?>{
                'type': 'array',
                'items': <String, Object?>{'type': 'string'},
              },
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
              'component': 'Gallery',
              'images': <Object?>[..._images],
            },
          ],
        ),
      ];
}
