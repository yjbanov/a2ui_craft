// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:test/test.dart';

// Uses a2ui_core's exported `MinimalCatalog` (Text/Column/...) as the catalog so
// this test needs no schema definitions of its own.

(MessageProcessor<ComponentApi>, SurfaceModel<ComponentApi>) _surface(
  List<A2uiMessage> messages,
) {
  final processor =
      MessageProcessor<ComponentApi>(catalogs: [MinimalCatalog()]);
  processor.processMessages(messages);
  return (processor, processor.groupModel.getSurface('s')!);
}

A2uiMessage _create() =>
    CreateSurfaceMessage(surfaceId: 's', catalogId: MinimalCatalog().id);

void main() {
  group('a2uiArgsFromProps', () {
    test('passes scalars through by name', () {
      final args = a2uiArgsFromProps(
        <String, dynamic>{'text': 'Hello', 'count': 3},
        (_) => fail('no children expected'),
      );
      expect(args, <String, Object?>{'text': 'Hello', 'count': 3});
    });

    test('injects a child per ChildNode in a structural list', () {
      final args = a2uiArgsFromProps(
        <String, dynamic>{
          'children': <ChildNode>[ChildNode('a', '/'), ChildNode('b', '/')],
        },
        (ChildNode c) => 'node:${c.id}@${c.basePath}',
      );
      expect(args['children'], <Object?>['node:a@/', 'node:b@/']);
    });

    test('injects a single child for a childRef prop (componentId)', () {
      final args = a2uiArgsFromProps(
        <String, dynamic>{'child': 'inner', 'title': 'not a child'},
        (ChildNode c) => 'node:${c.id}@${c.basePath}',
        childRefs: <String>{'child'},
        basePath: '/items/0',
      );
      // The childRef prop becomes one injected child at the owner's scope...
      expect(args['child'], 'node:inner@/items/0');
      // ...while an ordinary string prop passes through untouched.
      expect(args['title'], 'not a child');
    });
  });

  group('A2uiComponentBinding.childRefs', () {
    test('reports componentId props as single child references', () {
      // a2ui_core's MinimalButton has a `child` componentId slot.
      final (_, surface) = _surface(<A2uiMessage>[
        _create(),
        UpdateComponentsMessage(surfaceId: 's', components: [
          <String, dynamic>{'id': 'lbl', 'component': 'Text', 'text': 'hi'},
          <String, dynamic>{
            'id': 'btn',
            'component': 'Button',
            'child': 'lbl',
            'action': <String, dynamic>{
              'event': <String, dynamic>{'name': 'go'},
            },
          },
        ]),
      ]);

      final button = A2uiComponentBinding(surface, 'btn');
      addTearDown(button.dispose);
      expect(button.childRefs, contains('child'));

      final label = A2uiComponentBinding(surface, 'lbl');
      addTearDown(label.dispose);
      expect(label.childRefs, isEmpty);
    });
  });

  group('A2uiComponentBinding', () {
    test('exposes the resolved type and props of a present component', () {
      final (_, surface) = _surface(<A2uiMessage>[
        _create(),
        UpdateDataModelMessage(surfaceId: 's', path: '/name', value: 'Ada'),
        UpdateComponentsMessage(surfaceId: 's', components: [
          <String, dynamic>{
            'id': 'greeting',
            'component': 'Text',
            'text': <String, dynamic>{'path': '/name'},
          },
        ]),
      ]);

      final binding = A2uiComponentBinding(surface, 'greeting');
      addTearDown(binding.dispose);

      expect(binding.type, 'Text');
      expect(binding.resolvedProps!['text'], 'Ada');
    });

    test('notifies and re-resolves when bound data changes', () {
      final (processor, surface) = _surface(<A2uiMessage>[
        _create(),
        UpdateDataModelMessage(surfaceId: 's', path: '/name', value: 'Ada'),
        UpdateComponentsMessage(surfaceId: 's', components: [
          <String, dynamic>{
            'id': 'greeting',
            'component': 'Text',
            'text': <String, dynamic>{'path': '/name'},
          },
        ]),
      ]);

      final binding = A2uiComponentBinding(surface, 'greeting');
      addTearDown(binding.dispose);
      var notifications = 0;
      binding.addListener(() => notifications++);

      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(surfaceId: 's', path: '/name', value: 'Grace'),
      ]);

      expect(notifications, greaterThan(0));
      expect(binding.resolvedProps!['text'], 'Grace');
    });

    test('binds a component that arrives after the binding (forward ref)', () {
      final (processor, surface) = _surface(<A2uiMessage>[_create()]);

      final binding = A2uiComponentBinding(surface, 'late');
      addTearDown(binding.dispose);
      expect(binding.type, isNull);
      expect(binding.resolvedProps, isNull);

      var notified = false;
      binding.addListener(() => notified = true);

      processor.processMessages(<A2uiMessage>[
        UpdateComponentsMessage(surfaceId: 's', components: [
          <String, dynamic>{
            'id': 'late',
            'component': 'Text',
            'text': 'arrived',
          },
        ]),
      ]);

      expect(notified, isTrue);
      expect(binding.type, 'Text');
      expect(binding.resolvedProps!['text'], 'arrived');
    });
  });
}
