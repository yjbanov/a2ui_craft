@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// Resolves the path to bin/craft.dart relative to this test file so the test
/// works regardless of the current working directory.
String get _craftScript {
  final here = File.fromUri(Platform.script).parent.path;
  // When run via `dart test`, Platform.script points at the test runner, so
  // fall back to a path relative to this library's directory.
  final libDir = Directory.current.path;
  final candidate = '$libDir/bin/craft.dart';
  return File(candidate).existsSync() ? candidate : '$here/../bin/craft.dart';
}

void main() {
  test('--version prints the compiler version', () {
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [_craftScript, '--version'],
    );
    expect(result.exitCode, 0);
    expect(result.stdout, contains('craft'));
    expect(result.stdout, contains('A2UI Transport'));
  });

  test('missing file exits with EX_NOINPUT', () {
    final result = Process.runSync(
      Platform.resolvedExecutable,
      [_craftScript, 'does_not_exist.craft'],
    );
    expect(result.exitCode, 66);
  });
}
