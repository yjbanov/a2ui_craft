// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Button` primitive — owner of all four control paint layers
/// (DESIGN.md §8).
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';
import 'content_ink.dart';
import 'support.dart';

/// Builds `Button`.
Widget buildButton(BuildContext context, DataSource source) {
  final VoidCallback? onPressed = source.voidHandler(['onPressed']);
  final Rgba? color = rgbaArg(source, 'color');
  final CornerRadius radius = CornerRadius.decode(
      numArg(source, 'cornerRadius'),
      fallback: _kButtonCornerRadius);
  final Object? rawPadding = insetsRaw(source, 'padding');
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
    surface = roleColor(context, ThemeRoles.primary) ?? host.primary;
    ink = roleColor(context, ThemeRoles.onPrimary) ?? host.onPrimary;
  }
  return _CoreButton(
    onPressed: onPressed,
    surface: surface,
    ink: ink,
    cornerRadius: radius.pixels,
    padding: toEdgeInsets(padding),
    child: source.child(['child']),
  );
}

/// The stock corner rounding of an unstyled `Button` — the neutral Craft
/// default, shared with the Jaspr adapter so the two web panes agree.
const CornerRadius _kButtonCornerRadius = CornerRadius(6);

/// The stock content padding of a `Button` (layer 3 of the paint model);
/// `padding: 0` opts a fully sized child (e.g. a fixed Box) out of it.
const Insets _kButtonPadding = Insets.symmetric(vertical: 8, horizontal: 16);

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
class _CoreButton extends StatefulWidget {
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

  /// The content ink installed over the child ([ContentInk]); null leaves the
  /// ambient ink standing (an explicit author surface owns its own pairing).
  final Color? ink;

  final double cornerRadius;
  final EdgeInsets padding;
  final Widget child;

  @override
  State<_CoreButton> createState() => _CoreButtonState();
}

class _CoreButtonState extends State<_CoreButton> {
  /// Whether the pointer is down — drives the Cupertino idiom's composite
  /// pressed-fade (layer 4 of the paint model).
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final bool enabled = widget.onPressed != null;
    // The idiom is host-selected (ThemeData.platform, DESIGN.md §8). It
    // decides the corner *style* for the same cornerRadius amount — Apple's
    // continuous superellipse vs. a circular arc — and the state layer:
    // Material draws an ink splash on the surface under the content;
    // Cupertino fades the whole composite while pressed.
    final bool cupertino = switch (Theme.of(context).platform) {
      TargetPlatform.iOS || TargetPlatform.macOS => true,
      _ => false,
    };
    final BorderRadius radius = BorderRadius.circular(widget.cornerRadius);
    final OutlinedBorder shape = cupertino
        ? RoundedSuperellipseBorder(borderRadius: radius)
        : RoundedRectangleBorder(borderRadius: radius);
    Widget content = Padding(
      padding: widget.padding,
      // Hug the content, but center it when the parent stretches the button
      // (e.g. a stretched cross axis) — the Jaspr side is inline-flex with
      // centered alignment.
      child: Center(widthFactor: 1.0, heightFactor: 1.0, child: widget.child),
    );
    if (widget.ink != null) {
      content = ContentInk(color: widget.ink!, child: content);
    }
    Widget button = Material(
      color: widget.surface ?? Colors.transparent,
      shape: shape,
      // Clip the state layer (ink splash) to the surface's corners.
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        customBorder: shape,
        onTap: widget.onPressed,
        splashFactory: cupertino ? NoSplash.splashFactory : null,
        highlightColor: cupertino ? Colors.transparent : null,
        hoverColor: cupertino ? Colors.transparent : null,
        onHighlightChanged:
            cupertino ? (bool value) => setState(() => _pressed = value) : null,
        child: content,
      ),
    );
    if (cupertino) {
      button = AnimatedOpacity(
        // CupertinoButton's pressed opacity and fade cadence.
        opacity: _pressed ? 0.4 : 1.0,
        duration: const Duration(milliseconds: 120),
        child: button,
      );
    }
    return MergeSemantics(
      child: Semantics(button: true, enabled: enabled, child: button),
    );
  }
}
