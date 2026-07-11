// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The template-language model's `Switch` (the RFW switch expression) is not
// used here and would shadow Material's `Switch` control.
import 'package:a2ui_craft/a2ui_craft.dart' hide Switch;
import 'package:flutter/material.dart';

import 'runtime.dart';

// Design notes (not part of the public API):
// - Each component implements the framework-neutral spec (DESIGN.md §8,
//   Pillar A) using the shared value types (Dimension, FlexAxis, the
//   alignments), rather than mirroring the Jaspr adapter by hand; the contract
//   is verified by package:a2ui_craft_testing (behavioral, and geometric for the
//   Flex/Box slices).
// - Components outside the Flex/Box slices are still seed-grade fixtures.
// - The runtime lifts the reserved `key` onto its reconciliation unit
//   (`_Widget`, DESIGN.md §6), so these builders never read or apply it.
/// A library of standard core components (Text, Flex/Row/Column, Button, …)
/// implemented using Flutter widgets.
///
/// Register the result under the `core` library name; templates then compose
/// these primitives. The reserved `key` argument is handled by the runtime, so
/// the builders here do not read or apply it.
LocalWidgetLibrary createCoreComponents() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'Text': (BuildContext context, DataSource source) {
      final TextVariant variant =
          TextVariant.parse(source.v<String>(['variant']));
      return Text(
        _readText(source, const <Object>['text']),
        style: variant == TextVariant.caption
            ? TextStyle(
                fontSize: _roleSize(context, ThemeRoles.captionSize) ?? 12,
                color: _ContentInk.of(context) ??
                    _roleColor(context, ThemeRoles.onSurfaceVariant) ??
                    _captionFallback(context),
              )
            : _bodyStyle(context),
      );
    },
    // A single heading line carrying a real heading role + `level` (1–6) for
    // assistive tech — distinct from `Text`, which is a plain span. Kept simple:
    // one line, no inline markup (use `Markdown` for rich content).
    'Heading': (BuildContext context, DataSource source) {
      final int level = (source.v<int>(['level']) ?? 1).clamp(1, 6);
      return Semantics(
        headingLevel: level,
        child: Text(
          _readText(source, const <Object>['text']),
          style: _mdHeadingStyle(level, context),
        ),
      );
    },
    // Renders a Markdown string (parsed in the core) as headings, paragraphs,
    // and lists with inline emphasis — structurally, never as raw HTML.
    'Markdown': (BuildContext context, DataSource source) =>
        _buildMarkdown(source.v<String>(['text']) ?? '', context),
    // Row, Column, and Flex are one builder over a `FlexAxis`: Row/Column pin
    // the axis, Flex reads it from `direction` (DESIGN.md §8).
    'Flex': (BuildContext context, DataSource source) =>
        _buildFlex(source, FlexAxis.parse(source.v<String>(['direction']))),
    'Row': (BuildContext context, DataSource source) =>
        _buildFlex(source, FlexAxis.horizontal),
    'Column': (BuildContext context, DataSource source) =>
        _buildFlex(source, FlexAxis.vertical),
    'Expanded': (BuildContext context, DataSource source) {
      return Expanded(
        flex: source.v<int>(['flex']) ?? 1,
        child: source.child(['child']),
      );
    },
    'Button': (BuildContext context, DataSource source) {
      final VoidCallback? onPressed = source.voidHandler(['onPressed']);
      final Rgba? color = _rgba(source, 'color');
      final CornerRadius radius = CornerRadius.decode(
          _numArg(source, 'cornerRadius'),
          fallback: _kButtonCornerRadius);
      final Object? rawPadding = _insetsRaw(source, 'padding');
      final Insets padding =
          rawPadding == null ? _kButtonPadding : Insets.decode(rawPadding);
      // Surface + content ink per the role mapping (DESIGN.md §8): unstyled,
      // the idiom's stock button — `primary` surface, `onPrimary` content ink.
      // An explicit color is the author's surface; the ambient ink stands
      // (the author owns the pairing). A transparent color is the "text
      // button" degenerate case: no surface, no ink override.
      final Color? surface;
      final Color? ink;
      if (color != null) {
        surface = color.alpha == 0 ? null : Color(color.value);
        ink = null;
      } else {
        final ColorScheme host = Theme.of(context).colorScheme;
        surface = _roleColor(context, ThemeRoles.primary) ?? host.primary;
        ink = _roleColor(context, ThemeRoles.onPrimary) ?? host.onPrimary;
      }
      return _CoreButton(
        onPressed: onPressed,
        surface: surface,
        ink: ink,
        cornerRadius: radius.pixels,
        padding: _toEdgeInsets(padding),
        child: source.child(['child']),
      );
    },
    'Center': (BuildContext context, DataSource source) {
      return Center(
        child: source.child(['child']),
      );
    },
    // Places its child at an `alignment` within an (optionally sized) box. With
    // no width/height it hugs the child (alignment is then a no-op); a fixed
    // width/height gives the child room to be positioned. Generalizes `Center`.
    'Align': (BuildContext context, DataSource source) {
      final Alignment2D a = Alignment2D.parse(source.v<String>(['alignment']));
      final double? w = source.v<double>(['width']);
      final double? h = source.v<double>(['height']);
      Widget aligned = Align(
        alignment: Alignment(a.x, a.y),
        // A factor of 1.0 shrink-wraps that axis to the child; null fills the
        // (sized) box so the alignment has free space to position within.
        widthFactor: w == null ? 1.0 : null,
        heightFactor: h == null ? 1.0 : null,
        child: source.child(['child']),
      );
      if (w != null || h != null) {
        aligned = SizedBox(width: w, height: h, child: aligned);
      }
      return aligned;
    },
    // Sizes its child to a `ratio` (width ÷ height) within the incoming
    // constraints (Flutter `AspectRatio` / CSS `aspect-ratio`).
    'AspectRatio': (BuildContext context, DataSource source) {
      return AspectRatio(
        aspectRatio: _numArg(source, 'ratio') ?? 1.0,
        child: source.optionalChild(['child']),
      );
    },
    // A run of children that wraps onto the next line/column when they overflow
    // the main axis (Flutter `Wrap` / CSS `flex-wrap`).
    'Wrap': (BuildContext context, DataSource source) {
      final bool horizontal = FlexAxis.parse(source.v<String>(['direction']),
              fallback: FlexAxis.horizontal) ==
          FlexAxis.horizontal;
      return Wrap(
        direction: horizontal ? Axis.horizontal : Axis.vertical,
        spacing: _gap(source),
        runSpacing: _numArg(source, 'runGap') ?? 0.0,
        children: source.childList(['children']),
      );
    },
    // Makes its child partially (or fully) transparent without affecting layout.
    'Opacity': (BuildContext context, DataSource source) {
      return Opacity(
        opacity: (_numArg(source, 'opacity') ?? 1.0).clamp(0.0, 1.0),
        child: source.child(['child']),
      );
    },
    'SizedBox': (BuildContext context, DataSource source) {
      // The child is optional: a childless SizedBox is a fixed-size spacer.
      return SizedBox(
        width: source.v<double>(['width']),
        height: source.v<double>(['height']),
        child: source.optionalChild(['child']),
      );
    },
    'Box': (BuildContext context, DataSource source) => _buildBox(source),
    'Image': (BuildContext context, DataSource source) => _buildImage(source),
    'Icon': (BuildContext context, DataSource source) {
      return Icon(
        _iconData(source.v<String>(['icon'])),
        color: _ContentInk.of(context) ??
            _roleColor(context, ThemeRoles.onSurface),
      );
    },
    'Divider': (BuildContext context, DataSource source) {
      final FlexAxis axis = FlexAxis.parse(source.v<String>(['axis']),
          fallback: FlexAxis.horizontal);
      final Color? color = _roleColor(context, ThemeRoles.outline);
      return axis == FlexAxis.vertical
          ? VerticalDivider(color: color)
          : Divider(color: color);
    },
    'ScrollView': (BuildContext context, DataSource source) {
      return SingleChildScrollView(
        child: source.child(['child']),
      );
    },
    // A scrollable run of children along an axis (A2UI `List`).
    'List': (BuildContext context, DataSource source) {
      final bool horizontal = FlexAxis.parse(source.v<String>(['direction']),
              fallback: FlexAxis.vertical) ==
          FlexAxis.horizontal;
      final CrossAxisAlign align = CrossAxisAlign.parse(
          source.v<String>(['align']),
          fallback: CrossAxisAlign.stretch);
      return SingleChildScrollView(
        scrollDirection: horizontal ? Axis.horizontal : Axis.vertical,
        child: Flex(
          direction: horizontal ? Axis.horizontal : Axis.vertical,
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: _toCrossAxisAlignment(align),
          children: source.childList(['children']),
        ),
      );
    },
    'Card': (BuildContext context, DataSource source) {
      return Card(
        // Material's `Card` defaults to `margin: EdgeInsets.all(4)`, which the
        // Jaspr `Card` (a plain div) has no equivalent for — it would add an
        // invisible 4px inset (and ~8px between stacked cards) on Flutter only.
        // Zero it so the primitive is spacing-neutral on both adapters; spacing
        // between cards is the layout's job (a `Column` `gap`).
        margin: EdgeInsets.zero,
        color: _roleColor(context, ThemeRoles.surface),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: source.child(['child']),
        ),
      );
    },
    // The bare text input — no label. Label placement is a template's choice
    // (see DESIGN.md §4 "Bias to templatize" / §8), composed as a separate Text.
    'TextField': (BuildContext context, DataSource source) {
      return _CoreTextField(
        value: source.v<String>(['value']),
        outline: _roleColor(context, ThemeRoles.outline),
        accent: _roleColor(context, ThemeRoles.primary),
        ink: _roleColor(context, ThemeRoles.onSurface),
        // The `onChanged` arg is a2ui_core's two-way setter (a resolved
        // callback), accepted directly by the runtime's handler affordance.
        onChanged: source.handler<ValueChanged<String>>(
          ['onChanged'],
          (HandlerTrigger trigger) =>
              (String value) => trigger(<String, Object?>{'value': value}),
        ),
      );
    },
    'Checkbox': (BuildContext context, DataSource source) {
      final bool value = source.v<bool>(['value']) ?? false;
      final ValueChanged<bool>? onChanged = source.handler<ValueChanged<bool>>(
        ['onChanged'],
        (HandlerTrigger trigger) =>
            (bool v) => trigger(<String, Object?>{'value': v}),
      );
      // The role mapping (DESIGN.md §8), on the Material idiom's own knobs:
      // `primary` fully fills the checked state, `onPrimary` draws the mark,
      // `outline` inks the unchecked box. Null falls through to the host
      // Material look (blend in, §9.1) — same split as the Jaspr adapter's
      // native-vs-painted glyph.
      final Color? outline = _roleColor(context, ThemeRoles.outline);
      return Checkbox(
        value: value,
        activeColor: _roleColor(context, ThemeRoles.primary),
        checkColor: _roleColor(context, ThemeRoles.onPrimary),
        side: outline == null ? null : BorderSide(color: outline, width: 2),
        onChanged:
            onChanged == null ? null : (bool? v) => onChanged(v ?? !value),
      );
    },
    // A single radio button: shows [selected] and fires `onChanged` when tapped
    // ("select me"). Grouping — which radio is on — is the template's job.
    // TODO(a2ui-craft): revisit. This renders a tappable radio glyph rather than
    // the material `Radio<T>` widget, whose `groupValue`/`onChanged` API is
    // mid-deprecation in Flutter 3.46. Move to `RadioGroup`/`Radio` once that
    // settles, and reconcile the "select-me" event with the native group model.
    'Radio': (BuildContext context, DataSource source) {
      final bool selected = source.v<bool>(['selected']) ?? false;
      final VoidCallback? onChanged = source.voidHandler(['onChanged']);
      return _CoreRadio(
        selected: selected,
        onChanged: onChanged,
        // The role mapping (DESIGN.md §8): `primary` inks the selected glyph,
        // `outline` rings the unselected one; null keeps the host look.
        accent: _roleColor(context, ThemeRoles.primary),
        outline: _roleColor(context, ThemeRoles.outline),
      );
    },
    // A bare on/off switch. Two-way bound like Checkbox; the role mapping
    // (DESIGN.md §8): `primary` fully fills the active track (`onPrimary`
    // inks the thumb riding it), `outline` inks the inactive track's border
    // and thumb; null keeps the host Material look (blend in, §9.1).
    'Switch': (BuildContext context, DataSource source) {
      final bool value = source.v<bool>(['value']) ?? false;
      final ValueChanged<bool>? onChanged = source.handler<ValueChanged<bool>>(
        ['onChanged'],
        (HandlerTrigger trigger) =>
            (bool v) => trigger(<String, Object?>{'value': v}),
      );
      final Color? outline = _roleColor(context, ThemeRoles.outline);
      return Switch(
        value: value,
        activeTrackColor: _roleColor(context, ThemeRoles.primary),
        activeThumbColor: _roleColor(context, ThemeRoles.onPrimary),
        inactiveThumbColor: outline,
        trackOutlineColor: outline == null
            ? null
            : WidgetStateProperty.resolveWith((Set<WidgetState> states) =>
                states.contains(WidgetState.selected) ? null : outline),
        onChanged: onChanged,
      );
    },
    // A single-choice dropdown over string `options` — the bare control;
    // label placement is a template's choice, like TextField. Two-way bound:
    // `onChanged` is a2ui_core's setter for the bound `value`. Shares the
    // TextField chrome (`outline`/`primary`) and ink (`onSurface`).
    'Select': (BuildContext context, DataSource source) {
      final List<String> options = _stringList(source, 'options');
      final String? value = source.v<String>(['value']);
      final ValueChanged<String>? onChanged =
          source.handler<ValueChanged<String>>(
        ['onChanged'],
        (HandlerTrigger trigger) =>
            (String v) => trigger(<String, Object?>{'value': v}),
      );
      final Color? ink = _roleColor(context, ThemeRoles.onSurface);
      return DropdownButtonFormField<String>(
        // An unknown/absent value renders no selection rather than throwing.
        initialValue: options.contains(value) ? value : null,
        decoration: _fieldDecoration(context),
        style: ink == null ? null : TextStyle(color: ink),
        items: <DropdownMenuItem<String>>[
          for (final String option in options)
            DropdownMenuItem<String>(value: option, child: Text(option)),
        ],
        onChanged: onChanged == null
            ? null
            : (String? v) {
                if (v != null) onChanged(v);
              },
      );
    },
    // A bare numeric slider (no label — that is a template's choice). Two-way
    // bound: `onChanged` is a2ui_core's setter for the bound `value`.
    'Slider': (BuildContext context, DataSource source) {
      final double min = _numArg(source, 'min') ?? 0.0;
      final double max = _numArg(source, 'max') ?? 1.0;
      final double value = (_numArg(source, 'value') ?? min).clamp(min, max);
      final int? steps = source.v<int>(['steps']);
      final ValueChanged<double>? onChanged =
          source.handler<ValueChanged<double>>(
        ['onChanged'],
        (HandlerTrigger trigger) =>
            (double v) => trigger(<String, Object?>{'value': v}),
      );
      // The role mapping (DESIGN.md §8): `primary` inks the active track and
      // the thumb (Material's thumbColor follows activeColor), `outline` the
      // inactive track; null keeps the host look.
      return Slider(
        min: min,
        max: max,
        value: value,
        activeColor: _roleColor(context, ThemeRoles.primary),
        inactiveColor: _roleColor(context, ThemeRoles.outline),
        divisions: (steps != null && steps > 0) ? steps : null,
        onChanged: onChanged,
      );
    },
  });
}

