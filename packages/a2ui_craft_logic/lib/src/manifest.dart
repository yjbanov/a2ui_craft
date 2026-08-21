// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

/// The language a driver's shipped artifact is written in.
///
/// This is what a project declares, because it is a property of the artifact
/// the project ships. It is deliberately *not* where the driver runs: the same
/// JavaScript runs on a page, in an iframe, in a web worker, in a webview, or
/// in an embedded engine like QuickJS, and which of those a host picks is the
/// host's business.
enum DriverLanguage {
  /// JavaScript source, written against the driver SDK.
  javascript('javascript');

  const DriverLanguage(this.id);

  /// The name used in a manifest.
  final String id;

  /// The language named [id], or null if it is not one this version knows.
  static DriverLanguage? byId(String id) {
    for (final DriverLanguage language in DriverLanguage.values) {
      if (language.id == id) return language;
    }
    return null;
  }
}

/// What a host can do with a project's logic.
///
/// A host advertises this once and every project is checked against it. Note
/// what is *absent*: nothing here names a sandbox. Whether this host runs
/// JavaScript in a worker, an iframe, or an embedded engine is its own
/// decision, invisible to the projects it loads.
final class HostLogicSupport {
  /// Declares what this host can run.
  const HostLogicSupport({
    this.languages = const <DriverLanguage>{},
    this.remote = false,
  });

  /// A host that runs no logic at all — pure-UI projects only.
  static const HostLogicSupport none = HostLogicSupport();

  /// The languages this host can execute.
  final Set<DriverLanguage> languages;

  /// Whether this host can connect to a driver it does not run itself.
  final bool remote;

  /// A human-readable summary, for a refusal message.
  String describe() {
    final List<String> parts = <String>[
      for (final DriverLanguage l in languages) l.id,
      if (remote) 'remote drivers',
    ]..sort();
    return parts.isEmpty ? 'no logic at all' : parts.join(', ');
  }
}

/// A host cannot run the driver a project ships.
///
/// Thrown rather than tolerated, and this is the point: a mini-app without its
/// logic is not a degraded app, it is a lie shaped like an app — every wired
/// control disabled, nothing ever responding. Refusal with a reason beats inert
/// chrome.
final class UnsupportedDriver implements Exception {
  /// Reports that [needed] is beyond what [supported] offers.
  const UnsupportedDriver(this.needed, this.supported);

  /// What the project needs, in words.
  final String needed;

  /// What the host can actually do.
  final HostLogicSupport supported;

  @override
  String toString() => 'UnsupportedDriver: this project needs $needed, which '
      'this host cannot run (it supports: ${supported.describe()}).';
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
/// A project declares two things about its logic and no more: **what** it is
/// (an artifact in some language, shipped in the bundle — or an endpoint the
/// host connects to), and **what it needs** (capabilities). It does not
/// declare where the driver runs, because the same bundle has to work on the
/// web, in a webview, and inside an embedded engine, and only the host knows
/// which of those it is.
///
/// Parsing is deliberately **not** total, unlike the rest of the manifest. An
/// absent slot is fine — that is an ordinary pure-UI project. A slot that is
/// present but unreadable is a failure, because the alternative is loading a
/// mini-app with its logic quietly missing. Totality is for untrusted
/// agent-supplied data; a project's own declaration about itself gets to be
/// wrong out loud.
final class LogicManifest {
  /// Declares logic that ships with the bundle: an [entry] file in [language].
  const LogicManifest.bundled({
    required String this.entry,
    required DriverLanguage this.language,
    this.capabilities = const <String>[],
  }) : url = null;

  /// Declares logic that never ships to the client at all, reached at [url].
  ///
  /// An app-level fact, not a runtime choice: "my logic lives on my server" is
  /// something only the project can know.
  const LogicManifest.remote({
    required String this.url,
    this.capabilities = const <String>[],
  })  : entry = null,
        language = null;

