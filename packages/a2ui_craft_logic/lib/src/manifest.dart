// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// Where a project's driver runs.
///
/// A host advertises the kinds it can actually run; anything else refuses to
/// load. See [LogicManifest.requireSupported].
enum DriverKind {
  /// A web worker, from a script the bundle ships. The portable default: no
  /// DOM, no host objects, cheap to start, and the same script runs on every
  /// web host.
  worker('worker'),

  /// An iframe, for logic that needs origin isolation or its own network
  /// identity.
  iframe('iframe'),

  /// A webview over a platform channel — native hosts running JavaScript logic.
  webview('webview'),

  /// A driver that never ships to the client at all, reached over a socket.
  remote('remote'),

  /// A driver compiled into the host, resolved from its own registry by
  /// [LogicManifest.entry]. Build-time-vetted apps only: nothing about it is
  /// ephemeral.
  builtin('builtin');

  const DriverKind(this.id);

  /// The name used in a manifest.
  final String id;

  /// The kind named [id], or null if it is not one this version knows.
  static DriverKind? byId(String id) {
    for (final DriverKind kind in DriverKind.values) {
      if (kind.id == id) return kind;
    }
    return null;
  }
}

/// A host cannot run the driver a project declares.
///
/// Thrown rather than tolerated, and this is the point: a mini-app without its
/// logic is not a degraded app, it is a lie shaped like an app — every wired
/// control disabled, nothing ever responding. Refusal with a reason beats inert
/// chrome.
final class UnsupportedDriverKind implements Exception {
  /// Reports that [kind] is not among [supported].
  const UnsupportedDriverKind(this.kind, this.supported);

  /// What the project asked for.
  final DriverKind kind;

  /// What the host can actually run.
  final Set<DriverKind> supported;

  @override
  String toString() => 'UnsupportedDriverKind: this project needs a '
      "'${kind.id}' driver, which this host cannot run "
      '(it supports: ${(supported.map((DriverKind k) => k.id).toList()..sort()).join(', ')}).';
}

/// A project's `logic` manifest slot is present but malformed.
final class MalformedLogicManifest implements Exception {
  /// Reports why the slot could not be read.
  const MalformedLogicManifest(this.message);

  /// What was wrong.
  final String message;

  @override
  String toString() => 'MalformedLogicManifest: $message';
}

/// The `logic` block of a project's `manifest.json`.
///
/// Parsing is deliberately **not** total, unlike the rest of the manifest. An
/// absent slot is fine — that is an ordinary pure-UI project. A slot that is
/// present but unreadable is a failure, because the alternative is loading a
/// mini-app with its logic quietly missing. Totality is for untrusted
/// agent-supplied data; a project's own declaration about itself gets to be
/// wrong out loud.
final class LogicManifest {
  /// Declares a driver of [kind] at [entry].
  const LogicManifest({
    required this.kind,
    required this.entry,
    this.capabilities = const <String>[],
  });

  /// Reads the `logic` slot of a decoded `manifest.json`.
  ///
  /// Returns null when the project declares none. Throws
  /// [MalformedLogicManifest] when it declares one that cannot be read —
  /// including a `kind` this version does not know, which is how a project
  /// built against a newer host fails loudly here rather than silently there.
  static LogicManifest? read(Map<String, Object?> manifest) {
    final Object? slot = manifest['logic'];
    if (slot == null) return null;
    if (slot is! Map) {
      throw const MalformedLogicManifest("'logic' must be an object.");
    }
    final Object? rawKind = slot['kind'];
    if (rawKind is! String) {
      throw const MalformedLogicManifest("'logic' needs a string 'kind'.");
    }
    final DriverKind? kind = DriverKind.byId(rawKind);
    if (kind == null) {
      throw MalformedLogicManifest(
        "Unknown driver kind '$rawKind'. This version knows: "
        '${DriverKind.values.map((DriverKind k) => k.id).join(', ')}.',
      );
    }
    final Object? entry = slot['entry'];
    if (entry is! String || entry.isEmpty) {
      throw const MalformedLogicManifest(
        "'logic' needs a non-empty 'entry' — the script to run, or the "
        'registry key of a built-in driver.',
      );
    }
    final Object? capabilities = slot['capabilities'];
    if (capabilities != null && capabilities is! List) {
      throw const MalformedLogicManifest(
        "'capabilities' must be a list.",
      );
    }
    final List<String> requested = <String>[
      for (final Object? c in (capabilities as List<Object?>?) ?? const [])
        c.toString(),
    ];
    if (requested.isNotEmpty) {
      // Nothing is grantable yet, and granting nothing while a project asks for
      // something would run it with less power than it says it needs.
      throw MalformedLogicManifest(
        'This version grants no capabilities, but the project requests: '
        '${requested.join(', ')}.',
      );
    }
    return LogicManifest(kind: kind, entry: entry);
  }

  /// Reads the `logic` slot from `manifest.json` source.
  static LogicManifest? parse(String manifestJson) {
    final Object? decoded;
    try {
      decoded = jsonDecode(manifestJson);
    } on FormatException catch (error) {
      throw MalformedLogicManifest('manifest.json is not valid JSON: $error');
    }
    if (decoded is! Map<String, Object?>) return null;
    return read(decoded);
  }

  /// Where the driver runs.
  final DriverKind kind;

  /// The script to run, relative to the bundle's base URL — or, for
  /// [DriverKind.builtin], the key the host resolves in its own registry.
  final String entry;

  /// Capabilities the project requests. Always empty in this version.
  final List<String> capabilities;

  /// Resolves [entry] against a bundle's [baseUrl].
  ///
  /// Meaningless for [DriverKind.builtin], whose entry is a registry key rather
  /// than a path.
  String entryUrl(String baseUrl) =>
      baseUrl.endsWith('/') ? '$baseUrl$entry' : '$baseUrl/$entry';

  /// Throws [UnsupportedDriverKind] unless this host can run [kind].
  void requireSupported(Set<DriverKind> supported) {
    if (supported.contains(kind)) return;
    throw UnsupportedDriverKind(kind, supported);
  }
}
