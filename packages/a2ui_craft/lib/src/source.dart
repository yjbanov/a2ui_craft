/// A single A2UI Craft source file: its URI (for diagnostics and import
/// resolution) and its full textual contents.
class SourceFile {
  SourceFile(this.uri, this.contents);

  /// The location this source was loaded from. Used in diagnostics and to
  /// resolve relative imports. For in-memory sources, a synthetic URI such as
  /// `memory:main.craft` may be used.
  final Uri uri;

  /// The raw text of the source file.
  final String contents;

  /// Returns the 1-based line and column for the given 0-based [offset].
  ///
  /// This is a simple linear scan; it is intended for producing diagnostics,
  /// not for hot paths.
  ({int line, int column}) lineAndColumn(int offset) {
    var line = 1;
    var column = 1;
    final limit = offset.clamp(0, contents.length);
    for (var i = 0; i < limit; i++) {
      if (contents.codeUnitAt(i) == 0x0A /* \n */) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    return (line: line, column: column);
  }
}

/// A half-open span `[start, end)` of characters within a [SourceFile].
class SourceSpan {
  const SourceSpan(this.source, this.start, this.end);

  final SourceFile source;
  final int start;
  final int end;

  /// The text covered by this span.
  String get text => source.contents.substring(start, end);

  @override
  String toString() {
    final loc = source.lineAndColumn(start);
    return '${source.uri}:${loc.line}:${loc.column}';
  }
}
