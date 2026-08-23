// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'theme_mode.dart';

/// The landing page: what A2UI Craft is, and four things it does.
///
/// The gallery lives at `/gallery` — this page is the front door, in the shape
/// the framework-site genre has settled on (hero, then one section per claim,
/// each earning its claim with something that runs rather than an adjective).
///
/// Slice 1 is the skeleton: the copy and the navigation are real, and each
/// section reserves the space its live demo will occupy. Nothing here pretends
/// to be a demo it isn't — a placeholder says what is coming, so a half-built
/// page reads as half-built instead of as a broken one.
class LandingScreen extends StatelessComponent {
  const LandingScreen({super.key});

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'font-family': 'system-ui, -apple-system, sans-serif',
      }),
      <Component>[
        _topBar(),
        _hero(),
        for (final _Feature f in _features) _section(f),
      ],
    );
  }

  /// The minimal chrome slice 1 needs: the wordmark, the gallery link, and the
  /// colour-scheme toggle every other screen already carries. The full site
  /// header (nav, footer) is slice 2.
  Component _topBar() {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '12px',
        'max-width': '1100px',
        'margin': '0 auto',
        'padding': '16px 20px',
      }),
      <Component>[
        span(
          styles: Styles(raw: <String, String>{
            'font': '600 15px system-ui',
            'color': 'var(--fg)',
            // Never let the wordmark be the thing that compresses: without
            // this it shrinks to a 37px column of stacked letters on a phone.
            'flex': 'none',
            'white-space': 'nowrap',
          }),
          <Component>[Component.text('A2UI Craft')],
        ),
        div(styles: Styles(raw: <String, String>{'flex': '1'}), const []),
        // The nav folds away on a phone, following the toolbar convention the
        // other screens already use: a bar that keeps "a favoured few" links
        // visible just wraps to a second row and spends the axis a phone has
        // least of. Everything here is reachable from the hero CTAs and the
        // section links below.
        _navLink('/gallery', 'Gallery'),
        _navLink('/primitives', 'Primitives'),
        _navLink('/load', 'Load a project'),
        const ThemeToggle(),
      ],
    );
  }

  Component _navLink(String to, String label) {
    return Link(
      to: to,
      classes: 'wide-only',
      styles: Styles(raw: <String, String>{
        'white-space': 'nowrap',
        'color': 'var(--muted)',
        'text-decoration': 'none',
        'font': '14px system-ui',
        'padding': '6px 8px',
        'border-radius': '8px',
      }),
      child: Component.text(label),
    );
  }

  Component _hero() {
    return div(
      styles: Styles(raw: <String, String>{
        'max-width': '1100px',
        'margin': '0 auto',
        'padding': '48px 20px 56px',
      }),
      <Component>[
        _experimentalBadge(),
        h1(
          styles: Styles(raw: <String, String>{
            'font': '700 clamp(32px, 6vw, 56px)/1.1 system-ui',
            'letter-spacing': '-0.02em',
            'margin': '18px 0 0',
            'max-width': '18ch',
            'color': 'var(--fg)',
          }),
          <Component>[
            Component.text('Client-side templates and mini-apps for A2UI.'),
          ],
        ),
        p(
          styles: Styles(raw: <String, String>{
            'font': '18px/1.6 system-ui',
            'color': 'var(--muted)',
            'margin': '20px 0 0',
            'max-width': '62ch',
          }),
          <Component>[
            Component.text(
              'An agent composes UI from a catalog of components — but someone '
              'has to implement that catalog, by hand, once per UI framework. '
              'Craft makes the catalog data instead: templates over a standard '
              'primitive set, authored once and rendered natively by every '
              'adapter, with optional business logic that ships alongside.',
            ),
          ],
        ),
        div(
          styles: Styles(raw: <String, String>{
            'display': 'flex',
            'flex-wrap': 'wrap',
            'gap': '12px',
            'margin-top': '32px',
          }),
          <Component>[
            _cta('/gallery', 'Browse the gallery', primary: true),
            _cta('/mini-app/cart', 'Run a mini-app'),
          ],
        ),
      ],
    );
  }

  /// Says what this is before anything else does.
  ///
  /// The genre this page borrows from is used to sell finished frameworks, and
  /// a confident landing page reads as a stability promise unless it says
  /// otherwise. Craft is pre-1.0 and its template syntax is still moving, so
  /// the badge is the first thing on the page, not a footnote under the fold.
  Component _experimentalBadge() {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'inline-flex',
        'align-items': 'center',
        'gap': '8px',
        'padding': '5px 12px',
        'border-radius': '999px',
        'border': '1px solid var(--border-strong)',
        'background': 'var(--panel)',
        'font': '600 12px system-ui',
        'letter-spacing': '0.04em',
        'text-transform': 'uppercase',
        'color': 'var(--muted)',
      }),
      <Component>[
        span(
          styles: Styles(raw: <String, String>{
            'width': '6px',
            'height': '6px',
            'border-radius': '999px',
            'background': 'var(--accent)',
          }),
          const <Component>[],
        ),
        Component.text('Experimental'),
      ],
    );
  }

  Component _cta(String to, String label, {bool primary = false}) {
    return Link(
      to: to,
      styles: Styles(raw: <String, String>{
        'display': 'inline-flex',
        'align-items': 'center',
        'padding': '11px 20px',
        'border-radius': '10px',
        'font': '600 15px system-ui',
        'text-decoration': 'none',
        'border': primary
            ? '1px solid var(--accent)'
            : '1px solid var(--border-strong)',
        'background': primary ? 'var(--accent)' : 'transparent',
        'color': primary ? 'var(--accent-fg)' : 'var(--fg)',
      }),
      child: Component.text(label),
    );
  }

  /// One feature section: eyebrow, title, blurb, link, and the space its live
  /// demo will fill.
  Component _section(_Feature f) {
    return div(
      styles: Styles(raw: <String, String>{
        'border-top': '1px solid var(--border)',
      }),
      <Component>[
        div(
          styles: Styles(raw: <String, String>{
            'max-width': '1100px',
            'margin': '0 auto',
            'padding': '56px 20px',
            'display': 'grid',
            // The prose column stays readable while the demo takes the rest;
            // below ~880px they stack, which `auto-fit` does without a query.
            'grid-template-columns': 'repeat(auto-fit, minmax(320px, 1fr))',
            'gap': '32px',
            'align-items': 'center',
          }),
          <Component>[
            div(<Component>[
              div(
                styles: Styles(raw: <String, String>{
                  'font': '600 12px system-ui',
                  'letter-spacing': '0.08em',
                  'text-transform': 'uppercase',
                  'color': 'var(--accent)',
                }),
                <Component>[Component.text(f.eyebrow)],
              ),
              h2(
                styles: Styles(raw: <String, String>{
                  'font': '700 clamp(24px, 3.4vw, 34px)/1.2 system-ui',
                  'letter-spacing': '-0.01em',
                  'margin': '10px 0 0',
                  'color': 'var(--fg)',
                }),
                <Component>[Component.text(f.title)],
              ),
              p(
                styles: Styles(raw: <String, String>{
                  'font': '16px/1.65 system-ui',
                  'color': 'var(--muted)',
                  'margin': '14px 0 0',
                  'max-width': '52ch',
                }),
                <Component>[Component.text(f.blurb)],
              ),
              div(
                styles: Styles(raw: <String, String>{'margin-top': '20px'}),
                <Component>[_textLink(f.linkTo, f.linkLabel)],
              ),
            ]),
            _demoSlot(f.demoNote),
          ],
        ),
      ],
    );
  }

  Component _textLink(String to, String label) {
    return Link(
      to: to,
      styles: Styles(raw: <String, String>{
        'font': '600 15px system-ui',
        'color': 'var(--accent)',
        'text-decoration': 'none',
      }),
      child: Component.text('$label →'),
    );
  }

  /// The reserved space for a section's live demo.
  ///
  /// Dashed and explicitly labelled: an empty panel would read as a demo that
  /// failed to load, which is exactly the impression a framework site cannot
  /// afford. This disappears as each demo lands.
  Component _demoSlot(String note) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'center',
        'min-height': '260px',
        'padding': '24px',
        'border': '1px dashed var(--border-strong)',
        'border-radius': '14px',
        'background': 'var(--panel)',
        'font': '13px/1.6 ui-monospace, monospace',
        'color': 'var(--subtle)',
        'text-align': 'center',
      }),
      <Component>[Component.text(note)],
    );
  }
}

