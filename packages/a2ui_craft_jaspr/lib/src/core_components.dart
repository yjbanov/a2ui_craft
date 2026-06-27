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
      return Component.text(source.v<String>(['text']) ?? '');
    },
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
      return div(
        styles: Styles(
          display: Display.flex,
          justifyContent: JustifyContent.center,
          alignItems: AlignItems.center,
        ),
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
    'Image': (BuildContext context, DataSource source) {
      final String? url = source.v<String>(['url']);
      if (url == null || url.isEmpty) {
        return div([]);
      }
      return img(src: url);
    },
    'Icon': (BuildContext context, DataSource source) {
      final String? iconName = source.v<String>(['icon']);
      final String name = iconName ?? 'star'; // default fallback
      return i(classes: 'material-icons', [Component.text(name)]);
    },
    'Divider': (BuildContext context, DataSource source) {
      return hr();
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
    'Video': (BuildContext context, DataSource source) {
      final String? url = source.v<String>(['url']);
      if (url == null || url.isEmpty) {
        return div([]);
      }
      return video(src: url, controls: true, []);
    },
    'TextField': (BuildContext context, DataSource source) {
      final String? labelText = source.v<String>(['label']);
      // The `onChanged` arg is a2ui_core's two-way setter (a resolved callback),
      // accepted directly by the runtime's handler affordance.
      final onChanged = source.handler<ValueChanged<String>>(
        ['onChanged'],
        (HandlerTrigger trigger) =>
            (String value) => trigger(<String, Object?>{'value': value}),
      );
      return label([
        if (labelText != null) Component.text(labelText),
        input<String>(
          type: InputType.text,
          value: source.v<String>(['value']) ?? '',
          onInput: onChanged,
        ),
      ]);
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
  });
}

/// Builds a `Flex` (and thus `Row`/`Column`) from the catalog spec, mapping the
/// framework-neutral value types onto a CSS flex container.
///
/// Sizing is **explicit**: a default `Flex` hugs both axes
/// (`width`/`height: fit-content`; `align-items: center`, so children keep their
/// intrinsic cross size). This deliberately does *not* inherit CSS's native
/// block-level defaults (a `display:flex` div would fill its inline axis and
/// stretch its children), so the same template lays out identically here and in
/// the Flutter adapter. `fill`/`fixed` opt into `100%`/an exact pixel extent.
Component _buildFlex(DataSource source, FlexAxis axis) {
  final MainAxisAlign main =
      MainAxisAlign.parse(source.v<String>(['mainAxisAlignment']));
  final CrossAxisAlign cross =
      CrossAxisAlign.parse(source.v<String>(['crossAxisAlignment']));
  final double gap = _gap(source);
  final Dimension width = Dimension.decode(_dimRaw(source, ['width']));
  final Dimension height = Dimension.decode(_dimRaw(source, ['height']));
  final bool horizontal = axis == FlexAxis.horizontal;

  return div(
    styles: Styles(
      display: Display.flex,
      flexDirection: horizontal ? FlexDirection.row : FlexDirection.column,
      justifyContent: _toJustify(main),
      alignItems: _toAlign(cross),
      raw: <String, String>{
        'width': _cssExtent(width),
        'height': _cssExtent(height),
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
