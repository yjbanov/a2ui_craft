// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:test/test.dart';

// A minimal project served by a mock CDN — the production path (fetch a project
// over HTTP) exercised without a network (DESIGN.md §10).

const Map<String, String> _files = <String, String>{
  'manifest.json': '{ "name": "Pulse", "catalogId": "demo", '
      '"theme": { "theme": "default", "mode": "dark" } }',
  'template.craft': 'import core;\nwidget Counter = Text(text: args.label);',
  'schema.json': '{"catalogId":"demo","components":{"Counter":{"properties":'
      '{"label":{"\$ref":"DynamicString"}}}}}',
  'app.json': '[{"version":"v0.9","createSurface":{"surfaceId":"demo",'
      '"catalogId":"demo"}},{"version":"v0.9","updateComponents":'
      '{"surfaceId":"demo","components":[{"id":"root","component":"Counter",'
      '"label":"hi"}]}}]',
  'tests.json': '{"default":[{"version":"v0.9","createSurface":'
      '{"surfaceId":"demo","catalogId":"demo"}}]}',
};

CraftProjectLoader _loader(
    {Map<String, String> files = _files,
    Set<String> missing = const <String>{}}) {
  return CraftProjectLoader(
    client: MockClient((http.Request req) async {
      final String name = req.url.pathSegments.last;
      if (!missing.contains(name) && files.containsKey(name)) {
        return http.Response(files[name]!, 200);
      }
      return http.Response('not found', 404);
    }),
  );
}

void main() {
  test('loads a project from its base URL into a renderable bundle', () async {
    final LoadedProject project =
        await _loader().load('https://pulse.example.app');

    expect(project.baseUrl, 'https://pulse.example.app/');
    expect(project.manifest.name, 'Pulse');
    expect(project.manifest.catalogId, 'demo');
    // The theme rode along in the manifest (host resolves it per mode).
    expect(project.manifest.theme, isNotNull);
    expect(project.manifest.theme!.defaultMode.id, 'dark');
    // The app.json bootstrap decoded into the renderable spec.
    expect(project.spec.messages, isNotEmpty);
    expect(project.spec.catalogSource, contains('widget Counter'));
    // The optional tests.json scenarios came through.
    expect(project.tests.keys, contains('default'));
  });

  test('tolerates a pasted manifest.json URL', () async {
    final LoadedProject project =
        await _loader().load('https://pulse.example.app/manifest.json');
    expect(project.baseUrl, 'https://pulse.example.app/');
  });

  test('a project with no tests.json still loads (tests optional)', () async {
    final LoadedProject project =
        await _loader(missing: const <String>{'tests.json'})
            .load('https://pulse.example.app');
    expect(project.tests, isEmpty);
    expect(project.spec.messages, isNotEmpty);
  });

  test('a missing required file is a descriptive load error', () async {
    expect(
      _loader(missing: const <String>{'app.json'})
          .load('https://pulse.example.app'),
      throwsA(isA<ProjectLoadException>()),
    );
  });

  test('an empty URL is rejected', () async {
    expect(_loader().load('   '), throwsA(isA<ProjectLoadException>()));
  });
}