/// Reads a numeric argument, accepting an int or double literal.
double? _numArg(DataSource source, String key) =>
    source.v<double>([key]) ?? source.v<int>([key])?.toDouble();

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

/// Builds the `Markdown` primitive: the core parses the source into a neutral
/// [MarkdownBlock] model, and this renders it as Flutter widgets (headings,
/// paragraphs, and lists with inline emphasis). The Jaspr adapter renders the
/// same model with DOM elements.
Widget _buildMarkdown(String source, BuildContext context) {
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
      color: _roleColor(context, ThemeRoles.link) ?? _linkFallback(context),
      decoration: TextDecoration.underline,
    );
  }
  return style;
}

TextStyle _mdHeadingStyle(int level, BuildContext context) {
  const List<double> sizes = <double>[24, 22, 20, 18, 16, 14];
  return TextStyle(
    fontSize: _roleSize(context, ThemeRoles.headingSize(level)) ??
        sizes[(level - 1).clamp(0, 5)],
    fontWeight: FontWeight.bold,
    color: _roleColor(context, ThemeRoles.onSurface),
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
      _ContentInk.of(context) ?? _roleColor(context, ThemeRoles.onSurface);
  final double? size = _roleSize(context, ThemeRoles.bodySize);
  if (color == null && size == null) return null;
  return TextStyle(color: color, fontSize: size);
}

/// Reads a role color from the ambient theme as a Flutter [Color], or null
/// when the surface is unthemed / the theme omits the role — the caller then
/// falls back to the host default (DESIGN.md §9.4).
Color? _roleColor(BuildContext context, String role) {
  final Rgba? rgba = ambientCraftTheme(context)?.tokens.color(role);
  return rgba == null ? null : Color(rgba.value);
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

/// Reads a role size (a `dimension` token, logical pixels) from the ambient
/// theme, or null for the host default.
double? _roleSize(BuildContext context, String role) =>
    ambientCraftTheme(context)?.tokens.dimension(role);

/// Builds a `Flex` (and thus `Row`/`Column`) from the catalog spec, mapping the
/// framework-neutral value types onto Flutter's `Flex`.
///
/// Sizing is **explicit**: a default `Flex` hugs both axes
/// (`MainAxisSize.min` on the main axis; `CrossAxisAlignment.start`, so children
/// keep their intrinsic cross size and align to the leading edge). `fill`/`fixed`
/// opt into filling or a fixed extent. Neither Flutter's nor CSS's native
/// defaults are inherited, so the same template lays out identically here and in
/// the Jaspr adapter.
Widget _buildFlex(DataSource source, FlexAxis axis) {
  final MainAxisAlign main =
      MainAxisAlign.parse(source.v<String>(['mainAxisAlignment']));
  final CrossAxisAlign cross =
      CrossAxisAlign.parse(source.v<String>(['crossAxisAlignment']));
  final double gap = _gap(source);
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));

  final bool horizontal = axis == FlexAxis.horizontal;
  // The main-axis dimension decides whether the Flex shrink-wraps its children
  // (hug → min) or expands to fill the available/fixed main extent so that
  // `mainAxisAlignment` has free space to distribute.
  final Dimension mainDim = horizontal ? width : height;

  final Widget flex = Flex(
    direction: horizontal ? Axis.horizontal : Axis.vertical,
    mainAxisSize: mainDim is HugDimension ? MainAxisSize.min : MainAxisSize.max,
    mainAxisAlignment: _toMainAxisAlignment(main),
    crossAxisAlignment: _toCrossAxisAlignment(cross),
    spacing: gap,
    children: source.childList(['children']),
  );

  return _applySizing(flex, width: width, height: height);
}

