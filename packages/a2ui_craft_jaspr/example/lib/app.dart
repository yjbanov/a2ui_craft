// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show parseLibraryFile;
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'samples.dart';

/// End-to-end A2UI demo gallery: an agent would stream the A2UI messages in
/// `samples.dart`; `a2ui_core` ingests them and resolves bindings/actions, and
/// A2UI Craft renders the resolved components with the Jaspr adapter.
class App extends StatefulComponent {
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
  Component build(BuildContext context) {
    return div(
      styles: Styles(
        display: Display.flex,
        flexDirection: FlexDirection.row,
        height: Unit.vh(100),
      ),
      [
        div(
          styles: Styles(
            display: Display.flex,
            flexDirection: FlexDirection.column,
            width: Unit.pixels(200),
            padding: Padding.all(Unit.pixels(20)),
            border: Border.all(color: Colors.blue, width: Unit.pixels(1)),
          ),
          [
            for (final String sample in sampleNames) ...[
              button(
                onClick: () {
                  setState(() {
                    _currentSample = sample;
                    _loadSample(_currentSample);
                  });
                },
                [Component.text(sample)],
              ),
              div(styles: Styles(height: Unit.pixels(10)), []),
            ],
          ],
        ),
        div(
          styles: Styles(
            flex: Flex(grow: 1),
            display: Display.flex,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
          ),
          [
            div(
              styles: Styles(
                padding: Padding.all(Unit.pixels(20)),
                border: Border.all(color: Colors.blue, width: Unit.pixels(2)),
                radius: BorderRadius.circular(Unit.pixels(8)),
              ),
              [
                A2uiToRfwAdapter(
                  id: 'root',
                  surface: _surface,
                  runtime: _runtime,
                  scope: catalogName,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
