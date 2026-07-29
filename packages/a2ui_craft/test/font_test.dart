// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

ResolvedTokens _resolve(Object? document) =>
    resolveDesignTokens(<DesignTokenSet>[parseDesignTokens(document)]);

/// A token document naming [family] for `type.body.family`.
Map<String, Object?> _bodyFamily(String family) => <String, Object?>{
      'type': <String, Object?>{
        'body': <String, Object?>{
          'family': <String, Object?>{r'$type': 'string', r'$value': family},
        },
      },
    };

void main() {
  group('FontRole.decode', () {
    test('each canonical id decodes to its value', () {
      expect(FontRole.decode('sans'), FontRole.sans);
      expect(FontRole.decode('serif'), FontRole.serif);
      expect(FontRole.decode('mono'), FontRole.mono);
    });

    test('whitespace around the id is tolerated', () {
      expect(FontRole.decode('  mono '), FontRole.mono);
    });

    test('unknown / non-string / absent yields the fallback (sans)', () {
      expect(FontRole.decode('bogus'), FontRole.sans);
      expect(FontRole.decode(null), FontRole.sans);
      expect(FontRole.decode(42), FontRole.sans);
      expect(FontRole.decode(<String, Object?>{}), FontRole.sans);
    });

    test('an explicit fallback is honored', () {
      expect(FontRole.decode('bogus', fallback: FontRole.mono), FontRole.mono);
    });

    test('a raw CSS family name is not a role — the vocabulary is closed', () {
      // The whole point of the closed set: naming a typeface directly is not a
      // thing a template can do, so it decodes to nothing rather than passing
      // an arbitrary family through to the host.
      expect(FontRole.tryDecode('Georgia'), isNull);
      expect(FontRole.tryDecode('sans-serif'), isNull);
      expect(FontRole.tryDecode('monospace'), isNull);
    });
  });

  group('FontRole.tryDecode', () {
    test('distinguishes an explicit sans from silence', () {
      expect(FontRole.tryDecode('sans'), FontRole.sans);
      expect(FontRole.tryDecode(null), isNull);
      expect(FontRole.tryDecode('bogus'), isNull);
    });
  });

  group('resolveFontFamily', () {
    test('reads the named-string token at the role path', () {
      final ResolvedTokens tokens = _resolve(_bodyFamily('serif'));
      expect(
        resolveFontFamily(ThemeRoles.bodyFamily, tokens),
        FontRole.serif,
      );
    });

    test('an unthemed surface resolves to null, not to a default', () {
      // The host-blend invariant (DESIGN.md §9.4): no theme means the adapters
      // emit no family at all, so the surface keeps the host's own font.
      expect(resolveFontFamily(ThemeRoles.bodyFamily, null), isNull);
      expect(
        resolveFontFamily(ThemeRoles.bodyFamily, _resolve(<String, Object?>{})),
        isNull,
      );
    });

    test('a theme that omits *this* role resolves to null', () {
      final ResolvedTokens tokens = _resolve(_bodyFamily('serif'));
      expect(resolveFontFamily(ThemeRoles.captionFamily, tokens), isNull);
    });

    test('an unknown family id falls back rather than reaching the host', () {
      final ResolvedTokens tokens = _resolve(_bodyFamily('Comic Sans MS'));
      expect(resolveFontFamily(ThemeRoles.bodyFamily, tokens), isNull);
      expect(
        resolveFontFamily(ThemeRoles.bodyFamily, tokens,
            fallback: FontRole.mono),
        FontRole.mono,
      );
    });

    test('a primitive fallback applies only when the theme is silent', () {
      // `Markdown` code spans pass mono this way: fixed-pitch even unthemed,
      // but a theme that names a code family still wins.
      expect(
        resolveFontFamily(ThemeRoles.codeFamily, null, fallback: FontRole.mono),
        FontRole.mono,
      );
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'type': <String, Object?>{
          'code': <String, Object?>{
            'family': <String, Object?>{r'$type': 'string', r'$value': 'serif'},
          },
        },
      });
      expect(
        resolveFontFamily(ThemeRoles.codeFamily, tokens,
            fallback: FontRole.mono),
        FontRole.serif,
      );
    });
  });

  group('CraftFonts', () {
    test('forRole answers every role', () {
      const CraftFonts f = CraftFonts.systemUi;
      expect(f.forRole(FontRole.sans), f.sans);
      expect(f.forRole(FontRole.serif), f.serif);
      expect(f.forRole(FontRole.mono), f.mono);
    });

    test('every default stack ends in a generic family', () {
      // The last entry is the only one guaranteed to resolve, so it must be a
      // generic the platform can always answer.
      const CraftFonts f = CraftFonts.systemUi;
      expect(f.sans.last, 'sans-serif');
      expect(f.serif.last, 'serif');
      expect(f.mono.last, 'monospace');
    });

    test('value equality is by stack contents', () {
      const CraftFonts a = CraftFonts(
        sans: <String>['A', 'sans-serif'],
        serif: <String>['B', 'serif'],
        mono: <String>['C', 'monospace'],
      );
      const CraftFonts b = CraftFonts(
        sans: <String>['A', 'sans-serif'],
        serif: <String>['B', 'serif'],
        mono: <String>['C', 'monospace'],
      );
      const CraftFonts c = CraftFonts(
        sans: <String>['A', 'sans-serif'],
        serif: <String>['B', 'serif'],
        mono: <String>['different', 'monospace'],
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.toString(), contains('sans-serif'));
    });
  });
}
