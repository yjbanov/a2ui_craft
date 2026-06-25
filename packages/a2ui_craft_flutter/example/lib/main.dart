// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show parseLibraryFile;
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';

import 'samples.dart';

void main() {
  runApp(const App());
}

/// End-to-end A2UI demo gallery: an agent would stream the A2UI messages in
/// `samples.dart`; `a2ui_core` ingests them and resolves bindings/actions, and
/// A2UI Craft renders the resolved components with the Flutter adapter.
class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Runtime _runtime = Runtime();
  late MessageProcessor<ComponentApi> _processor;
  late SurfaceModel<ComponentApi> _surface;

  String _currentSample = sampleNames.first;
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _runtime
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(catalogName, parseLibraryFile(catalogSource));

    _loadSample(_currentSample);
  }

  void _loadSample(String sample) {
    _count = 0;
    _processor = MessageProcessor<ComponentApi>(catalogs: [demoCatalog()]);
    _processor.processMessages(messagesForSample(sample));
    _surface = _processor.groupModel.getSurface(surfaceId)!;
    _surface.onAction.addListener(_onAction);
  }

  void _onAction(A2uiClientAction action) {
    if (action.name == 'greet') {
      _processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: surfaceId,
          path: '/greeting',
          value: 'Hello from an A2UI event!',
        ),
      ]);
    } else if (action.name == 'increment') {
      _count++;
      _processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: surfaceId,
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
              selectedIndex: sampleNames.indexOf(_currentSample),
              onDestinationSelected: (int index) {
                setState(() {
                  _currentSample = sampleNames[index];
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
                NavigationRailDestination(
                  icon: Icon(Icons.person),
                  label: Text('Profile Card'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.image),
                  label: Text('Image Gallery'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: A2uiToRfwAdapter(
                    id: 'root',
                    surface: _surface,
                    runtime: _runtime,
                    scope: catalogName,
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
