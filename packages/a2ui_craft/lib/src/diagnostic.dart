import 'source.dart';

/// Severity of a [Diagnostic].
enum Severity { error, warning, info }

/// A compiler diagnostic (error, warning, or informational message) anchored to
/// a location in source.
class Diagnostic {
  Diagnostic(this.severity, this.message, this.span);

  final Severity severity;
  final String message;
  final SourceSpan? span;

  @override
  String toString() {
    final where = span == null ? '' : '$span: ';
    return '$where${severity.name}: $message';
  }
}

/// Thrown when compilation cannot proceed. Carries the accumulated
/// [diagnostics] so callers can present all of them at once.
class CompileException implements Exception {
  CompileException(this.diagnostics);

  final List<Diagnostic> diagnostics;

  @override
  String toString() => diagnostics.map((d) => d.toString()).join('\n');
}
