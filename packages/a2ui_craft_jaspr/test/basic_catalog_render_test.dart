// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Renders **real A2UI gallery examples** (vendored verbatim from the spec)
/// through `a2ui_core` + the bridge's Basic Catalog onto the core primitives —
/// no hand-authored template. The Flutter adapter renders the same examples; the
/// two together prove the surfaces render identically toward "render the A2UI
/// gallery via Craft."
void main() {
  /// Ingests [example] and mounts its `root` adapter.
  Future<void> pumpExample(
      ComponentTester tester, GalleryExample example) async {
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents());
    final MessageProcessor<ComponentApi> processor =
        MessageProcessor<ComponentApi>(catalogs: <Catalog<ComponentApi>>[
      a2uiBasicCatalog(),
    ]);
    processor.processMessages(example.messages);
    final SurfaceModel<ComponentApi> surface =
        processor.groupModel.getSurface(example.surfaceId)!;

    tester.pumpComponent(
      A2uiToRfwAdapter(
        id: 'root',
        surface: surface,
        runtime: runtime,
        scope: basicCatalogScope,
        mapComponent: a2uiBasicCatalogCall,
      ),
    );
    await tester.pump();
  }

  testComponents('renders the real "Row Layout" example via the Basic Catalog',
      (ComponentTester tester) async {
    await pumpExample(tester, rowLayoutExample);
    expect(find.text('Left Content'), findsOneComponent);
    expect(find.text('Right Content'), findsOneComponent);
  });

  testComponents('binds nested data paths in the real "Sports Player" example',
      (ComponentTester tester) async {
    await pumpExample(tester, sportsPlayerExample);
    expect(find.text('Marcus Johnson'), findsOneComponent); // /playerName
    expect(find.text('#23'), findsOneComponent); // /number
    expect(find.text('LA Lakers'), findsOneComponent); // /team
    expect(find.text('28.4'), findsOneComponent); // /stat1/value (nested)
    expect(find.text('PPG'), findsOneComponent); // /stat1/label
    expect(find.text('APG'), findsOneComponent); // /stat3/label
  });

  testComponents(
      'resolves a formatString call in the real "Formatted Text" example',
      (ComponentTester tester) async {
    await pumpExample(tester, formattedTextExample);
    expect(find.text('Formatted output:'), findsOneComponent);
    // `formatString` interpolates "You typed: ${/inputValue}"; with no data set,
    // the binding resolves to empty — proving the call executed and interpolated.
    expect(find.text('You typed: '), findsOneComponent);
  });
}
