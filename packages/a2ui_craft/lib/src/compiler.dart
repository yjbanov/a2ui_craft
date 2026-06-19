import 'diagnostic.dart';
import 'lexer.dart';
import 'source.dart';
import 'token.dart';

/// Options that influence compilation.
class CompileOptions {
  const CompileOptions({this.config = const <String, Object?>{}});

  /// Compile-time configuration values, made available to templates for
  /// compile-time evaluation (e.g. feature flags, environment names). Fed to
  /// the compiler alongside the source, typically loaded from a config file.
  final Map<String, Object?> config;
}

/// The result of a successful compilation: the emitted A2UI Transport messages
/// plus any non-fatal diagnostics (e.g. warnings).
class CompileResult {
  CompileResult(this.messages, this.diagnostics);

  /// The ordered stream of A2UI Transport envelope messages (as JSON-encodable
  /// maps), ready to be serialized to JSON / JSONL.
  final List<Map<String, Object?>> messages;

  /// Warnings and informational diagnostics produced during compilation.
  final List<Diagnostic> diagnostics;
}

/// Compiles a single in-memory A2UI Craft [source] into A2UI Transport.
///
/// This is the convenience entry point for the common single-file case. Import
/// resolution across multiple files is handled by the (forthcoming) module
/// loader, which calls into the same pipeline.
///
/// The pipeline is: lex -> parse -> resolve imports -> analyze -> evaluate
/// compile-time expressions -> lower to the adjacency-list model -> emit
/// Transport JSON. Today only the lexing stage is implemented; later stages
/// are tracked in `DESIGN.md`.
CompileResult compileSource(
  SourceFile source, {
  CompileOptions options = const CompileOptions(),
}) {
  // Stage 1: lexing. Throws CompileException on lexical errors.
  final List<Token> tokens = Lexer(source).tokenize();

  // Stages 2+ are not implemented yet. Surface this honestly rather than
  // returning an empty-but-successful result.
  throw UnimplementedError(
    'A2UI Craft parsing and code generation are not implemented yet. '
    'Lexing produced ${tokens.length} tokens for ${source.uri}.',
  );
}
