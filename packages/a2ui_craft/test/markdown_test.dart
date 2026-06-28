// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

void main() {
  group('parseMarkdown', () {
    test('empty input yields no blocks', () {
      expect(parseMarkdown(''), isEmpty);
      expect(parseMarkdown('   \n  '), isEmpty);
    });

    test('parses ATX headings with their level', () {
      final List<MarkdownBlock> blocks = parseMarkdown('### Title');
      expect(blocks, hasLength(1));
      final MarkdownHeading heading = blocks.single as MarkdownHeading;
      expect(heading.level, 3);
      expect(heading.spans.single.text, 'Title');
    });

    test('parses inline bold, italic, and code in a paragraph', () {
      final List<MarkdownBlock> blocks =
          parseMarkdown('Some **bold**, *italic*, and `code`.');
      final MarkdownParagraph para = blocks.single as MarkdownParagraph;
      final MarkdownSpan bold =
          para.spans.firstWhere((MarkdownSpan s) => s.bold);
      final MarkdownSpan italic =
          para.spans.firstWhere((MarkdownSpan s) => s.italic);
      final MarkdownSpan code =
          para.spans.firstWhere((MarkdownSpan s) => s.code);
      expect(bold.text, 'bold');
      expect(italic.text, 'italic');
      expect(code.text, 'code');
    });

    test('flattens nested emphasis (bold + italic)', () {
      final List<MarkdownBlock> blocks = parseMarkdown('**_both_**');
      final MarkdownParagraph para = blocks.single as MarkdownParagraph;
      final MarkdownSpan span = para.spans.single;
      expect(span.text, 'both');
      expect(span.bold, isTrue);
      expect(span.italic, isTrue);
    });

    test('captures a link target', () {
      final List<MarkdownBlock> blocks =
          parseMarkdown('[Google](https://google.com)');
      final MarkdownParagraph para = blocks.single as MarkdownParagraph;
      final MarkdownSpan link = para.spans.single;
      expect(link.text, 'Google');
      expect(link.href, 'https://google.com');
    });

    test('parses unordered and ordered lists with one run per item', () {
      final MarkdownList bullet =
          parseMarkdown('- one\n- two').single as MarkdownList;
      expect(bullet.ordered, isFalse);
      expect(bullet.items.map((List<MarkdownSpan> i) => i.single.text),
          <String>['one', 'two']);

      final MarkdownList numbered =
          parseMarkdown('1. first\n2. second').single as MarkdownList;
      expect(numbered.ordered, isTrue);
      expect(numbered.items, hasLength(2));
    });

    test('parses a multi-block document in order', () {
      final List<MarkdownBlock> blocks = parseMarkdown('# H\n\nbody\n\n- item');
      expect(blocks.map((MarkdownBlock b) => b.runtimeType), <Type>[
        MarkdownHeading,
        MarkdownParagraph,
        MarkdownList,
      ]);
    });
  });
}
