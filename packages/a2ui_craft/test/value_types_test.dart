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

    test('defaults to center', () {
      expect(CrossAxisAlign.parse(null), CrossAxisAlign.center);
      expect(CrossAxisAlign.parse('bogus'), CrossAxisAlign.center);
    });
  });
}
