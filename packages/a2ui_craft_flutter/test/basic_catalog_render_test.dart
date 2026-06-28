// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Renders **real A2UI gallery examples** (vendored verbatim from the spec)
/// through `a2ui_core` + the bridge's Basic Catalog onto the core primitives —
/// no hand-authored template. This proves the path toward "render the A2UI
/// gallery via Craft."
void main() {
  /// Ingests [example] and mounts its `root` adapter, returning the live surface.
  Future<void> pumpExample(WidgetTester tester, GalleryExample example) async {
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents());
    final MessageProcessor<ComponentApi> processor =
        MessageProcessor<ComponentApi>(catalogs: <Catalog<ComponentApi>>[
      a2uiBasicCatalog(),
    ]);
    processor.processMessages(example.messages);
    final SurfaceModel<ComponentApi> surface =
        processor.groupModel.getSurface(example.surfaceId)!;

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
  }

  testWidgets('renders the real "Row Layout" example via the Basic Catalog',
      (WidgetTester tester) async {
    await pumpExample(tester, rowLayoutExample);
    expect(find.text('Left Content'), findsOneWidget);
    expect(find.text('Right Content'), findsOneWidget);
  });

  testWidgets('binds nested data paths in the real "Sports Player" example',
      (WidgetTester tester) async {
    // The card's Image has a real network URL; mock it so the test stays
    // network-free while every Text resolves its `path` binding.
    await mockNetworkImagesFor(() => pumpExample(tester, sportsPlayerExample));

    expect(find.text('Marcus Johnson'), findsOneWidget); // /playerName
    expect(find.text('#23'), findsOneWidget); // /number
    expect(find.text('LA Lakers'), findsOneWidget); // /team
    expect(find.text('28.4'), findsOneWidget); // /stat1/value (nested pointer)
    expect(find.text('PPG'), findsOneWidget); // /stat1/label
    expect(find.text('APG'), findsOneWidget); // /stat3/label
  });

  testWidgets(
      'resolves a formatString call in the real "Formatted Text" example',
      (WidgetTester tester) async {
    await pumpExample(tester, formattedTextExample);

    expect(find.text('Formatted output:'), findsOneWidget);
    // `formatString` interpolates "You typed: ${/inputValue}"; with no data set,
    // the binding resolves to empty — proving the call executed and interpolated.
    expect(find.text('You typed: '), findsOneWidget);
  });
}
