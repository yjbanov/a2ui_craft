// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:example/main.dart';
import 'package:example/sample.dart';
import 'package:example/samples/counter.dart';
import 'package:example/samples/gallery.dart';
import 'package:example/samples/greeting.dart';
import 'package:example/samples/profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:network_image_mock/network_image_mock.dart';

/// Mounts a self-contained [Sample] exactly as the gallery does.
Future<void> _pump(WidgetTester tester, Sample sample) {
  return tester.pumpWidget(MaterialApp(home: Scaffold(body: sample)));
}

void main() {
  testWidgets('Greeting renders its title, bound message, and button',
      (WidgetTester tester) async {
    await _pump(tester, const GreetingSample());
    expect(find.text('A2UI Craft × Flutter'), findsOneWidget);
    expect(find.text('Press the button.'), findsOneWidget);
    expect(find.text('Say hi'), findsOneWidget);
  });

  testWidgets('Greeting button dispatches an action that updates bound text',
      (WidgetTester tester) async {
    await _pump(tester, const GreetingSample());
    await tester.tap(find.text('Say hi'));
    await tester.pump();
    expect(find.text('Press the button.'), findsNothing);
    expect(find.text('Hello from an A2UI event!'), findsOneWidget);
  });

  testWidgets('Counter renders its label, count, and button',
      (WidgetTester tester) async {
    await _pump(tester, const CounterSample());
    expect(find.text('You have pushed the button this many times:'),
        findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Increment'), findsOneWidget);
  });

  testWidgets('Counter increments its bound count on each press',
      (WidgetTester tester) async {
    await _pump(tester, const CounterSample());
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('Profile Card renders a Column of ProfileCard templates',
      (WidgetTester tester) async {
    await mockNetworkImagesFor(() async {
      await _pump(tester, const ProfileCardSample());
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
      await _pump(tester, const GallerySample());
      expect(find.byType(Image), findsNWidgets(3));
    });
  });

  testWidgets('the gallery app mounts and shows the first sample',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GalleryApp());
    expect(find.text('A2UI Craft × Flutter'), findsOneWidget);
  });
}
