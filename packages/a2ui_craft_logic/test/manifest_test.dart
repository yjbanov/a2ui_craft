// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

void main() {
  group('reading the slot', () {
    test('a project with no logic declares none', () {
      expect(
        LogicManifest.parse('{"name": "Greeting"}'),
        isNull,
        reason: 'a pure-UI project is the ordinary case, not an error',
      );
    });

    test('a worker driver names a script relative to the bundle', () {
      final LogicManifest logic = LogicManifest.parse('''
        {
          "name": "Cart",
          "logic": {"kind": "worker", "entry": "cart.js", "capabilities": []}
        }
      ''')!;
      expect(logic.kind, DriverKind.worker);
      expect(logic.entry, 'cart.js');
      expect(
        logic.entryUrl('https://cdn.example/cart'),
        'https://cdn.example/cart/cart.js',
      );
      expect(
        logic.entryUrl('https://cdn.example/cart/'),
        'https://cdn.example/cart/cart.js',
      );
    });

    test("a builtin driver's entry is a registry key, not a path", () {
      final LogicManifest logic = LogicManifest.parse(
        '{"logic": {"kind": "builtin", "entry": "cart"}}',
      )!;
      expect(logic.kind, DriverKind.builtin);
      expect(logic.entry, 'cart');
    });
  });

  group('a declared-but-unreadable slot refuses, loudly', () {
    // The rest of the project manifest parses totally — a malformed theme
    // block leaves a project unthemed. This slot cannot work that way: a
    // mini-app loaded with its logic quietly missing is a screen of controls
    // that answer nothing.

    test('a kind this version does not know', () {
      expect(
        () => LogicManifest.parse('{"logic": {"kind": "wasm", "entry": "a"}}'),
        throwsA(isA<MalformedLogicManifest>().having(
          (MalformedLogicManifest e) => e.message,
          'message',
          contains('Unknown driver kind'),
        )),
      );
    });

    test('a missing entry', () {
      expect(
        () => LogicManifest.parse('{"logic": {"kind": "worker"}}'),
        throwsA(isA<MalformedLogicManifest>()),
      );
    });

    test('an empty entry', () {
      expect(
        () => LogicManifest.parse('{"logic": {"kind": "worker", "entry": ""}}'),
        throwsA(isA<MalformedLogicManifest>()),
      );
    });

    test('a slot that is not an object', () {
      expect(
        () => LogicManifest.parse('{"logic": "cart.js"}'),
        throwsA(isA<MalformedLogicManifest>()),
      );
    });

    test('malformed JSON', () {
      expect(
        () => LogicManifest.parse('{not json'),
        throwsA(isA<MalformedLogicManifest>()),
      );
    });

    test('a capability this version cannot grant', () {
      // Running a project with less power than it says it needs is the same
      // failure as running it with none: it will not work, and it will not say
      // so.
      expect(
        () => LogicManifest.parse(
          '{"logic": {"kind": "worker", "entry": "a.js", '
          '"capabilities": ["fetch"]}}',
        ),
        throwsA(isA<MalformedLogicManifest>().having(
          (MalformedLogicManifest e) => e.message,
          'message',
          contains('fetch'),
        )),
      );
    });
  });

  group('host support', () {
    test('a kind the host runs is accepted', () {
      LogicManifest.parse('{"logic": {"kind": "worker", "entry": "a.js"}}')!
          .requireSupported(<DriverKind>{DriverKind.worker});
    });

    test('a kind the host cannot run refuses, and says what it can', () {
      expect(
        () => LogicManifest.parse(
          '{"logic": {"kind": "webview", "entry": "a.js"}}',
        )!
            .requireSupported(<DriverKind>{DriverKind.worker}),
        throwsA(isA<UnsupportedDriverKind>().having(
          (UnsupportedDriverKind e) => e.toString(),
          'message',
          allOf(contains('webview'), contains('worker')),
        )),
      );
    });
  });

  group('the shipped cart declares itself readably', () {
    test('its manifest parses and asks for a worker', () {
      // Pinned here rather than only in the examples package, because this is
      // the parser the failure would fall out of.
      const String manifest = '''
        {
          "name": "Cart",
          "logic": {"kind": "worker", "entry": "cart.js", "capabilities": []}
        }
      ''';
      final LogicManifest logic = LogicManifest.parse(manifest)!;
      expect(logic.kind, DriverKind.worker);
      expect(logic.capabilities, isEmpty);
    });
  });
}
