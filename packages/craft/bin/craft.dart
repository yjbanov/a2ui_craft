// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:args/command_runner.dart';
import 'package:craft/src/create_command.dart';

Future<void> main(List<String> arguments) async {
  final CommandRunner<int> runner = CommandRunner<int>(
    'craft',
    'Scaffold and manage A2UI Craft projects — ephemeral, data-only UI bundles '
        'that deploy to a CDN and load into a host at runtime.',
  )..addCommand(CreateCommand());

  try {
    exitCode = await runner.run(arguments) ?? 0;
  } on UsageException catch (e) {
    stderr.writeln(e);
    exitCode = 64; // EX_USAGE
  }
}
