// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `00_interactive-button` — a centered
/// `Column` of a prompt `Text` and a `Button`. (The button's action is a host
/// concern; the Greeting/Counter samples already exercise the event path.)
SampleSpec interactiveButtonSpec(String framework) => SampleSpec(
      label: 'Interactive Button',
      catalogSource: '''
import core;

widget InteractiveButton = Column(crossAxisAlignment: "center",
  mainAxisAlignment: "center", gap: 12.0, children: [
    Text(text: args.prompt),
    Button(child: Text(text: args.label)),
  ]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'InteractiveButton': <String, Object?>{
            'properties': <String, Object?>{
              'prompt': <String, Object?>{r'$ref': 'DynamicString'},
              'label': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'InteractiveButton',
              'prompt': 'Click the button below',
              'label': 'Click Me',
            },
          ],
        ),
      ],
    );
