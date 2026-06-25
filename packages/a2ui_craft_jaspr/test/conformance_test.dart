// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:jaspr/jaspr.dart' show Component, Key, ValueKey;
import 'package:jaspr_test/jaspr_test.dart';

/// Jaspr implementation of the shared [CraftTester], wrapping a
/// [ComponentTester] and a Jaspr [Runtime]. Produces HTML DOM rather than
/// widgets, but answers the same behavioral probes.
class _JasprCraftTester implements CraftTester {
  _JasprCraftTester(this._tester);

  final ComponentTester _tester;

  final Runtime _runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..update(a2uiDemoCatalogName, parseLibraryFile(a2uiDemoCatalogSource));

  @override
  Future<void> mountLibrary(
    RemoteWidgetLibrary main, {
    DynamicContent? data,
    CraftEventHandler? onEvent,
  }) async {
    _runtime.update(const LibraryName(<String>['main']), main);

    _tester.pumpComponent(
      RemoteComponent(
        runtime: _runtime,
        component: const FullyQualifiedWidgetName(
          LibraryName(<String>['main']),
          'root',
        ),
        data: data ?? DynamicContent(),
        onEvent: onEvent,
      ),
    );
    await _tester.pump();
  }

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
    _tester.pumpComponent(component as Component);
    await _tester.pump();
  }

  @override
  Future<void> pump() => _tester.pump();

  @override
  int textCount(String text) => find.text(text).evaluate().length;

  @override
  Future<void> activate(String key) {
    final Key k = ValueKey<String>(key);
    return _tester.click(find.byKey(k));
  }
}

class _JasprConformanceDriver implements CraftConformanceDriver {
  @override
  void defineTest(
    String description,
    Future<void> Function(CraftTester tester) body,
  ) {
    testComponents(
      description,
      (ComponentTester tester) => body(_JasprCraftTester(tester)),
    );
  }
}

void main() {
  runCoreComponentConformance(_JasprConformanceDriver());
  runA2uiConformance(_JasprConformanceDriver());
}
