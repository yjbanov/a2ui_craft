// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'back_link.dart';
import 'theme_mode.dart';

/// Where the project actually lives. Only links that resolve belong here — a
/// dead link on a landing page costs more trust than a missing one.
///
/// pub.dev is deliberately absent: the five public packages are versioned
/// `0.1.0-dev.1` but **none of them is published yet**, so a "Packages" link
/// would be four 404s. It goes in the day the first release lands.
const String _repoUrl = 'https://github.com/yjbanov/a2ui_craft';
const String _issuesUrl = 'https://github.com/yjbanov/a2ui_craft/issues';
const String _designUrl =
    'https://github.com/yjbanov/a2ui_craft/blob/main/DESIGN.md';

/// The top-level pages, in the order the landing page introduces them.
///
/// `/load` is deliberately absent. Bare in a nav bar it asks a first-time
/// visitor for a URL they have no way of having yet — the page only makes
/// sense once you know a project is a deployable folder of data files. It
/// keeps the two entry points that say so: the landing page's "Projects you
/// can deploy" card, and the gallery's own "Load a project from a URL" action,
/// both of which arrive with that context attached.
const List<(String, String)> _navItems = <(String, String)>[
  ('/gallery', 'Gallery'),
  ('/primitives', 'Primitives'),
];

/// Which colour-scheme control the bar carries.
enum SiteBarToggle {
  /// Always visible. For screens with no overflow menu to fold it into.
  always,

  /// Wide screens only — below the breakpoint the screen's own overflow menu
  /// carries it, along with every other option-bearing control.
  wideOnly,
}

/// The one bar every screen wears.
///
/// There used to be four of these, and they had drifted: the mini-app screen's
/// was not a toolbar at all (no border, its own padding, its own title
/// element), two screens had no colour-scheme toggle, and only the destination
/// pages offered a way home. Same zones everywhere now, so the back arrow, the
/// wordmark, and the toggle are always in the corner you last left them.
///
/// Left to right: [back], the wordmark, then a flexible middle ([title], or
/// [middle] for a screen whose bar *is* a control, or empty space), then
/// [actions], then the colour-scheme toggle. The middle takes the slack, which
/// is what pushes the actions to the right edge without a spacer.
///
/// [maxWidth] is about the content below rather than the bar: a screen that
/// centres a column wants its bar centred on the same one, and a full-bleed
/// screen wants the bar full-bleed too. Either way the border spans the
/// viewport, so the bar reads as one band across every screen.
class SiteBar extends StatelessComponent {
  const SiteBar({
    this.back,
    this.title,
    this.middle,
    this.actions = const <Component>[],
    this.toggle = SiteBarToggle.always,
    this.maxWidth,
    this.sticky = false,
    this.current,
    this.nav = false,
    super.key,
  }) : assert(title == null || middle == null,
            'A bar has one middle: a title or a component, not both.');

  /// The back affordance, or null on a page nothing is above.
  final BackLink? back;

  /// The screen's name, elided rather than wrapped when the bar is tight.
  final String? title;

  /// A screen whose bar *is* its control — the loader's URL field — supplies
  /// the middle itself instead of a title.
  final Component? middle;

  /// Screen-specific controls, in the order they should read.
  final List<Component> actions;

  /// Whether the colour-scheme toggle folds away on a phone.
  final SiteBarToggle toggle;

  /// The content column to centre on, or null for a full-bleed screen.
  final double? maxWidth;

  /// Whether the bar stays put as the page scrolls — for screens whose
  /// controls stay relevant after you have scrolled away from them.
  final bool sticky;

  /// The path being rendered, so its nav entry can mark itself.
  final String? current;

  /// Whether to carry the top-level nav links.
  final bool nav;

  @override
  Component build(BuildContext context) {
    return header(
      classes: sticky ? 'site-bar is-sticky' : 'site-bar',
      <Component>[
        div(
          classes: 'site-bar-inner',
          styles: maxWidth == null
              ? null
              : Styles(raw: <String, String>{
                  'max-width': '${maxWidth!.toStringAsFixed(0)}px',
                  'margin': '0 auto',
                }),
          <Component>[
            if (back != null) back!,
            Link(
              to: '/',
              // The wordmark folds away exactly when the bar also names a
              // screen, because that is when the width is contested and the
              // title is the half that has to survive.
              classes: title == null && middle == null
                  ? 'site-wordmark'
                  : 'site-wordmark wide-only',
              child: Component.text('A2UI Craft'),
            ),
            if (middle != null)
              middle!
            else if (title != null)
              h2(classes: 'site-bar-title', <Component>[Component.text(title!)])
            else
              div(classes: 'site-bar-spacer', const <Component>[]),
            if (nav)
              for (final (String to, String label) in _navItems)
                Link(
                  to: to,
                  classes: to == current
                      ? 'site-nav-link wide-only is-current'
                      : 'site-nav-link wide-only',
                  child: Component.text(label),
                ),
            ...actions,
            ThemeToggle(
              className: toggle == SiteBarToggle.wideOnly ? 'wide-only' : null,
            ),
          ],
        ),
      ],
    );
  }
}

/// The site footer: what this is, and where to go next.
class SiteFooter extends StatelessComponent {
  const SiteFooter({super.key});

  @override
  Component build(BuildContext context) {
    return footer(
      classes: 'site-footer',
      <Component>[
        div(
          classes: 'site-footer-inner',
          <Component>[
            div(
              <Component>[
                div(
                  styles: Styles(raw: <String, String>{
                    'font': '600 14px system-ui',
                    'color': 'var(--fg)',
                  }),
                  <Component>[Component.text('A2UI Craft')],
                ),
                p(
                  styles: Styles(raw: <String, String>{
                    'font': '13px/1.6 system-ui',
                    'color': 'var(--subtle)',
                    'margin': '6px 0 0',
                    'max-width': '48ch',
                  }),
                  <Component>[
                    Component.text(
                      'Experimental and pre-1.0. The template syntax is still '
                      'moving, and the packages are not published yet.',
                    ),
                  ],
                ),
              ],
            ),
            div(
              classes: 'site-footer-links',
              <Component>[
                _externalLink(_repoUrl, 'GitHub'),
                _externalLink(_issuesUrl, 'Issues'),
                _externalLink(_designUrl, 'Design doc'),
              ],
            ),
          ],
        ),
      ],
    );
  }

  /// A plain `<a>`, not a router [Link]: these leave the site, so client-side
  /// navigation would be wrong.
  Component _externalLink(String href, String label) {
    return a(
      href: href,
      classes: 'site-footer-link',
      attributes: const <String, String>{
        'target': '_blank',
        'rel': 'noopener noreferrer',
      },
      <Component>[Component.text(label)],
    );
  }
}
