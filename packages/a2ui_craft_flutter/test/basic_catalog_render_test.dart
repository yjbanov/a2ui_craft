// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders a **real A2UI gallery example** (vendored verbatim from the spec)
/// through `a2ui_core` + the bridge's Basic Catalog onto the core primitives —
/// no hand-authored template. This proves the path toward "render the A2UI
/// gallery via Craft."
void main() {
  testWidgets('renders the real "Row Layout" example via the Basic Catalog',
      (WidgetTester tester) async {
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents());
    final MessageProcessor<ComponentApi> processor =
        MessageProcessor<ComponentApi>(catalogs: <Catalog<ComponentApi>>[
      a2uiBasicCatalog(),
    ]);
    processor.processMessages(rowLayoutExample.messages);
    final SurfaceModel<ComponentApi> surface =
        processor.groupModel.getSurface(rowLayoutExample.surfaceId)!;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: A2uiToRfwAdapter(
              id: 'root',
              surface: surface,
              runtime: runtime,
              scope: basicCatalogScope,
              mapComponent: a2uiBasicCatalogCall,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Left Content'), findsOneWidget);
    expect(find.text('Right Content'), findsOneWidget);
  });
}
