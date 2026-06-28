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

  testComponents('Boxes renders the nested-box layout',
      (ComponentTester tester) async {
    await _pump(tester, boxesSpec('Jaspr'));
    expect(find.text('Here are some nested boxes with margins and padding:'),
        findsOneComponent);
    expect(find.text('Center'), findsOneComponent);
  });

  testComponents(
      'Layout demo renders the Align/AspectRatio/Wrap/Opacity primitives',
      (ComponentTester tester) async {
    await _pump(tester, layoutSpec('Jaspr'));
    expect(find.text('Layout primitives (same on every adapter):'),
        findsOneComponent);
    expect(find.text('faded'), findsOneComponent); // inside the Opacity
  });

  testComponents('Contact Card renders the atoms (name, caption, icon rows)',
      (ComponentTester tester) async {
    await _pump(tester, contactCardSpec('Jaspr'));
    expect(find.text('Ada Lovelace'), findsOneComponent);
    expect(find.text('Mathematician'), findsOneComponent);
    expect(find.text('ada@example.com'), findsOneComponent);
    expect(find.text('London, UK'), findsOneComponent);
  });

  testComponents('Stats Card renders its stats and a slider',
      (ComponentTester tester) async {
    await _pump(tester, statsCardSpec('Jaspr'));
    expect(find.text("Today's Activity"), findsOneComponent);
    expect(find.text('8,420'), findsOneComponent);
    expect(find.text('kcal'), findsOneComponent);
    expect(find.tag('input'), findsOneComponent); // the range slider
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

  // --- Templatized A2UI Basic Catalog gallery examples. ---

  testComponents('Simple Text renders the templatized text',
      (ComponentTester tester) async {
    await _pump(tester, simpleTextSpec('Jaspr'));
    expect(find.text('Hello, Minimal Catalog!'), findsOneComponent);
  });

  testComponents('Login Form renders title, field labels, and submit',
      (ComponentTester tester) async {
    await _pump(tester, loginFormSpec('Jaspr'));
    expect(find.text('Login'), findsOneComponent);
    expect(find.text('Username'), findsOneComponent);
    expect(find.text('Password'), findsOneComponent);
    expect(find.text('Sign In'), findsOneComponent);
  });

  testComponents('Weather renders the temperature, location, and forecast',
      (ComponentTester tester) async {
    await _pump(tester, weatherSpec('Jaspr'));
    expect(find.text('72°'), findsOneComponent);
    expect(find.text('Austin, TX'), findsOneComponent);
    expect(find.text('Mon'), findsOneComponent); // a `...for` forecast day
    expect(find.text('Fri'), findsOneComponent);
  });

  testComponents('Product Card renders name, price, and call-to-action',
      (ComponentTester tester) async {
    await _pump(tester, productCardSpec('Jaspr'));
    expect(find.text('Wireless Headphones Pro'), findsOneComponent);
    expect(find.text(r'$199.99'), findsOneComponent);
    expect(find.text('Add to Cart'), findsOneComponent);
  });

  testComponents('Restaurant Card renders name, cuisine, and rating',
      (ComponentTester tester) async {
    await _pump(tester, restaurantCardSpec('Jaspr'));
    expect(find.text('The Italian Kitchen'), findsOneComponent);
    expect(find.text('Italian • Pasta • Wine Bar'), findsOneComponent);
    expect(find.text('4.8'), findsOneComponent);
  });

  testComponents('Account Balance renders the balance and action buttons',
      (ComponentTester tester) async {
    await _pump(tester, accountBalanceSpec('Jaspr'));
    expect(find.text('Primary Checking'), findsOneComponent);
    expect(find.text(r'$12,458.32'), findsOneComponent);
    expect(find.text('Transfer'), findsOneComponent);
    expect(find.text('Pay Bill'), findsOneComponent);
  });

  testComponents('Shipping Status renders the templated step rows',
      (ComponentTester tester) async {
    await _pump(tester, shippingStatusSpec('Jaspr'));
    expect(find.text('Package Status'), findsOneComponent);
    expect(find.text('Order Placed'), findsOneComponent); // first `...for` step
    expect(find.text('Delivered'), findsOneComponent); // last `...for` step
  });

  testComponents('Interactive Button renders the prompt and button',
      (ComponentTester tester) async {
    await _pump(tester, interactiveButtonSpec('Jaspr'));
    expect(find.text('Click the button below'), findsOneComponent);
    expect(find.text('Click Me'), findsOneComponent);
  });

  testComponents('Flight Status renders the route and status',
      (ComponentTester tester) async {
    await _pump(tester, flightStatusSpec('Jaspr'));
    expect(find.text('OS 87'), findsOneComponent);
    expect(find.text('Vienna'), findsOneComponent);
    expect(find.text('New York'), findsOneComponent);
    expect(find.text('On Time'), findsOneComponent);
  });

  testComponents('Purchase Complete renders the confirmation and seller',
      (ComponentTester tester) async {
    await _pump(tester, purchaseCompleteSpec('Jaspr'));
    expect(find.text('Purchase Complete'), findsOneComponent);
    expect(find.text('TechStore Official'), findsOneComponent);
    expect(find.text('View Order Details'), findsOneComponent);
  });

  testComponents('Coffee Order renders items and total',
      (ComponentTester tester) async {
    await _pump(tester, coffeeOrderSpec('Jaspr'));
    expect(find.text('Sunrise Coffee'), findsOneComponent);
    expect(find.text('Oat Milk Latte'), findsOneComponent); // a `...for` item
    expect(find.text(r'$11.66'), findsOneComponent);
  });

  testComponents('Credit Card renders the brand, holder, and expiry',
      (ComponentTester tester) async {
    await _pump(tester, creditCardSpec('Jaspr'));
    expect(find.text('VISA'), findsOneComponent);
    expect(find.text('SARAH JOHNSON'), findsOneComponent);
    expect(find.text('09/27'), findsOneComponent);
  });

  testComponents('Child List Template renders one row per data item',
      (ComponentTester tester) async {
    await _pump(tester, childListTemplateSpec('Jaspr'));
    expect(find.text('Dynamic Item List'), findsOneComponent);
    expect(find.text('Apple'), findsOneComponent); // first `...for` item
    expect(find.text('Cherry'), findsOneComponent); // last `...for` item
  });

  testComponents('Markdown renders a heading, list items, and a link',
      (ComponentTester tester) async {
    await _pump(tester, markdownTextSpec('Jaspr'));
    expect(find.text('Heading 1'), findsOneComponent); // `#` heading
    expect(find.text('List item 1'), findsOneComponent); // `-` list item
    expect(find.text('Link to Google'), findsOneComponent); // `[..](..)` link
  });

  testComponents('Music Player renders the track heading and times',
      (ComponentTester tester) async {
    await _pump(tester, musicPlayerSpec('Jaspr'));
    expect(find.text('Blinding Lights'), findsOneComponent); // Heading
    expect(find.text('The Weeknd'), findsOneComponent);
    expect(find.text('4:22'), findsOneComponent);
  });

  testComponents('Permission renders the prompt and Yes/No actions',
      (ComponentTester tester) async {
    await _pump(tester, notificationPermissionSpec('Jaspr'));
    expect(find.text('Enable notifications'), findsOneComponent); // Heading
    expect(find.text('Yes'), findsOneComponent);
    expect(find.text('No'), findsOneComponent);
  });

  testComponents('Sports Player renders the name heading and stats',
      (ComponentTester tester) async {
    await _pump(tester, sportsPlayerSpec('Jaspr'));
    expect(find.text('Marcus Johnson'), findsOneComponent); // Heading
    expect(find.text('LA Lakers'), findsOneComponent);
    expect(find.text('PPG'), findsOneComponent);
    expect(find.text('APG'), findsOneComponent);
  });

  testComponents('Event Detail renders the title heading and actions',
      (ComponentTester tester) async {
    await _pump(tester, eventDetailSpec('Jaspr'));
    expect(find.text('Product Launch Meeting'), findsOneComponent); // Heading
    expect(find.text('Conference Room A, Building 2'), findsOneComponent);
    expect(find.text('Accept'), findsOneComponent);
  });

  testComponents('Step Counter renders the heading, steps, and stats',
      (ComponentTester tester) async {
    await _pump(tester, stepCounterSpec('Jaspr'));
    expect(find.text("Today's Steps"), findsOneComponent); // Heading
    expect(find.text('8,432'), findsOneComponent);
    expect(find.text('Distance'), findsOneComponent);
  });

  testComponents('Countdown renders the event heading and units',
      (ComponentTester tester) async {
    await _pump(tester, countdownTimerSpec('Jaspr'));
    expect(find.text('Product Launch'), findsOneComponent); // Heading
    expect(find.text('Days'), findsOneComponent);
    expect(find.text('January 15, 2025'), findsOneComponent);
  });

  testComponents('the gallery app mounts and shows the first sample',
      (ComponentTester tester) async {
    tester.pumpComponent(App());
    await tester.pump();
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
  });
}
