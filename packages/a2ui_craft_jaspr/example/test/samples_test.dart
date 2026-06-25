// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_jaspr_example/app.dart';
import 'package:a2ui_craft_jaspr_example/sample.dart';
import 'package:a2ui_craft_jaspr_example/samples/counter.dart';
import 'package:a2ui_craft_jaspr_example/samples/gallery.dart';
import 'package:a2ui_craft_jaspr_example/samples/greeting.dart';
import 'package:a2ui_craft_jaspr_example/samples/profile_card.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Mounts a self-contained [Sample] exactly as the gallery does.
Future<void> _pump(ComponentTester tester, Sample sample) async {
  tester.pumpComponent(sample);
  await tester.pump();
}

void main() {
  testComponents('Greeting renders its title, bound message, and button',
      (ComponentTester tester) async {
    await _pump(tester, const GreetingSample());
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
    expect(find.text('Press the button.'), findsOneComponent);
    expect(find.text('Say hi'), findsOneComponent);
  });

  testComponents('Counter renders its label, count, and button',
      (ComponentTester tester) async {
    await _pump(tester, const CounterSample());
    expect(find.text('You have pushed the button this many times:'),
        findsOneComponent);
    expect(find.text('0'), findsOneComponent);
    expect(find.text('Increment'), findsOneComponent);
  });

  testComponents('Profile Card renders a Column of ProfileCard templates',
      (ComponentTester tester) async {
    await _pump(tester, const ProfileCardSample());
    // Two ProfileCard templates, each expanding to its own card subtree.
    expect(find.text('Jaspr Framework'), findsOneComponent);
    expect(find.text('Build apps for any screen.'), findsOneComponent);
    expect(find.text('Dart'), findsOneComponent);
  });

  testComponents('Image Gallery renders three images',
      (ComponentTester tester) async {
    await _pump(tester, const GallerySample());
    expect(find.tag('img'), findsNComponents(3));
  });

  testComponents('the gallery app mounts and shows the first sample',
      (ComponentTester tester) async {
    tester.pumpComponent(App());
    await tester.pump();
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
  });
}
