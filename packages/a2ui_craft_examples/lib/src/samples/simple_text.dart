// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `00_simple-text` — the minimal
/// surface: a single `Text`. (The spec's `Text` is Markdown; our primitive is
/// plain, so the `#` heading marker is dropped.)
SampleSpec simpleTextSpec(String framework) => SampleSpec(
      label: 'Simple Text',
      catalogSource: '''
import core;

widget SimpleText = Text(text: args.text);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'SimpleText': <String, Object?>{
            'properties': <String, Object?>{
              'text': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'SimpleText',
              'text': 'Hello, Minimal Catalog!',
            },
          ],
        ),
      ],
    );
