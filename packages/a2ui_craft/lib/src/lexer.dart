import 'diagnostic.dart';
import 'source.dart';
import 'token.dart';

/// Converts A2UI Craft source text into a stream of [Token]s.
///
/// The lexer recognizes C-style line (`//`) and block (`/* */`) comments,
/// identifiers, integer/double/hex number literals, single- and double-quoted
/// string literals with escapes, and the punctuation used by the grammar.
///
/// Lexical errors are accumulated as [Diagnostic]s; if any are produced,
/// [tokenize] throws a [CompileException] after scanning as much as it can.
class Lexer {
  Lexer(this.source);

  final SourceFile source;

  String get _text => source.contents;
  int _pos = 0;
  final List<Token> _tokens = <Token>[];
  final List<Diagnostic> _diagnostics = <Diagnostic>[];

  bool get _atEnd => _pos >= _text.length;
  int _peek([int ahead = 0]) {
    final i = _pos + ahead;
    return i < _text.length ? _text.codeUnitAt(i) : -1;
  }

  /// Scans [source] and returns its tokens, always ending with an
  /// [TokenType.eof] token. Throws [CompileException] if lexical errors were
  /// encountered.
  List<Token> tokenize() {
    while (!_atEnd) {
      _skipTrivia();
      if (_atEnd) break;
      _scanToken();
    }
    _tokens.add(Token(TokenType.eof, SourceSpan(source, _pos, _pos)));
    if (_diagnostics.isNotEmpty) {
      throw CompileException(_diagnostics);
    }
    return _tokens;
  }

