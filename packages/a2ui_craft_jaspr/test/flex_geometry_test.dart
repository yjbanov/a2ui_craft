// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

/// Jaspr implementation of the geometric [CraftGeometryTester]: it mounts the
/// surface into a **real headless browser** and reads actual layout via
/// `getBoundingClientRect`. It runs the *same* `runFlexGeometryConformance`
/// suite the Flutter adapter does, so "lays out identically" is proven against
/// genuine DOM layout — not a CSS-structure proxy.
///
/// Runs under `dart test -p chrome` (see `tool/check.sh`).
class _JasprGeometryTester implements CraftGeometryTester {
  _JasprGeometryTester(this._tester);

  final ClientTester _tester;

  final Runtime _runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents());

  @override
  Future<void> mountTemplate(String template, {DynamicContent? data}) async {
    _runtime.update(
        const LibraryName(<String>['main']), parseLibraryFile(template));
    _tester.pumpComponent(
      RemoteWidget(
        runtime: _runtime,
        widget: const FullyQualifiedWidgetName(
          LibraryName(<String>['main']),
          'root',
        ),
        data: data ?? DynamicContent(),
      ),
    );
    await pumpEventQueue();
  }

  @override
  Future<CraftRect> rectOf(String key) async {
    final web.Element el =
        _tester.findNode<web.Element>(find.byKey(ValueKey<String>(key)))!;
    final web.DOMRect r = el.getBoundingClientRect();
    return CraftRect(
      left: r.left,
      top: r.top,
      width: r.width,
      height: r.height,
    );
  }
}

class _JasprGeometryDriver implements CraftGeometryDriver {
  @override
  void defineTest(
    String description,
    Future<void> Function(CraftGeometryTester tester) body,
  ) {
    testClient(
      description,
      (ClientTester tester) => body(_JasprGeometryTester(tester)),
    );
  }
}

void main() {
  runFlexGeometryConformance(_JasprGeometryDriver());
}
