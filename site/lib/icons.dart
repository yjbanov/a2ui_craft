// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The site chrome's **glyphs**, drawn as inline SVG rather than typed as
/// characters.
///
/// The chrome used to spell its affordances with literal codepoints — `←`,
/// `→`, `▸`, `▾`, `☰`, `✎`, `✓`. Every one of those lives in a Unicode block
/// (Arrows, Geometric Shapes, Dingbats) that most UI typefaces simply do not
/// cover, so the browser falls back per character to whatever font on the
/// device happens to have it. On a desktop that fallback is usually a well-made
/// symbol face and the result looks intentional; on a physical phone it is
/// often a hairline glyph sitting off the text's optical centre, and the arrows
/// in particular came out thin and vertically misaligned.
///
/// There is no font-stack fix for that — the whole problem is that we do not
/// control which font resolves the character. Drawing the shapes ourselves
/// removes the question: an inline `<svg>` renders from geometry we ship, at a
/// stroke weight we choose, on every platform. Emoji are the deliberate
/// exception ([SiteThemeMode]'s 🌓 ☀️ 🌙): those are colour glyphs the platform
/// is *expected* to supply in its own idiom.
///
/// Each icon sizes itself to `1em` and inks itself with `currentColor`, so it
/// inherits the surrounding control's type scale and colour exactly as the
/// character it replaced did.
library;

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

/// A leftward arrow — the back affordance.
Component backIcon() => _stroked('M20 12H4M10 6l-6 6 6 6');

/// A rightward arrow — "this link takes you somewhere".
Component forwardIcon() => _stroked('M4 12h16M14 6l6 6-6 6');

/// The three-bar overflow (hamburger) trigger.
Component menuIcon() => _stroked('M4 7h16M4 12h16M4 17h16');

/// A pencil — the code editor toggle.
Component editIcon() =>
    _stroked('M4 20h4L18.5 9.5a2.83 2.83 0 0 0-4-4L4 16v4zM13.5 6.5l4 4');

/// A checkmark — a menu row's selected state.
Component checkIcon() => _stroked('M4 12.5l5 5L20 6.5');

/// A small solid triangle pointing down: the closed state of a menu trigger.
///
/// Solid rather than a stroked chevron because it stands in for `▾`, and the
/// desktop rendering of that character — which is the look this is matching —
/// is a filled triangle.
Component caretDownIcon() => _solid('M5 8.5h14L12 17z');

/// A small solid triangle pointing right, for a "commit and go" button.
Component playIcon() => _solid('M8 5l10 7-10 7z');

/// An outlined icon: `fill: none`, `stroke: currentColor`, round joins. The
/// weight and colour come from `.icon` in `web/index.html`, not from here, so
/// one rule tunes the whole set.
Component _stroked(String d) => _icon('icon', d);

/// A filled icon: `fill: currentColor`, no stroke.
Component _solid(String d) => _icon('icon icon-solid', d);

Component _icon(String classes, String d) => svg(
      classes: classes,
      viewBox: '0 0 24 24',
      // Decorative: every control that carries one of these also carries a
      // real accessible name (`aria-label`, or visible text beside the icon),
      // so announcing the graphic too would just be noise. `focusable=false`
      // keeps IE/Edge legacy SVG out of the tab order.
      attributes: const <String, String>{
        'aria-hidden': 'true',
        'focusable': 'false',
      },
      <Component>[path(d: d, const <Component>[])],
    );
