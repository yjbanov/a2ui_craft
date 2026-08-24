// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:web/web.dart' as web;

import 'icons.dart';

/// Where this tab was when the site loaded, and therefore whether stepping
/// back stays inside the site.
abstract final class SiteNav {
  static String? _entryPath;

  /// Records the path the document loaded with.
  ///
  /// Call once, before `runApp` — the value has to be read before the first
  /// client-side navigation moves it, which rules out a lazily-initialized
  /// top-level field (Dart would capture whatever the path was at *first
  /// read*, not at load).
  static void init() => _entryPath ??= web.window.location.pathname;

  /// Whether there is a history entry of ours behind the current one.
  ///
  /// The site is a single page load: every route change after [init] is a
  /// `pushState`, so a path that differs from the entry path can only have
  /// been reached by one of our own pushes — which guarantees at least one of
  /// our entries sits behind us. When the paths match, this is either a fresh
  /// load or a deep link, and stepping back would leave the site entirely.
  static bool get canGoBack =>
      _entryPath != null && web.window.location.pathname != _entryPath;
}

/// The circled back arrow shared by the working screens.
///
/// **Back means "where you came from", not a fixed page.** It used to mean a
/// fixed page, and that was right while the gallery was the only way in: every
/// screen was reached from the gallery, so a hardcoded link there and a real
/// back step were the same journey. The landing page added a second way in,
/// and the hardcoded link started answering a question nobody asked — open a
/// mini-app from the landing page, press back, and you arrived at a gallery
/// you had never seen.
///
/// So it pops the history stack, and [fallback] catches the one case where
/// popping is wrong: someone who deep-linked straight to this screen has no
/// entry of ours behind them, and back would take them off the site. They get
/// the screen's parent page instead.
///
/// Rendered as an `<a>` rather than a `<button>` so the fallback destination is
/// a real link — it shows in the status bar on hover and opens in a new tab on
/// a middle click, both of which a button silently swallows.
class BackLink extends StatelessComponent {
  const BackLink({
    required this.fallback,
    required this.fallbackLabel,
    super.key,
  });

  /// Where to go when there is no in-app history to step back through: the
  /// screen's parent page.
  final String fallback;

  /// What that parent is called, for the accessible name — "back" alone says
  /// nothing about the destination when the destination is fixed.
  final String fallbackLabel;

  @override
  Component build(BuildContext context) {
    // Read at build time only to name the control. The click handler asks
    // again, because it is what actually decides.
    final String label = SiteNav.canGoBack ? 'Back' : 'Back to $fallbackLabel';
    return a(
      href: fallback,
      classes: 'back-btn',
      attributes: <String, String>{'aria-label': label, 'title': label},
      events: <String, void Function(web.Event)>{
        'click': (web.Event event) {
          event.preventDefault();
          if (SiteNav.canGoBack) {
            context.back();
          } else {
            context.push(fallback);
          }
        },
      },
      <Component>[
        span(classes: 'back-badge', <Component>[backIcon()])
      ],
    );
  }
}