  void _skipTrivia() {
    while (!_atEnd) {
      final c = _peek();
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        // space, tab, LF, CR
        _pos++;
      } else if (c == 0x2F && _peek(1) == 0x2F) {
        // line comment: // ... <newline | eof>
        _pos += 2;
        while (!_atEnd && _peek() != 0x0A) {
          _pos++;
        }
      } else if (c == 0x2F && _peek(1) == 0x2A) {
        // block comment: /* ... */ (non-nested)
        final start = _pos;
        _pos += 2;
        while (!_atEnd && !(_peek() == 0x2A && _peek(1) == 0x2F)) {
          _pos++;
        }
        if (_atEnd) {
          _error(start, _pos, 'Unterminated block comment.');
        } else {
          _pos += 2; // consume */
        }
      } else {
        break;
      }
    }
  }

  void _scanToken() {
    final start = _pos;
    final c = _peek();

    // Punctuation.
    switch (c) {
      case 0x7B:
        return _emit(TokenType.openBrace, start, ++_pos);
      case 0x7D:
        return _emit(TokenType.closeBrace, start, ++_pos);
      case 0x28:
        return _emit(TokenType.openParen, start, ++_pos);
      case 0x29:
        return _emit(TokenType.closeParen, start, ++_pos);
      case 0x5B:
        return _emit(TokenType.openBracket, start, ++_pos);
      case 0x5D:
        return _emit(TokenType.closeBracket, start, ++_pos);
      case 0x3A:
        return _emit(TokenType.colon, start, ++_pos);
      case 0x3B:
        return _emit(TokenType.semicolon, start, ++_pos);
      case 0x2C:
        return _emit(TokenType.comma, start, ++_pos);
      case 0x3D:
        return _emit(TokenType.equals, start, ++_pos);
    }

    if (c == 0x2E) {
      // '.' or '...'
      if (_peek(1) == 0x2E && _peek(2) == 0x2E) {
        _pos += 3;
        return _emit(TokenType.ellipsis, start, _pos);
      }
      return _emit(TokenType.dot, start, ++_pos);
    }

    if (c == 0x22 || c == 0x27) {
      return _scanString(start, c);
    }

    if (_isDigit(c) || (c == 0x2D && _isDigit(_peek(1)))) {
      return _scanNumber(start);
    }

    if (_isIdentifierStart(c)) {
      return _scanIdentifier(start);
    }

    // Unknown character: report and skip so lexing can continue.
    _pos++;
    _error(start, _pos, 'Unexpected character: ${_describe(c)}.');
  }

  void _scanIdentifier(int start) {
    _pos++; // first char already validated
    while (!_atEnd && _isIdentifierPart(_peek())) {
      _pos++;
    }
    final span = SourceSpan(source, start, _pos);
    _tokens.add(Token(TokenType.identifier, span, value: span.text));
  }

  void _scanNumber(int start) {
    if (_peek() == 0x2D) _pos++; // leading minus

    // Hex integer: 0x...
    if (_peek() == 0x30 && (_peek(1) == 0x78 || _peek(1) == 0x58)) {
      _pos += 2;
      final hexStart = _pos;
      while (!_atEnd && _isHexDigit(_peek())) {
        _pos++;
      }
      if (_pos == hexStart) {
        _error(start, _pos, 'Hex literal has no digits.');
        return;
      }
      final span = SourceSpan(source, start, _pos);
      _tokens.add(
          Token(TokenType.integerLiteral, span, value: int.parse(span.text)));
      return;
    }

    var isDouble = false;
    while (!_atEnd && _isDigit(_peek())) {
      _pos++;
    }
    // Fractional part: '.' digit+
    if (_peek() == 0x2E && _isDigit(_peek(1))) {
      isDouble = true;
      _pos++; // dot
      while (!_atEnd && _isDigit(_peek())) {
        _pos++;
      }
    }
    // Exponent: (e|E) (+|-)? digit+
    if (_peek() == 0x65 || _peek() == 0x45) {
      final mark = _pos;
      _pos++;
      if (_peek() == 0x2B || _peek() == 0x2D) _pos++;
      if (_isDigit(_peek())) {
        isDouble = true;
        while (!_atEnd && _isDigit(_peek())) {
          _pos++;
        }
      } else {
        // Not actually an exponent; rewind.
        _pos = mark;
      }
    }

    final span = SourceSpan(source, start, _pos);
    if (isDouble) {
      _tokens.add(
          Token(TokenType.doubleLiteral, span, value: double.parse(span.text)));
    } else {
      _tokens.add(
          Token(TokenType.integerLiteral, span, value: int.parse(span.text)));
    }
  }

  void _scanString(int start, int quote) {
    _pos++; // opening quote
    final buffer = StringBuffer();
    while (!_atEnd) {
      final c = _peek();
      if (c == quote) {
        _pos++; // closing quote
        final span = SourceSpan(source, start, _pos);
        _tokens.add(
            Token(TokenType.stringLiteral, span, value: buffer.toString()));
        return;
      }
      if (c == 0x0A) {
        break; // newline before closing quote -> unterminated
      }
      if (c == 0x5C) {
        // escape
        _pos++;
        if (!_appendEscape(buffer, start)) return;
      } else {
        buffer.writeCharCode(c);
        _pos++;
      }
    }
    _error(start, _pos, 'Unterminated string literal.');
  }

  /// Consumes one escape sequence (the backslash has already been consumed) and
  /// appends its value to [buffer]. Returns false on a fatal error.
  bool _appendEscape(StringBuffer buffer, int stringStart) {
    if (_atEnd) {
      _error(stringStart, _pos, 'Unterminated escape sequence.');
      return false;
    }
    final e = _peek();
    _pos++;
    switch (e) {
      case 0x62: // \b
        buffer.writeCharCode(0x08);
      case 0x66: // \f
        buffer.writeCharCode(0x0C);
      case 0x6E: // \n
        buffer.writeCharCode(0x0A);
      case 0x72: // \r
        buffer.writeCharCode(0x0D);
      case 0x74: // \t
        buffer.writeCharCode(0x09);
      case 0x22: // \"
      case 0x27: // \'
      case 0x2F: // \/
      case 0x5C: // \\
        buffer.writeCharCode(e);
      case 0x75: // \uXXXX
        var code = 0;
        for (var i = 0; i < 4; i++) {
          final h = _peek();
          if (!_isHexDigit(h)) {
            _error(stringStart, _pos,
                r'Invalid \u escape: expected 4 hex digits.');
            return false;
          }
          code = (code << 4) | _hexValue(h);
          _pos++;
        }
        buffer.writeCharCode(code);
      default:
        _error(stringStart, _pos, 'Invalid escape sequence: ${_describe(e)}.');
        return false;
    }
    return true;
  }

  void _emit(TokenType type, int start, int end) {
    _tokens.add(Token(type, SourceSpan(source, start, end)));
  }

  void _error(int start, int end, String message) {
    _diagnostics.add(
        Diagnostic(Severity.error, message, SourceSpan(source, start, end)));
  }

  static bool _isDigit(int c) => c >= 0x30 && c <= 0x39;
  static bool _isHexDigit(int c) =>
      _isDigit(c) || (c >= 0x41 && c <= 0x46) || (c >= 0x61 && c <= 0x66);
  static int _hexValue(int c) {
    if (_isDigit(c)) return c - 0x30;
    if (c >= 0x41 && c <= 0x46) return c - 0x41 + 10;
    return c - 0x61 + 10;
  }

  static bool _isIdentifierStart(int c) =>
      c == 0x5F || (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
  static bool _isIdentifierPart(int c) => _isIdentifierStart(c) || _isDigit(c);

  static String _describe(int c) => c < 0
      ? '<eof>'
      : "'${String.fromCharCode(c)}' (U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')})";
}
