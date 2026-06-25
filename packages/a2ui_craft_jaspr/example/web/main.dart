// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart' show parseLibraryFile;
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/browser.dart';

void main() {
  runApp(App());
}

/// This app's **high-level catalog**: small, vetted widgets the agent composes,
/// authored as RFW templates over the low-level `core` library. A2UI components
/// reference these names; the bridge passes their props through as `args`.
const String _catalogSource = '''
import core;

widget Label = Text(text: args.text);

widget Stack = Column(children: args.children);

widget Tappable = Button(onPressed: args.action, child: Text(text: args.label));
''';

const LibraryName _catalog = LibraryName(<String>['catalog']);

/// End-to-end A2UI demo: an agent would stream the A2UI Transport messages
/// below; the client renders them with A2UI Craft templates as the catalog (here
/// the Jaspr adapter). The agent never knows templates are involved.
class App extends StatefulComponent {
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Runtime _runtime = Runtime();
  late final A2uiSurface _surface;

  @override
  void initState() {
    super.initState();
    _runtime
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(_catalog, parseLibraryFile(_catalogSource));

    _surface = A2uiSurface(
      adapterBuilder: (String id) => A2uiToRfwAdapter(
        id: id,
        surface: _surface,
        runtime: _runtime,
        scope: _catalog,
        onEvent: _onEvent,
      ),
    );
    _surface.apply(_createSurfaceMessage());
  }

  void _onEvent(String name, DynamicMap arguments) {
    if (name == 'greet') {
      // Simulate the agent replying with an updateDataModel message. The bound
      // Text re-renders reactively — no component message needed.
      _surface.apply(<String, Object?>{
        'updateDataModel': <String, Object?>{
          'path': '/greeting',
          'value': 'Hello from an A2UI event!',
        },
      });
    }
  }

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(
      styles: Styles.box(
        padding: EdgeInsets.all(Unit.pixels(20)),
        border: Border.all(
          BorderSide.solid(color: Colors.blue, width: Unit.pixels(2)),
        ),
        radius: BorderRadius.circular(Unit.pixels(8)),
      ),
      [
        A2uiToRfwAdapter(
          id: 'root',
          surface: _surface,
          runtime: _runtime,
          scope: _catalog,
          onEvent: _onEvent,
        ),
      ],
    );
  }
}

/// A sample A2UI `createSurface` envelope (as decoded JSON).
Map<String, Object?> _createSurfaceMessage() => <String, Object?>{
      'createSurface': <String, Object?>{
        'surfaceId': 'demo',
        'components': <Object?>[
          <String, Object?>{
            'id': 'root',
            'component': 'Stack',
            'children': <Object?>['title', 'greeting', 'btn'],
          },
          <String, Object?>{
            'id': 'title',
            'component': 'Label',
            'text': 'A2UI Craft × Jaspr',
          },
          <String, Object?>{
            'id': 'greeting',
            'component': 'Label',
            'text': <String, Object?>{'path': '/greeting'},
          },
          <String, Object?>{
            'id': 'btn',
            'component': 'Tappable',
            'label': 'Say hi',
            'action': <String, Object?>{
              'event': <String, Object?>{
                'name': 'greet',
                'context': <String, Object?>{}
              },
            },
          },
        ],
        'dataModel': <String, Object?>{'greeting': 'Press the button.'},
      },
    };
