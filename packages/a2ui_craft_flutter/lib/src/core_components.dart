// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import 'runtime.dart';

// Design notes (not part of the public API):
// - Each component implements the framework-neutral spec (DESIGN.md §11,
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
      return Text(source.v<String>(['text']) ?? '');
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
      return Expanded(
        flex: source.v<int>(['flex']) ?? 1,
        child: source.child(['child']),
      );
    },
    'Button': (BuildContext context, DataSource source) {
      final VoidCallback? onPressed = source.voidHandler(['onPressed']);
      return GestureDetector(
        onTap: onPressed,
        child: source.child(['child']),
      );
    },
    'Center': (BuildContext context, DataSource source) {
      return Center(
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
    'Image': (BuildContext context, DataSource source) {
      final String? url = source.v<String>(['url']);
      if (url == null || url.isEmpty || url.contains('example.com')) {
        return const SizedBox.shrink();
      }
      return url.startsWith('http') ? Image.network(url) : Image.asset(url);
    },
    'Icon': (BuildContext context, DataSource source) {
      // Very basic icon mapping for demo purposes.
      final String? iconName = source.v<String>(['icon']);
      IconData iconData = Icons.star; // default fallback
      if (iconName == 'settings') iconData = Icons.settings;
      if (iconName == 'person') iconData = Icons.person;
      if (iconName == 'check') iconData = Icons.check;
      return Icon(iconData);
    },
    'Divider': (BuildContext context, DataSource source) {
      return const Divider();
    },
    'ScrollView': (BuildContext context, DataSource source) {
      return SingleChildScrollView(
        child: source.child(['child']),
      );
    },
    'Card': (BuildContext context, DataSource source) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: source.child(['child']),
        ),
      );
    },
    'Video': (BuildContext context, DataSource source) {
      // Stub for Video since we don't have video_player plugin
      return Container(
        color: Colors.black,
        height: 200,
        width: double.infinity,
        child: const Center(
          child: Icon(Icons.play_circle_outline, color: Colors.white, size: 48),
        ),
      );
    },
    'TextField': (BuildContext context, DataSource source) {
      return _CoreTextField(
        label: source.v<String>(['label']),
        value: source.v<String>(['value']),
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
      return Checkbox(
        value: value,
        onChanged:
            onChanged == null ? null : (bool? v) => onChanged(v ?? !value),
      );
    },
  });
}

/// Builds a `Flex` (and thus `Row`/`Column`) from the catalog spec, mapping the
/// framework-neutral value types onto Flutter's `Flex`.
///
/// Sizing is **explicit**: a default `Flex` hugs both axes
/// (`MainAxisSize.min` on the main axis; `CrossAxisAlignment.center`, so children
/// keep their intrinsic cross size). `fill`/`fixed` opt into filling or a fixed
/// extent. Neither Flutter's nor CSS's native defaults are inherited, so the same
/// template lays out identically here and in the Jaspr adapter.
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

/// A text field that reflects an externally-bound [value] (without clobbering
/// the cursor mid-edit) and reports edits through [onChanged] — the two halves
/// of two-way binding.
class _CoreTextField extends StatefulWidget {
  const _CoreTextField({this.label, this.value, this.onChanged});

  final String? label;
  final String? value;
  final ValueChanged<String>? onChanged;

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
      decoration: InputDecoration(labelText: widget.label),
      onChanged: widget.onChanged,
    );
  }
}
