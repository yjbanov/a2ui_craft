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

  group('DeviceFormFactor.decode (total)', () {
    test('maps each id and falls back on unknown/absent', () {
      for (final DeviceFormFactor f in DeviceFormFactor.values) {
        expect(DeviceFormFactor.decode(f.id), f);
      }
      expect(DeviceFormFactor.decode(null), DeviceFormFactor.phone);
      expect(DeviceFormFactor.decode('foldable'), DeviceFormFactor.phone);
      expect(DeviceFormFactor.decode(42), DeviceFormFactor.phone);
      expect(
          DeviceFormFactor.decode('unknown',
              fallback: DeviceFormFactor.desktop),
          DeviceFormFactor.desktop);
    });
  });

  group('HostPlatform.decode (total)', () {
    test('maps each id and falls back on unknown/absent', () {
      for (final HostPlatform p in HostPlatform.values) {
        expect(HostPlatform.decode(p.id), p);
      }
      expect(HostPlatform.decode(null), HostPlatform.web);
      expect(HostPlatform.decode('fuchsia'), HostPlatform.web);
      expect(HostPlatform.decode(123), HostPlatform.web);
      expect(HostPlatform.decode('unknown', fallback: HostPlatform.ios),
          HostPlatform.ios);
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

    test('reducedMotion participates in equality and hashCode', () {
      const MediaContext motionOn =
          MediaContext(width: WindowSizeClass.compact);
      const MediaContext motionOff = MediaContext(
        width: WindowSizeClass.compact,
        reducedMotion: true,
      );
      expect(motionOn.reducedMotion, isFalse); // default when host is silent
      expect(motionOn, isNot(motionOff));
      expect(motionOn.hashCode, isNot(motionOff.hashCode));
    });

    test('formFactor and platform participate in equality and hashCode', () {
      const MediaContext defaultMedia =
          MediaContext(width: WindowSizeClass.compact);
      const MediaContext watchMedia = MediaContext(
        width: WindowSizeClass.compact,
        formFactor: DeviceFormFactor.watch,
      );
      const MediaContext iosMedia = MediaContext(
        width: WindowSizeClass.compact,
        platform: HostPlatform.ios,
      );
      expect(defaultMedia.formFactor, DeviceFormFactor.phone);
      expect(defaultMedia.platform, HostPlatform.web);
      expect(defaultMedia, isNot(watchMedia));
      expect(defaultMedia.hashCode, isNot(watchMedia.hashCode));
      expect(defaultMedia, isNot(iosMedia));
      expect(defaultMedia.hashCode, isNot(iosMedia.hashCode));
    });

    test('capabilities participate in equality and hashCode unordered', () {
      const MediaContext a = MediaContext(
        width: WindowSizeClass.compact,
        capabilities: <String>{'gps', 'camera'},
      );
      const MediaContext b = MediaContext(
        width: WindowSizeClass.compact,
        capabilities: <String>{'camera', 'gps'},
      );
      const MediaContext c = MediaContext(
        width: WindowSizeClass.compact,
        capabilities: <String>{'gps'},
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(c));
      expect(a.hashCode, isNot(c.hashCode));
    });
  });

  group('MediaContext.toContent (the media. scope)', () {
    test('exposes the class ids and the reducedMotion flag', () {
      const MediaContext media = MediaContext(
        width: WindowSizeClass.expanded,
        reducedMotion: true,
      );
      final DynamicContent content = media.toContent();
      expect(content.subscribe(<Object>['width'], (_) {}), 'expanded');
      expect(content.subscribe(<Object>['reducedMotion'], (_) {}), true);
    });

    test('defaults match specifications in the scope', () {
      final DynamicContent content =
          const MediaContext(width: WindowSizeClass.compact).toContent();
      expect(content.subscribe(<Object>['reducedMotion'], (_) {}), false);
      expect(content.subscribe(<Object>['formFactor'], (_) {}), 'phone');
      expect(content.subscribe(<Object>['platform'], (_) {}), 'web');
      expect(content.subscribe(<Object>['hasGps'], (_) {}), false);
      expect(content.subscribe(<Object>['hasCamera'], (_) {}), false);
      expect(content.subscribe(<Object>['hasBiometrics'], (_) {}), false);
      expect(content.subscribe(<Object>['hasNfc'], (_) {}), false);
      expect(
          content.subscribe(<Object>['capabilities', 'gps'], (_) {}), missing);
    });

    test('custom formFactor, platform, and capabilities are exposed in scope',
        () {
      const MediaContext media = MediaContext(
        width: WindowSizeClass.compact,
        formFactor: DeviceFormFactor.watch,
        platform: HostPlatform.ios,
        capabilities: <String>{'gps', 'nfc', 'customSensor'},
      );
      final DynamicContent content = media.toContent();
      expect(content.subscribe(<Object>['formFactor'], (_) {}), 'watch');
      expect(content.subscribe(<Object>['platform'], (_) {}), 'ios');
      expect(content.subscribe(<Object>['hasGps'], (_) {}), true);
      expect(content.subscribe(<Object>['hasNfc'], (_) {}), true);
      expect(content.subscribe(<Object>['hasCamera'], (_) {}), false);
      expect(content.subscribe(<Object>['hasBiometrics'], (_) {}), false);
      expect(content.subscribe(<Object>['capabilities', 'gps'], (_) {}), true);
      expect(content.subscribe(<Object>['capabilities', 'nfc'], (_) {}), true);
      expect(
          content.subscribe(<Object>['capabilities', 'customSensor'], (_) {}),
          true);
      expect(content.subscribe(<Object>['capabilities', 'camera'], (_) {}),
          missing);
    });
  });
}
