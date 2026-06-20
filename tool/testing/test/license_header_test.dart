// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:io';

import 'package:test/test.dart';

/// The license header every Dart file in the repository must start with.
const String _licenseHeader = '// Copyright 2013 The Flutter Authors\n'
    '// Use of this source code is governed by a BSD-style license that can be\n'
    '// found in the LICENSE file.\n';

/// Directory names that never contain source we author (generated output, VCS,
/// editor state).
const Set<String> _excludedDirs = <String>{
  '.dart_tool',
  'build',
  '.git',
  '.jaspr',
  '.idea',
  '.vscode',
};

void main() {
  test('every Dart file starts with the license header', () {
    final Directory root = _findWorkspaceRoot();
    final List<String> offenders = <String>[];

    for (final File file in _dartFiles(root)) {
      var content = file.readAsStringSync().replaceAll('\r\n', '\n');
      if (content.isNotEmpty && content.codeUnitAt(0) == 0xFEFF) {
        content = content.substring(1); // strip UTF-8 BOM
      }
      if (!content.startsWith(_licenseHeader)) {
        offenders.add(_relative(root, file));
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'The following Dart files are missing the required license '
          'header:\n  ${offenders.join('\n  ')}',
    );
  });
}

/// Walks up from the current directory to the workspace root, identified by a
/// `pubspec.yaml` containing a top-level `workspace:` section.
Directory _findWorkspaceRoot() {
  final RegExp workspaceKey = RegExp(r'^workspace:', multiLine: true);
  var dir = Directory.current.absolute;
  while (true) {
    final File pubspec = File(
      '${dir.path}${Platform.pathSeparator}pubspec.yaml',
    );
    if (pubspec.existsSync() &&
        workspaceKey.hasMatch(pubspec.readAsStringSync())) {
      return dir;
    }
    final Directory parent = dir.parent;
    if (parent.path == dir.path) {
      fail(
        'Could not locate the workspace root (a pubspec.yaml with a '
        '"workspace:" section) starting from ${Directory.current.path}.',
      );
    }
    dir = parent;
  }
}

/// Yields every `.dart` file under [dir], pruning [_excludedDirs].
Iterable<File> _dartFiles(Directory dir) sync* {
  for (final FileSystemEntity entity in dir.listSync(followLinks: false)) {
    final String name = entity.path.split(Platform.pathSeparator).last;
    if (entity is Directory) {
      if (_excludedDirs.contains(name)) continue;
      yield* _dartFiles(entity);
    } else if (entity is File && name.endsWith('.dart')) {
      yield entity;
    }
  }
}

String _relative(Directory root, File file) =>
    file.path.substring(root.path.length + 1);
