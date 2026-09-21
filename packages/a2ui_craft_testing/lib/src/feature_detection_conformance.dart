// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

import 'conformance.dart';

/// Conformance tests verifying the multi-scenario feature detection specification
/// (Section 8 of FEATURE_DETECTION_DESIGN.md) across all adapters.
void runFeatureDetectionConformance(CraftConformanceDriver driver) {
  // ---------------------------------------------------------------------------
  // Scenario 1: Phone/Watch GPS vs. Laptop LocationFinder
  // ---------------------------------------------------------------------------
  driver.defineTest(
    'Scenario 1: selects Location when widget is available and GPS is enabled',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'Location',
        meta: const <String, Object?>{
          'args': <String, Object?>{'latLong': true, 'zoom': true},
        },
        textBuilder: (getArg) => 'Location: ${getArg("latLong")}',
      );
      tester.registerPrimitive(
        'LocationFinder',
        meta: const <String, Object?>{
          'args': <String, Object?>{'initialQuery': true},
        },
        textBuilder: (getArg) => 'LocationFinder: ${getArg("initialQuery")}',
      );

      await tester.mount(
        '''
        import core;
        import Location;
        import LocationFinder;

        widget root = switch and(a: hasWidget(name: "Location"), b: media.hasGps) {
          true: Location(latLong: "37.7749,-122.4194", zoom: 15),
          default: LocationFinder(initialQuery: "San Francisco"),
        };
        ''',
        media: const MediaContext(
          width: WindowSizeClass.compact,
          capabilities: <String>{'gps'},
        ),
      );

      expect(tester.hasText('Location: 37.7749,-122.4194'), isTrue);
      expect(tester.hasText('LocationFinder: San Francisco'), isFalse);
    },
  );

  driver.defineTest(
    'Scenario 1: falls back to LocationFinder when GPS is disabled and reacts to change',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'Location',
        meta: const <String, Object?>{
          'args': <String, Object?>{'latLong': true, 'zoom': true},
        },
        textBuilder: (getArg) => 'Location: ${getArg("latLong")}',
      );
      tester.registerPrimitive(
        'LocationFinder',
        meta: const <String, Object?>{
          'args': <String, Object?>{'initialQuery': true},
        },
        textBuilder: (getArg) => 'LocationFinder: ${getArg("initialQuery")}',
      );

      await tester.mount(
        '''
        import core;
        import Location;
        import LocationFinder;

        widget root = switch and(a: hasWidget(name: "Location"), b: media.hasGps) {
          true: Location(latLong: "37.7749,-122.4194", zoom: 15),
          default: LocationFinder(initialQuery: "San Francisco"),
        };
        ''',
        media: const MediaContext(
          width: WindowSizeClass.compact,
          capabilities: <String>{},
        ),
      );

      // GPS is disabled -> LocationFinder
      expect(tester.hasText('LocationFinder: San Francisco'), isTrue);
      expect(tester.hasText('Location: 37.7749,-122.4194'), isFalse);

      // Now toggle GPS on reactively -> switches to Location in place
      await tester.remedia(const MediaContext(
        width: WindowSizeClass.compact,
        capabilities: <String>{'gps'},
      ));
      expect(tester.hasText('Location: 37.7749,-122.4194'), isTrue);
      expect(tester.hasText('LocationFinder: San Francisco'), isFalse);
    },
  );

  driver.defineTest(
    'Scenario 1: constant-folds and prunes Location when widget is missing, even with GPS',
    (CraftTester tester) async {
      // Notice: Location is NOT registered!
      tester.registerPrimitive(
        'LocationFinder',
        meta: const <String, Object?>{
          'args': <String, Object?>{'initialQuery': true},
        },
        textBuilder: (getArg) => 'LocationFinder: ${getArg("initialQuery")}',
      );

      // and(false, media.hasGps) should fold to false at template load time,
      // excising the unregistered Location widget call completely.
      await tester.mount(
        '''
        import core;
        import LocationFinder;

        widget root = switch and(a: hasWidget(name: "Location"), b: media.hasGps) {
          true: Location(latLong: "37.7749,-122.4194", zoom: 15),
          default: LocationFinder(initialQuery: "San Francisco"),
        };
        ''',
        media: const MediaContext(
          width: WindowSizeClass.compact,
          capabilities: <String>{'gps'},
        ),
      );

      expect(tester.hasText('LocationFinder: San Francisco'), isTrue);
    },
  );

  // ---------------------------------------------------------------------------
  // Scenario 2: Apple Pay vs. Google Pay vs. Standard Credit Card
  // ---------------------------------------------------------------------------
  driver.defineTest(
    'Scenario 2: selects ApplePay on iOS and excises GooglePay',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'ApplePay',
        meta: const <String, Object?>{
          'args': <String, Object?>{'total': true, 'currency': true},
        },
        textBuilder: (getArg) =>
            'ApplePay: \$${getArg("total")} ${getArg("currency")}',
      );
      tester.registerPrimitive(
        'CreditCardForm',
        meta: const <String, Object?>{
          'args': <String, Object?>{'amount': true},
        },
        textBuilder: (getArg) => 'CreditCardForm: \$${getArg("amount")}',
      );

      // GooglePay is NOT registered on iOS
      await tester.mount(
        '''
        import core;
        import ApplePay;
        import CreditCardForm;

        widget root = switch and(a: hasWidget(name: "ApplePay"), b: equals(a: media.platform, b: "ios")) {
          true: ApplePay(total: 100, currency: "USD"),
          default: switch and(a: hasWidget(name: "GooglePay"), b: equals(a: media.platform, b: "android")) {
            true: GooglePay(total: 100, currency: "USD"),
            default: CreditCardForm(amount: 100),
          },
        };
        ''',
        media: const MediaContext(
          width: WindowSizeClass.compact,
          platform: HostPlatform.ios,
        ),
      );

      expect(tester.hasText('ApplePay: \$100 USD'), isTrue);
      expect(tester.hasText('CreditCardForm: \$100'), isFalse);
    },
  );

  driver.defineTest(
    'Scenario 2: selects GooglePay on Android and excises ApplePay',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'GooglePay',
        meta: const <String, Object?>{
          'args': <String, Object?>{'total': true, 'currency': true},
        },
        textBuilder: (getArg) =>
            'GooglePay: \$${getArg("total")} ${getArg("currency")}',
      );
      tester.registerPrimitive(
        'CreditCardForm',
        meta: const <String, Object?>{
          'args': <String, Object?>{'amount': true},
        },
        textBuilder: (getArg) => 'CreditCardForm: \$${getArg("amount")}',
      );

      // ApplePay is NOT registered on Android
      await tester.mount(
        '''
        import core;
        import GooglePay;
        import CreditCardForm;

        widget root = switch and(a: hasWidget(name: "ApplePay"), b: equals(a: media.platform, b: "ios")) {
          true: ApplePay(total: 100, currency: "USD"),
          default: switch and(a: hasWidget(name: "GooglePay"), b: equals(a: media.platform, b: "android")) {
            true: GooglePay(total: 100, currency: "USD"),
            default: CreditCardForm(amount: 100),
          },
        };
        ''',
        media: const MediaContext(
          width: WindowSizeClass.compact,
          platform: HostPlatform.android,
        ),
      );

      expect(tester.hasText('GooglePay: \$100 USD'), isTrue);
      expect(tester.hasText('CreditCardForm: \$100'), isFalse);
    },
  );

  driver.defineTest(
    'Scenario 2: falls back to CreditCardForm on Web when native pay primitives are absent',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'CreditCardForm',
        meta: const <String, Object?>{
          'args': <String, Object?>{'amount': true},
        },
        textBuilder: (getArg) => 'CreditCardForm: \$${getArg("amount")}',
      );

      // Neither ApplePay nor GooglePay registered
      await tester.mount(
        '''
        import core;
        import CreditCardForm;

        widget root = switch and(a: hasWidget(name: "ApplePay"), b: equals(a: media.platform, b: "ios")) {
          true: ApplePay(total: 100, currency: "USD"),
          default: switch and(a: hasWidget(name: "GooglePay"), b: equals(a: media.platform, b: "android")) {
            true: GooglePay(total: 100, currency: "USD"),
            default: CreditCardForm(amount: 100),
          },
        };
        ''',
        media: const MediaContext(
          width: WindowSizeClass.compact,
          platform: HostPlatform.web,
        ),
      );

      expect(tester.hasText('CreditCardForm: \$100'), isTrue);
    },
  );

  // ---------------------------------------------------------------------------
  // Scenario 3: Direct Symbol Member Access (Location.args.latLong)
  // ---------------------------------------------------------------------------
  driver.defineTest(
    'Scenario 3: selects latLong branch when symbol metadata declares it',
    (CraftTester tester) async {
      // Client v2 metadata: supports latLong
      tester.registerPrimitive(
        'Location',
        meta: const <String, Object?>{
          'args': <String, Object?>{'latLong': true, 'address': true},
        },
        textBuilder: (getArg) {
          final Object? latLong = getArg('latLong');
          if (latLong != null) return 'Location: $latLong';
          return 'Location: ${getArg("address")}';
        },
      );

      await tester.mount(
        '''
        import core;
        import Location;

        widget root = switch Location.args.latLong {
          true: Location(latLong: "37.7749,-122.4194"),
          default: Location(address: "1 Market St"),
        };
        ''',
      );

      expect(tester.hasText('Location: 37.7749,-122.4194'), isTrue);
      expect(tester.hasText('Location: 1 Market St'), isFalse);
    },
  );

  driver.defineTest(
    'Scenario 3: constant-folds to address fallback when latLong metadata is absent',
    (CraftTester tester) async {
      // Older client metadata: only knows address
      tester.registerPrimitive(
        'Location',
        meta: const <String, Object?>{
          'args': <String, Object?>{'address': true},
        },
        textBuilder: (getArg) => 'Location: ${getArg("address")}',
      );

      await tester.mount(
        '''
        import core;
        import Location;

        widget root = switch Location.args.latLong {
          true: Location(latLong: "37.7749,-122.4194"),
          default: Location(address: "1 Market St"),
        };
        ''',
      );

      expect(tester.hasText('Location: 1 Market St'), isTrue);
      expect(tester.hasText('Location: 37.7749,-122.4194'), isFalse);
    },
  );

  // ---------------------------------------------------------------------------
  // Scenario 4: Evolving Pure Functions
  // ---------------------------------------------------------------------------
  driver.defineTest(
    'Scenario 4: constant-folds to fallback string concat when formatCurrency is missing',
    (CraftTester tester) async {
      // formatCurrency is NOT registered
      await tester.mount(
        r'''
        import core;

        widget root = switch hasFunction(name: "formatCurrency") {
          true: Text(text: formatCurrency(value: 42, currency: "USD")),
          default: Text(text: concat(a: "$", b: 42)),
        };
        ''',
      );

      expect(tester.hasText(r'$42'), isTrue);
    },
  );

  driver.defineTest(
    'Scenario 4: calls formatCurrency when registered on host',
    (CraftTester tester) async {
      tester.registerFunctions(
        LocalFunctionLibrary(<String, LocalFunction>{
          'formatCurrency': LocalFunction(
            arguments: const <String, FunctionArgType>{
              'value': FunctionArgType.number,
              'currency': FunctionArgType.string,
            },
            implementation: (DynamicMap arguments) {
              final num? value = arguments['value'] as num?;
              final String? currency = arguments['currency'] as String?;
              if (value == null || currency == null) return null;
              return '$currency ${value.toStringAsFixed(2)}';
            },
          ),
        }),
      );

      await tester.mount(
        '''
        import core;

        widget root = switch hasFunction(name: "formatCurrency") {
          true: Text(text: formatCurrency(value: 42, currency: "USD")),
          default: Text(text: concat(a: "\$", b: 42)),
        };
        ''',
      );

      expect(tester.hasText('USD 42.00'), isTrue);
      expect(tester.hasText(r'$42'), isFalse);
    },
  );

  // ---------------------------------------------------------------------------
  // Scenario 5: Engine Introspection (media.engine)
  // ---------------------------------------------------------------------------
  driver.defineTest(
    'Scenario 5: reports canonical engine name via media.engine',
    (CraftTester tester) async {
      await tester.mount(
        '''
        import core;

        widget root = Text(text: concat(a: "engine:", b: media.engine));
        ''',
      );

      expect(tester.hasText('engine:${tester.engine.id}'), isTrue);
    },
  );

  // ---------------------------------------------------------------------------
  // Scenario 6: Unified Argument Detection (hasArg)
  // ---------------------------------------------------------------------------
  driver.defineTest(
    'Scenario 6: selects branch when widget argument is supported via hasArg',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'Location',
        meta: const <String, Object?>{
          'args': <String, Object?>{'latLong': true},
        },
        textBuilder: (getArg) => 'Location: ${getArg("latLong")}',
      );

      await tester.mount(
        '''
        import core;
        import Location;

        widget root = switch hasArg(widget: "Location", arg: "latLong") {
          true: Location(latLong: "37.7749,-122.4194"),
          default: Text(text: "fallback-no-arg"),
        };
        ''',
      );

      expect(tester.hasText('Location: 37.7749,-122.4194'), isTrue);
      expect(tester.hasText('fallback-no-arg'), isFalse);
    },
  );

  driver.defineTest(
    'Scenario 6: selects fallback when widget argument is absent via hasArg',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'Location',
        meta: const <String, Object?>{
          'args': <String, Object?>{'address': true},
        },
        textBuilder: (getArg) => 'Location: ${getArg("address")}',
      );

      await tester.mount(
        '''
        import core;
        import Location;

        widget root = switch hasArg(widget: "Location", arg: "latLong") {
          true: Location(address: "invalid"),
          default: Text(text: "fallback-no-arg"),
        };
        ''',
      );

      expect(tester.hasText('fallback-no-arg'), isTrue);
    },
  );

  driver.defineTest(
    'Scenario 6: inspects function argument via hasArg',
    (CraftTester tester) async {
      await tester.mount(
        '''
        import core;

        widget root = switch hasArg(function: "add", arg: "a") {
          true: Text(text: "has-add-a"),
          default: Text(text: "no-add-a"),
        };
        ''',
      );

      expect(tester.hasText('has-add-a'), isTrue);
      expect(tester.hasText('no-add-a'), isFalse);
    },
  );

  driver.defineTest(
    'Scenario 6: inspects unified symbol name via hasArg(name: ...)',
    (CraftTester tester) async {
      tester.registerPrimitive(
        'Location',
        meta: const <String, Object?>{
          'args': <String, Object?>{'latLong': true},
        },
        textBuilder: (getArg) => 'Location: ${getArg("latLong")}',
      );

      await tester.mount(
        '''
        import core;
        import Location;

        widget root = Column(children: [
          Text(text: switch hasArg(name: "Location", arg: "latLong") {
            true: "widget-arg-found",
            default: "widget-arg-missing",
          }),
          Text(text: switch hasArg(name: "add", arg: "a") {
            true: "function-arg-found",
            default: "function-arg-missing",
          }),
          Text(text: switch hasArg(name: "add", arg: "nonExistent") {
            true: "unexpected",
            default: "function-arg-absent",
          }),
        ]);
        ''',
      );

      expect(tester.hasText('widget-arg-found'), isTrue);
      expect(tester.hasText('function-arg-found'), isTrue);
      expect(tester.hasText('function-arg-absent'), isTrue);
    },
  );
}
