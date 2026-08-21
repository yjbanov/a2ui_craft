// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:http/http.dart' as http;

import 'project.dart';
import 'sample_spec.dart';

/// Thrown when a project cannot be fetched or is malformed. Carries a
/// human-readable [message] the host can surface.
class ProjectLoadException implements Exception {
  ProjectLoadException(this.message);

  final String message;

  @override
  String toString() => 'ProjectLoadException: $message';
}

/// An A2UI Craft project fetched from a URL — the *production* counterpart to
/// the zero-IO baked samples (DESIGN.md §10). This is what proves the
/// ephemeral-loadability property: a host fetches a project over HTTP at
/// runtime, so re-publishing the project's files to its CDN updates the UI with
/// no host redeploy.
class LoadedProject {
  LoadedProject({
    required this.baseUrl,
    required this.manifest,
    required this.spec,
    required this.tests,
    this.driverJs,
  });

  /// The normalized base URL the project was loaded from (trailing slash).
  final String baseUrl;

  /// The project manifest (name, catalog id, theme, logic).
  final ProjectManifest manifest;

  /// The renderable bundle: template + schema + the `app.json` bootstrap as its
  /// messages. Its `theme` is left unset — the theme lives on [manifest] so the
  /// host can offer the n-ary mode picker and resolve a snapshot per mode.
  final SampleSpec spec;

  /// Optional named dev scenarios from `tests.json` (may be empty), for
  /// demoing the project without an agent.
  final Map<String, List<A2uiMessage>> tests;

  /// The fetched source of the project's bundled JavaScript driver, when the
  /// manifest declares one. A host runs it (SDK prepended) in whatever
  /// sandbox it chooses; the project never named one.
  final String? driverJs;
}

/// Fetches an [LoadedProject] from a base URL over HTTP.
///
/// Given `https://my-app.web.app/`, it fetches `manifest.json`, `template.craft`,
/// `schema.json`, and `app.json` (the required bootstrap), plus `tests.json` if
/// present. The project's host must serve these cross-origin (the scaffolded
/// `firebase.json` sets `Access-Control-Allow-Origin: *`).
class CraftProjectLoader {
  /// Creates a loader for a host whose logic support is [logicSupport].
  ///
  /// The default is [HostLogicSupport.none]: a host that says nothing runs
  /// nothing, and a project that ships logic is **refused with a reason**
  /// rather than rendered as a screen of controls frozen on "Connecting…" —
  /// the inert-chrome outcome the design forbids. A host that can run drivers
  /// states so and gets the fetched source back on [LoadedProject.driverJs].
  CraftProjectLoader({
    http.Client? client,
    this.logicSupport = HostLogicSupport.none,
  }) : _client = client ?? http.Client();

  final http.Client _client;

  /// What driver support this host offers; see [LogicManifest.requireSupported].
  final HostLogicSupport logicSupport;

  /// Loads the project at [url] (its base URL, or a `.../manifest.json` URL).
  Future<LoadedProject> load(String url) async {
    final String base = _baseOf(url);
    final ProjectManifest manifest;
    try {
      manifest = ProjectManifest.parse(await _get('${base}manifest.json'));
      manifest.logic?.requireSupported(logicSupport);
    } on MalformedLogicManifest catch (e) {
      throw ProjectLoadException(e.message);
    } on UnsupportedDriver catch (e) {
      throw ProjectLoadException('$e');
    }
    final String template = await _get('${base}template.craft');
    final String schema = await _get('${base}schema.json');
    final String app = await _get('${base}app.json');
    // A bundled driver is fetched as text: the host prepends the SDK and runs
    // it in the sandbox of its own choosing (WorkerDriverRunner.fromSource on
    // the web), so the published file needs no import of its own.
    final LogicManifest? logic = manifest.logic;
    final String? driverJs = logic != null && !logic.isRemote
        ? await _get(logic.entryUrl(base))
        : null;

    final SampleSpec spec;
    try {
      spec = SampleSpec.fromData(
        label: manifest.name.isEmpty ? 'Project' : manifest.name,
        template: template,
        schemaJson: schema,
        messagesJson: app,
      );
    } on Object catch (e) {
      throw ProjectLoadException('Project data is malformed: $e');
    }

    // tests.json is optional dev tooling — a missing or malformed one is not an
    // error; the project simply has no canned scenarios.
    Map<String, List<A2uiMessage>> tests = const <String, List<A2uiMessage>>{};
    final String? testsBody = await _getOrNull('${base}tests.json');
    if (testsBody != null) {
      try {
        tests = _parseTests(testsBody);
      } on Object {
        tests = const <String, List<A2uiMessage>>{};
      }
    }

    return LoadedProject(
      baseUrl: base,
      manifest: manifest,
      spec: spec,
      tests: tests,
      driverJs: driverJs,
    );
  }

  Future<String> _get(String url) async {
    final http.Response response;
    try {
      response = await _client.get(Uri.parse(url));
    } on Object catch (e) {
      throw ProjectLoadException('Could not reach $url ($e)');
    }
    if (response.statusCode != 200) {
      throw ProjectLoadException('$url returned HTTP ${response.statusCode}');
    }
    return response.body;
  }

  Future<String?> _getOrNull(String url) async {
    try {
      final http.Response response = await _client.get(Uri.parse(url));
      return response.statusCode == 200 ? response.body : null;
    } on Object {
      return null;
    }
  }

  /// Normalizes a user-entered URL to a base with a trailing slash, tolerating a
  /// pasted `.../manifest.json`.
  static String _baseOf(String url) {
    String u = url.trim();
    if (u.isEmpty) throw ProjectLoadException('Enter a project URL.');
    const String manifest = 'manifest.json';
    if (u.endsWith(manifest)) {
      u = u.substring(0, u.length - manifest.length);
    }
    return u.endsWith('/') ? u : '$u/';
  }

  static Map<String, List<A2uiMessage>> _parseTests(String json) {
    final Object? decoded = jsonDecode(json);
    if (decoded is! Map<String, Object?>) {
      return const <String, List<A2uiMessage>>{};
    }
    return <String, List<A2uiMessage>>{
      for (final MapEntry<String, Object?> e in decoded.entries)
        if (e.value is List)
          e.key: <A2uiMessage>[
            for (final Object? m in e.value! as List<Object?>)
              A2uiMessage.fromJson(m! as Map<String, dynamic>),
          ],
    };
  }
}
