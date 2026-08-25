// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';

import 'code_block.dart';
import 'engine_demo.dart';
import 'landing_demos.dart';
import 'site_chrome.dart';

/// The landing page: what A2UI Craft is, and four things it does.
///
/// The gallery lives at `/gallery` — this page is the front door, in the shape
/// the framework-site genre has settled on (hero, then one section per claim,
/// each earning its claim with something that runs rather than an adjective).
///
/// Every section carries a demo that actually runs: the template section
/// renders a real sample through either engine, the primitives section is
/// interactive, the theming section repaints under four token sets, and the
/// logic section runs a mini-app's published JavaScript in a worker. A claim
/// here is backed by something running or it does not belong on the page.
class LandingScreen extends StatelessComponent {
  const LandingScreen({super.key});

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'font-family': 'system-ui, -apple-system, sans-serif',
      }),
      <Component>[
        const SiteBar(maxWidth: 1100, nav: true, current: '/'),
        _hero(),
        for (final _Feature f in _features) _section(f),
        _alsoInTheBox(),
        const SiteFooter(),
      ],
    );
  }

  Component _hero() {
    return div(
      styles: Styles(raw: <String, String>{
        'max-width': '1100px',
        'margin': '0 auto',
        'padding': '56px 20px 60px',
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
            Component.text('Client-side templates and logic for A2UI.'),
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
            _cta('/mini-app/cart', 'See logic running'),
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
      classes: primary ? 'landing-cta is-primary' : 'landing-cta',
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
            f.demo(),
          ],
        ),
      ],
    );
  }

  /// The rest of the framework, one card each.
  ///
  /// Four sections is the page's budget for things that get a demo; these are
  /// real capabilities that would each need one, and a landing page that gave
  /// them all a section would be a changelog. Every card links somewhere it can
  /// actually be seen — a card that only asserts is worse than no card.
  Component _alsoInTheBox() {
    return div(
      styles: Styles(raw: <String, String>{
        'border-top': '1px solid var(--border)',
        'background': 'var(--panel)',
      }),
      <Component>[
        div(
          styles: Styles(raw: <String, String>{
            'max-width': '1100px',
            'margin': '0 auto',
            'padding': '56px 20px',
          }),
          <Component>[
            h2(
              styles: Styles(raw: <String, String>{
                'font': '700 clamp(22px, 3vw, 30px)/1.2 system-ui',
                'letter-spacing': '-0.01em',
                'margin': '0',
                'color': 'var(--fg)',
              }),
              <Component>[Component.text('Also in the box')],
            ),
            div(
              styles: Styles(raw: <String, String>{
                'display': 'grid',
                'grid-template-columns': 'repeat(auto-fit, minmax(260px, 1fr))',
                'gap': '14px',
                'margin-top': '28px',
              }),
              <Component>[for (final _Extra e in _extras) _extraCard(e)],
            ),
          ],
        ),
      ],
    );
  }

  Component _extraCard(_Extra e) {
    return Link(
      to: e.to,
      classes: 'also-card',
      child: div(<Component>[
        div(
          styles: Styles(raw: <String, String>{
            'font': '600 15px system-ui',
            'color': 'var(--fg)',
          }),
          <Component>[Component.text(e.title)],
        ),
        p(
          styles: Styles(raw: <String, String>{
            'font': '14px/1.6 system-ui',
            'color': 'var(--muted)',
            'margin': '8px 0 0',
          }),
          <Component>[Component.text(e.blurb)],
        ),
      ]),
    );
  }

  Component _textLink(String to, String label) {
    return Link(
      to: to,
      classes: 'landing-section-link',
      child: Component.text('$label →'),
    );
  }
}

/// One "also in the box" card: a capability, and somewhere to go see it.
class _Extra {
  const _Extra({required this.title, required this.blurb, required this.to});

  final String title;
  final String blurb;

  /// Where the card goes. Every one of these resolves to a page that shows the
  /// thing; none is a dead end.
  final String to;
}

