// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

ResolvedTokens _resolve(Object? document) =>
    resolveDesignTokens(<DesignTokenSet>[parseDesignTokens(document)]);

void main() {
  group('parseDesignTokens', () {
    test('a token is an object with a \$value; groups nest into dot paths', () {
      final DesignTokenSet set = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          'base': <String, Object?>{
            'blue': <String, Object?>{r'$type': 'color', r'$value': '#0066CC'},
          },
        },
      });
      expect(set.tokens, contains('color.base.blue'));
      expect(set.tokens['color.base.blue']!.type, 'color');
      expect(set.tokens['color.base.blue']!.value, '#0066CC');
    });

    test(r'$type is inherited from the nearest ancestor group', () {
      final DesignTokenSet set = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'primary': <String, Object?>{r'$value': '#0066CC'},
          'sizes': <String, Object?>{
            r'$type': 'dimension',
            'border': <String, Object?>{r'$value': '1px'},
          },
        },
      });
      expect(set.tokens['color.primary']!.type, 'color');
      expect(set.tokens['color.sizes.border']!.type, 'dimension');
    });

    test(r"a token's own $type wins over the group's", () {
      final DesignTokenSet set = parseDesignTokens(<String, Object?>{
        'misc': <String, Object?>{
          r'$type': 'color',
          'scale': <String, Object?>{r'$type': 'number', r'$value': 1.5},
        },
      });
      expect(set.tokens['misc.scale']!.type, 'number');
    });

    test('a token with no type anywhere parses with a null type', () {
      final DesignTokenSet set = parseDesignTokens(<String, Object?>{
        'mystery': <String, Object?>{r'$value': 42},
      });
      expect(set.tokens['mystery']!.type, isNull);
    });

    test('names with reserved characters are dropped, siblings survive', () {
      final DesignTokenSet set = parseDesignTokens(<String, Object?>{
        'bad{name': <String, Object?>{r'$value': 1},
        'bad.name': <String, Object?>{r'$value': 2},
        'good': <String, Object?>{r'$type': 'number', r'$value': 3},
      });
      expect(set.tokens.keys, <String>['good']);
    });

    test('malformed documents parse to the empty set', () {
      expect(parseDesignTokens(null).tokens, isEmpty);
      expect(parseDesignTokens('not a map').tokens, isEmpty);
      expect(parseDesignTokens(<Object?>[1, 2]).tokens, isEmpty);
    });
  });

  group('alias resolution', () {
    test('a semantic token aliases a primitive', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'base': <String, Object?>{
            'blue': <String, Object?>{r'$value': '#0066CC'},
          },
          'action': <String, Object?>{r'$value': '{color.base.blue}'},
        },
      });
      expect(tokens.color('color.action'), Rgba.decode('#0066CC'));
    });

    test('aliases chain, and the alias inherits the target type', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'base': <String, Object?>{
          r'$type': 'color',
          'blue': <String, Object?>{r'$value': '#0066CC'},
        },
        'semantic': <String, Object?>{
          'action': <String, Object?>{r'$value': '{base.blue}'},
        },
        'component': <String, Object?>{
          'button': <String, Object?>{r'$value': '{semantic.action}'},
        },
      });
      expect(tokens.color('component.button'), Rgba.decode('#0066CC'));
    });

    test('a cyclic alias drops its tokens, not the document', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'a': <String, Object?>{r'$type': 'color', r'$value': '{b}'},
        'b': <String, Object?>{r'$type': 'color', r'$value': '{a}'},
        'ok': <String, Object?>{r'$type': 'color', r'$value': '#112233'},
      });
      expect(tokens.color('a'), isNull);
      expect(tokens.color('b'), isNull);
      expect(tokens.color('ok'), Rgba.decode('#112233'));
    });

    test('a dangling alias drops its token', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'a': <String, Object?>{r'$type': 'color', r'$value': '{no.such.token}'},
      });
      expect(tokens.color('a'), isNull);
      expect(tokens.raw('a'), isNull);
    });

    test(
      'an alias whose declared type disagrees with the target is dropped',
      () {
        final ResolvedTokens tokens = _resolve(<String, Object?>{
          'n': <String, Object?>{r'$type': 'number', r'$value': 4},
          'c': <String, Object?>{r'$type': 'color', r'$value': '{n}'},
        });
        expect(tokens.color('c'), isNull);
        expect(tokens.number('c'), isNull);
      },
    );
  });

  group('layer merge (mode overlays)', () {
    test('a later layer overrides token-by-token', () {
      final DesignTokenSet base = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'surface': <String, Object?>{r'$value': '#FFFFFF'},
          'action': <String, Object?>{r'$value': '#0066CC'},
        },
      });
      final DesignTokenSet dark = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'surface': <String, Object?>{r'$value': '#111111'},
        },
      });
      final ResolvedTokens tokens = resolveDesignTokens(<DesignTokenSet>[
        base,
        dark,
      ]);
      expect(tokens.color('color.surface'), Rgba.decode('#111111'));
      expect(tokens.color('color.action'), Rgba.decode('#0066CC'));
    });

    test(
        'aliases resolve after the merge: an overlay that overrides a '
        'primitive re-points the base layer\'s semantic aliases', () {
      final DesignTokenSet base = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'base': <String, Object?>{
            'bg': <String, Object?>{r'$value': '#FFFFFF'},
          },
          'surface': <String, Object?>{r'$value': '{color.base.bg}'},
        },
      });
      final DesignTokenSet dark = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'base': <String, Object?>{
            'bg': <String, Object?>{r'$value': '#111111'},
          },
        },
      });
      final ResolvedTokens tokens = resolveDesignTokens(<DesignTokenSet>[
        base,
        dark,
      ]);
      expect(tokens.color('color.surface'), Rgba.decode('#111111'));
    });
  });

  group('ResolvedTokens.color', () {
    test('legacy hex strings decode, including alpha', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'opaque': <String, Object?>{r'$type': 'color', r'$value': '#0066CC'},
        'translucent': <String, Object?>{
          r'$type': 'color',
          r'$value': '#800066CC',
        },
      });
      expect(tokens.color('opaque'), const Rgba(0xFF0066CC));
      expect(tokens.color('translucent'), const Rgba(0x800066CC));
    });

    test(
      'the 2025.10 sRGB object form decodes, alpha defaulting to opaque',
      () {
        final ResolvedTokens tokens = _resolve(<String, Object?>{
          'brand': <String, Object?>{
            r'$type': 'color',
            r'$value': <String, Object?>{
              'colorSpace': 'srgb',
              'components': <Object?>[0.0, 0.4, 0.8],
            },
          },
          'veil': <String, Object?>{
            r'$type': 'color',
            r'$value': <String, Object?>{
              'colorSpace': 'srgb',
              'components': <Object?>[1.0, 1.0, 1.0],
              'alpha': 0.5,
            },
          },
        });
        expect(tokens.color('brand'), const Rgba(0xFF0066CC));
        expect(tokens.color('veil'), const Rgba(0x80FFFFFF));
      },
    );

    test('a non-sRGB color space falls back to its hex member', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'wide': <String, Object?>{
          r'$type': 'color',
          r'$value': <String, Object?>{
            'colorSpace': 'display-p3',
            'components': <Object?>[0.0, 0.5, 1.0],
            'hex': '#0066CC',
          },
        },
      });
      expect(tokens.color('wide'), const Rgba(0xFF0066CC));
    });

    test('out-of-range sRGB components clamp to [0, 1]', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'hot': <String, Object?>{
          r'$type': 'color',
          r'$value': <String, Object?>{
            'colorSpace': 'srgb',
            'components': <Object?>[1.2, -0.1, 0.5],
          },
        },
      });
      expect(tokens.color('hot'), const Rgba(0xFFFF0080));
    });

    test('malformed colors and wrong-typed tokens read as null', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'notHex': <String, Object?>{r'$type': 'color', r'$value': 'red'},
        'shortList': <String, Object?>{
          r'$type': 'color',
          r'$value': <String, Object?>{
            'colorSpace': 'srgb',
            'components': <Object?>[0.5, 0.5],
          },
        },
        'aNumber': <String, Object?>{r'$type': 'number', r'$value': 7},
        'untyped': <String, Object?>{r'$value': '#0066CC'},
      });
      expect(tokens.color('notHex'), isNull);
      expect(tokens.color('shortList'), isNull);
      expect(tokens.color('aNumber'), isNull);
      expect(tokens.color('untyped'), isNull);
      expect(tokens.color('absent'), isNull);
    });
  });

  group('ResolvedTokens.dimension', () {
    test('object and legacy string forms, px and rem', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'a': <String, Object?>{
          r'$type': 'dimension',
          r'$value': <String, Object?>{'value': 12, 'unit': 'px'},
        },
        'b': <String, Object?>{
          r'$type': 'dimension',
          r'$value': <String, Object?>{'value': 1.5, 'unit': 'rem'},
        },
        'c': <String, Object?>{r'$type': 'dimension', r'$value': '16px'},
        'd': <String, Object?>{r'$type': 'dimension', r'$value': '2rem'},
      });
      expect(tokens.dimension('a'), 12.0);
      expect(tokens.dimension('b'), 24.0);
      expect(tokens.dimension('c'), 16.0);
      expect(tokens.dimension('d'), 32.0);
    });

    test('unknown units, bare numbers, and junk read as null', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'em': <String, Object?>{
          r'$type': 'dimension',
          r'$value': <String, Object?>{'value': 2, 'unit': 'em'},
        },
        'bare': <String, Object?>{r'$type': 'dimension', r'$value': 16},
        'junk': <String, Object?>{r'$type': 'dimension', r'$value': 'wide'},
      });
      expect(tokens.dimension('em'), isNull);
      expect(tokens.dimension('bare'), isNull);
      expect(tokens.dimension('junk'), isNull);
    });
  });

  group('ResolvedTokens.number', () {
    test('reads numbers strictly — no string coercion', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'n': <String, Object?>{r'$type': 'number', r'$value': 4},
        's': <String, Object?>{r'$type': 'number', r'$value': '4'},
      });
      expect(tokens.number('n'), 4.0);
      expect(tokens.number('s'), isNull);
    });
  });

  group('ResolvedTokens.raw', () {
    test('exposes resolved values of types without a typed getter', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'font': <String, Object?>{
          'sans': <String, Object?>{
            r'$type': 'fontFamily',
            r'$value': <Object?>['Inter', 'sans-serif'],
          },
          'brand': <String, Object?>{
            r'$type': 'fontFamily',
            r'$value': '{font.sans}',
          },
        },
      });
      expect(tokens.raw('font.brand'), <Object?>['Inter', 'sans-serif']);
    });
  });

  group('ResolvedTokens.toTemplateValues', () {
    test('re-encodes each type in its canonical template form, nested', () {
      final ResolvedTokens tokens = _resolve(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'base': <String, Object?>{
            'blue': <String, Object?>{r'$value': '#0066CC'},
          },
          'action': <String, Object?>{r'$value': '{color.base.blue}'},
        },
        'spacing': <String, Object?>{
          'gap': <String, Object?>{
            r'$type': 'dimension',
            r'$value': <String, Object?>{'value': 1.5, 'unit': 'rem'},
          },
        },
        'emphasis': <String, Object?>{r'$type': 'number', r'$value': 0.5},
        'font': <String, Object?>{
          'sans': <String, Object?>{r'$type': 'fontFamily', r'$value': 'Inter'},
        },
      });

      final Map<String, Object?> values = tokens.toTemplateValues();
      final Map<String, Object?> color =
          values['color']! as Map<String, Object?>;
      expect((color['base']! as Map<String, Object?>)['blue'], '#FF0066CC');
      expect(color['action'], '#FF0066CC'); // alias, canonicalized
      expect(
          (values['spacing']! as Map<String, Object?>)['gap'], 24.0); // rem→px
      expect(values['emphasis'], 0.5);
      // Types without a typed getter pass their resolved raw value through.
      expect((values['font']! as Map<String, Object?>)['sans'], 'Inter');
    });

    test('canonical color strings round-trip through Rgba.decode', () {
      expect(Rgba.decode(const Rgba(0x800066CC).toHexString()),
          const Rgba(0x800066CC));
    });
  });
}
