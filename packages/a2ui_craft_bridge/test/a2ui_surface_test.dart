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
  test('translates an A2UI surface into an RFW library', () {
    final A2uiSurface surface = A2uiSurface()..apply(_createSurface());
    final RemoteWidgetLibrary library = surface.library;

    expect(library.imports.single.name.parts, <String>['core']);
    final WidgetDeclaration root = library.widgets.single;
    expect(root.name, 'root');

    final ConstructorCall column = root.root as ConstructorCall;
    expect(column.name, 'Column');
    final List<Object?> children =
        column.arguments['children']! as List<Object?>;
    expect(children, hasLength(4));

    // Literal text + the id carried through as `key`.
    final ConstructorCall title = children[0]! as ConstructorCall;
    expect(title.name, 'Text');
    expect(title.arguments['text'], 'Hello');
    expect(title.arguments['key'], 'title');

    // Absolute data binding -> DataReference.
    final ConstructorCall greeting = children[1]! as ConstructorCall;
    final DataReference greetingRef =
        greeting.arguments['text']! as DataReference;
    expect(greetingRef.parts, <Object>['name']);

    // ChildList template -> a children list containing a Loop over the data
    // path, with a relative binding (matching `[ ...for x in xs: W ]`).
    final ConstructorCall list = children[2]! as ConstructorCall;
    final List<Object?> listChildren =
        list.arguments['children']! as List<Object?>;
    final Loop loop = listChildren.single! as Loop;
    expect((loop.input as DataReference).parts, <Object>['items']);
    final ConstructorCall itemTemplate = loop.output as ConstructorCall;
    final LoopReference itemRef =
        itemTemplate.arguments['text']! as LoopReference;
    expect(itemRef.loop, 0);
    expect(itemRef.parts, <Object>['label']);

    // Button: action.event -> onPressed EventHandler; child resolved inline.
    final ConstructorCall button = children[3]! as ConstructorCall;
    expect(button.name, 'Button');
    final EventHandler handler = button.arguments['onPressed']! as EventHandler;
    expect(handler.eventName, 'go');
    expect((button.arguments['child']! as ConstructorCall).arguments['text'],
        'Go');
  });

  test('applies updateDataModel reactively', () {
    final A2uiSurface surface = A2uiSurface()..apply(_createSurface());
    expect(surface.data.subscribe(<Object>['name'], (_) {}), 'Ada');

    surface.apply(<String, Object?>{
      'updateDataModel': <String, Object?>{'path': '/name', 'value': 'Grace'},
    });
    expect(surface.data.subscribe(<Object>['name'], (_) {}), 'Grace');
  });
}
