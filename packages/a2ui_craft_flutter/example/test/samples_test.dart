// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:example/main.dart';
import 'package:example/sample.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Mounts a shared [SampleSpec] exactly as the gallery does.
Future<void> _pump(WidgetTester tester, SampleSpec spec) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: Sample(spec))));
}

void main() {
  testWidgets('Greeting renders its title, bound message, and button',
      (WidgetTester tester) async {
    await _pump(tester, greetingSpec('Flutter'));
    expect(find.text('A2UI Craft × Flutter'), findsOneWidget);
    expect(find.text('Press the button.'), findsOneWidget);
    expect(find.text('Say hi'), findsOneWidget);
  });

  testWidgets('Greeting button dispatches an action that updates bound text',
      (WidgetTester tester) async {
    await _pump(tester, greetingSpec('Flutter'));
    await tester.tap(find.text('Say hi'));
    await tester.pump();
    expect(find.text('Press the button.'), findsNothing);
    expect(find.text('Hello from an A2UI event!'), findsOneWidget);
  });

  testWidgets('Counter renders its label, count, and button',
      (WidgetTester tester) async {
    await _pump(tester, counterSpec('Flutter'));
    expect(find.text('You have pushed the button this many times:'),
        findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Increment'), findsOneWidget);
  });

  testWidgets('Counter increments its bound count on each press',
      (WidgetTester tester) async {
    await _pump(tester, counterSpec('Flutter'));
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Boxes renders the nested-box layout',
      (WidgetTester tester) async {
    await _pump(tester, boxesSpec('Flutter'));
    expect(find.text('Here are some nested boxes with margins and padding:'),
        findsOneWidget);
    expect(find.text('Center'), findsOneWidget);
  });

  testWidgets('Contact Card renders the atoms (name, caption, icon rows)',
      (WidgetTester tester) async {
    await _pump(tester, contactCardSpec('Flutter'));
    expect(find.text('Ada Lovelace'), findsOneWidget);
    expect(find.text('Mathematician'), findsOneWidget);
    expect(find.text('ada@example.com'), findsOneWidget);
    expect(find.text('London, UK'), findsOneWidget);
  });

  testWidgets('Stats Card renders its stats and a slider',
      (WidgetTester tester) async {
    await _pump(tester, statsCardSpec('Flutter'));
    expect(find.text("Today's Activity"), findsOneWidget);
    expect(find.text('8,420'), findsOneWidget);
    expect(find.text('kcal'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('Profile Card renders a Column of ProfileCard templates',
      (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await _pump(tester, profileCardSpec('Flutter'));
      // Two ProfileCard templates, each expanding to its own card subtree.
      expect(find.text('Flutter Framework'), findsOneWidget);
      expect(find.text('Build apps for any screen.'), findsOneWidget);
      expect(find.text('Dart'), findsOneWidget);
      expect(find.byType(Card), findsNWidgets(2));
    });
  });

  testWidgets('Image Gallery renders three images',
      (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await _pump(tester, gallerySpec('Flutter'));
      expect(find.byType(Image), findsNWidgets(3));
    });
  });

  testWidgets('Form: typing two-way-binds the field back to the data model',
      (WidgetTester tester) async {
    await _pump(tester, formSpec('Flutter'));
    // The greeting Label mirrors /name, which starts empty.
    expect(find.text('Ada'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Ada');
    await tester.pump();

    // 'Ada' now shows in two places: the field's own echo *and* the greeting
    // Label bound to /name. The Label only updates if the edit wrote /name back
    // through a2ui_core's setter, so two matches proves two-way binding (a
    // one-way field would leave the Label empty, yielding a single match).
    expect(find.text('Ada'), findsNWidgets(2));
  });

  testWidgets('Form: toggling the checkbox flips its bound value',
      (WidgetTester tester) async {
    await _pump(tester, formSpec('Flutter'));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isFalse);

    await tester.tap(find.byType(Checkbox));
    await tester.pump();

    expect(tester.widget<Checkbox>(find.byType(Checkbox)).value, isTrue);
  });

  testWidgets('the gallery app mounts and shows the first sample',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GalleryApp());
    expect(find.text('A2UI Craft × Flutter'), findsOneWidget);
  });
}
