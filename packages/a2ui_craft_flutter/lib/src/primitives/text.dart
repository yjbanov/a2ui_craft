// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The text-content primitives — `Text`, `Heading`, `Markdown`, `Icon` — and
/// the ambient body/caption styling they share. These are the layer-3 content
/// consumers of a control's [ContentInk].
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'content_ink.dart';
import 'support.dart';

/// Builds `Text`: a plain span of body or caption text.
Widget buildText(BuildContext context, DataSource source) {
  final TextVariant variant = TextVariant.parse(source.v<String>(['variant']));
  return Text(
    _readText(source, const <Object>['text']),
    style: variant == TextVariant.caption
        ? TextStyle(
            fontSize: roleSize(context, ThemeRoles.captionSize) ?? 12,
            color: ContentInk.of(context) ??
                roleColor(context, ThemeRoles.onSurfaceVariant) ??
                _captionFallback(context),
          )
        : _bodyStyle(context),
  );
}

/// Builds `Heading`: a single heading line carrying a real heading role +
/// `level` (1–6) for assistive tech — distinct from `Text`, which is a plain
/// span. Kept simple: one line, no inline markup (use `Markdown` for rich
/// content).
Widget buildHeading(BuildContext context, DataSource source) {
  final int level = (source.v<int>(['level']) ?? 1).clamp(1, 6);
  return Semantics(
    headingLevel: level,
    child: Text(
      _readText(source, const <Object>['text']),
      style: _mdHeadingStyle(level, context),
    ),
  );
}

/// Builds `Markdown`: renders a Markdown string (parsed in the core) as
/// headings, paragraphs, and lists with inline emphasis — structurally, never
/// as raw HTML.
Widget buildMarkdown(BuildContext context, DataSource source) =>
    _markdown(source.v<String>(['text']) ?? '', context);

/// Builds `Icon`: a named glyph inked by the nearest [ContentInk] or the
/// ambient `onSurface` role.
Widget buildIcon(BuildContext context, DataSource source) {
  return Icon(
    _iconData(source.v<String>(['icon'])),
    color: ContentInk.of(context) ?? roleColor(context, ThemeRoles.onSurface),
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

/// The `Markdown` body: the core parses the source into a neutral
/// [MarkdownBlock] model, and this renders it as Flutter widgets (headings,
/// paragraphs, and lists with inline emphasis). The Jaspr adapter renders the
/// same model with DOM elements.
Widget _markdown(String source, BuildContext context) {
  final List<MarkdownBlock> blocks = parseMarkdown(source);
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      for (final MarkdownBlock block in blocks) _mdBlock(block, context)
    ],
  );
}

Widget _mdBlock(MarkdownBlock block, BuildContext context) => switch (block) {
      MarkdownHeading(:final int level, :final List<MarkdownSpan> spans) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Semantics(
            headingLevel: level,
            child: _mdInline(spans, context,
                base: _mdHeadingStyle(level, context)),
          ),
        ),
      MarkdownParagraph(:final List<MarkdownSpan> spans) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _mdInline(spans, context, base: _bodyStyle(context)),
        ),
      MarkdownList(
        :final bool ordered,
        :final List<List<MarkdownSpan>> items
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (int i = 0; i < items.length; i++)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(ordered ? '${i + 1}. ' : '• ',
                      style: _bodyStyle(context)),
                  _mdInline(items[i], context, base: _bodyStyle(context)),
                ],
              ),
          ],
        ),
    };

/// Renders a run of spans. A single span becomes a plain `Text` (so the
/// behavioral conformance harness's `find.text` can locate it); multiple spans
/// become a `Text.rich`.
Widget _mdInline(List<MarkdownSpan> spans, BuildContext context,
    {TextStyle? base}) {
  if (spans.length == 1) {
    return Text(spans.first.text,
        style: _mdSpanStyle(spans.first, base, context));
  }
  return Text.rich(TextSpan(children: <InlineSpan>[
    for (final MarkdownSpan span in spans)
      TextSpan(text: span.text, style: _mdSpanStyle(span, base, context)),
  ]));
}

