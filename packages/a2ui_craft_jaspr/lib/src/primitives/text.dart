// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The text-content primitives — `Text`, `Heading`, `Markdown`, `Icon` — and
/// the ambient body/caption styling they share. These are the layer-3 content
/// consumers of a control's [ContentInk].
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'content_ink.dart';
import 'support.dart';

/// Builds `Text`: a plain span of body or caption text.
Component buildText(BuildContext context, DataSource source) {
  final String text = _readText(source, const <Object>['text']);
  final TextVariant variant = TextVariant.parse(source.v<String>(['variant']));
  if (variant == TextVariant.caption) {
    return span(
      styles: Styles(raw: <String, String>{
        'font-size': roleSize(context, ThemeRoles.captionSize) ?? '12px',
        'color': ContentInk.of(context) ??
            roleColor(context, ThemeRoles.onSurfaceVariant) ??
            kCaptionFallback,
      }),
      <Component>[Component.text(text)],
    );
  }
  // Always wrap in a <span>, even unthemed (no styles). A bare text node is
  // not an element, so the CSS flexbox spec merges a run of adjacent text
  // nodes into a *single* anonymous flex item — collapsing sibling `Text`s
  // into one child, so the parent `Row`/`Column`'s gap and alignment never
  // separate them. A span is its own in-flow flex item (blockified by the
  // container) yet still flows inline when the parent isn't a flex, matching a
  // Flutter `Text`, which is always its own layout child.
  final Styles? style = _bodyStyle(context);
  return span(styles: style, <Component>[Component.text(text)]);
}

/// Builds `Heading`: a single heading line carrying a real heading role +
/// `level` (1–6) for assistive tech (an `h1`–`h6` element) — distinct from
/// `Text`, a plain span. Kept simple: one line, no inline markup (use
/// `Markdown` for rich content).
Component buildHeading(BuildContext context, DataSource source) {
  final int level = (source.v<int>(['level']) ?? 1).clamp(1, 6);
  return _mdHeading(
    level,
    context,
    <Component>[
      Component.text(_readText(source, const <Object>['text']))
    ],
  );
}

/// Builds `Markdown`: renders a Markdown string (parsed in the core) as
/// headings, paragraphs, and lists with inline emphasis — structurally, never
/// as raw HTML.
Component buildMarkdown(BuildContext context, DataSource source) =>
    _markdown(source.v<String>(['text']) ?? '', context);

/// Builds `Icon`: a named glyph inked by the nearest [ContentInk] or the
/// ambient `onSurface` role.
Component buildIcon(BuildContext context, DataSource source) {
  final String? color =
      ContentInk.of(context) ?? roleColor(context, ThemeRoles.onSurface);
  return i(
    classes: 'material-icons',
    styles:
        color == null ? null : Styles(raw: <String, String>{'color': color}),
    <Component>[
      Component.text(_iconLigature(source.v<String>(['icon'])))
    ],
  );
}

/// Reads a text-sink argument, coercing a numeric value to its string form.
///
/// Templates routinely bind numbers into text sinks — a counter's `count`, a
/// computed total from a function like `add`. RFW's `v<String>` is strict (a
/// number reads back as null), so coerce here. Returns '' when the value is
/// absent (or itself null, e.g. a total function given bad input).
///
/// An integer-valued double is rendered without a trailing `.0` so the result is
/// identical on every adapter: the Dart VM and dart2js disagree on
/// `(4.0).toString()` ("4.0" vs "4"), which would otherwise make `divide(20, 5)`
/// (and any whole-valued computation) render differently on Flutter vs Jaspr.
String _readText(DataSource source, List<Object> key) {
  final String? string = source.v<String>(key);
  if (string != null) {
    return string;
  }
  final int? integer = source.v<int>(key);
  if (integer != null) {
    return integer.toString();
  }
  final double? number = source.v<double>(key);
  if (number != null) {
    return numberToDisplayString(number);
  }
  return '';
}

/// The `Markdown` body, from the core's neutral [MarkdownBlock] model (the
/// Flutter adapter renders the same model with widgets), as DOM
/// headings/paragraphs/lists with `strong`/`em`/`code`/`a` emphasis — never raw
/// HTML.
Component _markdown(String source, BuildContext context) {
  final List<MarkdownBlock> blocks = parseMarkdown(source);
  // Body color/size land on the wrapper and cascade to paragraphs and lists
  // (CSS inheritance is the base-style threading the Flutter adapter does by
  // hand); headings and links override their own properties below.
  return div(
    styles: _bodyStyle(context),
    <Component>[
      for (final MarkdownBlock block in blocks) _mdBlock(block, context)
    ],
  );
}

