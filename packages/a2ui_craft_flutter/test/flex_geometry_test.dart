// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter implementation of the geometric [CraftGeometryTester]: it measures
/// real `RenderBox` geometry via [WidgetTester.getRect], proving the `Flex`
/// slice lays out as the spec requires. The Jaspr adapter runs the *same*
/// `runFlexGeometryConformance` suite against a headless browser.
class _FlutterGeometryTester implements CraftGeometryTester {
  _FlutterGeometryTester(this._tester);

  final WidgetTester _tester;

  final Runtime _runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents());

  @override
  Future<void> mountTemplate(String template, {DynamicContent? data}) async {
    _runtime.update(
        const LibraryName(<String>['main']), parseLibraryFile(template));
    await _tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RemoteWidget(
              runtime: _runtime,
              widget: const FullyQualifiedWidgetName(
                LibraryName(<String>['main']),
                'root',
              ),
              data: data ?? DynamicContent(),
            ),
          ),
        ),
      ),
    );
    await _tester.pumpAndSettle();
  }

  @override
  Future<CraftRect> rectOf(String key) async {
    final Rect r = _tester.getRect(find.byKey(ValueKey<String>(key)));
    return CraftRect(
        left: r.left, top: r.top, width: r.width, height: r.height);
  }
}

class _FlutterGeometryDriver implements CraftGeometryDriver {
  @override
  void defineTest(
    String description,
    Future<void> Function(CraftGeometryTester tester) body,
  ) {
    testWidgets(
      description,
      (WidgetTester tester) => body(_FlutterGeometryTester(tester)),
    );
  }
}

void main() {
  runFlexGeometryConformance(_FlutterGeometryDriver());
  runCrossAxisSizingGeometryConformance(_FlutterGeometryDriver());
  runBoxGeometryConformance(_FlutterGeometryDriver());
  runCardGeometryConformance(_FlutterGeometryDriver());
  runGridGeometryConformance(_FlutterGeometryDriver());
  runAtomGeometryConformance(_FlutterGeometryDriver());
  runLayoutGeometryConformance(_FlutterGeometryDriver());
}
