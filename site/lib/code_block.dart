// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// A syntax-coloured block of Craft template source.
///
/// Deliberately tiny, and deliberately not a dependency. A real highlighter is
/// a JavaScript bundle and a stylesheet fetched from somewhere, for a page that
/// shows a handful of short templates in one language nobody else's highlighter
/// knows anyway. This tokenizer is ~40 lines, ships in the same Dart, and
/// degrades honestly: anything it fails to classify renders as plain text in
/// the body colour rather than as the wrong colour.
class CraftCode extends StatelessComponent {
  const CraftCode({required this.source, this.label, super.key});

  /// The template source, shown verbatim.
  final String source;

  /// An optional filename shown above the code, like an editor tab.
  final String? label;

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'code-block',
      <Component>[
        if (label != null)
          div(classes: 'code-label', <Component>[Component.text(label!)]),
        pre(
          classes: 'code-pre',
          <Component>[code(_spans(source))],
        ),
      ],
    );
  }

  List<Component> _spans(String src) => <Component>[
        for (final _Token t in _tokenize(src))
          if (t.kind == _Kind.plain)
            Component.text(t.text)
          else
            span(classes: t.kind.cssClass, <Component>[Component.text(t.text)]),
      ];
}

enum _Kind {
  plain(''),
  keyword('tok-kw'),
  string('tok-str'),
  number('tok-num'),
  comment('tok-com'),
  // A name in call position — a widget being composed, or a function.
  call('tok-call');

  const _Kind(this.cssClass);

  final String cssClass;
}

class _Token {
  const _Token(this.kind, this.text);

  final _Kind kind;
  final String text;
}

/// The words the template language gives meaning to.
const Set<String> _keywords = <String>{
  'import',
  'widget',
  'set',
  'state',
  'args',
  'data',
  'switch',
  'for',
  'in',
  'event',
  'true',
  'false',
  'null',
};

final RegExp _wordChar = RegExp(r'[A-Za-z0-9_]');
final RegExp _digit = RegExp(r'[0-9]');

/// Splits [src] into coloured runs.
///
/// A hand-rolled scanner rather than one regex per token type: the kinds
/// overlap (a keyword inside a string is a string, a number inside a comment is
/// a comment), and precedence between competing regexes is exactly the sort of
/// thing that goes subtly wrong and colours half a line.
List<_Token> _tokenize(String src) {
  final List<_Token> out = <_Token>[];
  final StringBuffer plain = StringBuffer();
  void flush() {
    if (plain.isEmpty) return;
    out.add(_Token(_Kind.plain, plain.toString()));
    plain.clear();
  }

  int i = 0;
  while (i < src.length) {
    final String c = src[i];

    // A line comment runs to the end of the line, whatever it contains.
    if (c == '/' && i + 1 < src.length && src[i + 1] == '/') {
      final int end = src.indexOf('\n', i);
      final int stop = end == -1 ? src.length : end;
      flush();
      out.add(_Token(_Kind.comment, src.substring(i, stop)));
      i = stop;
      continue;
    }

    // A string runs to its closing quote; nothing inside it is anything else.
    if (c == '"' || c == "'") {
      int j = i + 1;
      while (j < src.length && src[j] != c) {
        // A backslash escapes the next character, closing quote included.
        j += src[j] == r'\' ? 2 : 1;
      }
      final int stop = j < src.length ? j + 1 : src.length;
      flush();
      out.add(_Token(_Kind.string, src.substring(i, stop)));
      i = stop;
      continue;
    }

    if (_digit.hasMatch(c)) {
      int j = i;
      while (j < src.length && (_digit.hasMatch(src[j]) || src[j] == '.')) {
        j++;
      }
      flush();
      out.add(_Token(_Kind.number, src.substring(i, j)));
      i = j;
      continue;
    }

    if (_wordChar.hasMatch(c)) {
      int j = i;
      while (j < src.length && _wordChar.hasMatch(src[j])) {
        j++;
      }
      final String word = src.substring(i, j);
      if (_keywords.contains(word)) {
        flush();
        out.add(_Token(_Kind.keyword, word));
      } else if (j < src.length && src[j] == '(') {
        // Call position: a widget being composed or a function being applied.
        flush();
        out.add(_Token(_Kind.call, word));
      } else {
        plain.write(word);
      }
      i = j;
      continue;
    }

    plain.write(c);
    i++;
  }
  flush();
  return out;
}
