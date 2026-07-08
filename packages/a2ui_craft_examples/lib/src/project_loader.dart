// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
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
/// the zero-IO baked samples (DESIGN.md §13.9). This is what proves the
/// ephemeral-loadability property: a host fetches a project over HTTP at
/// runtime, so re-publishing the project's files to its CDN updates the UI with
/// no host redeploy.
class LoadedProject {
  LoadedProject({
    required this.baseUrl,
    required this.manifest,
    required this.spec,
    required this.tests,
  });

  /// The normalized base URL the project was loaded from (trailing slash).
  final String baseUrl;

  /// The project manifest (name, catalog id, theme).
  final ProjectManifest manifest;

  /// The renderable bundle: template + schema + the `app.json` bootstrap as its
  /// messages. Its `theme` is left unset — the theme lives on [manifest] so the
  /// host can offer the n-ary mode picker and resolve a snapshot per mode.
  final SampleSpec spec;

  /// Optional named dev scenarios from `tests.json` (may be empty), for
  /// demoing the project without an agent.
  final Map<String, List<A2uiMessage>> tests;
}

/// Fetches an [LoadedProject] from a base URL over HTTP.
///
/// Given `https://my-app.web.app/`, it fetches `manifest.json`, `template.craft`,
/// `schema.json`, and `app.json` (the required bootstrap), plus `tests.json` if
/// present. The project's host must serve these cross-origin (the scaffolded
/// `firebase.json` sets `Access-Control-Allow-Origin: *`).
class CraftProjectLoader {
  CraftProjectLoader({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Loads the project at [url] (its base URL, or a `.../manifest.json` URL).
  Future<LoadedProject> load(String url) async {
    final String base = _baseOf(url);
    final ProjectManifest manifest =
        ProjectManifest.parse(await _get('${base}manifest.json'));
    final String template = await _get('${base}template.craft');
    final String schema = await _get('${base}schema.json');
    final String app = await _get('${base}app.json');

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
        baseUrl: base, manifest: manifest, spec: spec, tests: tests);
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
