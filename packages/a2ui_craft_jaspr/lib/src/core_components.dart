// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'runtime.dart';

// Design notes (not part of the public API):
// - Each component implements the framework-neutral spec (DESIGN.md §11,
//   Pillar A) using the shared value types (Dimension, FlexAxis, the
//   alignments), rather than mirroring the Flutter adapter by hand; the contract
//   is verified by package:a2ui_craft_testing (behavioral, and geometric for the
//   Flex/Box slices via getBoundingClientRect).
// - Components outside the Flex/Box slices are still seed-grade fixtures.
// - The runtime lifts the reserved `key` onto its reconciliation unit
//   (`_Widget`, DESIGN.md §6), so these builders never read or apply it.
/// A library of standard core components (Text, Flex/Row/Column, Button, …)
/// implemented using Jaspr DOM elements.
///
/// Register the result under the `core` library name; templates then compose
/// these primitives. The reserved `key` argument is handled by the runtime, so
/// the builders here do not read or apply it.
LocalWidgetLibrary createCoreComponents() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'Text': (BuildContext context, DataSource source) {
      final String text = _readText(source, const <Object>['text']);
      final TextVariant variant =
          TextVariant.parse(source.v<String>(['variant']));
      return variant == TextVariant.caption
          ? span(
              styles: Styles(raw: <String, String>{
                'font-size': '12px',
                'color': '#5f6368',
              }),
              <Component>[Component.text(text)],
            )
          : Component.text(text);
    },
    // A single heading line carrying a real heading role + `level` (1–6) for
    // assistive tech (an `h1`–`h6` element) — distinct from `Text`, a plain span.
    // Kept simple: one line, no inline markup (use `Markdown` for rich content).
    'Heading': (BuildContext context, DataSource source) {
      final int level = (source.v<int>(['level']) ?? 1).clamp(1, 6);
      return _mdHeading(
        level,
        <Component>[
          Component.text(source.v<String>(['text']) ?? '')
        ],
      );
    },
    // Renders a Markdown string (parsed in the core) as headings, paragraphs,
    // and lists with inline emphasis — structurally, never as raw HTML.
    'Markdown': (BuildContext context, DataSource source) =>
        _buildMarkdown(source.v<String>(['text']) ?? ''),
    // Row, Column, and Flex are one builder over a `FlexAxis`: Row/Column pin
    // the axis, Flex reads it from `direction` (DESIGN.md §11).
    'Flex': (BuildContext context, DataSource source) =>
        _buildFlex(source, FlexAxis.parse(source.v<String>(['direction']))),
    'Row': (BuildContext context, DataSource source) =>
        _buildFlex(source, FlexAxis.horizontal),
    'Column': (BuildContext context, DataSource source) =>
        _buildFlex(source, FlexAxis.vertical),
    'Expanded': (BuildContext context, DataSource source) {
      // A flex item that grows to take `flex` shares of free space, like
      // Flutter's `Expanded(flex:)`: grow factor, shrink 1, basis 0.
      final int flex = source.v<int>(['flex']) ?? 1;
      return div(
        styles: Styles(raw: <String, String>{'flex': '$flex 1 0'}),
        <Component>[
          source.child(['child'])
        ],
      );
    },
    'Button': (BuildContext context, DataSource source) {
      final onPressed = source.voidHandler(['onPressed']);
      return button(
        onClick: onPressed == null ? null : () => onPressed(),
        [
          source.child(['child'])
        ],
      );
    },
    'Center': (BuildContext context, DataSource source) {
      // Flutter's `Center` (an `Align` with null size factors) expands to the
      // largest size the incoming constraints allow, then centers its child —
      // shrink-wrapping only when a constraint is unbounded. A bare flex box
      // collapses to its content instead, pinning the child top-left, so fill
      // the parent explicitly: `100%` fills a bounded parent (where centering
      // has room) and resolves to the child's size in an unbounded one — the
      // same caveat Flutter documents.
      return div(
        styles: Styles(
          display: Display.flex,
          justifyContent: JustifyContent.center,
          alignItems: AlignItems.center,
          width: Unit.percent(100),
          height: Unit.percent(100),
        ),
        [
          source.child(['child'])
        ],
      );
    },
    // Places its child at an `alignment` within an (optionally sized) box. With
    // no width/height it hugs the child (alignment is then a no-op); a fixed
    // width/height gives the child room to be positioned. Generalizes `Center`.
    'Align': (BuildContext context, DataSource source) {
      final Alignment2D a = Alignment2D.parse(source.v<String>(['alignment']));
      final double? w = source.v<double>(['width']);
      final double? h = source.v<double>(['height']);
      return div(
        styles: Styles(
          display: Display.flex,
          justifyContent: _justifyFor(a.x),
          alignItems: _alignItemsFor(a.y),
          width: w != null ? Unit.pixels(w) : null,
          height: h != null ? Unit.pixels(h) : null,
        ),
        [
          source.child(['child'])
        ],
      );
    },
    // Sizes its child to a `ratio` (width ÷ height) within the incoming
    // constraints (CSS `aspect-ratio` / Flutter `AspectRatio`).
    'AspectRatio': (BuildContext context, DataSource source) {
      final double ratio = _numArg(source, 'ratio') ?? 1.0;
      final Component? child = source.optionalChild(['child']);
      return div(
        styles: Styles(raw: <String, String>{
          'aspect-ratio': '$ratio',
          'width': '100%',
        }),
        switch (child) {
          final Component c => <Component>[c],
          _ => const <Component>[],
        },
      );
    },
    // A run of children that wraps onto the next line/column when they overflow
    // the main axis (CSS `flex-wrap` / Flutter `Wrap`).
    'Wrap': (BuildContext context, DataSource source) {
      final bool horizontal = FlexAxis.parse(source.v<String>(['direction']),
              fallback: FlexAxis.horizontal) ==
          FlexAxis.horizontal;
      final double spacing = _gap(source);
      final double runSpacing = _numArg(source, 'runGap') ?? 0.0;
      // CSS `gap` shorthand is `row-gap column-gap`. For a horizontal wrap the
      // run axis is vertical (row-gap = runSpacing) and item spacing is
      // horizontal (column-gap = spacing); for a vertical wrap it is the reverse.
      final String gap = horizontal
          ? '${runSpacing}px ${spacing}px'
          : '${spacing}px ${runSpacing}px';
      return div(
        styles: Styles(raw: <String, String>{
          'display': 'flex',
          'flex-direction': horizontal ? 'row' : 'column',
          'flex-wrap': 'wrap',
          'gap': gap,
        }),
        source.childList(['children']),
      );
    },
    // Makes its child partially (or fully) transparent without affecting layout.
    'Opacity': (BuildContext context, DataSource source) {
      final double o = (_numArg(source, 'opacity') ?? 1.0).clamp(0.0, 1.0);
      return div(
        styles: Styles(raw: <String, String>{'opacity': '$o'}),
        [
          source.child(['child'])
        ],
      );
    },
    'SizedBox': (BuildContext context, DataSource source) {
      final double? w = source.v<double>(['width']);
      final double? h = source.v<double>(['height']);
      // The child is optional: a childless SizedBox is a fixed-size spacer.
      final Component? child = source.optionalChild(['child']);
      return div(
        styles: Styles(
          width: w != null ? Unit.pixels(w) : null,
          height: h != null ? Unit.pixels(h) : null,
        ),
        switch (child) {
          final Component c => <Component>[c],
          _ => const <Component>[],
        },
      );
    },
    'Box': (BuildContext context, DataSource source) => _buildBox(source),
    'Image': (BuildContext context, DataSource source) => _buildImage(source),
    'Icon': (BuildContext context, DataSource source) {
      return i(
        classes: 'material-icons',
        <Component>[
          Component.text(_iconLigature(source.v<String>(['icon'])))
        ],
      );
    },
    'Divider': (BuildContext context, DataSource source) {
      final FlexAxis axis = FlexAxis.parse(source.v<String>(['axis']),
          fallback: FlexAxis.horizontal);
      if (axis == FlexAxis.vertical) {
        return div(
          styles: Styles(raw: <String, String>{
            'width': '1px',
            'align-self': 'stretch',
            'background-color': 'rgba(0, 0, 0, 0.12)',
          }),
          const <Component>[],
        );
      }
      // `align-self: stretch` spans the parent's cross extent without forcing it
      // wider (it contributes ~0 to intrinsic sizing), mirroring Flutter's
      // `Divider`, which fills the column's resolved cross size. A plain <hr>
      // instead inherits `align-items` (e.g. `center`) and collapses to a dot.
      return div(
        styles: Styles(raw: <String, String>{
          'align-self': 'stretch',
          'height': '1px',
          'border': 'none',
          'margin': '0',
          'background-color': 'rgba(0, 0, 0, 0.12)',
        }),
        const <Component>[],
      );
    },
    'ScrollView': (BuildContext context, DataSource source) {
      return div(
        styles: Styles(
          overflow: Overflow.auto,
        ),
        [
          source.child(['child'])
        ],
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
      return div(
        styles: Styles(
          display: Display.flex,
          flexDirection: horizontal ? FlexDirection.row : FlexDirection.column,
          alignItems: _toAlign(align),
          raw: <String, String>{'overflow': 'auto'},
        ),
        source.childList(['children']),
      );
    },
    'Card': (BuildContext context, DataSource source) {
      return div(
        styles: Styles(
          padding: Padding.all(Unit.pixels(16)),
          radius: BorderRadius.circular(Unit.pixels(8)),
          shadow: BoxShadow(
            color: Color.rgba(0, 0, 0, 0.25),
            blur: Unit.pixels(4),
            offsetX: Unit.zero,
            offsetY: Unit.pixels(2),
          ),
          backgroundColor: Colors.white,
        ),
        [
          source.child(['child'])
        ],
      );
    },
    // The bare text input — no label. Label placement is a template's choice
    // (see DESIGN.md §2 "Bias to templatize" / §11), composed as a separate Text.
    'TextField': (BuildContext context, DataSource source) {
      // The `onChanged` arg is a2ui_core's two-way setter (a resolved callback),
      // accepted directly by the runtime's handler affordance.
      final onChanged = source.handler<ValueChanged<String>>(
        ['onChanged'],
        (HandlerTrigger trigger) =>
            (String value) => trigger(<String, Object?>{'value': value}),
      );
      return input<String>(
        type: InputType.text,
        value: source.v<String>(['value']) ?? '',
        onInput: onChanged,
      );
    },
    'Checkbox': (BuildContext context, DataSource source) {
      final bool value = source.v<bool>(['value']) ?? false;
      final onChanged = source.handler<ValueChanged<bool>>(
        ['onChanged'],
        (HandlerTrigger trigger) =>
            (bool v) => trigger(<String, Object?>{'value': v}),
      );
      // Toggle from the bound value rather than reading the event target, so the
      // handler works without a live DOM (e.g. in component tests).
      return input(
        type: InputType.checkbox,
        checked: value,
        events: onChanged == null
            ? null
            : <String, EventCallback>{'change': (_) => onChanged(!value)},
      );
    },
    // A single radio button: shows [selected] and fires `onChanged` when tapped
    // ("select me"). Grouping — which radio is on — is the template's job.
    // TODO(a2ui-craft): revisit alongside the Flutter Radio (see the Flutter
    // adapter) so the two stay behaviorally aligned — e.g. native radio grouping
    // and the `change` vs `click` event choice.
    'Radio': (BuildContext context, DataSource source) {
      final bool selected = source.v<bool>(['selected']) ?? false;
      final onChanged = source.voidHandler(['onChanged']);
      return input(
        type: InputType.radio,
        checked: selected,
        events: onChanged == null
            ? null
            : <String, EventCallback>{'click': (_) => onChanged()},
      );
    },
    // A bare numeric slider (no label — that is a template's choice). Two-way
    // bound: `onChanged` is a2ui_core's setter for the bound `value`.
    'Slider': (BuildContext context, DataSource source) {
      final double min = _numArg(source, 'min') ?? 0.0;
      final double max = _numArg(source, 'max') ?? 1.0;
      final double value = (_numArg(source, 'value') ?? min).clamp(min, max);
      final int? steps = source.v<int>(['steps']);
      // Read the raw string value and parse it, so we don't depend on the DOM
      // value being pre-typed.
      final onChanged = source.handler<ValueChanged<String>>(
        ['onChanged'],
        (HandlerTrigger trigger) => (String v) =>
            trigger(<String, Object?>{'value': double.tryParse(v) ?? min}),
      );
      return input<String>(
        type: InputType.range,
        value: '$value',
        attributes: <String, String>{
          'min': '$min',
          'max': '$max',
          if (steps != null && steps > 0) 'step': '${(max - min) / steps}',
        },
        onInput: onChanged,
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
    return (number.isFinite && number == number.roundToDouble())
        ? number.toInt().toString()
        : number.toString();
  }
  return '';
}

/// The standard **function library** — the pure, template-author-facing
/// computation layer that complements [createCoreComponents] (the rendering
/// layer). Register it on a [Runtime] with [Runtime.registerFunctions].
///
/// Each function is **total**: unexpected or missing arguments yield `null`
/// (rendered as absent) rather than an exception. This is the trusted library
/// used by template authors, kept deliberately separate from the agent-facing
/// `a2ui_core` function catalog (see DESIGN.md, two-layer plan).
///
/// Kept identical to the Flutter adapter's `createCoreFunctions` so a template
/// computes the same values on both.
LocalFunctionLibrary createCoreFunctions() {
  return LocalFunctionLibrary(<String, LocalFunction>{
    // Basic arithmetic over int/double operands.
    'add': _binaryNumberFunction((num a, num b) => a + b),
    'subtract': _binaryNumberFunction((num a, num b) => a - b),
    'multiply': _binaryNumberFunction((num a, num b) => a * b),
    // Division by zero has no numeric result → null (stays total).
    'divide': _binaryNumberFunction((num a, num b) => b == 0 ? null : a / b),
  });
}

/// The argument schema shared by the binary numeric functions: two required
/// numbers, `a` and `b`.
const Map<String, FunctionArgType> _binaryNumberArgs =
    <String, FunctionArgType>{
  'a': FunctionArgType.number,
  'b': FunctionArgType.number,
};

/// Builds a binary numeric [LocalFunction] from [combine].
///
/// Total by construction: a non-numeric operand — or a [combine] that returns
/// null (e.g. divide-by-zero) — yields null (an absent result) rather than
/// throwing. Types are **strict**: a string in a numeric position is a type
/// error, not silently coerced (no JS-style `"5" + 3 == 8`); an author's literal
/// mistake is caught at bind time by the schema, and a wrong-typed runtime
/// binding degrades here via [_numOrNull]. See DESIGN.md (two-layer plan).
///
/// Kept identical to the Flutter adapter's implementation so a template computes
/// the same values on both.
LocalFunction _binaryNumberFunction(num? Function(num a, num b) combine) {
  return LocalFunction(
    arguments: _binaryNumberArgs,
    implementation: (DynamicMap arguments) {
      final num? a = _numOrNull(arguments['a']);
      final num? b = _numOrNull(arguments['b']);
      if (a == null || b == null) {
        return null;
      }
      return combine(a, b);
    },
  );
}

/// Reads a resolved function argument as a [num], returning null for any
/// non-numeric value (no coercion; see [_binaryNumberFunction]).
num? _numOrNull(Object? value) => value is num ? value : null;

/// Builds a `Flex` (and thus `Row`/`Column`) from the catalog spec, mapping the
/// framework-neutral value types onto a CSS flex container.
///
/// Sizing is **explicit**: a default `Flex` hugs both axes
/// (`width`/`height: fit-content`; `align-items: flex-start`, so children keep
/// their intrinsic cross size and align to the leading edge). This deliberately
/// does *not* inherit CSS's native block-level defaults (a `display:flex` div
/// would fill its inline axis and stretch its children), so the same template
/// lays out identically here and in the Flutter adapter. `fill`/`fixed` opt into
/// `100%`/an exact pixel extent.
Component _buildFlex(DataSource source, FlexAxis axis) {
  final MainAxisAlign main =
      MainAxisAlign.parse(source.v<String>(['mainAxisAlignment']));
  final CrossAxisAlign cross =
      CrossAxisAlign.parse(source.v<String>(['crossAxisAlignment']));
  final double gap = _gap(source);
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));
  final bool horizontal = axis == FlexAxis.horizontal;

  // The main axis hugs to content (`fit-content`). The cross axis, when it hugs,
  // is left to CSS `auto` rather than `fit-content`: as a block-level flex this
  // fills the parent's cross size (so a fixed-width ancestor like `Box(width:)`
  // reaches a `fill` descendant, and a full-bleed `Divider` spans the card),
  // while a flex *item* (e.g. a `Stat` column inside a `Row`) still shrink-wraps.
  // This mirrors how Flutter's constraints carry a bounded cross extent down to
  // its children, which a rigid `fit-content` would sever.
  final Dimension mainDim = horizontal ? width : height;
  final Dimension crossDim = horizontal ? height : width;
  final String mainExtent = _cssExtent(mainDim);
  final String? crossExtent =
      crossDim is HugDimension ? null : _cssExtent(crossDim);
  final String widthCss = horizontal ? mainExtent : (crossExtent ?? 'auto');
  final String heightCss = horizontal ? (crossExtent ?? 'auto') : mainExtent;

  return div(
    styles: Styles(
      display: Display.flex,
      flexDirection: horizontal ? FlexDirection.row : FlexDirection.column,
      justifyContent: _toJustify(main),
      alignItems: _toAlign(cross),
      raw: <String, String>{
        'width': widthCss,
        'height': heightCss,
        if (gap > 0) 'gap': '${_px(gap)}px',
      },
    ),
    source.childList(['children']),
  );
}

