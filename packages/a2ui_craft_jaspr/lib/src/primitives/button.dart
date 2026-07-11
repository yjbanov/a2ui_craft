// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The `Button` primitive — owner of all four control paint layers
/// (DESIGN.md §8).
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import '../runtime.dart';
import 'content_ink.dart';
import 'support.dart';

/// Builds `Button`.
Component buildButton(BuildContext context, DataSource source) {
  // The state layer (hover/pressed, layer 2) needs pseudo-classes, which
  // inline styles cannot express; install the shared control stylesheet
  // into the document head once (a no-op off-web and after the first
  // control).
  ensureCoreControlStyleSheet(coreControlStyleSheet);
  final onPressed = source.voidHandler(['onPressed']);
  final Rgba? color = Rgba.decode(source.v<String>(['color']));
  final CornerRadius radius = CornerRadius.decode(
      numArg(source, 'cornerRadius'),
      fallback: _kButtonCornerRadius);
  final Object? rawPadding = insetsRaw(source, 'padding');
  final Insets padding =
      rawPadding == null ? _kButtonPadding : Insets.decode(rawPadding);
  // Surface + content ink per the role mapping (DESIGN.md §8): unstyled,
  // the idiom's stock button — `primary` surface, `onPrimary` content
  // ink. An explicit color is the author's surface; the ambient ink
  // stands (the author owns the pairing). A transparent color is the
  // "text button" degenerate case: no surface, no ink override.
  final String? surface;
  final String? ink;
  if (color != null) {
    surface = color.alpha == 0 ? null : color.toCssString();
    ink = null;
  } else {
    surface = roleColor(context, ThemeRoles.primary) ?? kButtonSurfaceFallback;
    ink = roleColor(context, ThemeRoles.onPrimary) ?? kButtonInkFallback;
  }
  Component content = source.child(['child']);
  if (ink != null) {
    // Layer 3 ownership: themed content primitives (Text/Icon) consult
    // this before their ambient roles; unthemed bare text nodes inherit
    // the CSS `color` set on the element below.
    content = ContentInk(color: ink, child: content);
  }
  return button(
    // `type=button` opts out of implicit form submission; `disabled` keeps
    // a handler-less button out of the tab order and announced as disabled
    // — parity with the Flutter adapter's Semantics(enabled: false).
    type: ButtonType.button,
    // The state layer (hover/active, layer 2) lives in
    // [coreControlStyleSheet] keyed off this class — pseudo-classes cannot
    // be expressed as inline styles.
    classes: 'craft-button',
    disabled: onPressed == null,
    onClick: onPressed == null ? null : () => onPressed(),
    styles: Styles(raw: <String, String>{
      // Layer 1 — the surface: color and corner shape, no UA chrome.
      'appearance': 'none',
      'border': 'none',
      'background-color': surface ?? 'transparent',
      'border-radius': '${numberToDisplayString(radius.pixels)}px',
      // Layer 3 — content placement. `font: inherit` drops the UA button
      // font so button text reads like the surrounding template; the
      // Flutter side centers via the same hug-then-center rule.
      'padding': '${numberToDisplayString(padding.top)}px '
          '${numberToDisplayString(padding.right)}px '
          '${numberToDisplayString(padding.bottom)}px '
          '${numberToDisplayString(padding.left)}px',
      'font': 'inherit',
      'display': 'inline-flex',
      'align-items': 'center',
      'justify-content': 'center',
      if (ink != null) 'color': ink,
    }),
    [content],
  );
}

/// The stock corner rounding of an unstyled `Button` — the neutral Craft
/// default, shared with the Flutter adapter so the two web panes agree.
const CornerRadius _kButtonCornerRadius = CornerRadius(6);

/// The stock content padding of a `Button` (layer 3 of the paint model);
/// `padding: 0` opts a fully sized child (e.g. a fixed Box) out of it.
const Insets _kButtonPadding = Insets.symmetric(vertical: 8, horizontal: 16);