/// Reads a raw scalar (a number → a fixed size, or a keyword string) for a
/// `Dimension`-valued argument. `DataSource.v` requires a concrete scalar type,
/// so we probe the few a `Dimension` can take.
Object? _dimRaw(DataSource source, List<Object> key) =>
    source.v<double>(key) ?? source.v<int>(key) ?? source.v<String>(key);

/// Reads the `gap` argument, accepting either an int or double literal.
double _gap(DataSource source) =>
    source.v<double>(['gap']) ?? source.v<int>(['gap'])?.toDouble() ?? 0.0;

/// Builds a `Box` — the catalog's single container primitive (size + padding +
/// margin + background) — from the spec, on the same explicit-sizing and
/// border-box model the Jaspr adapter renders.
///
/// Composition, inside-out: child → padding → fixed/fill size (child placed
/// top-left, like CSS block flow) → background (fills the padded box, not the
/// margin) → margin. `Container` is deliberately *not* used: with an alignment
/// it expands to fill when unsized, which would break `hug`.
///
/// `margin` is rendered as an outer `Padding`, so the keyed node's measured rect
/// includes the margin — matching how the Jaspr adapter wraps margin. Measuring
/// margin as part of the box (rather than excluding it) is the one consistent
/// contract available, since the runtime lifts the key onto the builder's output.
Widget _buildBox(DataSource source) {
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));
  final Insets padding = Insets.decode(_insetsRaw(source, 'padding'));
  final Insets margin = Insets.decode(_insetsRaw(source, 'margin'));
  final Rgba? color = _rgba(source, 'color');

  Widget box = source.optionalChild(['child']) ?? const SizedBox.shrink();

  if (!padding.isZero) {
    box = Padding(padding: _toEdgeInsets(padding), child: box);
  }

  final double? w = _extent(width);
  final double? h = _extent(height);
  if (w != null || h != null) {
    // A definite/fill box places its (smaller) child at the top-left, as a CSS
    // block does — not stretched to fill, which is Flutter's default.
    box = SizedBox(
      width: w,
      height: h,
      child: Align(alignment: Alignment.topLeft, child: box),
    );
  }

  if (color != null) {
    box = ColoredBox(color: Color(color.value), child: box);
  }

  if (!margin.isZero) {
    box = Padding(padding: _toEdgeInsets(margin), child: box);
  }

  return box;
}

