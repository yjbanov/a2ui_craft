/// A2UI Craft: a human-authored templating language that compiles to A2UI
/// Transport JSON.
///
/// This library is the public API surface of the compiler. It is pure Dart and
/// has no Flutter dependency, so it can run on servers and in command-line
/// tools.
library;

export 'src/compiler.dart';
export 'src/diagnostic.dart';
export 'src/lexer.dart' show Lexer;
export 'src/source.dart';
export 'src/token.dart';
export 'src/version.dart';
