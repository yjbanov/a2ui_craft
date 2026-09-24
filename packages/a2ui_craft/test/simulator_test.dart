// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

void main() {
  group('ClientProfile', () {
    test('defines canonical profiles with correct versions and metadata', () {
      expect(ClientProfile.v0Ancient.id, 'v0');
      expect(ClientProfile.v0Ancient.appVersion, '1.0.0');
      expect(ClientProfile.v0Ancient.metadata, isEmpty);

      expect(ClientProfile.v1Legacy.id, 'v1');
      expect(ClientProfile.v1Legacy.appVersion, '1.5.0');
      expect(ClientProfile.v1Legacy.metadata['Scanner']?['version'], 1);
      final Map<Object?, Object?> v1Caps = ClientProfile.v1Legacy
          .metadata['Scanner']?['capabilities'] as Map<Object?, Object?>;
      expect(v1Caps['qr'], isFalse);
      expect(v1Caps['barcode'], isTrue);

      expect(ClientProfile.v2Modern.id, 'v2');
      expect(ClientProfile.v2Modern.appVersion, '2.0.0');
      expect(ClientProfile.v2Modern.metadata['Scanner']?['version'], 2);
      final Map<Object?, Object?> v2Caps = ClientProfile.v2Modern
          .metadata['Scanner']?['capabilities'] as Map<Object?, Object?>;
      expect(v2Caps['qr'], isTrue);
      expect(v2Caps['barcode'], isTrue);

      expect(ClientProfile.standardProfiles, hasLength(3));
    });

    test('implements value equality', () {
      const ClientProfile custom = ClientProfile(
        id: 'v2',
        label: 'v2 (Modern)',
        appVersion: '2.0.0',
      );
      expect(custom, equals(ClientProfile.v2Modern));
      expect(custom.hashCode, equals(ClientProfile.v2Modern.hashCode));
    });
  });

  group('SimulatorThemeMode', () {
    test('resolves isDark against ambient systemDark', () {
      expect(SimulatorThemeMode.system.isDark(true), isTrue);
      expect(SimulatorThemeMode.system.isDark(false), isFalse);

      expect(SimulatorThemeMode.light.isDark(true), isFalse);
      expect(SimulatorThemeMode.light.isDark(false), isFalse);

      expect(SimulatorThemeMode.dark.isDark(true), isTrue);
      expect(SimulatorThemeMode.dark.isDark(false), isTrue);
    });
  });

  group('A2uiCraftSimulator', () {
    test('initializes with modern defaults', () {
      final A2uiCraftSimulator simulator = A2uiCraftSimulator();
      expect(simulator.clientProfile, ClientProfile.v2Modern);
      expect(simulator.appVersion, '2.0.0');
      expect(simulator.widgetMetadata, isNotEmpty);
      expect(simulator.themeMode, SimulatorThemeMode.system);
      expect(simulator.media.width, WindowSizeClass.compact);
      expect(simulator.media.capabilities, contains('gps'));
      expect(simulator.media.capabilities, contains('camera'));
      expect(simulator.media.capabilities, contains('biometrics'));
    });

    test('notifies listeners when client profile changes', () {
      final A2uiCraftSimulator simulator = A2uiCraftSimulator();
      int notifications = 0;
      simulator.addListener(() => notifications++);

      simulator.setClientProfile(ClientProfile.v0Ancient);
      expect(notifications, 1);
      expect(simulator.clientProfile, ClientProfile.v0Ancient);
      expect(simulator.appVersion, '1.0.0');
      expect(simulator.widgetMetadata, isEmpty);

      // No-op does not notify
      simulator.setClientProfile(ClientProfile.v0Ancient);
      expect(notifications, 1);
    });

    test('notifies listeners when media properties change', () {
      final A2uiCraftSimulator simulator = A2uiCraftSimulator();
      int notifications = 0;
      simulator.addListener(() => notifications++);

      simulator.setPlatform(HostPlatform.ios);
      expect(notifications, 1);
      expect(simulator.media.platform, HostPlatform.ios);

      simulator.setFormFactor(DeviceFormFactor.desktop);
      expect(notifications, 2);
      expect(simulator.media.formFactor, DeviceFormFactor.desktop);

      simulator.setWindowSizeClass(WindowSizeClass.expanded);
      expect(notifications, 3);
      expect(simulator.media.width, WindowSizeClass.expanded);

      simulator.setReducedMotion(true);
      expect(notifications, 4);
      expect(simulator.media.reducedMotion, isTrue);

      simulator.setEngine(RenderEngine.jaspr);
      expect(notifications, 5);
      expect(simulator.media.engine, RenderEngine.jaspr);
    });

    test('toggles and modifies hardware capabilities', () {
      final A2uiCraftSimulator simulator = A2uiCraftSimulator();
      int notifications = 0;
      simulator.addListener(() => notifications++);

      expect(simulator.media.capabilities, isNot(contains('nfc')));
      simulator.toggleCapability('nfc');
      expect(notifications, 1);
      expect(simulator.media.capabilities, contains('nfc'));

      simulator.setCapability('nfc', false);
      expect(notifications, 2);
      expect(simulator.media.capabilities, isNot(contains('nfc')));

      simulator.setCapabilities(<String>{'customSensor'});
      expect(notifications, 3);
      expect(simulator.media.capabilities, equals(<String>{'customSensor'}));
    });

    test('updates theme mode and resolves isDark', () {
      final A2uiCraftSimulator simulator = A2uiCraftSimulator();
      int notifications = 0;
      simulator.addListener(() => notifications++);

      simulator.setThemeMode(SimulatorThemeMode.dark);
      expect(notifications, 1);
      expect(simulator.themeMode, SimulatorThemeMode.dark);
      expect(simulator.isDark(false), isTrue);

      simulator.setThemeMode(SimulatorThemeMode.light);
      expect(notifications, 2);
      expect(simulator.isDark(true), isFalse);
    });

    test('reset restores default settings', () {
      final A2uiCraftSimulator simulator = A2uiCraftSimulator();
      simulator.setClientProfile(ClientProfile.v0Ancient);
      simulator.setThemeMode(SimulatorThemeMode.dark);
      simulator.setPlatform(HostPlatform.android);

      int notifications = 0;
      simulator.addListener(() => notifications++);

      simulator.reset();
      expect(notifications, 1);
      expect(simulator.clientProfile, ClientProfile.v2Modern);
      expect(simulator.themeMode, SimulatorThemeMode.system);
    });

    test('dispose removes all listeners and stops notifications', () {
      final A2uiCraftSimulator simulator = A2uiCraftSimulator();
      int notifications = 0;
      simulator.addListener(() => notifications++);

      simulator.dispose();
      simulator.setClientProfile(ClientProfile.v0Ancient);
      expect(notifications, 0);
    });
  });
}