const List<_Extra> _extras = <_Extra>[
  _Extra(
    title: 'Responsive structure',
    blurb: 'A quantized size class supplied at render time, never raw pixels — '
        'plus intrinsic reflow that needs no breakpoints at all.',
    to: '/sample/responsive',
  ),
  _Extra(
    title: 'Motion',
    blurb: 'Implicit animation: interpolate when a retained component\'s '
        'property changes between rebuilds, with easing as a token.',
    to: '/sample/motion',
  ),
  _Extra(
    title: 'Normalized controls',
    blurb: 'Every control specified once and painted per theme role, with a '
        'platform idiom the host selects.',
    to: '/sample/settings',
  ),
  _Extra(
    title: 'Projects you can deploy',
    blurb: 'A project is a folder of data files — template, schema, bootstrap, '
        'manifest — publishable to a CDN with no build step.',
    to: '/load',
  ),
  _Extra(
    title: 'Template functions',
    blurb: 'Math, comparison, logic, and strings, strict about types and total '
        'on bad input — so agent data cannot crash the surface.',
    to: '/sample/calculator',
  ),
  _Extra(
    title: 'Cross-adapter conformance',
    blurb: 'One suite asserting real geometry with tolerance on both engines, '
        'against actual layout rather than a structural proxy.',
    to: '/primitives',
  ),
];

/// The copy for one landing-page section.
class _Feature {
  const _Feature({
    required this.eyebrow,
    required this.title,
    required this.blurb,
    required this.linkTo,
    required this.linkLabel,
    required this.demo,
  });

  final String eyebrow;
  final String title;
  final String blurb;
  final String linkTo;
  final String linkLabel;

  /// The section's live demo. Every section has one — a claim on this page is
  /// backed by something running or it does not belong here.
  final Component Function() demo;
}

/// The sample the templates section renders: the counter.
///
/// Chosen because it is *interactive* — a tap increments state — so flipping
/// the engine and pressing again shows the same behaviour twice, which a static
/// card could not. It also happens to demonstrate local template state and a
/// standard function, since RFW has no `+` operator.
RawSample get _counter =>
    rawSamples.firstWhere((RawSample s) => s.id == 'counter');

/// The counter's shipped source, minus its explanatory comments.
///
/// Read from the sample itself rather than retyped, so the code on the landing
/// page cannot drift from the template the page is actually rendering beside
/// it. Only comment lines are dropped — what is left is exactly what runs.
String get _counterSource => _counter.template
    .split('\n')
    .where((String l) => !l.trimLeft().startsWith('//'))
    .join('\n')
    .replaceAll(RegExp(r'\n{3,}'), '\n\n')
    .trim();

Component _primitivesDemo() => const LandingSurface(
      surfaceId: 'landing-primitives',
      template: primitivesTemplate,
    );

Component _themingDemo() => const ThemingDemo();

Component _logicDemo() => const LogicDemo();

Component _templatesDemo() => div(
      styles: Styles(raw: <String, String>{
        'display': 'grid',
        'gap': '14px',
      }),
      <Component>[
        CraftCode(source: _counterSource, label: 'template.craft'),
        EngineDemo(sample: _counter),
      ],
    );

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
    demo: _templatesDemo,
  ),
  _Feature(
    eyebrow: 'A standard catalog',
    title: 'Primitives all engines agree on',
    blurb:
        'Layout, text and Markdown, images and icons, and the controls a real '
        'screen needs — text fields, checkboxes, radios, switches, selects, '
        'sliders. Each is built on the platform\'s own control, a native input '
        'on the web and an adaptive widget in Flutter, so focus, keyboard, and '
        'screen readers behave the way people expect. And a Slider is the same '
        'Slider wherever it renders.',
    linkTo: '/primitives',
    linkLabel: 'Browse the primitives',
    demo: _primitivesDemo,
  ),
  _Feature(
    eyebrow: 'Design systems',
    title: 'Your brand, from the tokens you already have',
    blurb: 'Themes are W3C DTCG token files — the format Figma, Tokens Studio, '
        'and Style Dictionary already speak — adopted as-is rather than '
        'reinvented. The roles primitives read carry the names Material 3 and '
        'shadcn already use, so an existing export maps on without '
        'translation. And they resolve at runtime rather than in a build step, '
        'so a project carries its brand with it — the switcher here is four '
        'token sets, and yours would be the fifth.',
    linkTo: '/primitives',
    linkLabel: 'Try the brands',
    demo: _themingDemo,
  ),
  _Feature(
    eyebrow: 'Logic',
    title: 'When a template is not enough',
    blurb: 'Templates render; they do not decide. When something has to — a '
        'whole mini-app, or a single catalog component templates cannot '
        'express — a project brings its own logic, in the language you '
        'already use. The contract is JSON over an asynchronous channel, so '
        'anything that can hold state and speak JSON can implement it, and '
        'that asynchrony makes the packaging, and the isolation, your choice: '
        'a web worker, an iframe, a webview, or your own server. Below, the '
        'cart\'s own JavaScript runs in a worker.',
    linkTo: '/mini-app/cart',
    linkLabel: 'Run it on both engines',
    demo: _logicDemo,
  ),
];
