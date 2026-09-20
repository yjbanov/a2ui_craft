// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

void main() {
  group('createIntrospectionFunctions', () {
    final Map<String, LocalFunction> functions = createIntrospectionFunctions(
      hasWidget: (String name) => name == 'Text' || name == 'Button',
      hasFunction: (String name) => name == 'add' || name == 'subtract',
      hasFunctionArg: (String fn, String arg) =>
          fn == 'add' && (arg == 'a' || arg == 'b'),
      hasWidgetArg: (String widget, String arg) =>
          widget == 'Text' && arg == 'text',
      appVersion: '1.2.3',
      runtimeVersion: 1,
    );

    test('declares all standard introspection functions', () {
      expect(
        functions.keys,
        containsAll(<String>[
          'hasWidget',
          'hasWidgetArg',
          'hasFunction',
          'hasFunctionArg',
          'runtimeVersion',
          'appVersion',
        ]),
      );
    });

    test('hasWidget evaluates presence and is total', () {
      final LocalFunction fn = functions['hasWidget']!;
      expect(fn.arguments, hasLength(1));
      expect(fn.arguments['name'], FunctionArgType.string);

      expect(fn.implementation(<String, Object?>{'name': 'Text'}), isTrue);
      expect(fn.implementation(<String, Object?>{'name': 'Button'}), isTrue);
      expect(fn.implementation(<String, Object?>{'name': 'Unknown'}), isFalse);
      expect(fn.implementation(<String, Object?>{'name': 42}), isFalse);
      expect(fn.implementation(<String, Object?>{}), isFalse);
    });

    test('hasWidgetArg evaluates widget arguments and is total', () {
      final LocalFunction fn = functions['hasWidgetArg']!;
      expect(fn.arguments, hasLength(2));
      expect(fn.arguments['widget'], FunctionArgType.string);
      expect(fn.arguments['arg'], FunctionArgType.string);

      expect(
        fn.implementation(<String, Object?>{'widget': 'Text', 'arg': 'text'}),
        isTrue,
      );
      expect(
        fn.implementation(<String, Object?>{'widget': 'Text', 'arg': 'foo'}),
        isFalse,
      );
      expect(
        fn.implementation(<String, Object?>{'widget': 'Button', 'arg': 'text'}),
        isFalse,
      );
      expect(
        fn.implementation(<String, Object?>{'widget': 42, 'arg': 'text'}),
        isFalse,
      );
    });

    test('hasFunction evaluates function presence and is total', () {
      final LocalFunction fn = functions['hasFunction']!;
      expect(fn.arguments, hasLength(1));
      expect(fn.arguments['name'], FunctionArgType.string);

      expect(fn.implementation(<String, Object?>{'name': 'add'}), isTrue);
      expect(fn.implementation(<String, Object?>{'name': 'multiply'}), isFalse);
      expect(fn.implementation(<String, Object?>{'name': null}), isFalse);
    });

    test('hasFunctionArg evaluates function arguments and is total', () {
      final LocalFunction fn = functions['hasFunctionArg']!;
      expect(fn.arguments, hasLength(2));
      expect(fn.arguments['function'], FunctionArgType.string);
      expect(fn.arguments['arg'], FunctionArgType.string);

      expect(
        fn.implementation(<String, Object?>{'function': 'add', 'arg': 'a'}),
        isTrue,
      );
      expect(
        fn.implementation(<String, Object?>{'function': 'add', 'arg': 'c'}),
        isFalse,
      );
      expect(
        fn.implementation(<String, Object?>{'function': 'unknown', 'arg': 'a'}),
        isFalse,
      );
    });

    test('runtimeVersion returns the engine version number', () {
      final LocalFunction fn = functions['runtimeVersion']!;
      expect(fn.arguments, isEmpty);
      expect(fn.implementation(<String, Object?>{}), 1);
    });

    test('appVersion returns configured string or empty string default', () {
      final LocalFunction fn = functions['appVersion']!;
      expect(fn.arguments, isEmpty);
      expect(fn.implementation(<String, Object?>{}), '1.2.3');

      final Map<String, LocalFunction> defaultFns =
          createIntrospectionFunctions(
        hasWidget: (_) => false,
        hasFunction: (_) => false,
        hasFunctionArg: (_, __) => false,
      );
      expect(defaultFns['appVersion']!.implementation(<String, Object?>{}), '');
    });
  });
}
