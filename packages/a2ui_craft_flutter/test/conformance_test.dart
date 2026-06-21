// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Flutter implementation of the shared [CraftTester], wrapping a [WidgetTester]
/// and a Flutter [Runtime]. Renders under a bare [Directionality] (no Material
/// chrome) so probes see only the template's own widgets.
class _FlutterCraftTester implements CraftTester {
  _FlutterCraftTester(this._tester);

  final WidgetTester _tester;

  @override
  Future<void> mount(
    String template, {
    DynamicContent? data,
    CraftEventHandler? onEvent,
  }) async {
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(const LibraryName(<String>['main']), parseLibraryFile(template));

    await _tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RemoteComponent(
          runtime: runtime,
          component: const FullyQualifiedWidgetName(
            LibraryName(<String>['main']),
            'root',
          ),
          data: data ?? DynamicContent(),
          onEvent: onEvent,
        ),
      ),
    );
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
}
