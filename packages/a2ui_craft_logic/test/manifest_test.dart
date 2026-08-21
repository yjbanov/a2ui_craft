// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

const HostLogicSupport _webHost = HostLogicSupport(
  languages: <DriverLanguage>{DriverLanguage.javascript},
);

void main() {
  group('reading the slot', () {
    test('a project with no logic declares none', () {
      expect(
        LogicManifest.parse('{"name": "Greeting"}'),
        isNull,
        reason: 'a pure-UI project is the ordinary case, not an error',
      );
    });

    test('bundled logic names a file and the language it is written in', () {
      final LogicManifest logic = LogicManifest.parse('''
        {
          "name": "Cart",
          "logic": {
            "entry": "cart.js",
            "language": "javascript",
            "capabilities": []
          }
        }
      ''')!;
      expect(logic.language, DriverLanguage.javascript);
      expect(logic.entry, 'cart.js');
      expect(logic.isRemote, isFalse);
      expect(
        logic.entryUrl('https://cdn.example/cart'),
        'https://cdn.example/cart/cart.js',
      );
      expect(
        logic.entryUrl('https://cdn.example/cart/'),
        'https://cdn.example/cart/cart.js',
      );
    });

    test('remote logic names an endpoint and no language', () {
      final LogicManifest logic = LogicManifest.parse(
        '{"logic": {"url": "wss://api.example/cart"}}',
      )!;
      expect(logic.isRemote, isTrue);
      expect(logic.url, 'wss://api.example/cart');
      expect(logic.language, isNull,
          reason: 'logic that never ships has no artifact to describe');
      expect(() => logic.entryUrl('https://cdn.example'), throwsStateError);
    });

    test('the manifest says nothing about where the driver runs', () {
      // The whole point of the reshape: the same bundle has to work on a page,
      // in a worker, in a webview, and inside an embedded engine. Which of
      // those a host picks is the host's business, so the project cannot name
      // it — there is no key here that could.
      final LogicManifest logic = LogicManifest.parse(
        '{"logic": {"entry": "cart.js", "language": "javascript"}}',
      )!;
      logic.requireSupported(_webHost);
      logic.requireSupported(const HostLogicSupport(
        languages: <DriverLanguage>{DriverLanguage.javascript},
        remote: true,
      ));
    });
  });

  group('a declared-but-unreadable slot refuses, loudly', () {
    // The rest of the project manifest parses totally — a malformed theme
    // block leaves a project unthemed. This slot cannot work that way: a
    // mini-app loaded with its logic quietly missing is a screen of controls
    // that answer nothing.

    test('a language this version does not know', () {
      expect(
        () => LogicManifest.parse(
          '{"logic": {"entry": "a.wasm", "language": "wasm"}}',
        ),
        throwsA(isA<MalformedLogicManifest>().having(
          (MalformedLogicManifest e) => e.message,
          'message',
          contains('Unknown driver language'),
        )),
      );
    });

    test('bundled logic with no language', () {
      expect(
        () => LogicManifest.parse('{"logic": {"entry": "a.js"}}'),
        throwsA(isA<MalformedLogicManifest>()),
      );
    });

    test('neither an entry nor a url', () {
      expect(
        () => LogicManifest.parse('{"logic": {"language": "javascript"}}'),
        throwsA(isA<MalformedLogicManifest>()),
      );
    });

    test('both an entry and a url', () {
      expect(
        () => LogicManifest.parse(
          '{"logic": {"entry": "a.js", "language": "javascript", '
          '"url": "wss://x"}}',
        ),
        throwsA(isA<MalformedLogicManifest>().having(
          (MalformedLogicManifest e) => e.message,
          'message',
          contains('not both'),
        )),
      );
    });

    test('an empty entry', () {
      expect(
        () => LogicManifest.parse(
          '{"logic": {"entry": "", "language": "javascript"}}',
        ),
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
          '{"logic": {"entry": "a.js", "language": "javascript", '
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
    test('a language the host runs is accepted', () {
      LogicManifest.parse(
        '{"logic": {"entry": "a.js", "language": "javascript"}}',
      )!
          .requireSupported(_webHost);
    });

    test('a host that runs no logic refuses, and says so', () {
      expect(
        () => LogicManifest.parse(
          '{"logic": {"entry": "a.js", "language": "javascript"}}',
        )!
            .requireSupported(HostLogicSupport.none),
        throwsA(isA<UnsupportedDriver>().having(
          (UnsupportedDriver e) => e.toString(),
          'message',
          allOf(contains('javascript'), contains('no logic at all')),
        )),
      );
    });

    test('a host that runs JavaScript still refuses a remote driver', () {
      // Connecting outward is a different capability from executing an
      // artifact, and a host may reasonably have one without the other.
      expect(
        () => LogicManifest.parse('{"logic": {"url": "wss://api.example"}}')!
            .requireSupported(_webHost),
        throwsA(isA<UnsupportedDriver>().having(
          (UnsupportedDriver e) => e.toString(),
          'message',
          contains('remote driver'),
        )),
      );
    });

    test('a host that allows remote drivers accepts one', () {
      LogicManifest.parse('{"logic": {"url": "wss://api.example"}}')!
          .requireSupported(const HostLogicSupport(remote: true));
    });
  });
}
