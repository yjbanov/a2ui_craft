// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName;
import 'package:json_schema_builder/json_schema_builder.dart';

/// The catalog and per-sample A2UI message scripts that drive the example
/// gallery. This is UI-framework-free so both the app and its tests can import
/// it (the tests mount each sample's root and assert it renders).

/// The app's **high-level catalog**: each agent-facing widget is a vetted RFW
/// template that composes the low-level `core` primitives. `Greeting`, `Counter`,
/// `ProfileCard`, and `Gallery` are real domain widgets — the agent supplies a
/// few props and the template builds the whole subtree — so the A2UI payloads
/// below stay short and never spell out primitive trees. `Column` is the one
/// layout widget the agent arranges them with (it resolves to `core`'s `Column`).
const String catalogSource = '''
import core;

widget Greeting = Column(children: [
  Text(text: args.title),
  Text(text: args.message),
  Button(onPressed: args.action, child: Text(text: args.buttonLabel)),
]);

widget Counter = Column(children: [
  Text(text: args.label),
  Text(text: args.count),
  Button(onPressed: args.action, child: Text(text: args.buttonLabel)),
]);

widget ProfileCard = Card(child: Column(children: [
  Image(url: args.avatarUrl),
  Row(children: [
    Text(text: args.name),
    Icon(icon: "check"),
  ]),
  Divider(),
  Text(text: args.bio),
]));

widget Gallery = ScrollView(child: Column(children: [
  ...for url in args.images: Image(url: url),
]));
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

/// The matching `a2ui_core` component schemas — one per **agent-facing** widget
/// (the primitives the templates use internally are resolved by RFW, not
/// a2ui_core, so they need no schema here). These drive `GenericBinder`'s
/// resolution of bindings, actions, and structural child lists.
class _ColumnApi extends ComponentApi {
  @override
  String get name => 'Column';
  @override
  Schema get schema => Schema.object(
        properties: {'children': CommonSchemas.childList},
        required: ['children'],
      );
}

class _GreetingApi extends ComponentApi {
  @override
  String get name => 'Greeting';
  @override
  Schema get schema => Schema.object(
        properties: {
          'title': CommonSchemas.dynamicString,
          'message': CommonSchemas.dynamicString,
          'buttonLabel': CommonSchemas.dynamicString,
          'action': CommonSchemas.action,
        },
      );
}

class _CounterApi extends ComponentApi {
  @override
  String get name => 'Counter';
  @override
  Schema get schema => Schema.object(
        properties: {
          'label': CommonSchemas.dynamicString,
          'count': CommonSchemas.dynamicString,
          'buttonLabel': CommonSchemas.dynamicString,
          'action': CommonSchemas.action,
        },
      );
}

class _ProfileCardApi extends ComponentApi {
  @override
  String get name => 'ProfileCard';
  @override
  Schema get schema => Schema.object(
        properties: {
          'name': CommonSchemas.dynamicString,
          'avatarUrl': CommonSchemas.dynamicString,
          'bio': CommonSchemas.dynamicString,
        },
      );
}

class _GalleryApi extends ComponentApi {
  @override
  String get name => 'Gallery';
  @override
  Schema get schema => Schema.object(
        properties: {'images': Schema.list(items: Schema.string())},
      );
}

/// Builds the `a2ui_core` demo catalog (matching [catalogSource]).
Catalog<ComponentApi> demoCatalog() => Catalog<ComponentApi>(
      id: catalogId,
      components: [
        _ColumnApi(),
        _GreetingApi(),
        _CounterApi(),
        _ProfileCardApi(),
        _GalleryApi(),
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

// A few image URLs reused across the samples.
const String _flutterLogo =
    'https://storage.googleapis.com/cms-storage-bucket/lockup_flutter_horizontal.c823e53b3a1a7b0d36a9.png';
const String _dartLogo =
    'https://dart.dev/assets/shared/dart/logo+text/horizontal/white.png';
const String _flutterShare =
    'https://flutter.dev/images/flutter-logo-sharing.png';

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
            'component': 'Greeting',
            'title': 'A2UI Craft × Jaspr',
            'message': <String, dynamic>{'path': '/greeting'},
            'buttonLabel': 'Say hi',
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
            'component': 'Counter',
            'label': 'You have pushed the button this many times:',
            'count': <String, dynamic>{'path': '/count'},
            'buttonLabel': 'Increment',
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
      UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Column',
            'children': <Object?>['p1', 'p2'],
          },
          <String, dynamic>{
            'id': 'p1',
            'component': 'ProfileCard',
            'name': 'Jaspr Framework',
            'avatarUrl': _flutterLogo,
            'bio': 'Build apps for any screen.',
          },
          <String, dynamic>{
            'id': 'p2',
            'component': 'ProfileCard',
            'name': 'Dart',
            'avatarUrl': _dartLogo,
            'bio': 'A client-optimized language for fast apps on any platform.',
          },
        ],
      ),
    ];

List<A2uiMessage> _imageGalleryMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
      UpdateComponentsMessage(
        surfaceId: surfaceId,
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Gallery',
            'images': <Object?>[_flutterShare, _dartLogo, _flutterLogo],
          },
        ],
      ),
    ];
