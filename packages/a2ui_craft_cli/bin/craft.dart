import 'dart:io';

import 'package:a2ui_craft/a2ui_craft.dart';

/// Entry point for the `craft` command-line compiler.
///
/// Usage:
///   craft <file.craft>      Compile a Craft file and print Transport JSON.
///   craft --version         Print the compiler version.
///   craft --help            Print usage.
void main(List<String> args) {
  exitCode = _run(args);
}

int _run(List<String> args) {
  if (args.isEmpty || args.contains('--help') || args.contains('-h')) {
    stdout.writeln(_usage);
    return args.isEmpty ? 64 /* EX_USAGE */ : 0;
  }
  if (args.contains('--version')) {
    stdout.writeln('craft $craftCompilerVersion '
        '(targets A2UI Transport $defaultTargetTransportVersion)');
    return 0;
  }

  final path = args.last;
  final file = File(path);
  if (!file.existsSync()) {
    stderr.writeln('craft: no such file: $path');
    return 66; // EX_NOINPUT
  }

  final source = SourceFile(file.uri, file.readAsStringSync());
  try {
    final result = compileSource(source);
    for (final message in result.messages) {
      stdout.writeln(message); // TODO: emit canonical JSON once codegen lands.
    }
    for (final diagnostic in result.diagnostics) {
      stderr.writeln(diagnostic);
    }
    return 0;
  } on CompileException catch (e) {
    for (final diagnostic in e.diagnostics) {
      stderr.writeln(diagnostic);
    }
    return 65; // EX_DATAERR
  } on UnimplementedError catch (e) {
    stderr.writeln('craft: $e');
    return 70; // EX_SOFTWARE
  }
}

const String _usage = '''
craft — the A2UI Craft compiler

Usage:
  craft <file.craft>   Compile a Craft source file to A2UI Transport JSON.
  craft --version      Print version information.
  craft --help         Show this help.
''';
