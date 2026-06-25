// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName;
import 'package:json_schema_builder/json_schema_builder.dart';

/// The catalog and per-sample A2UI message scripts that drive the example
/// gallery. This is UI-framework-free so both the app and its tests can import
/// it (the tests mount each sample's root and assert it renders).

/// The app's **high-level catalog**: small, vetted widgets the agent composes.
/// `Label`/`Stack`/`Tappable`/`List` are RFW templates over the low-level `core`
/// library; the agent also references a few `core` primitives (`Card`, `Image`,
/// `Icon`, `Divider`) directly, since for those a 1:1 wrapper would add nothing.
const String catalogSource = '''
import core;

widget Label = Text(text: args.text);
widget Stack = Column(children: args.children);
widget Tappable = Button(onPressed: args.action, child: Text(text: args.label));
widget List = ScrollView(child: Column(children: args.children));
''';

/// The library name under which [catalogSource] is registered.
const LibraryName catalogName = LibraryName(<String>['catalog']);

/// The `a2ui_core` catalog id the sample `createSurface` messages reference.
const String catalogId = 'demo';

/// The id of the surface the samples build.
const String surfaceId = 'demo';

/// The sample names, in the order the gallery presents them.
const List<String> sampleNames = <String>[
  'Greeting',
  'Counter',
  'Profile Card',
  'Image Gallery',
];

/// The matching `a2ui_core` component schemas (these drive `GenericBinder`'s
/// resolution of bindings, actions, and structural child lists).
class _LabelApi extends ComponentApi {
  @override
  String get name => 'Label';
  @override
  Schema get schema => Schema.object(
        properties: {'text': CommonSchemas.dynamicString},
        required: ['text'],
      );
}

class _StackApi extends ComponentApi {
  @override
  String get name => 'Stack';
  @override
  Schema get schema => Schema.object(
        properties: {'children': CommonSchemas.childList},
        required: ['children'],
      );
}

class _TappableApi extends ComponentApi {
  @override
  String get name => 'Tappable';
  @override
  Schema get schema => Schema.object(
        properties: {
          'label': CommonSchemas.dynamicString,
          'action': CommonSchemas.action,
        },
        required: ['label', 'action'],
      );
}

class _CardApi extends ComponentApi {
  @override
  String get name => 'Card';
  @override
  Schema get schema => Schema.object(
        properties: {'child': CommonSchemas.componentId},
        required: ['child'],
      );
}

class _DividerApi extends ComponentApi {
  @override
  String get name => 'Divider';
  @override
  Schema get schema => Schema.object();
}

class _ImageApi extends ComponentApi {
  @override
  String get name => 'Image';
  @override
  Schema get schema => Schema.object(
        properties: {
          'url': CommonSchemas.dynamicString,
          'fit': CommonSchemas.dynamicString,
        },
      );
}

class _IconApi extends ComponentApi {
  @override
  String get name => 'Icon';
  @override
  Schema get schema => Schema.object(
        properties: {'icon': CommonSchemas.dynamicString},
      );
}

class _ListApi extends ComponentApi {
  @override
  String get name => 'List';
  @override
  Schema get schema => Schema.object(
        properties: {'children': CommonSchemas.childList},
        required: ['children'],
      );
}

/// Builds the `a2ui_core` demo catalog (matching [catalogSource]).
Catalog<ComponentApi> demoCatalog() => Catalog<ComponentApi>(
      id: catalogId,
      components: [
        _StackApi(),
        _LabelApi(),
        _TappableApi(),
        _CardApi(),
        _DividerApi(),
        _ImageApi(),
        _IconApi(),
        _ListApi(),
      ],
    );

/// The initial A2UI messages for [sample], one of [sampleNames].
List<A2uiMessage> messagesForSample(String sample) {
  switch (sample) {
    case 'Counter':
      return _counterMessages();
    case 'Profile Card':
      return _profileCardMessages();
    case 'Image Gallery':
      return _imageGalleryMessages();
    case 'Greeting':
    default:
      return _greetingMessages();
  }
}