/// Gathers a raw inset value (a number or a list of numbers) from [source] so
/// the framework-neutral `Insets.decode` can interpret it. Only the extraction
/// is adapter-specific; the 2-vs-4-element interpretation lives in the core.
Object? _insetsRaw(DataSource source, String key) {
  if (source.isList([key])) {
    final int n = source.length([key]);
    return <double>[
      for (int i = 0; i < n; i++)
        source.v<double>([key, i]) ??
            source.v<int>([key, i])?.toDouble() ??
            0.0,
    ];
  }
  return source.v<double>([key]) ?? source.v<int>([key])?.toDouble();
}

Rgba? _rgba(DataSource source, String key) =>
    Rgba.decode(source.v<String>([key]));

EdgeInsets _toEdgeInsets(Insets i) =>
    EdgeInsets.fromLTRB(i.left, i.top, i.right, i.bottom);

/// Builds an `Image` sized to its [ImageVariant] (so it occupies the same box as
/// the Jaspr adapter) with the requested [ImageFit].
///
/// An empty or `example.com` URL renders a sized placeholder instead of a
/// network image, so widget tests stay deterministic and network-free.
Widget _buildImage(DataSource source) {
  final String? url = source.v<String>(['url']);
  final ImageVariant variant =
      ImageVariant.parse(source.v<String>(['variant']));
  final BoxFit fit = _boxFit(ImageFit.parse(source.v<String>(['fit'])));
  final bool placeholder =
      url == null || url.isEmpty || url.contains('example.com');

  final Widget content = placeholder
      ? const ColoredBox(color: Color(0x1F000000))
      : Image.network(url,
          fit: fit, width: variant.width, height: variant.height);

  Widget box =
      SizedBox(width: variant.width, height: variant.height, child: content);
  if (variant.circular) box = ClipOval(child: box);
  return box;
}

