// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Bind-time argument-schema validation for template function calls (see
// DESIGN.md, the template-functions slice). The *values* computed by the
// functions are covered cross-adapter in the conformance suite; this file
// covers the debug-only validation, which surfaces per-framework (so it lives in
// each adapter's tests, not the shared behavioral conformance harness).
//
// `buildNode` binds eagerly, so the validation runs synchronously during the
// call and can be caught directly — no reliance on framework exception plumbing.

const LibraryName _core = LibraryName(<String>['core']);

void _noEvents(String name, DynamicMap arguments) {}

Runtime _runtime() => Runtime()
  ..update(_core, createCoreComponents())
  ..registerFunctions(createCoreFunctions());

/// Binds [composition] via `buildNode` and returns any exception it throws.
Future<Object?> _bindError(
    WidgetTester tester, ConstructorCall composition) async {
  Object? caught;
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Builder(builder: (BuildContext context) {
      try {
        return _runtime().buildNode(
            context, composition, DynamicContent(), _noEvents,
            scope: _core);
      } catch (error) {
        caught = error;
        return const SizedBox.shrink();
      }
    }),
  ));
  return caught;
}

/// Wraps a function call in a `Text` so it sits in a value position.
ConstructorCall _text(ConstructorCall call) =>
    ConstructorCall('Text', <String, Object?>{'text': call});

void main() {
  testWidgets('a wrong-typed literal argument is rejected at bind time',
      (WidgetTester tester) async {
    // `a` is a literal String where a number is required — an author mistake.
    final Object? error = await _bindError(
      tester,
      _text(ConstructorCall('add', <String, Object?>{'a': 'x', 'b': 3})),
    );
    expect(error, isA<RemoteFlutterWidgetsException>());
  });

  testWidgets('an unknown argument name is rejected at bind time',
      (WidgetTester tester) async {
    final Object? error = await _bindError(
      tester,
      _text(ConstructorCall('add', <String, Object?>{'a': 1, 'c': 3})),
    );
    expect(error, isA<RemoteFlutterWidgetsException>());
  });

  testWidgets('a missing required argument is rejected at bind time',
      (WidgetTester tester) async {
    final Object? error = await _bindError(
      tester,
      _text(ConstructorCall('add', <String, Object?>{'a': 1})),
    );
    expect(error, isA<RemoteFlutterWidgetsException>());
  });

  testWidgets('a bound (non-literal) argument is not type-checked at bind time',
      (WidgetTester tester) async {
    // The crux of the design: `data.foo` is a binding whose value is only known
    // at runtime and may be agent-controlled, so it is NOT rejected at bind
    // time even though at runtime it would resolve to a non-number. Totality
    // handles the runtime case; here we assert bind does not throw.
    final Object? error = await _bindError(
      tester,
      _text(ConstructorCall('add', <String, Object?>{
        'a': const DataReference(<Object>['foo']),
        'b': 3,
      })),
    );
    expect(error, isNull);
  });
}