TextStyle _mdSpanStyle(
    MarkdownSpan span, TextStyle? base, BuildContext context) {
  TextStyle style = base ?? const TextStyle();
  if (span.bold) style = style.copyWith(fontWeight: FontWeight.bold);
  if (span.italic) style = style.copyWith(fontStyle: FontStyle.italic);
  if (span.code) style = style.copyWith(fontFamily: 'monospace');
  if (span.href != null) {
    style = style.copyWith(
      color: roleColor(context, ThemeRoles.link) ?? _linkFallback(context),
      decoration: TextDecoration.underline,
    );
  }
  return style;
}

TextStyle _mdHeadingStyle(int level, BuildContext context) {
  const List<double> sizes = <double>[24, 22, 20, 18, 16, 14];
  return TextStyle(
    fontSize: roleSize(context, ThemeRoles.headingSize(level)) ??
        sizes[(level - 1).clamp(0, 5)],
    fontWeight: FontWeight.bold,
    color: roleColor(context, ThemeRoles.onSurface),
  );
}

/// The ambient body-text style, or null when neither role is themed (the host
/// default shows through untouched — an unthemed surface must render exactly
/// as before the semantic contract existed).
TextStyle? _bodyStyle(BuildContext context) {
  // A control's content ink (e.g. a Button's `onPrimary`) is nearer than the
  // ambient `onSurface` role — the control owns its content layer (DESIGN.md
  // §8, the paint model).
  final Color? color =
      ContentInk.of(context) ?? roleColor(context, ThemeRoles.onSurface);
  final double? size = roleSize(context, ThemeRoles.bodySize);
  if (color == null && size == null) return null;
  return TextStyle(color: color, fontSize: size);
}

// Host-default fallbacks for roles this adapter must ink even unthemed. Card
// and Divider pass a null color through to Material (which already follows
// the host theme's brightness); caption and link have no Material equivalent,
// so they adapt on the theme brightness themselves — mirroring the Jaspr
// adapter's `light-dark()` fallbacks so the pair stays behaviorally identical
// on dark hosts.
Color _captionFallback(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF9AA0A6)
        : const Color(0xFF5F6368);

Color _linkFallback(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF8AB4F8)
        : const Color(0xFF1A73E8);

/// Maps a (subset of) A2UI icon names to Material icons; unmapped names fall
/// back to a generic glyph. The full catalog icon set is future work.
IconData _iconData(String? name) => switch (name) {
      'accountCircle' => Icons.account_circle,
      'add' => Icons.add,
      'arrowBack' => Icons.arrow_back,
      'arrowForward' => Icons.arrow_forward,
      'attachFile' => Icons.attach_file,
      'calendarToday' || 'event' => Icons.event,
      'call' || 'phone' => Icons.call,
      'camera' => Icons.camera_alt,
      'check' => Icons.check,
      'close' => Icons.close,
      'delete' => Icons.delete,
      'directionsRun' || 'directions_run' => Icons.directions_run,
      'download' => Icons.download,
      'edit' => Icons.edit,
      'error' => Icons.error,
      'info' => Icons.info,
      'email' || 'mail' => Icons.email,
      'favorite' => Icons.favorite,
      'favoriteOff' => Icons.favorite_border,
      'folder' => Icons.folder,
      'help' => Icons.help,
      'location' || 'place' || 'locationOn' => Icons.place,
      'notifications' => Icons.notifications,
      'pause' => Icons.pause,
      'person' => Icons.person,
      'play' || 'playArrow' => Icons.play_arrow,
      'settings' => Icons.settings,
      'skipNext' => Icons.skip_next,
      'skipPrevious' => Icons.skip_previous,
      'star' => Icons.star,
      _ => Icons.help_outline,
    };