BoxFit _boxFit(ImageFit f) => switch (f) {
      ImageFit.contain => BoxFit.contain,
      ImageFit.cover => BoxFit.cover,
      ImageFit.fill => BoxFit.fill,
      ImageFit.none => BoxFit.none,
      ImageFit.scaleDown => BoxFit.scaleDown,
    };

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

/// Wraps [child] in a `SizedBox` when either axis is `fixed`/`fill`; `hug`
/// leaves the axis unconstrained (shrink-wrap). `fill` resolves to
/// `double.infinity`, which the bounded parent (a sized container, the test
/// harness, …) gives a concrete extent.
Widget _applySizing(Widget child,
    {required Dimension width, required Dimension height}) {
  final double? w = _extent(width);
  final double? h = _extent(height);
  if (w == null && h == null) return child;
  return SizedBox(width: w, height: h, child: child);
}

double? _extent(Dimension d) => switch (d) {
      FixedDimension(:final double pixels) => pixels,
      FillDimension() => double.infinity,
      HugDimension() => null,
      // A container is not itself a flex child, so `flex(n)` has no meaning here.
      FlexDimension() => null,
    };

MainAxisAlignment _toMainAxisAlignment(MainAxisAlign a) => switch (a) {
      MainAxisAlign.start => MainAxisAlignment.start,
      MainAxisAlign.center => MainAxisAlignment.center,
      MainAxisAlign.end => MainAxisAlignment.end,
      MainAxisAlign.spaceBetween => MainAxisAlignment.spaceBetween,
      MainAxisAlign.spaceAround => MainAxisAlignment.spaceAround,
      MainAxisAlign.spaceEvenly => MainAxisAlignment.spaceEvenly,
    };

