// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:test/test.dart';

/// A small surface exercising literals, data bindings, an event, and a
/// data-driven `ChildList` — all four seed components.
Map<String, Object?> _createSurface() => <String, Object?>{
      'createSurface': <String, Object?>{
        'surfaceId': 's',
        'components': <Object?>[
          <String, Object?>{
            'id': 'root',
            'component': 'Column',
            'children': <Object?>['title', 'greeting', 'list', 'btn'],
          },
          <String, Object?>{
            'id': 'title',
            'component': 'Text',
            'text': 'Hello'
          },
          <String, Object?>{
            'id': 'greeting',
            'component': 'Text',
            'text': <String, Object?>{'path': '/name'},
          },
          <String, Object?>{
            'id': 'list',
            'component': 'Column',
            'children': <String, Object?>{
              'path': '/items',
              'componentId': 'itemTmpl'
            },
          },
          <String, Object?>{
            'id': 'itemTmpl',
            'component': 'Text',
            'text': <String, Object?>{'path': 'label'},
          },
          <String, Object?>{
            'id': 'btn',
            'component': 'Button',
            'child': 'btnLabel',
            'action': <String, Object?>{
              'event': <String, Object?>{
                'name': 'go',
                'context': <String, Object?>{}
              },
            },
          },
          <String, Object?>{
            'id': 'btnLabel',
            'component': 'Text',
            'text': 'Go'
          },
        ],
        'dataModel': <String, Object?>{
          'name': 'Ada',
          'items': <Object?>[
            <String, Object?>{'label': 'a'},
            <String, Object?>{'label': 'b'},
          ],
        },
      },
    };

