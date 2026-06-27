// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'runtime.dart';

/// A library of standard core components (Text, Flex/Row/Column, Button, …)
/// implemented using Jaspr DOM elements.
///
/// Each component **implements the framework-neutral spec** (DESIGN.md §11,
/// Pillar A) — the cross-framework value types (`Dimension`, `FlexAxis`,
/// `MainAxisAlign`/`CrossAxisAlign`) and behavioral contract — rather than
/// mirroring the Flutter file by hand. The shared contract is verified by the
/// conformance suite in `package:a2ui_craft_testing` (behavioral and, for the
/// `Flex` slice, geometric via `getBoundingClientRect`/`getComputedStyle`).
/// Components outside the `Flex` slice are still seed-grade fixtures.
///
/// Note: the reserved `key` argument is handled by the runtime, which lifts it
/// onto the reconciliation unit (`_Widget`) — see DESIGN.md §6 — so these
/// builders do not read or apply it themselves.
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
      return div(
        styles: Styles(
          width: w != null ? Unit.pixels(w) : null,
          height: h != null ? Unit.pixels(h) : null,
        ),
        [
          source.child(['child'])
        ],
      );
    },
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
/// Sizing is **explicit** (DESIGN.md §11): a default `Flex` hugs both axes
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

/// Reads a raw scalar (a number → a fixed size, or a keyword string) for a
/// `Dimension`-valued argument. `DataSource.v` requires a concrete scalar type,
/// so we probe the few a `Dimension` can take.
Object? _dimRaw(DataSource source, List<Object> key) =>
    source.v<double>(key) ?? source.v<int>(key) ?? source.v<String>(key);

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
