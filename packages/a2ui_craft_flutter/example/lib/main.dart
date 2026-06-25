// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show parseLibraryFile;
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

void main() {
  runApp(const App());
}

/// This app's **high-level catalog**: small, vetted widgets the agent composes,
/// authored as RFW templates over the low-level `core` library. A2UI components
/// reference these names; the bridge passes their resolved props through as
/// `args`.
const String _catalogSource = '''
import core;

widget Label = Text(text: args.text);

widget Stack = Column(children: args.children);

widget Tappable = Button(onPressed: args.action, child: Text(text: args.label));
''';

const LibraryName _catalogName = LibraryName(<String>['catalog']);

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

const String _catalogId = 'demo';

Catalog<ComponentApi> _catalog() => Catalog<ComponentApi>(
      id: _catalogId,
      components: [_StackApi(), _LabelApi(), _TappableApi()],
    );

/// End-to-end A2UI demo: an agent would stream the A2UI messages below;
/// `a2ui_core` ingests them and resolves bindings/actions, and A2UI Craft renders
/// the resolved components with the Flutter adapter. The agent never knows
/// templates are involved.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Runtime _runtime = Runtime();
  late final MessageProcessor<ComponentApi> _processor;
  late final SurfaceModel<ComponentApi> _surface;

  @override
  void initState() {
    super.initState();
    _runtime
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(_catalogName, parseLibraryFile(_catalogSource));

    _processor = MessageProcessor<ComponentApi>(catalogs: [_catalog()]);
    _processor.processMessages(_initialMessages());
    _surface = _processor.groupModel.getSurface('demo')!;
    _surface.onAction.addListener(_onAction);
  }

  void _onAction(A2uiClientAction action) {
    if (action.name == 'greet') {
      // Simulate the agent replying with an updateDataModel message. The bound
      // Label re-renders reactively — no component message needed.
      _processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: 'demo',
          path: '/greeting',
          value: 'Hello from an A2UI event!',
        ),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              border: Border.all(
                color: Colors.blue,
                width: 2,
              ),
              borderRadius: BorderRadius.circular(8),
            ),
            child: A2uiToRfwAdapter(
              id: 'root',
              surface: _surface,
              runtime: _runtime,
              scope: _catalogName,
            ),
          ),
        ),
      ),
    );
  }
}

/// The sample A2UI conversation: create a surface, seed the data model, then a
/// title, a data-bound greeting, and a button.
List<A2uiMessage> _initialMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 'demo', catalogId: _catalogId),
      UpdateDataModelMessage(
        surfaceId: 'demo',
        path: '/',
        value: <String, Object?>{'greeting': 'Press the button.'},
      ),
      UpdateComponentsMessage(
        surfaceId: 'demo',
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