Component _mdBlock(MarkdownBlock block, BuildContext context) =>
    switch (block) {
      MarkdownHeading(:final int level, :final List<MarkdownSpan> spans) =>
        _mdHeading(level, context, _mdInline(spans, context)),
      MarkdownParagraph(:final List<MarkdownSpan> spans) =>
        p(_mdInline(spans, context)),
      MarkdownList(
        :final bool ordered,
        :final List<List<MarkdownSpan>> items
      ) =>
        ordered
            ? ol(<Component>[
                for (final List<MarkdownSpan> item in items)
                  li(_mdInline(item, context)),
              ])
            : ul(<Component>[
                for (final List<MarkdownSpan> item in items)
                  li(_mdInline(item, context)),
              ]),
    };

Component _mdHeading(
    int level, BuildContext context, List<Component> children) {
  final String? size = roleSize(context, ThemeRoles.headingSize(level));
  final String? color = roleColor(context, ThemeRoles.onSurface);
  // Unthemed headings keep the browser's default h1–h6 rendering (the host
  // default on this adapter, as the Flutter ramp is on that one).
  final Styles? styles = (size == null && color == null)
      ? null
      : Styles(raw: <String, String>{
          if (size != null) 'font-size': size,
          if (color != null) 'color': color,
        });
  return switch (level) {
    1 => h1(styles: styles, children),
    2 => h2(styles: styles, children),
    3 => h3(styles: styles, children),
    4 => h4(styles: styles, children),
    5 => h5(styles: styles, children),
    _ => h6(styles: styles, children),
  };
}

List<Component> _mdInline(List<MarkdownSpan> spans, BuildContext context) =>
    <Component>[for (final MarkdownSpan span in spans) _mdSpan(span, context)];

Component _mdSpan(MarkdownSpan span, BuildContext context) {
  Component node = Component.text(span.text);
  if (span.code) node = code(<Component>[node]);
  if (span.italic) node = em(<Component>[node]);
  if (span.bold) node = strong(<Component>[node]);
  final String? href = span.href;
  if (href != null) {
    final String? link = roleColor(context, ThemeRoles.link);
    node = a(
      <Component>[node],
      href: href,
      styles:
          link == null ? null : Styles(raw: <String, String>{'color': link}),
    );
  }
  return node;
}

/// The ambient body-text style, or null when neither role is themed — an
/// unthemed surface must render exactly the pre-theming DOM (DESIGN.md §9.4).
Styles? _bodyStyle(BuildContext context) {
  // A control's content ink (e.g. a Button's `onPrimary`) is nearer than the
  // ambient `onSurface` role — the control owns its content layer (DESIGN.md
  // §8, the paint model). Unthemed bare text nodes need no styled wrapper:
  // they inherit the CSS `color` the control sets on its own element.
  final String? color =
      ContentInk.of(context) ?? roleColor(context, ThemeRoles.onSurface);
  final String? size = roleSize(context, ThemeRoles.bodySize);
  if (color == null && size == null) return null;
  return Styles(raw: <String, String>{
    if (size != null) 'font-size': size,
    if (color != null) 'color': color,
  });
}

/// Maps a (subset of) A2UI icon names to Material-Icons ligatures, matching the
/// Flutter adapter's set; unmapped names fall back to a generic glyph.
String _iconLigature(String? name) => switch (name) {
      'accountCircle' => 'account_circle',
      'add' => 'add',
      'arrowBack' => 'arrow_back',
      'arrowForward' => 'arrow_forward',
      'attachFile' => 'attach_file',
      'calendarToday' || 'event' => 'event',
      'call' || 'phone' => 'call',
      'camera' => 'camera_alt',
      'check' => 'check',
      'close' => 'close',
      'delete' => 'delete',
      'directionsRun' || 'directions_run' => 'directions_run',
      'download' => 'download',
      'edit' => 'edit',
      'error' => 'error',
      'info' => 'info',
      'email' || 'mail' => 'email',
      'favorite' => 'favorite',
      'favoriteOff' => 'favorite_border',
      'folder' => 'folder',
      'help' => 'help',
      'location' || 'place' || 'locationOn' => 'place',
      'notifications' => 'notifications',
      'pause' => 'pause',
      'person' => 'person',
      'play' || 'playArrow' => 'play_arrow',
      'settings' => 'settings',
      'skipNext' => 'skip_next',
      'skipPrevious' => 'skip_previous',
      'star' => 'star',
      _ => 'help_outline',
    };
