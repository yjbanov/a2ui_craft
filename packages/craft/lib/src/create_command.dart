// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:path/path.dart' as p;

import 'scaffold.dart';

/// `craft create <name>` — scaffold a new, deployable A2UI Craft project.
class CreateCommand extends Command<int> {
  CreateCommand() {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Parent directory to create the project in.',
        defaultsTo: '.',
      )
      ..addFlag(
        'force',
        help: 'Overwrite an existing, non-empty target directory.',
        negatable: false,
      );
  }

  @override
  final String name = 'create';

  @override
  final String description =
      'Create a new A2UI Craft project (a deployable, agent-optional UI bundle).';

  @override
  String get invocation => 'craft create <name>';

  /// Valid project ids: letters/digits plus `_`/`-`, starting with a letter.
  static final RegExp _validName = RegExp(r'^[a-zA-Z][a-zA-Z0-9_-]*$');

  @override
  Future<int> run() async {
    final args = argResults!;
    final List<String> rest = args.rest;
    if (rest.isEmpty) {
      usageException('Provide a project name, e.g. `craft create my_counter`.');
    }
    if (rest.length > 1) {
      usageException('Unexpected extra arguments: ${rest.skip(1).join(' ')}');
    }
    final String projectName = rest.first;
    if (!_validName.hasMatch(projectName)) {
      usageException("Invalid project name '$projectName' — use letters, "
          'digits, `_` or `-`, starting with a letter.');
    }

    final Directory dir =
        Directory(p.join(args.option('output')!, projectName));
    final bool force = args.flag('force');
    if (dir.existsSync() && dir.listSync().isNotEmpty && !force) {
      stderr.writeln("Target '${dir.path}' already exists and is not empty. "
          'Pass --force to overwrite.');
      return 1;
    }
    dir.createSync(recursive: true);

    final Map<String, String> files = counterProjectFiles(projectName);
    for (final MapEntry<String, String> entry in files.entries) {
      File(p.join(dir.path, entry.key)).writeAsStringSync(entry.value);
    }

    stdout
      ..writeln('Created A2UI Craft project "${humanizeName(projectName)}" at '
          '${dir.path}/')
      ..writeln('  ${files.keys.join(', ')}')
      ..writeln()
      ..writeln('Deploy it to a CDN (no build step):')
      ..writeln('  cd ${dir.path}')
      ..writeln('  firebase deploy --only hosting')
      ..writeln('See its README.md for the full walkthrough.');
    return 0;
  }
}
