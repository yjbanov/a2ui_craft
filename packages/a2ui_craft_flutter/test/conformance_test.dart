// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter implementation of the shared [CraftTester], wrapping a [WidgetTester]
/// and a Flutter [Runtime]. Renders under a bare [Directionality] (no Material
/// chrome) so probes see only the template's own widgets.
class _FlutterCraftTester implements CraftTester {
  _FlutterCraftTester(this._tester);

  final WidgetTester _tester;

  final Runtime _runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(a2uiDemoCatalogName, parseLibraryFile(a2uiDemoCatalogSource));

  @override
  Future<void> mountLibrary(
    RemoteWidgetLibrary main, {
    DynamicContent? data,
    DynamicContent? theme,
    CraftEventHandler? onEvent,
  }) async {
    _runtime.update(const LibraryName(<String>['main']), main);

    await _tester.pumpWidget(
      _host(
        RemoteWidget(
          runtime: _runtime,
          widget: const FullyQualifiedWidgetName(
            LibraryName(<String>['main']),
            'root',
          ),
          data: data ?? DynamicContent(),
          theme: theme,
          onEvent: onEvent,
        ),
      ),
    );
  }

  /// Hosts [child] under just enough Material chrome (Directionality, Theme,
  /// MediaQuery, Overlay, a Material surface) for inputs like `TextField` to
  /// render; the behavioral probes still see only the template's own content.
  Widget _host(Widget child) =>
      MaterialApp(home: Scaffold(body: Center(child: child)));

  @override
  Object buildAdapter(SurfaceModel<ComponentApi> surface, String id) {
    return A2uiToRfwAdapter(
      id: id,
      surface: surface,
      runtime: _runtime,
      scope: a2uiDemoCatalogName,
    );
  }

  @override
  Future<void> mountComponent(Object component) async {
    await _tester.pumpWidget(_host(component as Widget));
  }

  @override
  Future<void> pump() => _tester.pump();

  @override
  int textCount(String text) => find.text(text).evaluate().length;

  @override
  Future<void> activate(String key) async {
    await _tester.tap(find.byKey(ValueKey<String>(key)));
    await _tester.pump();
  }

  @override
  Future<void> toggleCheckbox() async {
    await _tester.tap(find.byType(Checkbox));
    await _tester.pump();
  }
}

class _FlutterConformanceDriver implements CraftConformanceDriver {
  @override
  void defineTest(
    String description,
    Future<void> Function(CraftTester tester) body,
  ) {
    testWidgets(
      description,
      (WidgetTester tester) => body(_FlutterCraftTester(tester)),
    );
  }
}

void main() {
  runCoreComponentConformance(_FlutterConformanceDriver());
  runA2uiConformance(_FlutterConformanceDriver());
}
