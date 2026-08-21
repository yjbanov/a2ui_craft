// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
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
    Set<String> missing = const <String>{},
    HostLogicSupport logicSupport = HostLogicSupport.none}) {
  return CraftProjectLoader(
    logicSupport: logicSupport,
    client: MockClient((http.Request req) async {
      final String name = req.url.pathSegments.last;
      if (!missing.contains(name) && files.containsKey(name)) {
        return http.Response(files[name]!, 200);
      }
      return http.Response('not found', 404);
    }),
  );
}

/// The same project, shipping a JavaScript driver.
Map<String, String> _miniAppFiles() => <String, String>{
      ..._files,
      'manifest.json': '{ "name": "Pulse", "catalogId": "demo", '
          '"logic": { "entry": "logic.js", "language": "javascript" } }',
      'logic.js': "a2uiDriver({ handlers: {} });",
    };

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

  group('a project that ships logic', () {
    // The production path for a `craft create --logic` deployment: the same
    // loader, the same URL bar. This is where "refusal with a reason beats
    // inert chrome" is enforced — a logic project rendered without its driver
    // is a screen of controls frozen on "Connecting…".

    test('is refused, with a reason, by a host that runs none', () async {
      expect(
        _loader(files: _miniAppFiles()).load('https://pulse.example.app'),
        throwsA(isA<ProjectLoadException>().having(
          (ProjectLoadException e) => e.message,
          'message',
          contains('javascript'),
        )),
      );
    });

    test('loads on a host that runs JavaScript, driver source included',
        () async {
      final LoadedProject project = await _loader(
        files: _miniAppFiles(),
        logicSupport: const HostLogicSupport(
          languages: <DriverLanguage>{DriverLanguage.javascript},
        ),
      ).load('https://pulse.example.app');

      expect(project.manifest.logic, isNotNull);
      expect(project.manifest.logic!.entry, 'logic.js');
      expect(project.driverJs, contains('a2uiDriver'),
          reason: 'fetched as text so the host can prepend the SDK and pick '
              'its own sandbox');
    });

    test('a pure-UI project carries no driver and loads on any host', () async {
      final LoadedProject project =
          await _loader().load('https://pulse.example.app');
      expect(project.manifest.logic, isNull);
      expect(project.driverJs, isNull);
    });

    test('a declared-but-missing driver file is a load error', () async {
      expect(
        _loader(
          files: _miniAppFiles(),
          missing: const <String>{'logic.js'},
          logicSupport: const HostLogicSupport(
            languages: <DriverLanguage>{DriverLanguage.javascript},
          ),
        ).load('https://pulse.example.app'),
        throwsA(isA<ProjectLoadException>()),
      );
    });

    test('a malformed logic slot refuses loudly, unlike a malformed theme',
        () async {
      final Map<String, String> files = <String, String>{
        ..._files,
        'manifest.json': '{ "name": "Pulse", "logic": { "entry": "a.wasm", '
            '"language": "wasm" } }',
      };
      expect(
        _loader(files: files).load('https://pulse.example.app'),
        throwsA(isA<ProjectLoadException>().having(
          (ProjectLoadException e) => e.message,
          'message',
          contains('Unknown driver language'),
        )),
      );
    });
  });
}
