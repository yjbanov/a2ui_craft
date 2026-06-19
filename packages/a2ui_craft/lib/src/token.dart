import 'source.dart';

/// The kinds of tokens produced by the A2UI Craft [Lexer].
enum TokenType {
  // Literals and names.
  identifier,
  integerLiteral,
  doubleLiteral,
  stringLiteral,

  // Punctuation.
  openBrace, // {
  closeBrace, // }
  openParen, // (
  closeParen, // )
  openBracket, // [
  closeBracket, // ]
  colon, // :
  semicolon, // ;
  comma, // ,
  dot, // .
  equals, // =
  ellipsis, // ...

  // End of input.
  eof,
}

/// A lexical token with its [type], the raw [span] it covers, and, for
/// literals, the decoded [value].
class Token {
  Token(this.type, this.span, {this.value});

  final TokenType type;
  final SourceSpan span;

  /// The decoded value of a literal token:
  ///  * [String] for [TokenType.stringLiteral] and [TokenType.identifier],
  ///  * [int] for [TokenType.integerLiteral],
  ///  * [double] for [TokenType.doubleLiteral],
  ///  * `null` otherwise.
  final Object? value;

  /// The raw source lexeme for this token.
  String get lexeme => span.text;

  @override
  String toString() => '${type.name}(${lexeme.replaceAll('\n', r'\n')})';
}
