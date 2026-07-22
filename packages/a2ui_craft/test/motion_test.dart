// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

void main() {
  group('MotionEasing.decode', () {
    test('each canonical id decodes to its value', () {
      expect(MotionEasing.decode('linear'), MotionEasing.linear);
      expect(MotionEasing.decode('standard'), MotionEasing.standard);
      expect(MotionEasing.decode('emphasized'), MotionEasing.emphasized);
      expect(MotionEasing.decode('decelerate'), MotionEasing.decelerate);
      expect(MotionEasing.decode('accelerate'), MotionEasing.accelerate);
    });

    test('whitespace around the id is tolerated', () {
      expect(MotionEasing.decode('  standard '), MotionEasing.standard);
    });

    test('unknown / non-string / absent yields the fallback (standard)', () {
      expect(MotionEasing.decode('bogus'), MotionEasing.standard);
      expect(MotionEasing.decode(null), MotionEasing.standard);
      expect(MotionEasing.decode(42), MotionEasing.standard);
      expect(MotionEasing.decode(<String, Object?>{}), MotionEasing.standard);
    });

    test('an explicit fallback is honored', () {
      expect(MotionEasing.decode('bogus', fallback: MotionEasing.linear),
          MotionEasing.linear);
    });

    test('control points anchor the well-known curves', () {
      // linear is the identity ramp; standard is M3 standard.
      expect(
        <double>[
          MotionEasing.linear.x1,
          MotionEasing.linear.y1,
          MotionEasing.linear.x2,
          MotionEasing.linear.y2,
        ],
        <double>[0, 0, 1, 1],
      );
      expect(
        <double>[
          MotionEasing.standard.x1,
          MotionEasing.standard.y1,
          MotionEasing.standard.x2,
          MotionEasing.standard.y2,
        ],
        <double>[0.2, 0, 0, 1],
      );
    });
  });

  group('Motion.decode', () {
    test('false is explicitly off (none); true keeps the fallback', () {
      expect(Motion.decode(false), Motion.none);
      // Default fallback is none, so a bare `true` with no default is instant.
      expect(Motion.decode(true), Motion.none);
      // A caller (e.g. Box) passes the theme default as the fallback, and
      // `true` resolves to it.
      const Motion themeDefault = Motion(durationMs: 250);
      expect(Motion.decode(true, fallback: themeDefault), themeDefault);
    });

    test('a non-negative number is that many ms with standard easing', () {
      expect(Motion.decode(200),
          const Motion(durationMs: 200, easing: MotionEasing.standard));
      expect(Motion.decode(0), const Motion(durationMs: 0));
      expect(Motion.decode(199.6).durationMs, 200); // rounded
    });

    test('a map gives an explicit duration and easing', () {
      expect(
        Motion.decode(<String, Object?>{
          'duration': 400,
          'easing': 'decelerate',
        }),
        const Motion(durationMs: 400, easing: MotionEasing.decelerate),
      );
    });

    test('a map with a duration but no/bad easing falls back to standard', () {
      expect(
        Motion.decode(<String, Object?>{'duration': 120}),
        const Motion(durationMs: 120, easing: MotionEasing.standard),
      );
      expect(
        Motion.decode(<String, Object?>{'duration': 120, 'easing': 'bogus'}),
        const Motion(durationMs: 120, easing: MotionEasing.standard),
      );
    });

    test('garbage / absent / malformed yields the fallback', () {
      expect(Motion.decode(null), Motion.none);
      expect(Motion.decode('animate'), Motion.none);
      expect(
          Motion.decode(<String, Object?>{'easing': 'standard'}), Motion.none);
      expect(Motion.decode(<Object?>[200]), Motion.none);
    });

    test('the fallback is used for malformed input', () {
      const Motion themeDefault = Motion(durationMs: 250);
      expect(Motion.decode('garbage', fallback: themeDefault), themeDefault);
    });

    // Test-the-test: totality's whole point is that a bad value can NEVER be
    // read as a silent non-zero animation. If any of these ever animates, the
    // decoder has grown an unsound coercion.
    test('a bad value never becomes a non-zero duration', () {
      expect(Motion.decode('garbage').isInstant, isTrue);
      expect(Motion.decode(null).isInstant, isTrue);
      expect(Motion.decode(-5).isInstant, isTrue); // negative → fallback (none)
      expect(Motion.decode(double.nan).isInstant, isTrue);
      expect(Motion.decode(double.infinity).isInstant, isTrue);
      expect(
        Motion.decode(<String, Object?>{'duration': -1}).isInstant,
        isTrue,
      );
    });
  });

  group('Motion', () {
    test('none and a zero duration are instant; a positive duration is not',
        () {
      expect(Motion.none.isInstant, isTrue);
      expect(const Motion(durationMs: 0).isInstant, isTrue);
      expect(const Motion(durationMs: -1).isInstant, isTrue);
      expect(const Motion(durationMs: 200).isInstant, isFalse);
    });

    test('value equality and hashCode cover duration and easing', () {
      expect(
        const Motion(durationMs: 200, easing: MotionEasing.standard),
        const Motion(durationMs: 200),
      );
      expect(
        const Motion(durationMs: 200, easing: MotionEasing.standard).hashCode,
        const Motion(durationMs: 200).hashCode,
      );
      expect(
        const Motion(durationMs: 200),
        isNot(const Motion(durationMs: 200, easing: MotionEasing.decelerate)),
      );
      expect(
        const Motion(durationMs: 200),
        isNot(const Motion(durationMs: 300)),
      );
    });

    test('toString names the duration and the easing id', () {
      expect(
        const Motion(durationMs: 250, easing: MotionEasing.decelerate)
            .toString(),
        'Motion(durationMs: 250, easing: decelerate)',
      );
    });

    test('the default easing is standard', () {
      expect(const Motion(durationMs: 1).easing, MotionEasing.standard);
    });
  });
}
