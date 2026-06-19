import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

List<Token> lex(String code) =>
    Lexer(SourceFile(Uri.parse('memory:test.craft'), code)).tokenize();

void main() {
  group('Lexer', () {
    test('tokenizes punctuation and identifiers', () {
      final tokens = lex('widget Foo = Text(text: "hi");');
      expect(tokens.map((t) => t.type), [
        TokenType.identifier, // widget
        TokenType.identifier, // Foo
        TokenType.equals,
        TokenType.identifier, // Text
        TokenType.openParen,
        TokenType.identifier, // text
        TokenType.colon,
        TokenType.stringLiteral,
        TokenType.closeParen,
        TokenType.semicolon,
        TokenType.eof,
      ]);
      expect(tokens[1].value, 'Foo');
      expect(tokens[7].value, 'hi');
    });

    test('distinguishes integers, doubles, and hex', () {
      final tokens = lex('42 -3 1.5 2e3 6.0e-2 0xFF');
      expect(tokens[0].type, TokenType.integerLiteral);
      expect(tokens[0].value, 42);
      expect(tokens[1].value, -3);
      expect(tokens[2].type, TokenType.doubleLiteral);
      expect(tokens[2].value, 1.5);
      expect(tokens[3].type, TokenType.doubleLiteral);
      expect(tokens[3].value, 2000.0);
      expect(tokens[4].value, 0.06);
      expect(tokens[5].type, TokenType.integerLiteral);
      expect(tokens[5].value, 255);
    });

    test('handles string escapes including unicode', () {
      final tokens = lex(r'"a\nb\tA\"end" ' "'single'");
      expect(tokens[0].value, 'a\nb\tA"end');
      expect(tokens[1].value, 'single');
    });

    test('skips line and block comments', () {
      final tokens = lex('''
        // a line comment
        foo /* block
        spanning lines */ bar
      ''');
      expect(tokens.map((t) => t.type),
          [TokenType.identifier, TokenType.identifier, TokenType.eof]);
      expect(tokens[0].value, 'foo');
      expect(tokens[1].value, 'bar');
    });

    test('lexes the ellipsis spread token', () {
      final tokens = lex('...for');
      expect(tokens[0].type, TokenType.ellipsis);
      expect(tokens[1].type, TokenType.identifier);
      expect(tokens[1].value, 'for');
    });

    test('reports unterminated strings as errors', () {
      expect(() => lex('"oops'), throwsA(isA<CompileException>()));
    });

    test('reports unterminated block comments as errors', () {
      expect(() => lex('/* never closed'), throwsA(isA<CompileException>()));
    });
  });
}
