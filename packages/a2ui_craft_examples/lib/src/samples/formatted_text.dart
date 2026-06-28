// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `00_formatted-text` — a labelled text
/// field over a formatted result line. The A2UI `TextField` bundles its label;
/// our bare `TextField` gets the label as a sibling `Text` *in the template*.
/// The `formatString` result is supplied already interpolated.
SampleSpec formattedTextSpec(String framework) => SampleSpec(
      label: 'Formatted Text',
      catalogSource: '''
import core;

widget Labelled = Column(gap: 4.0, children: [
  Text(text: args.label, variant: "caption"),
  TextField(value: args.value),
]);

widget FormattedText = Column(crossAxisAlignment: "stretch", gap: 8.0,
  children: [
    Labelled(label: args.inputLabel, value: args.inputValue),
    Text(text: args.resultLabel, variant: "caption"),
    Text(text: args.result),
  ]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'FormattedText': <String, Object?>{
            'properties': <String, Object?>{
              'inputLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'inputValue': <String, Object?>{r'$ref': 'DynamicString'},
              'resultLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'result': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'FormattedText',
              'inputLabel': 'Type something:',
              'inputValue': 'hello',
              'resultLabel': 'Formatted output:',
              'result': 'You typed: hello',
            },
          ],
        ),
      ],
    );
