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
/// the resolved components with the Flutter adapter.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Runtime _runtime = Runtime();
  late MessageProcessor<ComponentApi> _processor;
  late SurfaceModel<ComponentApi> _surface;

  String _currentSample = 'Greeting';
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _runtime
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(_catalogName, parseLibraryFile(_catalogSource));

    _loadSample('Greeting');
  }

  void _loadSample(String sampleName) {
    _processor = MessageProcessor<ComponentApi>(catalogs: [_catalog()]);
    if (sampleName == 'Greeting') {
      _processor.processMessages(_greetingMessages());
    } else if (sampleName == 'Counter') {
      _count = 0;
      _processor.processMessages(_counterMessages());
    }
    _surface = _processor.groupModel.getSurface('demo')!;
    _surface.onAction.addListener(_onAction);
  }

  void _onAction(A2uiClientAction action) {
    if (action.name == 'greet') {
      _processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: 'demo',
          path: '/greeting',
          value: 'Hello from an A2UI event!',
        ),
      ]);
    } else if (action.name == 'increment') {
      _count++;
      _processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: 'demo',
          path: '/count',
          value: _count.toString(),
        ),
      ]);
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _currentSample == 'Greeting' ? 0 : 1,
              onDestinationSelected: (int index) {
                setState(() {
                  _currentSample = index == 0 ? 'Greeting' : 'Counter';
                  _loadSample(_currentSample);
                });
              },
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.message),
                  label: Text('Greeting'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.add),
                  label: Text('Counter'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Center(
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
          ],
        ),
      ),
    );
  }
}

List<A2uiMessage> _greetingMessages() => <A2uiMessage>[
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

List<A2uiMessage> _counterMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 'demo', catalogId: _catalogId),
      UpdateDataModelMessage(
        surfaceId: 'demo',
        path: '/',
        value: <String, Object?>{'count': '0'},
      ),
      UpdateComponentsMessage(
        surfaceId: 'demo',
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
