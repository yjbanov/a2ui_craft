// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Renders a **real A2UI gallery example** (vendored verbatim from the spec)
/// through `a2ui_core` + the bridge's Basic Catalog onto the core primitives —
/// no hand-authored template. The Flutter adapter renders the same example; the
/// two together prove the surface renders identically toward "render the A2UI
/// gallery via Craft."
void main() {
  testComponents('renders the real "Row Layout" example via the Basic Catalog',
      (ComponentTester tester) async {
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents());
    final MessageProcessor<ComponentApi> processor =
        MessageProcessor<ComponentApi>(catalogs: <Catalog<ComponentApi>>[
      a2uiBasicCatalog(),
    ]);
    processor.processMessages(rowLayoutExample.messages);
    final SurfaceModel<ComponentApi> surface =
        processor.groupModel.getSurface(rowLayoutExample.surfaceId)!;

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

    expect(find.text('Left Content'), findsOneComponent);
    expect(find.text('Right Content'), findsOneComponent);
  });
}
