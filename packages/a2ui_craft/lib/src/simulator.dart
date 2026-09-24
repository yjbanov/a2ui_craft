// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'media_context.dart';

/// A simulated generation or release of a client application host.
///
/// Used by [A2uiCraftSimulator] to model client version skew (e.g. mobile app
/// users who have not updated their application from an app store). Each profile
/// specifies the client application SemVer string [appVersion], human-readable
/// [label] and [description], and the static [metadata] dictionary associated
/// with host-registered symbols.
class ClientProfile {
  /// Creates a [ClientProfile].
  const ClientProfile({
    required this.id,
    required this.label,
    required this.appVersion,
    this.description = '',
    this.metadata = const <String, Map<String, Object?>>{},
  });

  /// The unique machine-readable identifier for this profile (e.g. `'v0'`).
  final String id;

  /// A short human-readable label suitable for display in navigation controls.
  final String label;

  /// The SemVer version string reported to templates via `appVersion()`.
  final String appVersion;

  /// An explanation of what capabilities or primitives this client generation
  /// supports or lacks.
  final String description;

  /// Static metadata attached to host symbols for this client generation.
  ///
  /// Passed to the specialization compiler during template load time to fold
  /// symbol queries (e.g. `Scanner.capabilities.qr`) and prune unsupported
  /// branches ahead of render.
  final Map<String, Map<String, Object?>> metadata;

  /// An ancient client installation (e.g. a user who has not updated their app
  /// in two years).
  ///
  /// The `Scanner` primitive is absent from the host, requiring templates to
  /// fall back to pure-template manual entry polyfills.
  static const ClientProfile v0Ancient = ClientProfile(
    id: 'v0',
    label: 'v0 (Ancient)',
    appVersion: '1.0.0',
    description:
        'Ancient client installation. The Scanner primitive is absent from the host.',
    metadata: <String, Map<String, Object?>>{},
  );

  /// A legacy client installation (e.g. a user running a previous release).
  ///
  /// The `Scanner` primitive is present with version `1`, supporting 1D barcode
  /// scanning only (`capabilities.qr` is false).
  static const ClientProfile v1Legacy = ClientProfile(
    id: 'v1',
    label: 'v1 (Legacy)',
    appVersion: '1.5.0',
    description:
        'Previous release. Scanner primitive supports 1D barcode scanning only.',
    metadata: <String, Map<String, Object?>>{
      'Scanner': <String, Object?>{
        'version': 1,
        'capabilities': <String, Object?>{
          'barcode': true,
          'qr': false,
        },
        'args': <String, Object?>{
          'mode': true,
          'onDetected': true,
        },
      },
    },
  );

  /// The modern client installation (latest App Store release).
  ///
  /// The `Scanner` primitive is present with version `2`, supporting full 2D
  /// QR code streaming (`capabilities.qr` is true).
  static const ClientProfile v2Modern = ClientProfile(
    id: 'v2',
    label: 'v2 (Modern)',
    appVersion: '2.0.0',
    description:
        'Latest app release. Scanner primitive supports 2D QR camera scanning.',
    metadata: <String, Map<String, Object?>>{
      'Scanner': <String, Object?>{
        'version': 2,
        'capabilities': <String, Object?>{
          'barcode': true,
          'qr': true,
        },
        'args': <String, Object?>{
          'mode': true,
          'onDetected': true,
        },
      },
    },
  );

  /// The standard set of simulated client profiles.
  static const List<ClientProfile> standardProfiles = <ClientProfile>[
    v0Ancient,
    v1Legacy,
    v2Modern,
  ];

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientProfile &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          label == other.label &&
          appVersion == other.appVersion;

  @override
  int get hashCode => Object.hash(id, label, appVersion);

  @override
  String toString() => 'ClientProfile($id, $label, v$appVersion)';
}

/// Simulated theme brightness mode for the host environment.
enum SimulatorThemeMode {
  /// Follows the host system dark/light preference.
  system('system'),

  /// Explicitly forces light theme mode.
  light('light'),

  /// Explicitly forces dark theme mode.
  dark('dark');

  const SimulatorThemeMode(this.id);

  /// Canonical string identifier for this theme mode.
  final String id;

  /// Resolves whether dark mode is active given the host ambient [systemDark] setting.
  bool isDark(bool systemDark) => switch (this) {
        SimulatorThemeMode.system => systemDark,
        SimulatorThemeMode.light => false,
        SimulatorThemeMode.dark => true,
      };
}