CrossAxisAlignment _toCrossAxisAlignment(CrossAxisAlign a) => switch (a) {
      CrossAxisAlign.start => CrossAxisAlignment.start,
      CrossAxisAlign.center => CrossAxisAlignment.center,
      CrossAxisAlign.end => CrossAxisAlignment.end,
      CrossAxisAlign.stretch => CrossAxisAlignment.stretch,
    };

/// The stock corner rounding of an unstyled `Button` — the neutral Craft
/// default, shared with the Jaspr adapter so the two web panes agree.
const CornerRadius _kButtonCornerRadius = CornerRadius(6);

/// The stock content padding of a `Button` (layer 3 of the paint model);
/// `padding: 0` opts a fully sized child (e.g. a fixed Box) out of it.
const Insets _kButtonPadding = Insets.symmetric(vertical: 8, horizontal: 16);

/// The content ink a control installs over its subtree — layer 3 of the
/// control paint model (DESIGN.md §8): a `Button` painting its default
/// `primary` surface inks its content `onPrimary`, overriding the ambient
/// `onSurface`/`onSurfaceVariant` role defaults that [_bodyStyle], the caption
/// style, and `Icon` would otherwise read. Content primitives consult this
/// *before* the ambient roles; explicit per-widget props still win over both
/// (the cascade, DESIGN.md §9.5).
class _ContentInk extends InheritedWidget {
  const _ContentInk({required this.color, required super.child});

