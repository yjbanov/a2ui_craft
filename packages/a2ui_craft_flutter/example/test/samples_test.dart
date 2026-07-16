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
///
/// Wrapped in [mockNetworkImagesFor] so the samples' `Image` URLs resolve to a
/// stub instead of hitting the network during the pump (harmless for the
/// image-free samples).
Future<void> _pump(WidgetTester tester, SampleSpec spec) {
  return mockNetworkImagesFor(
    // The scroll view hosts the sample the way the demo site embeds Flutter
    // (unbounded height, content sizes itself), so a sample taller than the
    // test viewport lays out instead of overflowing the 600px test surface.
    () => tester.pumpWidget(MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: Sample(spec))),
    )),
  );
}

/// The `Card` primitive now owns its paint (a `DecoratedBox`, not Material's
/// `Card`); its decoration is the one carrying an elevation shadow, so that
/// identifies a rendered Card among the tree's decorated boxes.
Iterable<BoxDecoration> _cardDecorations(WidgetTester tester) => tester
    .widgetList<DecoratedBox>(find.byType(DecoratedBox))
    .map((DecoratedBox d) => d.decoration)
    .whereType<BoxDecoration>()
    .where((BoxDecoration d) => d.boxShadow?.isNotEmpty ?? false);

void main() {
  testWidgets('Greeting renders its title, bound message, and button',
      (WidgetTester tester) async {
    await _pump(tester, greetingSpec('Flutter'));
    expect(find.text('A2UI Craft × Flutter'), findsOneWidget);
    expect(find.text('Press the button.'), findsOneWidget);
    expect(find.text('Say hi'), findsOneWidget);
  });

  testWidgets('Counter counts up purely in-template (state + add)',
      (WidgetTester tester) async {
    await _pump(tester, counterSpec('Flutter'));
    expect(find.text('You have pushed the button this many times:'),
        findsOneWidget);
    expect(find.text('0'), findsOneWidget);
    expect(find.text('Increment'), findsOneWidget);

    // Tapping increments `count` in-template via `set state.count =
    // add(count, 1)` — no host code — through the full A2UI-surface/adapter path.
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
    expect(find.text('0'), findsNothing);
  });

  testWidgets('Calculator computes in-template (7 + 3 = 10)',
      (WidgetTester tester) async {
    await _pump(tester, calculatorSpec('Flutter'));
    // The keypad and the initial display render.
    expect(find.text('7'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    // Two zeros initially: the display (starts at 0) and the "0" key.
    expect(find.text('0'), findsNWidgets(2));

    // 7, +, 3, = → 10, all via state + the standard math functions.
    await tester.tap(find.text('7'));
    await tester.pump();
    await tester.tap(find.text('+'));
    await tester.pump();
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.tap(find.text('='));
    await tester.pump();
    expect(find.text('10'), findsOneWidget);
  });

  testWidgets('Settings renders every control; the radio group selects',
      (WidgetTester tester) async {
    await _pump(tester, settingsSpec('Flutter'));
    expect(find.text('Settings'), findsOneWidget);
    expect(find.byType(Switch), findsOneWidget);
    expect(find.text('Pro'), findsOneWidget); // Select shows the bound plan
    expect(find.byType(Checkbox), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Save changes'), findsOneWidget);

    // The template-state radio group: Imperial "selects me".
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
    await tester.tap(find.byIcon(Icons.radio_button_off).last);
    await tester.pump();
    // Still exactly one selected — the group moved, it didn't grow.
    expect(find.byIcon(Icons.radio_button_checked), findsOneWidget);
  });

  testWidgets('Boxes renders the nested-box layout',
      (WidgetTester tester) async {
    await _pump(tester, boxesSpec('Flutter'));
    expect(find.text('Here are some nested boxes with margins and padding:'),
        findsOneWidget);
    expect(find.text('Center'), findsOneWidget);
  });

  testWidgets(
      'Layout demo renders the Align/AspectRatio/Wrap/Opacity primitives',
      (WidgetTester tester) async {
    await _pump(tester, layoutSpec('Flutter'));
    expect(find.text('Layout primitives (same on every adapter):'),
        findsOneWidget);
    expect(find.text('faded'), findsOneWidget); // inside the Opacity
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
      expect(_cardDecorations(tester).length, 2);
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

  // --- Templatized A2UI Basic Catalog gallery examples. ---

  testWidgets('Simple Text renders the templatized text',
      (WidgetTester tester) async {
    await _pump(tester, simpleTextSpec('Flutter'));
    expect(find.text('Hello, Minimal Catalog!'), findsOneWidget);
  });

  testWidgets('Login Form renders title, field labels, and submit',
      (WidgetTester tester) async {
    await _pump(tester, loginFormSpec('Flutter'));
    expect(find.text('Login'), findsOneWidget);
    expect(find.text('Username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });

  testWidgets('Weather renders the temperature, location, and forecast',
      (WidgetTester tester) async {
    await _pump(tester, weatherSpec('Flutter'));
    expect(find.text('72°'), findsOneWidget);
    expect(find.text('Austin, TX'), findsOneWidget);
    expect(find.text('Mon'), findsOneWidget); // a `...for` forecast day
    expect(find.text('Fri'), findsOneWidget);
  });

  testWidgets('Product Card steps quantity and computes the line total',
      (WidgetTester tester) async {
    await _pump(tester, productCardSpec('Flutter'));
    expect(find.text('Wireless Headphones Pro'), findsOneWidget);
    // Unit price and total (qty 1) both render from the numeric unitPrice.
    expect(find.text(r'$199.99'), findsNWidgets(2));
    expect(find.text('Add to Cart'), findsOneWidget);

    // "+" raises the quantity; the total recomputes (unitPrice × qty ÷ 100).
    await tester.tap(find.text('+'));
    await tester.pump();
    expect(find.text('2'), findsOneWidget); // qty
    expect(find.text(r'$399.98'), findsOneWidget); // 19999 * 2 / 100

    // "−" lowers it, and is clamped at 1 by `max`.
    await tester.tap(find.text('−'));
    await tester.pump();
    await tester.tap(find.text('−'));
    await tester.pump();
    expect(find.text('1'), findsOneWidget); // clamped, not 0
    expect(find.text(r'$199.99'), findsNWidgets(2));
  });

  testWidgets('Restaurant Card renders name, cuisine, and rating',
      (WidgetTester tester) async {
    await _pump(tester, restaurantCardSpec('Flutter'));
    expect(find.text('The Italian Kitchen'), findsOneWidget);
    expect(find.text('Italian • Pasta • Wine Bar'), findsOneWidget);
    expect(find.text('4.8'), findsOneWidget);
  });

  testWidgets('Account Balance deposits and withdraws, recomputing the balance',
      (WidgetTester tester) async {
    await _pump(tester, accountBalanceSpec('Flutter'));
    expect(find.text('Primary Checking'), findsOneWidget);
    expect(find.text(r'$12458.32'), findsOneWidget); // 1245832 cents / 100

    await tester.tap(find.text(r'Deposit $50'));
    await tester.pump();
    expect(find.text(r'$12508.32'), findsOneWidget); // +5000 cents

    await tester.tap(find.text(r'Withdraw $20'));
    await tester.pump();
    expect(find.text(r'$12488.32'), findsOneWidget); // -2000 cents
  });

  testWidgets('Shipping Status renders the templated step rows',
      (WidgetTester tester) async {
    await _pump(tester, shippingStatusSpec('Flutter'));
    expect(find.text('Package Status'), findsOneWidget);
    expect(find.text('Order Placed'), findsOneWidget); // first `...for` step
    expect(find.text('Delivered'), findsOneWidget); // last `...for` step
  });

  testWidgets('Interactive Button renders the prompt and button',
      (WidgetTester tester) async {
    await _pump(tester, interactiveButtonSpec('Flutter'));
    expect(find.text('Click the button below'), findsOneWidget);
    expect(find.text('Click Me'), findsOneWidget);
  });

  testWidgets('Flight Status renders the route and status',
      (WidgetTester tester) async {
    await _pump(tester, flightStatusSpec('Flutter'));
    expect(find.text('OS 87'), findsOneWidget);
    expect(find.text('Vienna'), findsOneWidget);
    expect(find.text('New York'), findsOneWidget);
    expect(find.text('On Time'), findsOneWidget);
  });

  testWidgets('Purchase Complete renders the confirmation and seller',
      (WidgetTester tester) async {
    await _pump(tester, purchaseCompleteSpec('Flutter'));
    expect(find.text('Purchase Complete'), findsOneWidget);
    expect(find.text('TechStore Official'), findsOneWidget);
    expect(find.text('View Order Details'), findsOneWidget);
  });

  testWidgets('Coffee Order steps line quantities and sums the total',
      (WidgetTester tester) async {
    await _pump(tester, coffeeOrderSpec('Flutter'));
    expect(find.text('Sunrise Coffee'), findsOneWidget);
    expect(find.text('Oat Milk Latte'), findsOneWidget);
    expect(find.text(r'$6'), findsOneWidget); // line 1 (6 * 1)
    expect(find.text(r'$10'), findsOneWidget); // total (6 + 4)

    // Raise the first item's quantity: its line total and the order total both
    // recompute (multiply for the line, add for the sum).
    await tester.tap(find.text('+').first);
    await tester.pump();
    expect(find.text(r'$12'), findsOneWidget); // line 1 (6 * 2)
    expect(find.text(r'$16'), findsOneWidget); // total (12 + 4)
  });

  testWidgets('Credit Card renders the brand, holder, and expiry',
      (WidgetTester tester) async {
    await _pump(tester, creditCardSpec('Flutter'));
    expect(find.text('VISA'), findsOneWidget);
    expect(find.text('SARAH JOHNSON'), findsOneWidget);
    expect(find.text('09/27'), findsOneWidget);
  });

  testWidgets('Child List Template renders one row per data item',
      (WidgetTester tester) async {
    await _pump(tester, childListTemplateSpec('Flutter'));
    expect(find.text('Dynamic Item List'), findsOneWidget);
    expect(find.text('Apple'), findsOneWidget); // first `...for` item
    expect(find.text('Cherry'), findsOneWidget); // last `...for` item
  });

  testWidgets('Markdown renders a heading, list items, and a link',
      (WidgetTester tester) async {
    await _pump(tester, markdownTextSpec('Flutter'));
    expect(find.text('Heading 1'), findsOneWidget); // `#` heading
    expect(find.text('List item 1'), findsOneWidget); // `-` list item
    expect(find.text('Link to Google'), findsOneWidget); // `[..](..)` link
  });

  testWidgets('Music Player renders the track heading and times',
      (WidgetTester tester) async {
    await _pump(tester, musicPlayerSpec('Flutter'));
    expect(find.text('Blinding Lights'), findsOneWidget); // Heading
    expect(find.text('The Weeknd'), findsOneWidget);
    expect(find.text('4:22'), findsOneWidget);
  });

  testWidgets('Permission renders the prompt and Yes/No actions',
      (WidgetTester tester) async {
    await _pump(tester, notificationPermissionSpec('Flutter'));
    expect(find.text('Enable notifications'), findsOneWidget); // Heading
    expect(find.text('Yes'), findsOneWidget);
    expect(find.text('No'), findsOneWidget);
  });

  testWidgets('Sports Player renders the name heading and stats',
      (WidgetTester tester) async {
    await _pump(tester, sportsPlayerSpec('Flutter'));
    expect(find.text('Marcus Johnson'), findsOneWidget); // Heading
    expect(find.text('LA Lakers'), findsOneWidget);
    expect(find.text('PPG'), findsOneWidget);
    expect(find.text('APG'), findsOneWidget);
  });

  testWidgets('Event Detail renders the title heading and actions',
      (WidgetTester tester) async {
    await _pump(tester, eventDetailSpec('Flutter'));
    expect(find.text('Product Launch Meeting'), findsOneWidget); // Heading
    expect(find.text('Conference Room A, Building 2'), findsOneWidget);
    expect(find.text('Accept'), findsOneWidget);
  });

  testWidgets('Step Counter logs steps and derives metrics via functions',
      (WidgetTester tester) async {
    await _pump(tester, stepCounterSpec('Flutter'));
    expect(find.text("Today's Activity"), findsOneWidget); // Heading
    expect(find.text('Distance'), findsOneWidget);
    expect(find.text('Log 500 steps'), findsOneWidget);

    // Logging bumps `steps` state; distance/calories/progress are all recomputed
    // from it with the math functions (÷, ×, min, concat, round).
    await tester.tap(find.text('Log 500 steps'));
    await tester.pump();
    expect(find.text('500'), findsOneWidget); // steps
    expect(find.text('0.25 mi'), findsOneWidget); // 500 / 2000
    expect(find.text('20'), findsOneWidget); // round(500 * 0.04)
    expect(find.text('5% of 10,000 step goal'), findsOneWidget);
  });

  testWidgets('Countdown renders the event heading and units',
      (WidgetTester tester) async {
    await _pump(tester, countdownTimerSpec('Flutter'));
    expect(find.text('Product Launch'), findsOneWidget); // Heading
    expect(find.text('Days'), findsOneWidget);
    expect(find.text('January 15, 2025'), findsOneWidget);
  });

  testWidgets('Row Layout pushes its two texts to opposite edges',
      (WidgetTester tester) async {
    await _pump(tester, rowLayoutSpec('Flutter'));
    expect(find.text('Left Content'), findsOneWidget);
    expect(find.text('Right Content'), findsOneWidget);
  });

  testWidgets('User Profile renders the name heading, stats, and follow',
      (WidgetTester tester) async {
    await _pump(tester, userProfileSpec('Flutter'));
    expect(find.text('Sarah Chen'), findsOneWidget); // Heading
    expect(find.text('@sarahchen'), findsOneWidget);
    expect(find.text('Followers'), findsOneWidget);
    expect(find.text('Follow'), findsOneWidget);
  });

  testWidgets('Chat renders the channel heading and message rows',
      (WidgetTester tester) async {
    await _pump(tester, chatMessageSpec('Flutter'));
    expect(find.text('project-updates'), findsOneWidget); // Heading
    expect(find.text('Mike Chen'), findsOneWidget); // a `...for` message
    expect(find.text('Sarah Kim'), findsOneWidget);
  });

  testWidgets('Workout renders the heading and metrics',
      (WidgetTester tester) async {
    await _pump(tester, workoutSummarySpec('Flutter'));
    expect(find.text('Workout Complete'), findsOneWidget); // Heading
    expect(find.text('Duration'), findsOneWidget);
    expect(find.text('32:15'), findsOneWidget);
  });

  testWidgets('Track List renders the playlist heading and tracks',
      (WidgetTester tester) async {
    await _pump(tester, trackListSpec('Flutter'));
    expect(find.text('Focus Flow'), findsOneWidget); // Heading
    expect(find.text('Weightless'), findsOneWidget); // a `...for` track
    expect(find.text('Ambient Light'), findsOneWidget);
  });

  testWidgets('Data Grid renders the header and asset rows',
      (WidgetTester tester) async {
    await _pump(tester, financialDataGridSpec('Flutter'));
    expect(find.text('Asset'), findsOneWidget); // header column
    expect(find.text('Bitcoin'), findsOneWidget); // a `...for` asset
    expect(find.text('Solana'), findsOneWidget);
  });

  testWidgets('Formatted Text renders the field label and result',
      (WidgetTester tester) async {
    await _pump(tester, formattedTextSpec('Flutter'));
    expect(find.text('Type something:'), findsOneWidget);
    expect(find.text('Formatted output:'), findsOneWidget);
    expect(find.text('You typed: hello'), findsOneWidget);
  });

  testWidgets('Incremental renders one restaurant card per item',
      (WidgetTester tester) async {
    await _pump(tester, incrementalSpec('Flutter'));
    expect(find.text('The Golden Fork'), findsOneWidget); // first `...for`
    expect(find.text('Spice Route'), findsOneWidget); // last `...for`
  });

  testWidgets('Complex Layout renders the heading and side-by-side fields',
      (WidgetTester tester) async {
    await _pump(tester, complexLayoutSpec('Flutter'));
    expect(find.text('User Profile Form'), findsOneWidget); // Heading
    expect(find.text('First Name'), findsOneWidget);
    expect(find.text('Last Name'), findsOneWidget);
    expect(find.text('Please fill out all fields.'), findsOneWidget);
  });

  testWidgets('Email Compose renders headers, body, and actions',
      (WidgetTester tester) async {
    await _pump(tester, emailComposeSpec('Flutter'));
    expect(find.text('Q4 Revenue Forecast'), findsOneWidget);
    expect(find.text('alex@acme.com'), findsOneWidget);
    expect(find.text('Send email'), findsOneWidget);
  });

  testWidgets('Calendar Day renders the day, events, and actions',
      (WidgetTester tester) async {
    await _pump(tester, calendarDaySpec('Flutter'));
    expect(find.text('28'), findsOneWidget); // Heading day number
    expect(find.text('Q1 roadmap review'), findsOneWidget); // a `...for` event
    expect(find.text('Add to calendar'), findsOneWidget);
  });

  testWidgets('Sign In renders the welcome heading, fields, and links',
      (WidgetTester tester) async {
    await _pump(tester, signInSpec('Flutter'));
    expect(find.text('Welcome back'), findsOneWidget); // Heading
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('Sign up'), findsOneWidget);
  });

  testWidgets('Dashboard renders the heading and both panels',
      (WidgetTester tester) async {
    await _pump(tester, incrementalDashboardSpec('Flutter'));
    expect(find.text('System Dashboard'), findsOneWidget); // Heading
    expect(find.text('Analytics are ready.'), findsOneWidget);
    expect(
        find.text('System boot complete.'), findsOneWidget); // a `...for` log
  });

  testWidgets('Form Validator renders fields, terms, and submit',
      (WidgetTester tester) async {
    await _pump(tester, formValidatorSpec('Flutter'));
    expect(find.text('Email Address'), findsOneWidget);
    expect(find.text('I agree to the terms and conditions'), findsOneWidget);
    expect(find.text('Submit Registration'), findsOneWidget);
  });

  testWidgets('the gallery app mounts and shows the first sample',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GalleryApp());
    expect(find.text('A2UI Craft × Flutter'), findsOneWidget);
  });
}
