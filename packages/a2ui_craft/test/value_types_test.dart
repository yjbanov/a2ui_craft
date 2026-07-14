// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

void main() {
  group('Dimension.decode', () {
    test('a bare number is a fixed dimension', () {
      expect(Dimension.decode(100), const Dimension.fixed(100));
      expect(Dimension.decode(12.5), const Dimension.fixed(12.5));
    });

    test('keyword strings decode to their variants', () {
      expect(Dimension.decode('hug'), const Dimension.hug());
      expect(Dimension.decode('fill'), const Dimension.fill());
      expect(Dimension.decode('flex'), const Dimension.flex());
      expect(Dimension.decode('flex(3)'), const Dimension.flex(3));
    });

    test('keyword parsing is case- and space-insensitive', () {
      expect(Dimension.decode('  FILL '), const Dimension.fill());
      expect(Dimension.decode('Flex( 2 )'), const Dimension.flex(2));
    });

    test('a numeric string decodes to fixed', () {
      expect(Dimension.decode('100'), const Dimension.fixed(100));
    });

    test('absent or unrecognized values fall back to hug by default', () {
      expect(Dimension.decode(null), const Dimension.hug());
      expect(Dimension.decode(true), const Dimension.hug());
      expect(Dimension.decode('nonsense'), const Dimension.hug());
      expect(Dimension.decode('flex(0)'), const Dimension.hug());
    });

    test('the fallback is configurable', () {
      expect(
        Dimension.decode(null, fallback: const Dimension.fill()),
        const Dimension.fill(),
      );
    });

    test('variants compare by value', () {
      expect(const Dimension.fixed(10), const Dimension.fixed(10));
      expect(const Dimension.fixed(10) == const Dimension.fixed(11), isFalse);
      expect(const Dimension.flex(2) == const Dimension.flex(1), isFalse);
    });
  });

  group('FlexAxis.parse', () {
    test('parses canonical names', () {
      expect(FlexAxis.parse('horizontal'), FlexAxis.horizontal);
      expect(FlexAxis.parse('vertical'), FlexAxis.vertical);
    });

    test('defaults to vertical (a Column) when absent/unknown', () {
      expect(FlexAxis.parse(null), FlexAxis.vertical);
      expect(FlexAxis.parse('sideways'), FlexAxis.vertical);
    });
  });

  group('MainAxisAlign.parse', () {
    test('parses each canonical name', () {
      expect(MainAxisAlign.parse('start'), MainAxisAlign.start);
      expect(MainAxisAlign.parse('center'), MainAxisAlign.center);
      expect(MainAxisAlign.parse('end'), MainAxisAlign.end);
      expect(MainAxisAlign.parse('spaceBetween'), MainAxisAlign.spaceBetween);
      expect(MainAxisAlign.parse('spaceAround'), MainAxisAlign.spaceAround);
      expect(MainAxisAlign.parse('spaceEvenly'), MainAxisAlign.spaceEvenly);
    });

    test('defaults to start', () {
      expect(MainAxisAlign.parse(null), MainAxisAlign.start);
      expect(MainAxisAlign.parse('bogus'), MainAxisAlign.start);
    });
  });

  group('CrossAxisAlign.parse', () {
    test('parses each canonical name', () {
      expect(CrossAxisAlign.parse('start'), CrossAxisAlign.start);
      expect(CrossAxisAlign.parse('center'), CrossAxisAlign.center);
      expect(CrossAxisAlign.parse('end'), CrossAxisAlign.end);
      expect(CrossAxisAlign.parse('stretch'), CrossAxisAlign.stretch);
    });

    test('defaults to start', () {
      expect(CrossAxisAlign.parse(null), CrossAxisAlign.start);
      expect(CrossAxisAlign.parse('bogus'), CrossAxisAlign.start);
    });

    test('honors an explicit fallback', () {
      expect(CrossAxisAlign.parse(null, fallback: CrossAxisAlign.stretch),
          CrossAxisAlign.stretch);
    });
  });

  group('Insets.decode', () {
    test('a bare number is the same offset on all sides', () {
      expect(Insets.decode(8), const Insets.all(8));
      expect(Insets.decode(2.5), const Insets(2.5, 2.5, 2.5, 2.5));
    });

    test('a 2-element array is [vertical, horizontal]', () {
      // vertical=10 → top/bottom; horizontal=20 → left/right.
      final Insets i = Insets.decode(<Object?>[10, 20]);
      expect(i.top, 10);
      expect(i.bottom, 10);
      expect(i.left, 20);
      expect(i.right, 20);
    });

    test('a 4-element array is [top, right, bottom, left] (CSS order)', () {
      // Deliberately asymmetric so a side-swap would be caught.
      final Insets i = Insets.decode(<Object?>[1, 2, 3, 4]);
      expect(i.top, 1);
      expect(i.right, 2);
      expect(i.bottom, 3);
      expect(i.left, 4);
    });

    test('accepts int or double elements', () {
      expect(
          Insets.decode(<Object?>[1, 2.5, 3, 4]), const Insets(1, 2.5, 3, 4));
    });

    test('unrecognized shapes decode to zero', () {
      expect(Insets.decode(null), Insets.zero);
      expect(Insets.decode('8'), Insets.zero); // strings are not insets
      expect(Insets.decode(<Object?>[1, 2, 3]), Insets.zero); // wrong length
      expect(Insets.decode(<Object?>[1, 'x', 3, 4]), Insets.zero); // non-num
    });

    test('named constructors and isZero', () {
      expect(const Insets.all(0).isZero, isTrue);
      expect(Insets.zero.isZero, isTrue);
      expect(const Insets.all(1).isZero, isFalse);
      expect(const Insets.symmetric(vertical: 5, horizontal: 9),
          const Insets(5, 9, 5, 9));
      // fromLTRB(left, top, right, bottom) maps to (top, right, bottom, left).
      expect(const Insets.fromLTRB(4, 1, 2, 3), const Insets(1, 2, 3, 4));
    });
  });

  group('Rgba.decode', () {
    test('a 6-digit hex string is opaque', () {
      final Rgba? c = Rgba.decode('#102030');
      expect(c, isNotNull);
      expect(c!.value, 0xFF102030);
      expect(c.alpha, 0xFF);
      expect(c.red, 0x10);
      expect(c.green, 0x20);
      expect(c.blue, 0x30);
    });

    test('an 8-digit hex string carries its alpha', () {
      expect(Rgba.decode('#80aabbcc')!.value, 0x80AABBCC);
    });

    test('parsing is case-insensitive and trims whitespace', () {
      expect(Rgba.decode('  #AaBbCc ')!.value, 0xFFAABBCC);
    });

    test('invalid inputs decode to null', () {
      expect(Rgba.decode('102030'), isNull); // missing '#'
      expect(Rgba.decode('#12345'), isNull); // wrong length
      expect(Rgba.decode('#GG0000'), isNull); // non-hex
      expect(Rgba.decode(0xFF102030), isNull); // not a string
      expect(Rgba.decode(null), isNull);
    });

    test('toCssString renders channels and 0–1 alpha', () {
      expect(const Rgba(0xFF102030).toCssString(), 'rgba(16, 32, 48, 1.0)');
      expect(const Rgba(0x00000000).toCssString(), 'rgba(0, 0, 0, 0.0)');
    });
  });

  group('CornerRadius.decode', () {
    test('a non-negative number is a radius in px', () {
      expect(CornerRadius.decode(8), const CornerRadius(8));
      expect(CornerRadius.decode(8.5), const CornerRadius(8.5));
      expect(CornerRadius.decode(0), CornerRadius.none);
      expect(CornerRadius.decode(0).isSharp, isTrue);
      expect(CornerRadius.decode(9999).isSharp, isFalse);
    });

    test('anything else is total: falls back (default sharp)', () {
      expect(CornerRadius.decode(null), CornerRadius.none);
      expect(CornerRadius.decode(-4), CornerRadius.none);
      expect(CornerRadius.decode(double.nan), CornerRadius.none);
      expect(CornerRadius.decode(double.infinity), CornerRadius.none);
      // A per-corner form is reserved, not misread.
      expect(CornerRadius.decode(<Object>[4, 4, 0, 0]), CornerRadius.none);
      expect(CornerRadius.decode('8'), CornerRadius.none);
      expect(CornerRadius.decode(null, fallback: const CornerRadius(8)),
          const CornerRadius(8));
    });
  });

  group('BorderSpec.decode', () {
    test('a positive number is a role-inked stroke of that width', () {
      expect(BorderSpec.decode(1), const BorderSpec(width: 1));
      expect(BorderSpec.decode(2.5), const BorderSpec(width: 2.5));
      expect(BorderSpec.decode(1).color, isNull); // inks the mapped role
      expect(BorderSpec.decode(1).isNone, isFalse);
    });

    test('a {width, color} map is an explicit stroke', () {
      final BorderSpec b =
          BorderSpec.decode(<String, Object?>{'width': 2, 'color': '#FF0000'});
      expect(b.width, 2);
      expect(b.color, const Rgba(0xFFFF0000));
      // Missing/invalid color leaves it role-inked.
      expect(BorderSpec.decode(<String, Object?>{'width': 2}).color, isNull);
    });

    test('zero, false, and malformed collapse to none; true keeps the default',
        () {
      expect(BorderSpec.decode(0), BorderSpec.none);
      expect(BorderSpec.decode(-1), BorderSpec.none);
      expect(BorderSpec.decode(false), BorderSpec.none);
      expect(BorderSpec.decode(<String, Object?>{'width': 0}), BorderSpec.none);
      expect(BorderSpec.none.isNone, isTrue);
      // Absent falls back; `true` means "keep the fallback".
      expect(BorderSpec.decode(null, fallback: const BorderSpec(width: 1)),
          const BorderSpec(width: 1));
      expect(BorderSpec.decode(true, fallback: const BorderSpec(width: 1)),
          const BorderSpec(width: 1));
    });
  });

  group('Elevation.decode / shadowForElevation', () {
    test('a non-negative number is a depth; anything else falls back', () {
      expect(Elevation.decode(2), const Elevation(2));
      expect(Elevation.decode(0), Elevation.none);
      expect(Elevation.decode(0).isFlat, isTrue);
      expect(Elevation.decode(-1), Elevation.none);
      expect(Elevation.decode(double.nan), Elevation.none);
      expect(Elevation.decode(null, fallback: const Elevation(2)),
          const Elevation(2));
    });

    test('flat casts no shadow; a depth scales offset=dp, blur=2*dp', () {
      expect(shadowForElevation(0), isEmpty);
      expect(const Elevation(0).shadows, isEmpty);
      final List<ShadowSpec> s = shadowForElevation(2);
      expect(s, hasLength(1));
      expect(s.single.offsetY, 2);
      expect(s.single.blur, 4);
      expect(s.single.spread, 0);
      expect(s.single.color, const Rgba(0x33000000)); // 20% black
    });
  });

  group('TextVariant.parse', () {
    test('parses canonical names; defaults to body', () {
      expect(TextVariant.parse('caption'), TextVariant.caption);
      expect(TextVariant.parse('body'), TextVariant.body);
      expect(TextVariant.parse(null), TextVariant.body);
      expect(TextVariant.parse('bogus'), TextVariant.body);
    });
  });

  group('ImageFit.parse', () {
    test('parses each name; defaults to fill', () {
      expect(ImageFit.parse('contain'), ImageFit.contain);
      expect(ImageFit.parse('cover'), ImageFit.cover);
      expect(ImageFit.parse('fill'), ImageFit.fill);
      expect(ImageFit.parse('none'), ImageFit.none);
      expect(ImageFit.parse('scaleDown'), ImageFit.scaleDown);
      expect(ImageFit.parse(null), ImageFit.fill);
      expect(ImageFit.parse('bogus'), ImageFit.fill);
    });
  });

  group('ImageVariant', () {
    test('parses each name; defaults to mediumFeature', () {
      expect(ImageVariant.parse('icon'), ImageVariant.icon);
      expect(ImageVariant.parse('avatar'), ImageVariant.avatar);
      expect(ImageVariant.parse('header'), ImageVariant.header);
      expect(ImageVariant.parse(null), ImageVariant.mediumFeature);
      expect(ImageVariant.parse('bogus'), ImageVariant.mediumFeature);
    });

    test('canonical sizes: fixed variants are square; header fills width', () {
      expect(ImageVariant.icon.width, 24);
      expect(ImageVariant.icon.height, 24);
      expect(ImageVariant.avatar.width, 48);
      expect(ImageVariant.avatar.circular, isTrue);
      expect(ImageVariant.largeFeature.width, 280);
      expect(ImageVariant.header.width, isNull); // fills available width
      expect(ImageVariant.header.height, 200);
      expect(ImageVariant.mediumFeature.circular, isFalse);
    });
  });
}
