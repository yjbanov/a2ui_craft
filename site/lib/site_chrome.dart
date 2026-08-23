// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

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
const List<(String, String)> _navItems = <(String, String)>[
  ('/gallery', 'Gallery'),
  ('/primitives', 'Primitives'),
  ('/load', 'Load a project'),
];

/// The site header: wordmark home, the top-level nav, and the colour-scheme
/// toggle.
///
/// Shared by the pages that are *destinations* (the landing page, the gallery).
/// The working screens — a sample, a mini-app, the primitives page — keep their
/// own toolbars instead, because those carry screen-specific controls (the
/// adapter switch, the brand and mode pickers) that have nowhere to live here,
/// and because a second row of chrome above a working surface is exactly the
/// vertical space the phone layout has least of.
class SiteHeader extends StatelessComponent {
  const SiteHeader({this.current, super.key});

  /// The path of the page being rendered, so its nav entry can mark itself —
  /// or null on a page that is not one of [_navItems].
  final String? current;

  @override
  Component build(BuildContext context) {
    return header(
      classes: 'site-header',
      <Component>[
        div(
          classes: 'site-header-inner',
          <Component>[
            Link(
              to: '/',
              classes: 'site-wordmark',
              child: Component.text('A2UI Craft'),
            ),
            div(styles: Styles(raw: <String, String>{'flex': '1'}), const []),
            // The nav folds away on a phone, following the convention the
            // other toolbars already use: keeping "a favoured few" links
            // visible only wraps the bar to a second row.
            for (final (String to, String label) in _navItems)
              Link(
                to: to,
                classes: to == current
                    ? 'site-nav-link wide-only is-current'
                    : 'site-nav-link wide-only',
                child: Component.text(label),
              ),
            const ThemeToggle(),
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