  final Color color;

  static Color? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ContentInk>()?.color;

  @override
  bool updateShouldNotify(_ContentInk oldWidget) => color != oldWidget.color;
}

/// The control behind the `Button` primitive — owner of all four paint layers
/// (DESIGN.md §8): the [surface] (color + corner shape), the state layer
/// (Material ink splash + hover/focus highlights, drawn on the surface *under*
/// the content), the content placement ([padding], centered), and the
/// composite effects. The child is content, never chrome.
///
/// Behavioral contract (parity with the Jaspr `<button>`): announces a
/// **button role** whose accessible name merges from the child, exposes the
/// enabled/disabled state, participates in focus traversal, and activates from
/// the keyboard ([InkWell] handles Space/Enter via the app-level activation
/// intents).
class _CoreButton extends StatelessWidget {
  const _CoreButton({
    required this.onPressed,
    required this.surface,
    required this.ink,
    required this.cornerRadius,
    required this.padding,
    required this.child,
  });

  final VoidCallback? onPressed;

  /// The surface color; null paints nothing (the "text button" case).
  final Color? surface;

  /// The content ink installed over the child ([_ContentInk]); null leaves the
  /// ambient ink standing (an explicit author surface owns its own pairing).
  final Color? ink;

  final double cornerRadius;
  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onPressed != null;
    final RoundedRectangleBorder shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(cornerRadius),
    );
    Widget content = Padding(
      padding: padding,
      // Hug the content, but center it when the parent stretches the button
      // (e.g. a stretched cross axis) — the Jaspr side is inline-flex with
      // centered alignment.
      child: Center(widthFactor: 1.0, heightFactor: 1.0, child: child),
    );
    if (ink != null) {
      content = _ContentInk(color: ink!, child: content);
    }
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: enabled,
        child: Material(
          color: surface ?? Colors.transparent,
          shape: shape,
          // Clip the state layer (ink splash) to the surface's corners.
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            customBorder: shape,
            onTap: onPressed,
            child: content,
          ),
        ),
      ),
    );
  }
}

