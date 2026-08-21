// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:io';

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:args/command_runner.dart';
import 'package:craft/src/create_command.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

Future<int> _run(List<String> arguments) async {
  final CommandRunner<int> runner = CommandRunner<int>('craft', 'test')
    ..addCommand(CreateCommand());
  return (await runner.run(arguments)) ?? 0;
}

void main() {
  late Directory tmp;
  setUp(() => tmp = Directory.systemTemp.createTempSync('craft_test'));
  tearDown(() => tmp.deleteSync(recursive: true));

  test('create scaffolds every deployable project file', () async {
    final int code =
        await _run(<String>['create', 'my_counter', '-o', tmp.path]);
    expect(code, 0);
    final String dir = p.join(tmp.path, 'my_counter');
    for (final String f in const <String>[
      'manifest.json',
      'template.craft',
      'schema.json',
      'app.json',
      'tests.json',
      'firebase.json',
      'README.md',
    ]) {
      expect(File(p.join(dir, f)).existsSync(), isTrue, reason: '$f missing');
    }
  });

  test('the scaffolded project parses end to end', () async {
    await _run(<String>['create', 'demo_app', '-o', tmp.path]);
    final String dir = p.join(tmp.path, 'demo_app');
    String read(String f) => File(p.join(dir, f)).readAsStringSync();

    // The consolidated manifest.
    final ProjectManifest manifest =
        ProjectManifest.parse(read('manifest.json'));
    expect(manifest.name, 'Demo App');
    expect(manifest.catalogId, 'demo');

    // The template is valid RFW.
    expect(() => parseLibraryFile(read('template.craft')), returnsNormally);

    // Schema + app.json bootstrap decode into a renderable SampleSpec.
    final SampleSpec spec = SampleSpec.fromData(
      label: manifest.name,
      template: read('template.craft'),
      schemaJson: read('schema.json'),
      messagesJson: read('app.json'),
    );
    expect(spec.messages, isNotEmpty);

    // Every named test scenario decodes as an A2UI message stream.
    final Map<String, dynamic> tests =
        jsonDecode(read('tests.json')) as Map<String, dynamic>;
    expect(tests.keys, containsAll(<String>['default', 'custom-labels']));
    for (final MapEntry<String, dynamic> entry in tests.entries) {
      final SampleSpec scenario = SampleSpec.fromData(
        label: entry.key,
        template: read('template.craft'),
        schemaJson: read('schema.json'),
        messagesJson: jsonEncode(entry.value),
      );
      expect(scenario.messages, isNotEmpty, reason: '${entry.key} is empty');
    }
  });

  test('--logic scaffolds a mini-app that declares its own driver', () async {
    final int code =
        await _run(<String>['create', 'my_app', '--logic', '-o', tmp.path]);
    expect(code, 0);
    final String dir = p.join(tmp.path, 'my_app');
    String read(String f) => File(p.join(dir, f)).readAsStringSync();

    for (final String f in const <String>[
      'manifest.json',
      'template.craft',
      'schema.json',
      'app.json',
      'logic.js',
      'firebase.json',
      'README.md',
    ]) {
      expect(File(p.join(dir, f)).existsSync(), isTrue, reason: '$f missing');
    }

    // The scaffold has to be loadable by the parser that will actually read
    // it, not merely look right.
    final LogicManifest logic = LogicManifest.parse(read('manifest.json'))!;
    expect(logic.language, DriverLanguage.javascript);
    expect(logic.entry, 'logic.js');
    logic.requireSupported(const HostLogicSupport(
      languages: <DriverLanguage>{DriverLanguage.javascript},
    ));

    // The template and its cold boot render as an ordinary project would.
    final SampleSpec spec = SampleSpec.fromData(
      label: 'My App',
      template: read('template.craft'),
      schemaJson: read('schema.json'),
      messagesJson: read('app.json'),
    );
    expect(spec.messages, isNotEmpty);
    expect(parseLibraryFile(read('template.craft')).widgets, isNotEmpty);

    // The driver answers exactly the action the schema advertises to an agent.
    final InferenceCatalog catalog = InferenceCatalog.parse(
      jsonDecode(read('schema.json')) as Map<String, Object?>,
    );
    expect(catalog.actionNames, <String>{'reserve'});
    for (final String action in catalog.actionNames) {
      expect(read('logic.js'), contains('$action:'),
          reason: 'the scaffolded driver must implement what it advertises');
    }

    // A counter project is not a mini-app: no logic slot, no driver.
    expect(await _run(<String>['create', 'plain', '-o', tmp.path]), 0);
    expect(
      LogicManifest.parse(
        File(p.join(tmp.path, 'plain', 'manifest.json')).readAsStringSync(),
      ),
      isNull,
    );
  });

  test('refuses a non-empty target without --force', () async {
    expect(await _run(<String>['create', 'dup', '-o', tmp.path]), 0);
    expect(await _run(<String>['create', 'dup', '-o', tmp.path]), 1);
    // --force overwrites.
    expect(await _run(<String>['create', 'dup', '-o', tmp.path, '--force']), 0);
  });

  test('rejects an invalid project name', () async {
    expect(_run(<String>['create', '1bad', '-o', tmp.path]),
        throwsA(isA<UsageException>()));
  });
}
