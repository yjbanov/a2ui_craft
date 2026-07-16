// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

// The media-context value type — the render-time responsive input
// (research/responsive/RESPONSIVE_DESIGN.md). The pixel→class quantization and
// the `Responsive` selection live here (the core), so every host and adapter
// agrees; these tests pin that shared vocabulary.

void main() {
  group('WindowSizeClass.forWidth (Material 3 breakpoints)', () {
    test('quantizes at the M3 boundaries', () {
      expect(WindowSizeClass.forWidth(0), WindowSizeClass.compact);
      expect(WindowSizeClass.forWidth(599), WindowSizeClass.compact);
      expect(WindowSizeClass.forWidth(600), WindowSizeClass.medium);
      expect(WindowSizeClass.forWidth(839), WindowSizeClass.medium);
      expect(WindowSizeClass.forWidth(840), WindowSizeClass.expanded);
      expect(WindowSizeClass.forWidth(1199), WindowSizeClass.expanded);
      expect(WindowSizeClass.forWidth(1200), WindowSizeClass.large);
      expect(WindowSizeClass.forWidth(1599), WindowSizeClass.large);
      expect(WindowSizeClass.forWidth(1600), WindowSizeClass.extraLarge);
      expect(WindowSizeClass.forWidth(4000), WindowSizeClass.extraLarge);
    });
  });

  group('WindowHeightClass.forHeight', () {
    test('quantizes at the M3 boundaries', () {
      expect(WindowHeightClass.forHeight(479), WindowHeightClass.compact);
      expect(WindowHeightClass.forHeight(480), WindowHeightClass.medium);
      expect(WindowHeightClass.forHeight(899), WindowHeightClass.medium);
      expect(WindowHeightClass.forHeight(900), WindowHeightClass.expanded);
    });
  });

  group('decode (total)', () {
    test('maps each id and falls back on the unknown/absent', () {
      for (final WindowSizeClass c in WindowSizeClass.values) {
        expect(WindowSizeClass.decode(c.id), c);
      }
      expect(WindowSizeClass.decode(null), WindowSizeClass.compact);
      expect(WindowSizeClass.decode('phablet'), WindowSizeClass.compact);
      expect(WindowSizeClass.decode(42), WindowSizeClass.compact);
      expect(WindowSizeClass.decode('x', fallback: WindowSizeClass.large),
          WindowSizeClass.large);
    });
  });

  group('atLeast', () {
    test('compares by ascending size', () {
      expect(WindowSizeClass.expanded.atLeast(WindowSizeClass.medium), isTrue);
      expect(WindowSizeClass.medium.atLeast(WindowSizeClass.medium), isTrue);
      expect(
          WindowSizeClass.compact.atLeast(WindowSizeClass.expanded), isFalse);
    });
  });

  group('resolveResponsive (mobile-first selection)', () {
    WindowSizeClass? pick(WindowSizeClass w, Set<WindowSizeClass> provided) =>
        WindowSizeClass.resolveResponsive(w, provided);

    test('empty set selects nothing', () {
      expect(pick(WindowSizeClass.expanded, <WindowSizeClass>{}), isNull);
    });

    test('picks the largest provided class at or below the width', () {
      const Set<WindowSizeClass> provided = <WindowSizeClass>{
        WindowSizeClass.compact,
        WindowSizeClass.expanded,
      };
      expect(pick(WindowSizeClass.compact, provided), WindowSizeClass.compact);
      // medium has no slot → nearest smaller (compact).
      expect(pick(WindowSizeClass.medium, provided), WindowSizeClass.compact);
      expect(
          pick(WindowSizeClass.expanded, provided), WindowSizeClass.expanded);
      // large/extraLarge → the largest provided (expanded).
      expect(pick(WindowSizeClass.large, provided), WindowSizeClass.expanded);
      expect(
          pick(WindowSizeClass.extraLarge, provided), WindowSizeClass.expanded);
    });

    test('falls back to the smallest provided when width is below all', () {
      const Set<WindowSizeClass> provided = <WindowSizeClass>{
        WindowSizeClass.medium,
        WindowSizeClass.large,
      };
      // compact is below every provided class → the smallest provided (medium).
      expect(pick(WindowSizeClass.compact, provided), WindowSizeClass.medium);
      expect(pick(WindowSizeClass.expanded, provided), WindowSizeClass.medium);
      expect(pick(WindowSizeClass.large, provided), WindowSizeClass.large);
    });
  });

  group('MediaContext value equality', () {
    test('equal fields are equal; a differing class is not', () {
      const MediaContext a = MediaContext(width: WindowSizeClass.expanded);
      const MediaContext b = MediaContext(width: WindowSizeClass.expanded);
      const MediaContext c = MediaContext(width: WindowSizeClass.compact);
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
    });
  });
}
