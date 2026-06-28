// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';

/// A real A2UI Basic Catalog example surface, vendored **verbatim** from the A2UI
/// spec (`specification/v1_0/catalogs/basic/examples`).
///
/// These let tests render the *actual* gallery JSON — parsed through
/// `a2ui_core` and the bridge's `a2uiBasicCatalog()` / `a2uiBasicCatalogCall`
/// against the core primitives — rather than hand-authored Craft templates, so
/// "we can render the gallery" is proven against the source of truth.
///
/// The only change from the spec files is the message `version` tag (`v1.0` →
/// `v0.9`), to match the pinned `a2ui_core`; the component/data structure is
/// untouched. (The two protocol revisions share this envelope shape.)
class GalleryExample {
  const GalleryExample(this.name, this.surfaceId, this.json);

  /// The example's display name (from the spec file's `name`).
  final String name;

  /// The `surfaceId` the example's messages create.
  final String surfaceId;

  /// The raw example JSON, exactly as it appears in the spec.
  final String json;

  /// The example's messages, decoded into `a2ui_core` [A2uiMessage]s ready for a
  /// `MessageProcessor`.
  List<A2uiMessage> get messages => <A2uiMessage>[
        for (final Object? m in jsonDecode(json)['messages'] as List<Object?>)
          A2uiMessage.fromJson(m as Map<String, dynamic>),
      ];
}

/// `00_row-layout` — a `Row` (`justify: spaceBetween`, `align: center`) of two
/// `Text`s with `body`/`caption` variants. Exercises the Basic-Catalog prop
/// transform (`justify`/`align` → `mainAxisAlignment`/`crossAxisAlignment`) with
/// no data bindings or functions.
const GalleryExample rowLayoutExample = GalleryExample(
  'Row Layout',
  'gallery-row-layout',
  r'''
{
  "name": "Row Layout",
  "description": "Simple example demonstrating basic catalog components.",
  "messages": [
    {
      "version": "v0.9",
      "createSurface": {
        "surfaceId": "gallery-row-layout",
        "catalogId": "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json"
      }
    },
    {
      "version": "v0.9",
      "updateComponents": {
        "surfaceId": "gallery-row-layout",
        "components": [
          {
            "id": "root",
            "component": "Row",
            "children": ["left_text", "right_text"],
            "justify": "spaceBetween",
            "align": "center"
          },
          {
            "id": "left_text",
            "component": "Text",
            "text": "Left Content",
            "variant": "body"
          },
          {
            "id": "right_text",
            "component": "Text",
            "text": "Right Content",
            "variant": "caption"
          }
        ]
      }
    }
  ]
}
''',
);