List<A2uiMessage> _greetingMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
      UpdateDataModelMessage(
        surfaceId: surfaceId,
        path: '/',
        value: <String, Object?>{'greeting': 'Press the button.'},
      ),
      UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Stack',
            'children': <Object?>['title', 'greeting', 'btn'],
          },
          <String, dynamic>{
            'id': 'title',
            'component': 'Label',
            'text': 'A2UI Craft × Flutter',
          },
          <String, dynamic>{
            'id': 'greeting',
            'component': 'Label',
            'text': <String, dynamic>{'path': '/greeting'},
          },
          <String, dynamic>{
            'id': 'btn',
            'component': 'Tappable',
            'label': 'Say hi',
            'action': <String, dynamic>{
              'event': <String, dynamic>{
                'name': 'greet',
                'context': <String, dynamic>{},
              },
            },
          },
        ],
      ),
    ];

List<A2uiMessage> _counterMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
      UpdateDataModelMessage(
        surfaceId: surfaceId,
        path: '/',
        value: <String, Object?>{'count': '0'},
      ),
      UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Stack',
            'children': <Object?>['title', 'count', 'btn'],
          },
          <String, dynamic>{
            'id': 'title',
            'component': 'Label',
            'text': 'You have pushed the button this many times:',
          },
          <String, dynamic>{
            'id': 'count',
            'component': 'Label',
            'text': <String, dynamic>{'path': '/count'},
          },
          <String, dynamic>{
            'id': 'btn',
            'component': 'Tappable',
            'label': 'Increment',
            'action': <String, dynamic>{
              'event': <String, dynamic>{
                'name': 'increment',
                'context': <String, dynamic>{},
              },
            },
          },
        ],
      ),
    ];

List<A2uiMessage> _profileCardMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
      UpdateDataModelMessage(
        surfaceId: surfaceId,
        path: '/',
        value: <String, Object?>{},
      ),
      UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Card',
            'child': 'list',
          },
          <String, dynamic>{
            'id': 'list',
            'component': 'List',
            'children': <Object?>['avatar', 'name_row', 'div', 'bio'],
          },
          <String, dynamic>{
            'id': 'avatar',
            'component': 'Image',
            'url':
                'https://storage.googleapis.com/cms-storage-bucket/lockup_flutter_horizontal.c823e53b3a1a7b0d36a9.png',
            'fit': 'contain',
          },
          <String, dynamic>{
            'id': 'name_row',
            'component': 'Stack',
            'children': <Object?>['name', 'verified'],
          },
          <String, dynamic>{
            'id': 'name',
            'component': 'Label',
            'text': 'Flutter Framework',
          },
          <String, dynamic>{
            'id': 'verified',
            'component': 'Icon',
            'icon': 'check',
          },
          <String, dynamic>{
            'id': 'div',
            'component': 'Divider',
          },
          <String, dynamic>{
            'id': 'bio',
            'component': 'Label',
            'text': 'Build apps for any screen.',
          },
        ],
      ),
    ];

List<A2uiMessage> _imageGalleryMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
      UpdateDataModelMessage(
        surfaceId: surfaceId,
        path: '/',
        value: <String, Object?>{},
      ),
      UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'List',
            'children': <Object?>['img1', 'img2', 'img3'],
          },
          <String, dynamic>{
            'id': 'img1',
            'component': 'Image',
            'url': 'https://flutter.dev/images/flutter-logo-sharing.png',
          },
          <String, dynamic>{
            'id': 'img2',
            'component': 'Image',
            'url':
                'https://dart.dev/assets/shared/dart/logo+text/horizontal/white.png',
          },
          <String, dynamic>{
            'id': 'img3',
            'component': 'Image',
            'url':
                'https://storage.googleapis.com/cms-storage-bucket/lockup_flutter_horizontal.c823e53b3a1a7b0d36a9.png',
          },
        ],
      ),
    ];
