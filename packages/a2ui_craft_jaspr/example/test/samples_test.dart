// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr_example/app.dart';
import 'package:a2ui_craft_jaspr_example/sample.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Mounts a shared [SampleSpec] exactly as the gallery does. [dark] is the
/// host's system dark-light preference (false on the test VM, matching the
/// gallery's no-preference stub).
Future<void> _pump(ComponentTester tester, SampleSpec spec,
    {bool dark = false}) async {
  tester.pumpComponent(Sample(spec, dark: dark));
  await tester.pump();
}

/// All values of the CSS [property] explicitly set by rendered DOM components.
List<String> _styleValues(String property) => <String>[
      for (final Element element in find
          .byComponentPredicate((Component c) =>
              c is DomComponent &&
              (c.styles?.properties.containsKey(property) ?? false))
          .evaluate())
        (element.component as DomComponent).styles!.properties[property]!,
    ];

void main() {
  testComponents('Greeting renders its title, bound message, and button',
      (ComponentTester tester) async {
    await _pump(tester, greetingSpec('Jaspr'));
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
    expect(find.text('Press the button.'), findsOneComponent);
    expect(find.text('Say hi'), findsOneComponent);
  });

  testComponents('Counter counts up purely in-template (state + add)',
      (ComponentTester tester) async {
    await _pump(tester, counterSpec('Jaspr'));
    expect(find.text('You have pushed the button this many times:'),
        findsOneComponent);
    expect(find.text('0'), findsOneComponent);
    expect(find.text('Increment'), findsOneComponent);

    // Clicking increments `count` in-template via `set state.count =
    // add(count, 1)` — no host code — through the full A2UI-surface/adapter path.
    await tester.click(find.tag('button'));
    await tester.pump();
    expect(find.text('1'), findsOneComponent);
    expect(find.text('0'), findsNothing);
  });

  testComponents('Calculator renders its keypad and display',
      (ComponentTester tester) async {
    // Render-smoke: the calculator's 16-key grid and its display mount on Jaspr.
    // The compute logic (multi-set-state + switch + the math functions) is proven
    // cross-adapter in the conformance suite, so this need only prove the sample
    // builds here; Flutter's example test exercises the full 7 + 3 = 10 path.
    await _pump(tester, calculatorSpec('Jaspr'));
    expect(find.text('7'), findsOneComponent);
    expect(find.text('÷'), findsOneComponent);
    expect(find.text('C'), findsOneComponent);
    expect(find.text('='), findsOneComponent);
    expect(find.tag('button'), findsNComponents(16));
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

  testComponents(
      'Profile Card is a themed project — its mode follows the host darkness',
      (ComponentTester tester) async {
    // profile_card ships a manifest theme ({theme:default, mode:dark}). Its
    // SampleSpec carries a ProjectTheme (§10); the gallery Sample maps the
    // host's dark-light preference onto the theme's modes (host render-time
    // config, §9.5), so the same project paints light or dark with the system.
    final SampleSpec spec = profileCardSpec('Jaspr');
    expect(spec.theme, isNotNull);
    expect(spec.theme!.usesDefaultTheme, isTrue);
    expect(spec.theme!.defaultMode.id, 'dark');

    // A dark host: each of the two cards paints its surface (color.surface =
    // #202124) and, via its Divider, the outline role (#5F6368 in Dark).
    await _pump(tester, spec, dark: true);
    expect(_styleValues('background-color'), <String>[
      'rgba(32, 33, 36, 1.0)', // card 1 ← surface
      'rgba(95, 99, 104, 1.0)', // card 1 divider ← outline
      'rgba(32, 33, 36, 1.0)', // card 2 ← surface
      'rgba(95, 99, 104, 1.0)', // card 2 divider ← outline
    ]);

    // A light host: the same project re-themes to the Light layer.
    await _pump(tester, spec);
    expect(_styleValues('background-color'), <String>[
      'rgba(255, 255, 255, 1.0)', // card 1 ← surface
      'rgba(218, 220, 224, 1.0)', // card 1 divider ← outline
      'rgba(255, 255, 255, 1.0)', // card 2 ← surface
      'rgba(218, 220, 224, 1.0)', // card 2 divider ← outline
    ]);
  });

  testComponents(
      'Product Card ships a custom inline theme with light + dark layers',
      (ComponentTester tester) async {
    // product_card's manifest inlines a bespoke brand: a base DTCG layer
    // (Light) plus a "modes.dark" overlay (§9.5). The gallery Sample picks the
    // layer matching the host's dark-light preference.
    final SampleSpec spec = productCardSpec('Jaspr');
    expect(spec.theme, isNotNull);
    expect(spec.theme!.usesDefaultTheme, isFalse);

    await _pump(tester, spec);
    expect(_styleValues('background-color'), <String>[
      'rgba(255, 248, 240, 1.0)', // card ← brand surface, Light
      'rgba(224, 207, 194, 1.0)', // divider ← brand outline, Light
    ]);

    await _pump(tester, spec, dark: true);
    expect(_styleValues('background-color'), <String>[
      'rgba(42, 30, 23, 1.0)', // card ← brand surface, Dark
      'rgba(93, 64, 55, 1.0)', // divider ← brand outline, Dark
    ]);
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

  testComponents('Product Card renders name, computed price, and stepper',
      (ComponentTester tester) async {
    // Render-smoke: the numeric unit price flows through and the total renders
    // (unit price and qty-1 total are both "$199.99"); the stepper's buttons
    // mount. The stepper arithmetic is exercised on Flutter and in conformance.
    await _pump(tester, productCardSpec('Jaspr'));
    expect(find.text('Wireless Headphones Pro'), findsOneComponent);
    expect(find.text(r'$199.99'), findsNComponents(2));
    expect(find.text('Add to Cart'), findsOneComponent);
    expect(find.tag('button'), findsNComponents(3)); // − , + , Add to Cart
  });

  testComponents('Restaurant Card renders name, cuisine, and rating',
      (ComponentTester tester) async {
    await _pump(tester, restaurantCardSpec('Jaspr'));
    expect(find.text('The Italian Kitchen'), findsOneComponent);
    expect(find.text('Italian • Pasta • Wine Bar'), findsOneComponent);
    expect(find.text('4.8'), findsOneComponent);
  });

  testComponents('Account Balance renders the computed balance and actions',
      (ComponentTester tester) async {
    // Render-smoke: the numeric balance renders as dollars (÷100); the
    // deposit/withdraw buttons mount. The arithmetic is exercised on Flutter and
    // in conformance.
    await _pump(tester, accountBalanceSpec('Jaspr'));
    expect(find.text('Primary Checking'), findsOneComponent);
    expect(find.text(r'$12458.32'), findsOneComponent);
    expect(find.text(r'Deposit $50'), findsOneComponent);
    expect(find.text(r'Withdraw $20'), findsOneComponent);
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

  testComponents('Coffee Order renders line items, steppers, and the total',
      (ComponentTester tester) async {
    // Render-smoke: both items, their line totals, and the summed order total
    // render; the per-line steppers mount. The arithmetic runs on Flutter and in
    // conformance.
    await _pump(tester, coffeeOrderSpec('Jaspr'));
    expect(find.text('Sunrise Coffee'), findsOneComponent);
    expect(find.text('Oat Milk Latte'), findsOneComponent);
    expect(find.text(r'$6'), findsOneComponent); // line 1
    expect(find.text(r'$10'), findsOneComponent); // total
    expect(find.tag('button'), findsNComponents(5)); // 2×(− +) + Checkout
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

  testComponents('Step Counter logs steps and derives metrics via functions',
      (ComponentTester tester) async {
    await _pump(tester, stepCounterSpec('Jaspr'));
    expect(find.text("Today's Activity"), findsOneComponent); // Heading
    expect(find.text('Distance'), findsOneComponent);
    expect(find.text('Log 500 steps'), findsOneComponent);

    // One button (Log 500 steps): clicking recomputes the derived metrics.
    await tester.click(find.tag('button'));
    await tester.pump();
    expect(find.text('500'), findsOneComponent); // steps
    expect(find.text('0.25 mi'), findsOneComponent); // 500 / 2000
    expect(find.text('20'), findsOneComponent); // round(500 * 0.04)
  });

  testComponents('Countdown renders the event heading and units',
      (ComponentTester tester) async {
    await _pump(tester, countdownTimerSpec('Jaspr'));
    expect(find.text('Product Launch'), findsOneComponent); // Heading
    expect(find.text('Days'), findsOneComponent);
    expect(find.text('January 15, 2025'), findsOneComponent);
  });

  testComponents('Row Layout pushes its two texts to opposite edges',
      (ComponentTester tester) async {
    await _pump(tester, rowLayoutSpec('Jaspr'));
    expect(find.text('Left Content'), findsOneComponent);
    expect(find.text('Right Content'), findsOneComponent);
  });

  testComponents('User Profile renders the name heading, stats, and follow',
      (ComponentTester tester) async {
    await _pump(tester, userProfileSpec('Jaspr'));
    expect(find.text('Sarah Chen'), findsOneComponent); // Heading
    expect(find.text('@sarahchen'), findsOneComponent);
    expect(find.text('Followers'), findsOneComponent);
    expect(find.text('Follow'), findsOneComponent);
  });

  testComponents('Chat renders the channel heading and message rows',
      (ComponentTester tester) async {
    await _pump(tester, chatMessageSpec('Jaspr'));
    expect(find.text('project-updates'), findsOneComponent); // Heading
    expect(find.text('Mike Chen'), findsOneComponent); // a `...for` message
    expect(find.text('Sarah Kim'), findsOneComponent);
  });

  testComponents('Workout renders the heading and metrics',
      (ComponentTester tester) async {
    await _pump(tester, workoutSummarySpec('Jaspr'));
    expect(find.text('Workout Complete'), findsOneComponent); // Heading
    expect(find.text('Duration'), findsOneComponent);
    expect(find.text('32:15'), findsOneComponent);
  });

  testComponents('Track List renders the playlist heading and tracks',
      (ComponentTester tester) async {
    await _pump(tester, trackListSpec('Jaspr'));
    expect(find.text('Focus Flow'), findsOneComponent); // Heading
    expect(find.text('Weightless'), findsOneComponent); // a `...for` track
    expect(find.text('Ambient Light'), findsOneComponent);
  });

  testComponents('Data Grid renders the header and asset rows',
      (ComponentTester tester) async {
    await _pump(tester, financialDataGridSpec('Jaspr'));
    expect(find.text('Asset'), findsOneComponent); // header column
    expect(find.text('Bitcoin'), findsOneComponent); // a `...for` asset
    expect(find.text('Solana'), findsOneComponent);
  });

  testComponents('Formatted Text renders the field label and result',
      (ComponentTester tester) async {
    await _pump(tester, formattedTextSpec('Jaspr'));
    expect(find.text('Type something:'), findsOneComponent);
    expect(find.text('Formatted output:'), findsOneComponent);
    expect(find.text('You typed: hello'), findsOneComponent);
  });

  testComponents('Incremental renders one restaurant card per item',
      (ComponentTester tester) async {
    await _pump(tester, incrementalSpec('Jaspr'));
    expect(find.text('The Golden Fork'), findsOneComponent); // first `...for`
    expect(find.text('Spice Route'), findsOneComponent); // last `...for`
  });

  testComponents('Complex Layout renders the heading and side-by-side fields',
      (ComponentTester tester) async {
    await _pump(tester, complexLayoutSpec('Jaspr'));
    expect(find.text('User Profile Form'), findsOneComponent); // Heading
    expect(find.text('First Name'), findsOneComponent);
    expect(find.text('Last Name'), findsOneComponent);
    expect(find.text('Please fill out all fields.'), findsOneComponent);
  });

  testComponents('Email Compose renders headers, body, and actions',
      (ComponentTester tester) async {
    await _pump(tester, emailComposeSpec('Jaspr'));
    expect(find.text('Q4 Revenue Forecast'), findsOneComponent);
    expect(find.text('alex@acme.com'), findsOneComponent);
    expect(find.text('Send email'), findsOneComponent);
  });

  testComponents('Calendar Day renders the day, events, and actions',
      (ComponentTester tester) async {
    await _pump(tester, calendarDaySpec('Jaspr'));
    expect(find.text('28'), findsOneComponent); // Heading day number
    expect(
        find.text('Q1 roadmap review'), findsOneComponent); // a `...for` event
    expect(find.text('Add to calendar'), findsOneComponent);
  });

  testComponents('Sign In renders the welcome heading, fields, and links',
      (ComponentTester tester) async {
    await _pump(tester, signInSpec('Jaspr'));
    expect(find.text('Welcome back'), findsOneComponent); // Heading
    expect(find.text('Email'), findsOneComponent);
    expect(find.text('Sign in'), findsOneComponent);
    expect(find.text('Sign up'), findsOneComponent);
  });

  testComponents('Dashboard renders the heading and both panels',
      (ComponentTester tester) async {
    await _pump(tester, incrementalDashboardSpec('Jaspr'));
    expect(find.text('System Dashboard'), findsOneComponent); // Heading
    expect(find.text('Analytics are ready.'), findsOneComponent);
    expect(
        find.text('System boot complete.'), findsOneComponent); // `...for` log
  });

  testComponents('Form Validator renders fields, terms, and submit',
      (ComponentTester tester) async {
    await _pump(tester, formValidatorSpec('Jaspr'));
    expect(find.text('Email Address'), findsOneComponent);
    expect(find.text('I agree to the terms and conditions'), findsOneComponent);
    expect(find.text('Submit Registration'), findsOneComponent);
  });

  testComponents('the gallery app mounts and shows the first sample',
      (ComponentTester tester) async {
    tester.pumpComponent(App());
    await tester.pump();
    expect(find.text('A2UI Craft × Jaspr'), findsOneComponent);
  });
}
