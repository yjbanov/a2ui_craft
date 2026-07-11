// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
// The model's `Switch` (the RFW switch expression) would shadow Material's.
import 'package:a2ui_craft/a2ui_craft.dart' hide Switch;
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

  DynamicContent? _mountedData;
  CraftEventHandler? _mountedOnEvent;

  @override
  Future<void> mountLibrary(
    RemoteWidgetLibrary main, {
    DynamicContent? data,
    CraftTheme? theme,
    CraftEventHandler? onEvent,
  }) async {
    _runtime.update(const LibraryName(<String>['main']), main);
    _mountedData = data ?? DynamicContent();
    _mountedOnEvent = onEvent;
    await _pumpMounted(theme);
  }

  @override
  Future<void> retheme(CraftTheme? theme) => _pumpMounted(theme);

  /// Pumps the mounted surface with [theme]. The runtime, library, and data
  /// are unchanged, so a re-pump updates the same element tree in place — a
  /// theme swap must not remount (state survives), which the conformance
  /// suite asserts.
  Future<void> _pumpMounted(CraftTheme? theme) {
    return _tester.pumpWidget(
      _host(
        RemoteWidget(
          runtime: _runtime,
          widget: const FullyQualifiedWidgetName(
            LibraryName(<String>['main']),
            'root',
          ),
          data: _mountedData!,
          theme: theme,
          onEvent: _mountedOnEvent,
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
  int buttonCount(String label) => find.semantics
      .byPredicate(
          (node) => node.flagsCollection.isButton && node.label == label)
      .evaluate()
      .length;

  @override
  String? textColorOf(String text) {
    final Color? color = _tester.widget<Text>(find.text(text)).style?.color;
    return color == null
        ? null
        : '#${color.toARGB32().toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

  @override
  double? textFontSizeOf(String text) =>
      _tester.widget<Text>(find.text(text)).style?.fontSize;

  @override
  String? buttonSurfaceColorOf(String label) {
    // The nearest Material ancestor of the label is the Button's surface
    // (layer 1 of the paint model); the ancestor finder yields nearest-first.
    final Iterable<Element> surfaces = find
        .ancestor(of: find.text(label), matching: find.byType(Material))
        .evaluate();
    if (surfaces.isEmpty) return null;
    final Color? color = (surfaces.first.widget as Material).color;
    if (color == null) return null;
    final int argb = color.toARGB32();
    if (argb >>> 24 == 0) return null; // Transparent: no painted surface.
    return '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';
  }

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

  @override
  Future<void> toggleSwitch() async {
    await _tester.tap(find.byType(Switch));
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
      (WidgetTester tester) async {
        // Semantics stays on for every case: the suite probes the a11y tree
        // (CraftTester.buttonCount), and the handle must be released before
        // the test ends.
        final semantics = tester.ensureSemantics();
        try {
          await body(_FlutterCraftTester(tester));
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}

void main() {
  runCoreComponentConformance(_FlutterConformanceDriver());
  runA2uiConformance(_FlutterConformanceDriver());
}
