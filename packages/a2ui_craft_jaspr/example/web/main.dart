// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/browser.dart';

void main() {
  runApp(App());
}

class App extends StatefulComponent {
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  final Runtime _runtime = Runtime();
  final DynamicContent _data = DynamicContent();
  int _count = 0;

  @override
  void initState() {
    super.initState();
    _runtime.update(
      const LibraryName(['core']),
      createCoreComponents(),
    );
    _runtime.update(
      const LibraryName(['main']),
      parseLibraryFile('''
        import core;
        widget root = Column(
          children: [
            Text(text: "Hello, A2UI Craft from Jaspr!"),
            Button(
              onPressed: event "increment" {},
              child: Text(text: ["Clicked ", data.count, " times"])
            )
          ]
        );
      '''),
    );
    _data.update('count', _count);
  }

  void _onEvent(String name, DynamicMap arguments) {
    if (name == 'increment') {
      _count++;
      _data.update('count', _count);
    }
  }

  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield div(
        styles: Styles.box(
          padding: EdgeInsets.all(Unit.pixels(20)),
          border: Border.all(
              BorderSide.solid(color: Colors.blue, width: Unit.pixels(2))),
          radius: BorderRadius.circular(Unit.pixels(8)),
        ),
        [
          RemoteComponent(
            runtime: _runtime,
            component:
                const FullyQualifiedWidgetName(LibraryName(['main']), 'root'),
            data: _data,
            onEvent: _onEvent,
          )
        ]);
  }
}
