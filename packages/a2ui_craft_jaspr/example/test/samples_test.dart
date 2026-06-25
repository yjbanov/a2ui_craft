// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName, parseLibraryFile;
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_jaspr_example/app.dart';
import 'package:a2ui_craft_jaspr_example/samples.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Builds the runtime + surface for [sample] and mounts its root adapter, so
/// each gallery sample is rendered exactly as the app renders it.
Future<void> _pumpSample(ComponentTester tester, String sample) async {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..update(catalogName, parseLibraryFile(catalogSource));
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(catalogs: [demoCatalog()]);
  processor.processMessages(messagesForSample(sample));
  final SurfaceModel<ComponentApi> surface =
      processor.groupModel.getSurface(surfaceId)!;

  tester.pumpComponent(
    A2uiToRfwAdapter(
      id: 'root',
      surface: surface,
      runtime: runtime,
      scope: catalogName,
    ),
  );
  await tester.pump();
}

void main() {
  testComponents(
      'Greeting sample renders its title, bound greeting, and button',
      (ComponentTester tester) async {
    await _pumpSample(tester, 'Greeting');
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
    expect(find.text('Press the button.'), findsOneComponent);
    expect(find.text('Say hi'), findsOneComponent);
  });

  testComponents('Counter sample renders its label, count, and button',
      (ComponentTester tester) async {
    await _pumpSample(tester, 'Counter');
    expect(find.text('You have pushed the button this many times:'),
        findsOneComponent);
    expect(find.text('0'), findsOneComponent);
    expect(find.text('Increment'), findsOneComponent);
  });

  testComponents(
      'Profile Card sample renders a Column of ProfileCard templates',
      (ComponentTester tester) async {
    await _pumpSample(tester, 'Profile Card');
    // Two ProfileCard templates, each expanding to its own card subtree.
    expect(find.text('Jaspr Framework'), findsOneComponent);
    expect(find.text('Build apps for any screen.'), findsOneComponent);
    expect(find.text('Dart'), findsOneComponent);
  });

  testComponents('Image Gallery sample renders three images',
      (ComponentTester tester) async {
    await _pumpSample(tester, 'Image Gallery');
    expect(find.tag('img'), findsNComponents(3));
  });

  testComponents('the gallery app mounts and loads the default sample',
      (ComponentTester tester) async {
    tester.pumpComponent(App());
    await tester.pump();
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
    expect(find.text('Say hi'), findsOneComponent);
  });
}
