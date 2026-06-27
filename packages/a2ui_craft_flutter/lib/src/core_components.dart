// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import 'runtime.dart';

/// A library of standard core components (Text, Flex/Row/Column, Button, …)
/// implemented using Flutter widgets.
///
/// Each component **implements the framework-neutral spec** (DESIGN.md §11,
/// Pillar A) — the cross-framework value types (`Dimension`, `FlexAxis`,
/// `MainAxisAlign`/`CrossAxisAlign`) and behavioral contract — rather than
/// mirroring the Jaspr file by hand. The shared contract is verified by the
/// conformance suite in `package:a2ui_craft_testing` (behavioral and, for the
/// `Flex` slice, geometric), and the set of names is pinned by its `coreCatalog`.
/// Components outside the `Flex` slice are still seed-grade fixtures.
///
/// Note: the reserved `key` argument is handled by the runtime, which lifts it
/// onto the reconciliation unit (`_Widget`) — see DESIGN.md §6 — so these
/// builders do not read or apply it themselves.
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
/// Sizing is **explicit** (DESIGN.md §11): a default `Flex` hugs both axes
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
