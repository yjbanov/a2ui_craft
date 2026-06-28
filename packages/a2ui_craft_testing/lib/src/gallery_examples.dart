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

/// `14_sports-player` — a data-bound `Card` (`Column` of `Image`, nested
/// `Column`/`Row`s of `Text`, a `Divider`, and a three-stat `Row`). **No
/// functions**: every dynamic value is a plain `path` binding (incl. nested
/// pointers like `/stat1/value`), filled by a trailing `updateDataModel`.
/// Exercises end-to-end data binding through `a2ui_core`'s `GenericBinder`.
const GalleryExample sportsPlayerExample = GalleryExample(
  'Sports Player',
  'gallery-sports-player',
  r'''
{
  "name": "Sports Player",
  "description": "Example of sports player",
  "messages": [
    {
      "version": "v0.9",
      "createSurface": {
        "surfaceId": "gallery-sports-player",
        "catalogId": "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json",
        "sendDataModel": true
      }
    },
    {
      "version": "v0.9",
      "updateComponents": {
        "surfaceId": "gallery-sports-player",
        "components": [
          {
            "id": "root",
            "component": "Card",
            "child": "main_column"
          },
          {
            "id": "main_column",
            "component": "Column",
            "children": ["player_image", "player_info", "divider", "stats_row"],
            "align": "center"
          },
          {
            "id": "player_image",
            "component": "Image",
            "url": {
              "path": "/playerImage"
            },
            "fit": "cover"
          },
          {
            "id": "player_info",
            "component": "Column",
            "children": ["player_name", "player_details"],
            "align": "center"
          },
          {
            "id": "player_name",
            "component": "Text",
            "text": {
              "path": "/playerName"
            }
          },
          {
            "id": "player_details",
            "component": "Row",
            "children": ["player_number", "player_team"],
            "align": "center"
          },
          {
            "id": "player_number",
            "component": "Text",
            "text": {
              "path": "/number"
            }
          },
          {
            "id": "player_team",
            "component": "Text",
            "text": {
              "path": "/team"
            },
            "variant": "caption"
          },
          {
            "id": "divider",
            "component": "Divider"
          },
          {
            "id": "stats_row",
            "component": "Row",
            "children": ["stat1", "stat2", "stat3"],
            "justify": "spaceAround"
          },
          {
            "id": "stat1",
            "component": "Column",
            "children": ["stat1_value", "stat1_label"],
            "align": "center"
          },
          {
            "id": "stat1_value",
            "component": "Text",
            "text": {
              "path": "/stat1/value"
            }
          },
          {
            "id": "stat1_label",
            "component": "Text",
            "text": {
              "path": "/stat1/label"
            },
            "variant": "caption"
          },
          {
            "id": "stat2",
            "component": "Column",
            "children": ["stat2_value", "stat2_label"],
            "align": "center"
          },
          {
            "id": "stat2_value",
            "component": "Text",
            "text": {
              "path": "/stat2/value"
            }
          },
          {
            "id": "stat2_label",
            "component": "Text",
            "text": {
              "path": "/stat2/label"
            },
            "variant": "caption"
          },
          {
            "id": "stat3",
            "component": "Column",
            "children": ["stat3_value", "stat3_label"],
            "align": "center"
          },
          {
            "id": "stat3_value",
            "component": "Text",
            "text": {
              "path": "/stat3/value"
            }
          },
          {
            "id": "stat3_label",
            "component": "Text",
            "text": {
              "path": "/stat3/label"
            },
            "variant": "caption"
          }
        ]
      }
    },
    {
      "version": "v0.9",
      "updateDataModel": {
        "surfaceId": "gallery-sports-player",
        "value": {
          "playerImage": "https://images.unsplash.com/photo-1546519638-68e109498ffc?w=200&h=200&fit=crop",
          "playerName": "Marcus Johnson",
          "number": "#23",
          "team": "LA Lakers",
          "stat1": {
            "value": "28.4",
            "label": "PPG"
          },
          "stat2": {
            "value": "7.2",
            "label": "RPG"
          },
          "stat3": {
            "value": "6.8",
            "label": "APG"
          }
        }
      }
    }
  ]
}
''',
);

/// `00_formatted-text` — a `Column` of a `TextField`, a label `Text`, and a
/// `Text` whose value is a `formatString` call interpolating `${/inputValue}`.
/// Proves **function resolution** (the bridge registers [FormatStringFunction])
/// and a data-bound two-way `value`. The `TextField`'s `label` is a composite
/// control prop the core primitive does not render yet (it renders bare), so the
/// proof asserts on the `formatString` output `Text`, not the field's label.
const GalleryExample formattedTextExample = GalleryExample(
  'Formatted Text',
  'gallery-formatted-text',
  r'''
{
  "name": "Formatted Text",
  "description": "Simple example demonstrating basic catalog components.",
  "messages": [
    {
      "version": "v0.9",
      "createSurface": {
        "surfaceId": "gallery-formatted-text",
        "catalogId": "https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json",
        "sendDataModel": true
      }
    },
    {
      "version": "v0.9",
      "updateComponents": {
        "surfaceId": "gallery-formatted-text",
        "components": [
          {
            "id": "root",
            "component": "Column",
            "children": ["input_field", "result_label", "result_text"],
            "justify": "start",
            "align": "stretch"
          },
          {
            "id": "input_field",
            "component": "TextField",
            "label": "Type something:",
            "value": {
              "path": "/inputValue"
            },
            "variant": "shortText"
          },
          {
            "id": "result_label",
            "component": "Text",
            "text": "Formatted output:",
            "variant": "caption"
          },
          {
            "id": "result_text",
            "component": "Text",
            "text": {
              "call": "formatString",
              "args": {
                "value": "You typed: ${/inputValue}"
              }
            },
            "variant": "body"
          }
        ]
      }
    }
  ]
}
''',
);
