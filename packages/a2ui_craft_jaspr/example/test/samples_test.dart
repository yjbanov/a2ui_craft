// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr_example/app.dart';
import 'package:a2ui_craft_jaspr_example/sample.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Mounts a shared [SampleSpec] exactly as the gallery does.
Future<void> _pump(ComponentTester tester, SampleSpec spec) async {
  tester.pumpComponent(Sample(spec));
  await tester.pump();
}

void main() {
  testComponents('Greeting renders its title, bound message, and button',
      (ComponentTester tester) async {
    await _pump(tester, greetingSpec('Jaspr'));
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
    expect(find.text('Press the button.'), findsOneComponent);
    expect(find.text('Say hi'), findsOneComponent);
  });

  testComponents('Counter renders its label, count, and button',
      (ComponentTester tester) async {
    await _pump(tester, counterSpec('Jaspr'));
    expect(find.text('You have pushed the button this many times:'),
        findsOneComponent);
    expect(find.text('0'), findsOneComponent);
    expect(find.text('Increment'), findsOneComponent);
  });

  testComponents('Profile Card renders a Column of ProfileCard templates',
      (ComponentTester tester) async {
    await _pump(tester, profileCardSpec('Jaspr'));
    // Two ProfileCard templates, each expanding to its own card subtree.
    expect(find.text('Jaspr Framework'), findsOneComponent);
    expect(find.text('Build apps for any screen.'), findsOneComponent);
    expect(find.text('Dart'), findsOneComponent);
  });

  testComponents('Image Gallery renders three images',
      (ComponentTester tester) async {
    await _pump(tester, gallerySpec('Jaspr'));
    expect(find.tag('img'), findsNComponents(3));
  });

  testComponents('Form renders a labelled text field and a checkbox',
      (ComponentTester tester) async {
    await _pump(tester, formSpec('Jaspr'));
    expect(find.text('Your name'), findsOneComponent);
    // A text input and a checkbox input.
    expect(find.tag('input'), findsNComponents(2));
  });

  testComponents('the gallery app mounts and shows the first sample',
      (ComponentTester tester) async {
    tester.pumpComponent(App());
    await tester.pump();
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
  });
}
