// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName, parseLibraryFile;
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:example/main.dart';
import 'package:example/samples.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Builds the runtime + surface for [sample] and mounts its root adapter, so
/// each gallery sample is rendered exactly as the app renders it.
Future<void> _pumpSample(WidgetTester tester, String sample) async {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..update(catalogName, parseLibraryFile(catalogSource));
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(catalogs: [demoCatalog()]);
  processor.processMessages(messagesForSample(sample));
  final SurfaceModel<ComponentApi> surface =
      processor.groupModel.getSurface(surfaceId)!;

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: A2uiToRfwAdapter(
          id: 'root',
          surface: surface,
          runtime: runtime,
          scope: catalogName,
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('Greeting sample renders its title, bound greeting, and button',
      (WidgetTester tester) async {
    await _pumpSample(tester, 'Greeting');
    expect(find.text('A2UI Craft × Flutter'), findsOneWidget);
    expect(find.text('Press the button.'), findsOneWidget);
    expect(find.text('Say hi'), findsOneWidget);
  });

  testWidgets('Counter sample renders its label, count, and button',
      (WidgetTester tester) async {
    await _pumpSample(tester, 'Counter');
    expect(find.text('You have pushed the button this many times:'),
        findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Increment'), findsOneWidget);
  });

  testWidgets('Profile Card sample renders its card contents',
      (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await _pumpSample(tester, 'Profile Card');
      expect(find.text('Flutter Framework'), findsOneWidget);
      expect(find.text('Build apps for any screen.'), findsOneWidget);
    });
  });

  testWidgets('Image Gallery sample renders three images',
      (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await _pumpSample(tester, 'Image Gallery');
      expect(find.byType(Image), findsNWidgets(3));
    });
  });

  testWidgets('tapping the greeting button updates the bound text',
      (WidgetTester tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Press the button.'), findsOneWidget);

    await tester.tap(find.text('Say hi'));
    await tester.pump();

    expect(find.text('Press the button.'), findsNothing);
    expect(find.text('Hello from an A2UI event!'), findsOneWidget);
  });
}