  /// Reads the `logic` slot of a decoded `manifest.json`.
  ///
  /// Returns null when the project declares none. Throws
  /// [MalformedLogicManifest] when it declares one that cannot be read.
  static LogicManifest? read(Map<String, Object?> manifest) {
    final Object? slot = manifest['logic'];
    if (slot == null) return null;
    if (slot is! Map) {
      throw const MalformedLogicManifest("'logic' must be an object.");
    }
    final List<String> capabilities = _capabilities(slot['capabilities']);

    final Object? url = slot['url'];
    final Object? entry = slot['entry'];
    if (url != null && entry != null) {
      throw const MalformedLogicManifest(
        "'logic' declares both a 'url' and an 'entry'; logic either ships "
        'with the bundle or lives at an endpoint, not both.',
      );
    }

    if (url != null) {
      if (url is! String || url.isEmpty) {
        throw const MalformedLogicManifest("'url' must be a non-empty string.");
      }
      return LogicManifest.remote(url: url, capabilities: capabilities);
    }

    if (entry is! String || entry.isEmpty) {
      throw const MalformedLogicManifest(
        "'logic' needs a non-empty 'entry' — the file this bundle ships — or "
        "a 'url' for logic that stays on a server.",
      );
    }
    final Object? rawLanguage = slot['language'];
    if (rawLanguage is! String) {
      throw const MalformedLogicManifest(
        "'logic' needs a string 'language' naming what 'entry' is written in.",
      );
    }
    final DriverLanguage? language = DriverLanguage.byId(rawLanguage);
    if (language == null) {
      throw MalformedLogicManifest(
        "Unknown driver language '$rawLanguage'. This version knows: "
        '${DriverLanguage.values.map((DriverLanguage l) => l.id).join(', ')}.',
      );
    }
    return LogicManifest.bundled(
      entry: entry,
      language: language,
      capabilities: capabilities,
    );
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

  /// The file this bundle ships, relative to its base URL — or null for
  /// [LogicManifest.remote].
  final String? entry;

  /// What [entry] is written in — or null for [LogicManifest.remote].
  final DriverLanguage? language;

  /// The endpoint a remote driver is reached at — or null for bundled logic.
  final String? url;

  /// Capabilities the project requests. Always empty in this version.
  final List<String> capabilities;

  /// Whether this driver stays on a server rather than shipping to the client.
  bool get isRemote => url != null;

  /// Resolves [entry] against a bundle's [baseUrl]. Bundled logic only.
  String entryUrl(String baseUrl) {
    final String? file = entry;
    if (file == null) {
      throw StateError('Remote logic has no bundled entry to resolve.');
    }
    return baseUrl.endsWith('/') ? '$baseUrl$file' : '$baseUrl/$file';
  }

  /// Throws [UnsupportedDriver] unless [host] can run this project's logic.
  ///
  /// Deliberately a question about *language*, not about sandboxes: a host that
  /// runs JavaScript answers yes whether it does so in a worker, an iframe, or
  /// an embedded engine, and the project never learns which.
  void requireSupported(HostLogicSupport host) {
    if (isRemote) {
      if (host.remote) return;
      throw UnsupportedDriver('a remote driver at $url', host);
    }
    if (host.languages.contains(language)) return;
    throw UnsupportedDriver('a driver written in ${language!.id}', host);
  }

  static List<String> _capabilities(Object? raw) {
    if (raw == null) return const <String>[];
    if (raw is! List) {
      throw const MalformedLogicManifest("'capabilities' must be a list.");
    }
    final List<String> requested = <String>[
      for (final Object? c in raw) c.toString(),
    ];
    if (requested.isNotEmpty) {
      // Nothing is grantable yet, and granting nothing while a project asks for
      // something would run it with less power than it says it needs.
      throw MalformedLogicManifest(
        'This version grants no capabilities, but the project requests: '
        '${requested.join(', ')}.',
      );
    }
    return requested;
  }
}