void main() {
  test('translates an A2UI surface into component listenables', () {
    int notifications = 0;
    final A2uiSurface surface = A2uiSurface(
      adapterBuilder: (String id) => 'adapter:$id',
    );
    final SurfaceListenable<ConstructorCall?> rootListenable =
        surface.componentDefinition('root');
    rootListenable.addListener(() => notifications++);

    surface.apply(_createSurface());
    expect(notifications, 1);

    final ConstructorCall column = rootListenable.value!;
    expect(column.name, 'Column');
    final List<Object?> children =
        column.arguments['children']! as List<Object?>;
    expect(children, <Object?>[
      'adapter:title',
      'adapter:greeting',
      'adapter:list',
      'adapter:btn'
    ]);

    // Inspect the 'title' component separately.
    final ConstructorCall title = surface.componentDefinition('title').value!;
    expect(title.name, 'Text');
    expect(title.arguments['text'], 'Hello');

    // Inspect the 'greeting' component (absolute data binding).
    final ConstructorCall greeting =
        surface.componentDefinition('greeting').value!;
    final DataReference greetingRef =
        greeting.arguments['text']! as DataReference;
    expect(greetingRef.parts, <Object>['name']);

    // Inspect the 'list' component.
    final ConstructorCall list = surface.componentDefinition('list').value!;
    final List<Object?> listChildren =
        list.arguments['children']! as List<Object?>;
    final Loop loop = listChildren.single! as Loop;
    expect((loop.input as DataReference).parts, <Object>['items']);
    final ConstructorCall itemTemplate = loop.output as ConstructorCall;
    final LoopReference itemRef =
        itemTemplate.arguments['text']! as LoopReference;
    expect(itemRef.loop, 0);
    expect(itemRef.parts, <Object>['label']);

    // Inspect the 'btn' component.
    final ConstructorCall button = surface.componentDefinition('btn').value!;
    expect(button.name, 'Button');
    final EventHandler handler = button.arguments['onPressed']! as EventHandler;
    expect(handler.eventName, 'go');
    expect(button.arguments['child'], 'adapter:btnLabel');
  });

  test('updateComponents notifies only the changed component', () {
    final A2uiSurface surface = A2uiSurface(
      adapterBuilder: (String id) => 'adapter:$id',
    )..apply(_createSurface());

    // Subscribe to both the component that will change and an unrelated one.
    int titleNotifications = 0;
    int rootNotifications = 0;
    final SurfaceListenable<ConstructorCall?> title = surface
        .componentDefinition('title')
      ..addListener(() => titleNotifications++);
    surface.componentDefinition('root').addListener(() => rootNotifications++);

    surface.apply(<String, Object?>{
      'updateComponents': <String, Object?>{
        'components': <Object?>[
          <String, Object?>{'id': 'title', 'component': 'Text', 'text': 'Hi'},
        ],
      },
    });

    // Only the touched component's listenable fires; siblings/parents are left
    // alone — this is the partial-update isolation that per-id listenables buy.
    expect(titleNotifications, 1);
    expect(rootNotifications, 0);
    expect(title.value!.arguments['text'], 'Hi');
  });

  test('a component referenced before it arrives renders once it does', () {
    final A2uiSurface surface = A2uiSurface(
      adapterBuilder: (String id) => 'adapter:$id',
    );

    // A host adapter subscribes to an id that has not been ingested yet.
    int notifications = 0;
    final SurfaceListenable<ConstructorCall?> pending =
        surface.componentDefinition('late')..addListener(() => notifications++);
    expect(pending.value, isNull);

    surface.apply(<String, Object?>{
      'updateComponents': <String, Object?>{
        'components': <Object?>[
          <String, Object?>{
            'id': 'late',
            'component': 'Text',
            'text': 'arrived'
          },
        ],
      },
    });

    expect(notifications, 1);
    expect(pending.value!.arguments['text'], 'arrived');
  });

  test('applies updateDataModel reactively', () {
    final A2uiSurface surface = A2uiSurface(
      adapterBuilder: (String id) => 'adapter:$id',
    )..apply(_createSurface());
    expect(surface.data.subscribe(<Object>['name'], (_) {}), 'Ada');

    surface.apply(<String, Object?>{
      'updateDataModel': <String, Object?>{'path': '/name', 'value': 'Grace'},
    });
    expect(surface.data.subscribe(<Object>['name'], (_) {}), 'Grace');
  });

  test('updateDataModel addresses into a list (field, append, remove)', () {
    final A2uiSurface surface = A2uiSurface(
      adapterBuilder: (String id) => 'adapter:$id',
    )..apply(_createSurface());
    expect(surface.data.subscribe(<Object>['items', 0, 'label'], (_) {}), 'a');

    // Update a field inside an existing item.
    surface.apply(<String, Object?>{
      'updateDataModel': <String, Object?>{
        'path': '/items/0/label',
        'value': 'A1'
      },
    });
    expect(surface.data.subscribe(<Object>['items', 0, 'label'], (_) {}), 'A1');
    // Its sibling is untouched.
    expect(surface.data.subscribe(<Object>['items', 1, 'label'], (_) {}), 'b');

    // Append an item at the end (index == length).
    surface.apply(<String, Object?>{
      'updateDataModel': <String, Object?>{
        'path': '/items/2',
        'value': <String, Object?>{'label': 'c'},
      },
    });
    expect(surface.data.subscribe(<Object>['items', 2, 'label'], (_) {}), 'c');

    // Remove an item (null value).
    surface.apply(<String, Object?>{
      'updateDataModel': <String, Object?>{'path': '/items/1', 'value': null},
    });
    final Object items = surface.data.subscribe(<Object>['items'], (_) {});
    expect((items as List<Object?>).length, 2);
    expect(surface.data.subscribe(<Object>['items', 1, 'label'], (_) {}), 'c');
  });

  test('nested ChildList nests the loop scope', () {
    final A2uiSurface surface = A2uiSurface(
      adapterBuilder: (String id) => 'adapter:$id',
    )..apply(<String, Object?>{
        'createSurface': <String, Object?>{
          'surfaceId': 'nested',
          'components': <Object?>[
            <String, Object?>{
              'id': 'root',
              'component': 'Column',
              'children': <String, Object?>{
                'path': '/groups',
                'componentId': 'group',
              },
            },
            <String, Object?>{
              'id': 'group',
              'component': 'Column',
              // Relative path: resolved against each outer (group) item.
              'children': <String, Object?>{
                'path': 'members',
                'componentId': 'member',
              },
            },
            <String, Object?>{
              'id': 'member',
              'component': 'Text',
              'text': <String, Object?>{'path': 'name'},
            },
          ],
        },
      });

    final ConstructorCall root = surface.componentDefinition('root').value!;
    final Loop outer =
        (root.arguments['children']! as List<Object?>).single! as Loop;
    // Outer input is absolute -> DataReference.
    expect((outer.input as DataReference).parts, <Object>['groups']);

    final ConstructorCall group = outer.output as ConstructorCall;
    final Loop inner =
        (group.arguments['children']! as List<Object?>).single! as Loop;
    // Inner input is relative & inside the outer loop -> LoopReference(0).
    final LoopReference innerInput = inner.input as LoopReference;
    expect(innerInput.loop, 0);
    expect(innerInput.parts, <Object>['members']);

    // The leaf binding resolves against the innermost (member) item.
    final ConstructorCall member = inner.output as ConstructorCall;
    final LoopReference name = member.arguments['text']! as LoopReference;
    expect(name.loop, 0);
    expect(name.parts, <Object>['name']);
  });
}