/// Reads a raw scalar for a `Dimension`-valued argument.
Object? _dimRaw(DataSource source, List<Object> key) =>
    source.v<double>(key) ?? source.v<int>(key) ?? source.v<String>(key);

/// Builds a `Box` — the catalog's single container primitive (size + padding +
/// margin + background) — from the spec, on the same explicit-sizing and
/// border-box model the Flutter adapter renders.
///
/// `margin` is rendered as an **outer wrapper** rather than CSS `margin`, so the
/// keyed node's `getBoundingClientRect` *includes* the margin band — matching the
/// Flutter adapter (whose margin `Padding` is likewise part of the measured box).
/// The wrapper sizes to fill only when the box itself fills; otherwise it hugs
/// the inner box plus its margin. This keeps the measured footprint identical
/// across adapters (CSS `margin` would otherwise be excluded from the rect).
Component _buildBox(DataSource source) {
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));
  final Insets padding = Insets.decode(_insetsRaw(source, 'padding'));
  final Insets margin = Insets.decode(_insetsRaw(source, 'margin'));
  final Rgba? color = _rgba(source, 'color');
  final Component? child = source.optionalChild(['child']);

  final Map<String, String> inner = <String, String>{
    'box-sizing': 'border-box',
    'width': _cssExtent(width),
    'height': _cssExtent(height),
  };
  if (!padding.isZero) inner['padding'] = _cssInsets(padding);
  if (color != null) inner['background-color'] = color.toCssString();

  Component box = div(styles: Styles(raw: inner), _childList(child));

  if (!margin.isZero) {
    box = div(
      styles: Styles(raw: <String, String>{
        'box-sizing': 'border-box',
        // The wrapper fills only if the box fills; otherwise it hugs inner+margin.
        'width': width is FillDimension ? '100%' : 'fit-content',
        'height': height is FillDimension ? '100%' : 'fit-content',
        'padding': _cssInsets(margin),
      }),
      <Component>[box],
    );
  }

  return box;
}

