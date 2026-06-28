// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A framework-neutral Markdown model for the `Markdown` primitive.
///
/// [parseMarkdown] turns a Markdown string into a small list of [MarkdownBlock]s
/// (headings, paragraphs, lists) of styled [MarkdownSpan]s. Parsing happens
/// **here, in the core** — like the value-type decoders in `value_types.dart` —
/// so every adapter renders the *same* model and they cannot silently disagree
/// about what a document means. Adapters render the model **structurally** (their
/// own headings/paragraphs/lists/emphasis), never by injecting raw HTML, so no
/// untrusted markup reaches the host.
///
/// The supported subset covers the common agent-output cases: ATX/Setext
/// headings, paragraphs, ordered/unordered lists, and inline **bold**, *italic*,
/// `code`, and `[links](url)`. Block quotes, code fences, images, and tables are
/// flattened to their text for now (future work).
library;

import 'package:markdown/markdown.dart' as md;

/// A block-level element of a parsed Markdown document.
sealed class MarkdownBlock {
  const MarkdownBlock();
}

/// A heading of [level] 1–6.
final class MarkdownHeading extends MarkdownBlock {
  const MarkdownHeading(this.level, this.spans);

  /// The heading level, 1 (largest) to 6.
  final int level;

  /// The heading's inline content.
  final List<MarkdownSpan> spans;
}

/// A paragraph of inline content.
final class MarkdownParagraph extends MarkdownBlock {
  const MarkdownParagraph(this.spans);

  /// The paragraph's inline content.
  final List<MarkdownSpan> spans;
}

/// An ordered or unordered list. Each item is its own run of inline content.
final class MarkdownList extends MarkdownBlock {
  const MarkdownList(this.ordered, this.items);

  /// Whether the list is numbered (`1.`) rather than bulleted (`-`).
  final bool ordered;

  /// The inline content of each list item, in order.
  final List<List<MarkdownSpan>> items;
}

/// A run of inline text with uniform styling.
final class MarkdownSpan {
  const MarkdownSpan(
    this.text, {
    this.bold = false,
    this.italic = false,
    this.code = false,
    this.href,
  });

  /// The literal text of the run.
  final String text;

  /// Whether the run is bold (`**…**`).
  final bool bold;

  /// Whether the run is italic (`*…*`).
  final bool italic;

  /// Whether the run is inline code (`` `…` ``).
  final bool code;

  /// The link target if the run is part of a `[text](href)` link, else null.
  final String? href;
}

/// Parses [source] into a list of [MarkdownBlock]s. Returns an empty list for
/// empty input.
List<MarkdownBlock> parseMarkdown(String source) {
  if (source.trim().isEmpty) return const <MarkdownBlock>[];
  // `encodeHtml: false` keeps text as-is (no `&amp;`); we render structurally,
  // so HTML entity encoding would only corrupt the visible text.
  final md.Document document = md.Document(encodeHtml: false);
  final List<md.Node> nodes = document.parse(source);
  final List<MarkdownBlock> blocks = <MarkdownBlock>[];
  for (final md.Node node in nodes) {
    _appendBlock(node, blocks);
  }
  return blocks;
}

void _appendBlock(md.Node node, List<MarkdownBlock> out) {
  if (node is md.Text) {
    final String t = node.text.trim();
    if (t.isNotEmpty)
      out.add(MarkdownParagraph(<MarkdownSpan>[MarkdownSpan(t)]));
    return;
  }
  if (node is! md.Element) return;
  switch (node.tag) {
    case 'h1':
    case 'h2':
    case 'h3':
    case 'h4':
    case 'h5':
    case 'h6':
      out.add(MarkdownHeading(
          int.parse(node.tag.substring(1)), _inlineSpans(node.children)));
    case 'p':
      out.add(MarkdownParagraph(_inlineSpans(node.children)));
    case 'ul':
    case 'ol':
      final List<List<MarkdownSpan>> items = <List<MarkdownSpan>>[];
      for (final md.Node child in node.children ?? const <md.Node>[]) {
        if (child is md.Element && child.tag == 'li') {
          items.add(_inlineSpans(child.children));
        }
      }
      out.add(MarkdownList(node.tag == 'ol', items));
    case 'blockquote':
    case 'pre':
      // Render the contents as their own blocks (a quote/code fence degrades to
      // its text for now).
      for (final md.Node child in node.children ?? const <md.Node>[]) {
        _appendBlock(child, out);
      }
    default:
      out.add(MarkdownParagraph(_inlineSpans(node.children)));
  }
}

/// Flattens an inline subtree into styled spans, accumulating the styling of
/// each enclosing `strong`/`em`/`code`/`a` element.
List<MarkdownSpan> _inlineSpans(
  List<md.Node>? nodes, {
  bool bold = false,
  bool italic = false,
  bool code = false,
  String? href,
}) {
  final List<MarkdownSpan> spans = <MarkdownSpan>[];
  for (final md.Node node in nodes ?? const <md.Node>[]) {
    if (node is md.Text) {
      spans.add(MarkdownSpan(node.text,
          bold: bold, italic: italic, code: code, href: href));
    } else if (node is md.Element) {
      switch (node.tag) {
        case 'strong':
          spans.addAll(_inlineSpans(node.children,
              bold: true, italic: italic, code: code, href: href));
        case 'em':
          spans.addAll(_inlineSpans(node.children,
              bold: bold, italic: true, code: code, href: href));
        case 'code':
          spans.add(MarkdownSpan(_textOf(node),
              bold: bold, italic: italic, code: true, href: href));
        case 'a':
          spans.addAll(_inlineSpans(node.children,
              bold: bold,
              italic: italic,
              code: code,
              href: node.attributes['href'] ?? href));
        default:
          spans.addAll(_inlineSpans(node.children,
              bold: bold, italic: italic, code: code, href: href));
      }
    }
  }
  return spans;
}

/// The concatenated text of an element's descendants.
String _textOf(md.Element element) {
  final StringBuffer buffer = StringBuffer();
  void visit(md.Node node) {
    if (node is md.Text) {
      buffer.write(node.text);
    } else if (node is md.Element) {
      for (final md.Node child in node.children ?? const <md.Node>[]) {
        visit(child);
      }
    }
  }

  visit(element);
  return buffer.toString();
}
