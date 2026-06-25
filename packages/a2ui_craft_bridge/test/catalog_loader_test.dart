// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:test/test.dart';

/// A catalog authored as raw JSON — no schema code — referencing A2UI common
/// types by `$ref`, exactly as it would arrive over the wire.
final Map<String, Object?> _catalogJson = <String, Object?>{
  'catalogId': 'demo',
  'components': <String, Object?>{
    'Greeting': <String, Object?>{
      'properties': <String, Object?>{
        'title': <String, Object?>{r'$ref': 'DynamicString'},
        'action': <String, Object?>{r'$ref': 'Action'},
      },
    },
    'Stack': <String, Object?>{
      'properties': <String, Object?>{
        'children': <String, Object?>{r'$ref': 'ChildList'},
      },
      'required': <Object?>['children'],
    },
    'Card': <String, Object?>{
      'properties': <String, Object?>{
        // Canonical $ref form also resolves.
        'child': <String, Object?>{
          r'$ref': r'common_types.json#/$defs/ComponentId',
        },
      },
    },
    'Gallery': <String, Object?>{
      'properties': <String, Object?>{
        // Plain JSON Schema (not a common type) passes through untouched.
        'images': <String, Object?>{
          'type': 'array',
          'items': <String, Object?>{'type': 'string'},
        },
      },
    },
  },
};

SurfaceModel<ComponentApi> _surface() {
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(catalogs: [loadCatalog(_catalogJson)]);
  processor.processMessages(<A2uiMessage>[
    CreateSurfaceMessage(surfaceId: 's', catalogId: 'demo'),
    UpdateDataModelMessage(
      surfaceId: 's',
      path: '/',
      value: <String, Object?>{'name': 'Ada'},
    ),
    UpdateComponentsMessage(surfaceId: 's', components: [
      <String, dynamic>{
        'id': 'g',
        'component': 'Greeting',
        'title': <String, dynamic>{'path': '/name'},
        'action': <String, dynamic>{
          'event': <String, dynamic>{'name': 'go'},
        },
      },
      <String, dynamic>{
        'id': 'stack',
        'component': 'Stack',
        'children': ['g']
      },
      <String, dynamic>{'id': 'card', 'component': 'Card', 'child': 'g'},
      <String, dynamic>{
        'id': 'gallery',
        'component': 'Gallery',
        'images': <Object?>['x', 'y', 'z'],
      },
    ]),
  ]);
  return processor.groupModel.getSurface('s')!;
}

void main() {
  test('loadCatalog builds a catalog with the named components', () {
    final Catalog<ComponentApi> catalog = loadCatalog(_catalogJson);
    expect(catalog.id, 'demo');
    expect(
      catalog.components.keys,
      containsAll(<String>['Greeting', 'Stack', 'Card', 'Gallery']),
    );
  });

  test('a DynamicString \$ref binds data, an Action \$ref resolves a callback',
      () {
    final A2uiComponentBinding binding = A2uiComponentBinding(_surface(), 'g');
    addTearDown(binding.dispose);
    // The data-bound title resolved to the model value...
    expect(binding.resolvedProps!['title'], 'Ada');
    // ...and the action resolved to an invokable callback.
    expect(binding.resolvedProps!['action'], isA<Function>());
  });

  test('a ChildList \$ref resolves to structural ChildNodes', () {
    final A2uiComponentBinding binding =
        A2uiComponentBinding(_surface(), 'stack');
    addTearDown(binding.dispose);
    final Object? children = binding.resolvedProps!['children'];
    expect(children, isA<List<Object?>>());
    expect((children as List).single, isA<ChildNode>());
    expect((children.single as ChildNode).id, 'g');
  });

  test('a ComponentId \$ref is reported as a single child reference', () {
    final A2uiComponentBinding binding =
        A2uiComponentBinding(_surface(), 'card');
    addTearDown(binding.dispose);
    expect(binding.childRefs, contains('child'));
  });

  test('a plain (non-common-type) JSON Schema passes through', () {
    final A2uiComponentBinding binding =
        A2uiComponentBinding(_surface(), 'gallery');
    addTearDown(binding.dispose);
    expect(binding.resolvedProps!['images'], <Object?>['x', 'y', 'z']);
  });
}