List<Component> _childList(Component? child) => switch (child) {
      final Component c => <Component>[c],
      _ => const <Component>[],
    };

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

/// Formats [i] as a CSS `top right bottom left` length list.
String _cssInsets(Insets i) =>
    '${_px(i.top)}px ${_px(i.right)}px ${_px(i.bottom)}px ${_px(i.left)}px';

/// Reads the `gap` argument, accepting either an int or double literal.
double _gap(DataSource source) =>
    source.v<double>(['gap']) ?? source.v<int>(['gap'])?.toDouble() ?? 0.0;

String _cssExtent(Dimension d) => switch (d) {
      HugDimension() => 'fit-content',
      FillDimension() => '100%',
      FixedDimension(:final double pixels) => '${_px(pixels)}px',
      // A container is not itself a flex child, so `flex(n)` has no meaning here.
      FlexDimension() => 'fit-content',
    };

/// Renders a CSS length without a trailing `.0` for whole pixels.
String _px(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Builds an `Image` sized to its [ImageVariant] (so it occupies the same box as
/// the Flutter adapter) with the requested [ImageFit] as `object-fit`.
Component _buildImage(DataSource source) {
  final String? url = source.v<String>(['url']);
  final ImageVariant variant =
      ImageVariant.parse(source.v<String>(['variant']));
  final Map<String, String> raw = <String, String>{
    'width': variant.width != null ? '${_px(variant.width!)}px' : '100%',
    'height': '${_px(variant.height)}px',
    'object-fit': _objectFit(ImageFit.parse(source.v<String>(['fit']))),
    if (variant.circular) 'border-radius': '50%',
  };
  if (url == null || url.isEmpty) {
    // Placeholder box (keeps tests deterministic and matches Flutter).
    raw['background-color'] = 'rgba(0, 0, 0, 0.12)';
    return div(styles: Styles(raw: raw), const <Component>[]);
  }
  return img(src: url, styles: Styles(raw: raw));
}

String _objectFit(ImageFit f) => switch (f) {
      ImageFit.contain => 'contain',
      ImageFit.cover => 'cover',
      ImageFit.fill => 'fill',
      ImageFit.none => 'none',
      ImageFit.scaleDown => 'scale-down',
    };

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

JustifyContent _toJustify(MainAxisAlign a) => switch (a) {
      MainAxisAlign.start => JustifyContent.start,
      MainAxisAlign.center => JustifyContent.center,
      MainAxisAlign.end => JustifyContent.end,
      MainAxisAlign.spaceBetween => JustifyContent.spaceBetween,
      MainAxisAlign.spaceAround => JustifyContent.spaceAround,
      MainAxisAlign.spaceEvenly => JustifyContent.spaceEvenly,
    };

AlignItems _toAlign(CrossAxisAlign a) => switch (a) {
      CrossAxisAlign.start => AlignItems.start,
      CrossAxisAlign.center => AlignItems.center,
      CrossAxisAlign.end => AlignItems.end,
      CrossAxisAlign.stretch => AlignItems.stretch,
    };

/// Maps an `Alignment2D` horizontal anchor (`x` in `[-1, 1]`) to the
/// main-axis `justify-content` of the (row) flex box that positions the child.
JustifyContent _justifyFor(double x) => x < 0
    ? JustifyContent.start
    : x > 0
        ? JustifyContent.end
        : JustifyContent.center;

/// Maps an `Alignment2D` vertical anchor (`y` in `[-1, 1]`) to the cross-axis
/// `align-items` of the (row) flex box that positions the child.
AlignItems _alignItemsFor(double y) => y < 0
    ? AlignItems.start
    : y > 0
        ? AlignItems.end
        : AlignItems.center;

/// Builds the `Markdown` primitive from the core's neutral [MarkdownBlock]
/// model (the Flutter adapter renders the same model with widgets), as DOM
/// headings/paragraphs/lists with `strong`/`em`/`code`/`a` emphasis — never raw
/// HTML.
Component _buildMarkdown(String source) {
  final List<MarkdownBlock> blocks = parseMarkdown(source);
  return div(
    <Component>[for (final MarkdownBlock block in blocks) _mdBlock(block)],
  );
}

Component _mdBlock(MarkdownBlock block) => switch (block) {
      MarkdownHeading(:final int level, :final List<MarkdownSpan> spans) =>
        _mdHeading(level, _mdInline(spans)),
      MarkdownParagraph(:final List<MarkdownSpan> spans) => p(_mdInline(spans)),
      MarkdownList(
        :final bool ordered,
        :final List<List<MarkdownSpan>> items
      ) =>
        ordered
            ? ol(<Component>[
                for (final List<MarkdownSpan> item in items)
                  li(_mdInline(item)),
              ])
            : ul(<Component>[
                for (final List<MarkdownSpan> item in items)
                  li(_mdInline(item)),
              ]),
    };

Component _mdHeading(int level, List<Component> children) => switch (level) {
      1 => h1(children),
      2 => h2(children),
      3 => h3(children),
      4 => h4(children),
      5 => h5(children),
      _ => h6(children),
    };

List<Component> _mdInline(List<MarkdownSpan> spans) =>
    <Component>[for (final MarkdownSpan span in spans) _mdSpan(span)];

Component _mdSpan(MarkdownSpan span) {
  Component node = Component.text(span.text);
  if (span.code) node = code(<Component>[node]);
  if (span.italic) node = em(<Component>[node]);
  if (span.bold) node = strong(<Component>[node]);
  final String? href = span.href;
  if (href != null) node = a(<Component>[node], href: href);
  return node;
}