/// The copy for one landing-page section.
class _Feature {
  const _Feature({
    required this.eyebrow,
    required this.title,
    required this.blurb,
    required this.linkTo,
    required this.linkLabel,
    required this.demoNote,
  });

  final String eyebrow;
  final String title;
  final String blurb;
  final String linkTo;
  final String linkLabel;

  /// What will replace the placeholder, stated plainly.
  final String demoNote;
}

/// The four claims, in the order they build on each other: a template needs
/// primitives to be written over, a theme re-skins what those render, and logic
/// is what turns the result into an app.
const List<_Feature> _features = <_Feature>[
  _Feature(
    eyebrow: 'Author once',
    title: 'One template, every renderer',
    blurb: 'A catalog component is a template over primitives — text, not code '
        '— so it ships as data and every adapter renders it natively. The same '
        'template, schema, and message stream drive the DOM and Flutter, and '
        'neither one knows which it is.',
    linkTo: '/gallery',
    linkLabel: 'See the samples',
    demoNote: 'Live: a template and its rendered surface, '
        'with a switch between the Jaspr and Flutter engines.',
  ),
  _Feature(
    eyebrow: 'A standard catalog',
    title: 'Primitives both engines agree on',
    blurb:
        'Layout, text, images, and controls, specified once as a constrained '
        'common model rather than hand-mirrored per framework. Conformance is '
        'asserted against real layout on both adapters — actual geometry, with '
        'tolerance, not a structural proxy.',
    linkTo: '/primitives',
    linkLabel: 'Browse the primitives',
    demoNote: 'Live: a strip of primitive specimens, '
        'rendered by the same catalog the conformance suite pins.',
  ),
  _Feature(
    eyebrow: 'Design systems',
    title: 'Re-skin it without touching the template',
    blurb: 'Themes are W3C DTCG tokens delivered as data, resolved at runtime. '
        'Primitives read semantic roles, so a new brand re-inks a live surface '
        'in place — no remount, no reload, and not one edit to the template '
        'that drew it.',
    linkTo: '/gallery',
    linkLabel: 'See a themed project',
    demoNote: 'Live: a brand switcher re-inking one surface, '
        'across light and dark.',
  ),
  _Feature(
    eyebrow: 'Mini-apps',
    title: 'Logic that ships with the UI',
    blurb: 'A project can bring its own business logic, sandboxed and speaking '
        'the same protocol the UI does. The cart mini-app ships that logic '
        'twice — JavaScript and Dart — and one conformance suite passes against '
        'both, which is what proves the protocol is the only coupling.',
    linkTo: '/mini-app/cart',
    linkLabel: 'Run the cart mini-app',
    demoNote: 'Live: a mini-app driven by its own published '
        'JavaScript, running in a web worker.',
  ),
];
