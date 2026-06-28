// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `35_markdown-text` — a `Card` whose
/// body is the **`Markdown` primitive**, rendering a heading, a paragraph with
/// inline emphasis, a list, and a link from a single Markdown string. (The
/// A2UI `Text` is itself Markdown; we keep `Text` plain and render rich content
/// with the dedicated `Markdown` primitive.)
SampleSpec markdownTextSpec(String framework) => SampleSpec(
      label: 'Markdown',
      catalogSource: '''
import core;

widget MarkdownText = Card(child: Column(crossAxisAlignment: "stretch",
  gap: 8.0, children: [
    Text(text: args.title),
    Markdown(text: args.content),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'MarkdownText': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'content': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'MarkdownText',
              'title': 'Markdown Rendering',
              'content': '# Heading 1\n\n'
                  'This is **bold** text and *italic* text.\n\n'
                  '- List item 1\n'
                  '- List item 2\n\n'
                  '[Link to Google](https://google.com)',
            },
          ],
        ),
      ],
    );
