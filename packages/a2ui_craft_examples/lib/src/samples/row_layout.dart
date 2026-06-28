// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `00_row-layout` — a `Row` that pushes
/// two `Text`s to opposite edges (`spaceBetween`, cross-axis centered).
SampleSpec rowLayoutSpec(String framework) => SampleSpec(
      label: 'Row Layout',
      catalogSource: '''
import core;

widget RowLayout = Row(mainAxisAlignment: "spaceBetween",
  crossAxisAlignment: "center", width: "fill", children: [
    Text(text: args.left),
    Text(text: args.right, variant: "caption"),
  ]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'RowLayout': <String, Object?>{
            'properties': <String, Object?>{
              'left': <String, Object?>{r'$ref': 'DynamicString'},
              'right': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'RowLayout',
              'left': 'Left Content',
              'right': 'Right Content',
            },
          ],
        ),
      ],
    );