/// An interactive controller managing an ambient environment simulation session.
///
/// Models both dynamic ambient context ([MediaContext]) and static client
/// version skew ([ClientProfile]). Used by developer tools, previews, and
/// example galleries to simulate how templates adapt across device form factors,
/// platforms, hardware sensors, and client app generations.
class A2uiCraftSimulator {
  /// Creates an [A2uiCraftSimulator] with the given initial state.
  A2uiCraftSimulator({
    ClientProfile clientProfile = ClientProfile.v2Modern,
    MediaContext media = const MediaContext(
      width: WindowSizeClass.compact,
      capabilities: <String>{'gps', 'camera', 'biometrics'},
    ),
    SimulatorThemeMode themeMode = SimulatorThemeMode.system,
  })  : _clientProfile = clientProfile,
        _media = media,
        _themeMode = themeMode;

  ClientProfile _clientProfile;
  MediaContext _media;
  SimulatorThemeMode _themeMode;
  bool _disposed = false;

  final List<void Function()> _listeners = <void Function()>[];

  /// The active simulated client generation.
  ClientProfile get clientProfile => _clientProfile;

  /// The active ambient responsive and device context.
  MediaContext get media => _media;

  /// The active simulated theme brightness preference.
  SimulatorThemeMode get themeMode => _themeMode;

  /// The SemVer string of the active client profile, exposed to templates via `appVersion()`.
  String get appVersion => _clientProfile.appVersion;

  /// The static symbol metadata dictionary associated with the active client profile.
  Map<String, Map<String, Object?>> get widgetMetadata =>
      _clientProfile.metadata;

  /// Resolves whether dark mode is currently active given the host ambient [systemDark] setting.
  bool isDark(bool systemDark) => _themeMode.isDark(systemDark);

  /// Registers a [listener] callback invoked whenever simulation state changes.
  void addListener(void Function() listener) {
    if (_disposed) return;
    _listeners.add(listener);
  }

  /// Removes a previously registered [listener].
  void removeListener(void Function() listener) {
    _listeners.remove(listener);
  }

  void _notifyListeners() {
    if (_disposed) return;
    for (final void Function() listener
        in List<void Function()>.from(_listeners)) {
      listener();
    }
  }

  /// Sets the active [clientProfile] and notifies listeners.
  void setClientProfile(ClientProfile profile) {
    if (_clientProfile == profile) return;
    _clientProfile = profile;
    _notifyListeners();
  }

  /// Sets the active ambient [media] context and notifies listeners.
  void setMedia(MediaContext media) {
    if (_media == media) return;
    _media = media;
    _notifyListeners();
  }

  /// Updates the simulated host operating system [platform].
  void setPlatform(HostPlatform platform) {
    setMedia(_media.copyWith(platform: platform));
  }

  /// Updates the simulated device [formFactor].
  void setFormFactor(DeviceFormFactor formFactor) {
    setMedia(_media.copyWith(formFactor: formFactor));
  }

  /// Updates the simulated window width and optional height size classes.
  void setWindowSizeClass(WindowSizeClass width, [WindowHeightClass? height]) {
    setMedia(_media.copyWith(width: width, height: height));
  }

  /// Updates the simulated user reduced-motion preference.
  void setReducedMotion(bool reduced) {
    setMedia(_media.copyWith(reducedMotion: reduced));
  }

  /// Updates the simulated rendering engine.
  void setEngine(RenderEngine? engine) {
    setMedia(_media.copyWith(engine: engine));
  }

  /// Enables or disables a hardware sensor or modality [capability].
  void setCapability(String capability, bool enabled) {
    final Set<String> updated = Set<String>.from(_media.capabilities);
    if (enabled) {
      updated.add(capability);
    } else {
      updated.remove(capability);
    }
    setMedia(_media.copyWith(capabilities: updated));
  }

  /// Toggles presence of the given hardware sensor or modality [capability].
  void toggleCapability(String capability) {
    setCapability(capability, !_media.capabilities.contains(capability));
  }

  /// Replaces the entire set of hardware [capabilities].
  void setCapabilities(Set<String> capabilities) {
    setMedia(_media.copyWith(capabilities: capabilities));
  }

  /// Updates the simulated theme brightness [mode].
  void setThemeMode(SimulatorThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    _notifyListeners();
  }

  /// Resets all simulated properties back to default settings.
  void reset() {
    _clientProfile = ClientProfile.v2Modern;
    _media = const MediaContext(
      width: WindowSizeClass.compact,
      capabilities: <String>{'gps', 'camera', 'biometrics'},
    );
    _themeMode = SimulatorThemeMode.system;
    _notifyListeners();
  }

  /// Discards resources and clears all listeners.
  void dispose() {
    _disposed = true;
    _listeners.clear();
  }
}