/// The radio glyph behind the `Radio` primitive, with the semantics the bare
/// `GestureDetector` + `Icon` lacked: a checked/unchecked state in a mutually
/// exclusive group, enabled/disabled, focus, and keyboard activation — parity
/// with the Jaspr adapter's native `<input type=radio>`. (The glyph itself is
/// still the interim rendering; see the TODO at the registration site.)
class _CoreRadio extends StatelessWidget {
  const _CoreRadio({
    required this.selected,
    required this.onChanged,
    this.accent,
    this.outline,
  });

  final bool selected;
  final VoidCallback? onChanged;

  /// The `color.primary` role, shown by the selected glyph; null keeps the
  /// host look.
  final Color? accent;

  /// The `color.outline` role, ringing the unselected glyph; null keeps the
  /// host look.
  final Color? outline;

  @override
  Widget build(BuildContext context) {
    final bool enabled = onChanged != null;
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: true,
        enabled: enabled,
        child: FocusableActionDetector(
          enabled: enabled,
          actions: <Type, Action<Intent>>{
            ActivateIntent: CallbackAction<ActivateIntent>(
              onInvoke: (ActivateIntent intent) {
                onChanged!();
                return null;
              },
            ),
            ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
              onInvoke: (ButtonActivateIntent intent) {
                onChanged!();
                return null;
              },
            ),
          },
          child: GestureDetector(
            onTap: onChanged,
            child: Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? accent : outline,
            ),
          ),
        ),
      ),
    );
  }
}

/// A text field that reflects an externally-bound [value] (without clobbering
/// the cursor mid-edit) and reports edits through [onChanged] — the two halves
/// of two-way binding.
class _CoreTextField extends StatefulWidget {
  const _CoreTextField(
      {this.value, this.onChanged, this.outline, this.accent, this.ink});

  final String? value;
  final ValueChanged<String>? onChanged;

  /// The `color.outline` role — the field's chrome (a 1px box border, the
  /// stock 6px control corner, 8/12 content padding); null keeps the host's
  /// default decoration (blend in, §9.1). Error states keep the host
  /// emphasis until the contract grows state roles.
  final Color? outline;

  /// The `color.primary` role — the focused border and the caret; null keeps
  /// the host emphasis.
  final Color? accent;

  /// The `color.onSurface` role — the typed text's ink; null inherits.
  final Color? ink;

  @override
  State<_CoreTextField> createState() => _CoreTextFieldState();
}

class _CoreTextFieldState extends State<_CoreTextField> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.value ?? '');

  @override
  void didUpdateWidget(_CoreTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reflect external (data-model) changes, but don't fight the user's cursor
    // for edits that already match.
    if (widget.value != null && widget.value != _controller.text) {
      _controller.text = widget.value!;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      style: widget.ink == null ? null : TextStyle(color: widget.ink),
      cursorColor: widget.accent,
      decoration: _fieldDecorationFor(widget.outline, widget.accent),
      onChanged: widget.onChanged,
    );
  }
}

/// The shared field chrome (DESIGN.md §8), degrading role-by-role: `outline`
/// draws the box (1px border, the stock 6px control corner, 8/12 padding);
/// `primary` the focused border. Used by `TextField` and `Select`; the Jaspr
/// adapter paints the same spec (border/radius/padding inline; focus via the
/// control stylesheet). Unthemed keeps the host's default decoration.
InputDecoration _fieldDecorationFor(Color? outline, Color? accent) {
  if (outline == null) return const InputDecoration();
  final BorderRadius radius = BorderRadius.circular(6);
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: accent ?? outline, width: 2),
    ),
  );
}

/// [_fieldDecorationFor], reading the roles from the ambient theme.
InputDecoration _fieldDecoration(BuildContext context) => _fieldDecorationFor(
      _roleColor(context, ThemeRoles.outline),
      _roleColor(context, ThemeRoles.primary),
    );

/// Reads a list-of-strings argument (e.g. a Select's `options`).
List<String> _stringList(DataSource source, String key) {
  if (!source.isList([key])) return const <String>[];
  final int n = source.length([key]);
  return <String>[
    for (int i = 0; i < n; i++) source.v<String>([key, i]) ?? '',
  ];
}
