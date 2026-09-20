// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_logic/web.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'brand_themes.dart';
import 'code_block.dart';
import 'mini_app_screen.dart';
import 'segmented.dart';
import 'theme_mode.dart';

/// One self-contained Craft surface for the landing page.
///
/// The same shape as a sample trio in miniature — a `Root` template, a bare
/// catalog naming it, and the three messages that build the surface — so a
/// landing-page demo goes through the *real* A2UI path (create surface, seed
/// the model, place the component) rather than a shortcut that would prove
/// less than it appears to.
class LandingSurface extends StatefulComponent {
  const LandingSurface({
    required this.surfaceId,
    required this.template,
    this.rootComponent = 'Root',
    this.theme,
    this.media,
    super.key,
  });

  /// Unique per demo: each surface must be unmistakably its own.
  final String surfaceId;

  /// RFW source defining a [rootComponent] widget.
  final String template;

  /// The root component name. Defaults to 'Root'.
  final String rootComponent;

  /// The theme to render under, or null to blend into the host.
  final CraftTheme? theme;

  /// The media context (environment and capabilities).
  final MediaContext? media;

  @override
  State<LandingSurface> createState() => _LandingSurfaceState();
}

class _LandingSurfaceState extends State<LandingSurface> {
  // Built once. `SampleView` reads its catalog and message script in
  // `initState`, so rebuilding these on every parent rebuild would be pure
  // waste — and the re-theme path rebuilds this component by design.
  late final Map<String, Object?> _schema = <String, Object?>{
    'catalogId': component.surfaceId,
    'components': <String, Object?>{
      component.rootComponent: <String, Object?>{
        'properties': <String, Object?>{}
      },
    },
  };

  late final List<A2uiMessage> _messages = <A2uiMessage>[
    A2uiMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'createSurface': <String, Object?>{
        'surfaceId': component.surfaceId,
        'catalogId': component.surfaceId,
        'sendDataModel': false,
      },
    }),
    A2uiMessage.fromJson(<String, dynamic>{
      'version': 'v0.9',
      'updateComponents': <String, Object?>{
        'surfaceId': component.surfaceId,
        'components': <Object?>[
          <String, Object?>{'id': 'root', 'component': component.rootComponent},
        ],
      },
    }),
  ];

  @override
  Component build(BuildContext context) {
    return SampleView(
      // A stable key so a re-theme reconciles onto the *same* SampleView —
      // which is what keeps its Runtime, and therefore the surface's template
      // state, alive across the swap.
      key: ValueKey<String>(component.surfaceId),
      template: component.template,
      schema: _schema,
      messages: _messages,
      theme: component.theme,
      media: component.media,
    );
  }
}

/// The primitives section's demo: a handful of the catalog, live.
///
/// Interactive on purpose. A row of static swatches would say "there are
/// primitives"; controls that actually toggle say "these are the real ones,
/// and they behave" — which is the claim the conformance suite backs.
const String primitivesTemplate = r'''
import core;

widget Root { on: true, agree: false, level: 60.0 } =
  Column(width: "fill", gap: 14.0, crossAxisAlignment: "start", children: [
    Heading(text: "Heading", level: 4),
    Text(text: "Body text over the type scale, plus a caption below."),
    Text(text: "Caption", variant: "caption"),
    Divider(),
    Wrap(gap: 10.0, runGap: 10.0, children: [
      Button(onPressed: set state.on = switch state.on { true: false, false: true },
        child: Text(text: "Button")),
      Button(onPressed: set state.on = switch state.on { true: false, false: true },
        cornerRadius: 999.0, child: Row(gap: 6.0, crossAxisAlignment: "center",
          children: [Icon(icon: "add"), Text(text: "Pill")])),
    ]),
    Row(gap: 10.0, crossAxisAlignment: "center", children: [
      Checkbox(value: state.agree,
        onChanged: set state.agree = switch state.agree { true: false, false: true }),
      Text(text: "Checkbox"),
      Switch(value: state.on,
        onChanged: set state.on = switch state.on { true: false, false: true }),
      Text(text: "Switch"),
    ]),
    Row(width: "fill", gap: 12.0, crossAxisAlignment: "center", children: [
      Text(text: "Slider", variant: "caption"),
      Expanded(child: Box(height: 40.0, child: Slider(min: 0.0, max: 100.0,
        steps: 100, value: state.level, onChanged: set state.level = args.value))),
    ]),
  ]);
''';

/// The theming section's demo: one surface, re-inked live.
///
/// Deliberately the *same* markup under every brand. The point is not that
/// four cards exist but that switching the token set repaints this one, with
/// not a character of the template changed.
///
/// **Known gap:** the surface's *template state* (the quantity stepper) resets
/// on a brand switch, so this demo does not show the no-remount half of the
/// re-theme contract. The engine's own conformance case
/// ("the default theme paints its modes; a mode flip re-themes in place")
/// proves local state survives a re-theme on both adapters, so the contract
/// holds — something in this site's `SampleView` path is tearing the runtime
/// down instead of handing it the next snapshot. Worth chasing; the copy
/// claims only the repaint until it is.
const String themingTemplate = r'''
import core;

widget Root { qty: 1 } = Card(child:
  Column(width: "fill", gap: 12.0, crossAxisAlignment: "start", children: [
    Heading(text: "Mechanical keyboard", level: 5),
    Text(text: "Tactile switches, two-year warranty.", variant: "caption"),
    Row(gap: 10.0, crossAxisAlignment: "center", children: [
      Button(onPressed: set state.qty = max(a: 1.0, b: subtract(a: state.qty, b: 1)),
        child: Text(text: "-")),
      Text(text: state.qty),
      Button(onPressed: set state.qty = add(a: state.qty, b: 1),
        child: Text(text: "+")),
    ]),
    Divider(),
    Row(width: "fill", gap: 10.0, crossAxisAlignment: "center", children: [
      Checkbox(value: true),
      Text(text: "Gift wrap"),
      Expanded(child: Box()),
      Button(onPressed: set state.qty = state.qty, child: Text(text: "Add to cart")),
    ]),
  ]));
''';

/// The brand switcher: the same surface, re-inked by whichever token set is
/// selected.
class ThemingDemo extends StatefulComponent {
  const ThemingDemo({super.key});

  @override
  State<ThemingDemo> createState() => _ThemingDemoState();
}

class _ThemingDemoState extends State<ThemingDemo> {
  Brand _brand = kBrands.first;
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    // The brand's theme is resolved per colour scheme, so a flip of the site's
    // dark-light toggle has to re-resolve it — the surface is themed
    // explicitly and cannot pick that up from CSS.
    _unsubscribe = SiteTheme.onChange(() => setState(() {}));
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  CraftThemeMode get _mode =>
      SiteTheme.effectiveDark ? CraftThemeMode.dark : CraftThemeMode.light;

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'engine-demo',
      <Component>[
        div(
          classes: 'engine-demo-bar',
          <Component>[
            span(
              classes: 'engine-demo-caption wide-only',
              <Component>[Component.text('Brand')],
            ),
            CraftSegmented(
              options: <String>[for (final Brand b in kBrands) b.label],
              selected: _brand.label,
              onSelect: (String label) => setState(() {
                _brand = kBrands.firstWhere((Brand b) => b.label == label);
              }),
              ariaLabel: 'Brand theme',
            ),
          ],
        ),
        div(
          classes: 'engine-demo-surface',
          <Component>[
            LandingSurface(
              surfaceId: 'landing-theming',
              template: themingTemplate,
              theme: _brand.craftTheme(_mode),
            ),
          ],
        ),
      ],
    );
  }
}

/// The cart mini-app: a project that ships its own business logic.
RawMiniApp get _cart =>
    rawMiniApps.firstWhere((RawMiniApp m) => m.id == 'cart');

/// The opening of the shipped `cart.js`, down to the end of its first handler.
///
/// Sliced out of the real driver rather than retyped, so it cannot drift from
/// the file the worker beside it is running. It *is* an excerpt — the label
/// says so, and the ellipsis stands where the rest of the shop's rules were —
/// because the whole driver is 169 lines and the point is the shape: an
/// `onInit`, and handlers that answer events by writing to the data model.
String get _cartDriverExcerpt {
  final String src = _cart.driverJs;
  final int start = src.indexOf('a2uiDriver({');
  final int end = src.indexOf('    removeItem:', start);
  if (start < 0 || end < 0) return src;
  final String head = src.substring(start, end).trimRight();
  return "$head\n\n    // …the rest of the shop's rules.\n  },\n});";
}

/// The logic section's demo: the cart mini-app, driven by its own JavaScript.
///
/// The driver runs in a **web worker** — no DOM, no access to anything the page
/// holds — and talks to the surface over the session protocol. Nothing about
/// this pane knows the logic is JavaScript; the Flutter pane on `/mini-app/cart`
/// runs a Dart port of the same rules against the same conformance suite.
class LogicDemo extends StatelessComponent {
  const LogicDemo({super.key});

  @override
  Component build(BuildContext context) {
    final RawMiniApp cart = _cart;
    return div(
      styles: Styles(raw: <String, String>{'display': 'grid', 'gap': '14px'}),
      <Component>[
        CraftCode(source: _cartDriverExcerpt, label: 'cart.js (excerpt)'),
        div(
          classes: 'engine-demo',
          <Component>[
            div(
              classes: 'engine-demo-bar',
              <Component>[
                span(
                  classes: 'engine-demo-caption',
                  <Component>[Component.text('Driver in a web worker')],
                ),
              ],
            ),
            div(
              classes: 'engine-demo-surface',
              <Component>[
                JasprMiniAppPane(
                  template: cart.template,
                  schema: jsonDecode(cart.schema) as Map<String, Object?>,
                  coldBoot: () => <A2uiMessage>[
                    for (final Object? m
                        in jsonDecode(cart.messages) as List<Object?>)
                      A2uiMessage.fromJson(m! as Map<String, dynamic>),
                  ],
                  // The file the project publishes, run as it ships: nothing
                  // is compiled and nothing is bundled.
                  createTransport: () =>
                      WorkerDriverRunner.fromSource(cart.driverJs),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// The feature detection sample.
RawSample get featureDetectionSample =>
    rawSamples.firstWhere((RawSample s) => s.id == 'feature_detection');

/// Excerpt from `packages/a2ui_craft_examples/samples/feature_detection/template.craft`.
const String featureDetectionExcerpt = r'''
// Branch on platform & hardware capabilities with graceful fallbacks:
switch and(a: media.hasBiometrics, b: equals(a: media.platform, b: "ios")) {
  true: Button(
    onPressed: set state.paymentMethod = "Apple Pay (Biometrics)",
    child: Text(text: "Pay with Apple Pay"),
  ),
  default: switch and(a: media.hasNfc, b: equals(a: media.platform, b: "android")) {
    true: Button(
      onPressed: set state.paymentMethod = "Google Pay (NFC)",
      child: Text(text: "Pay with Google Pay"),
    ),
    default: Button(
      onPressed: set state.paymentMethod = "Credit Card (Standard Fallback)",
      child: Text(text: "Pay with Credit Card"),
    ),
  },
}
''';

/// The feature detection section's demo: an interactive environment simulator.
///
/// Visitors can flip simulated host platforms (iOS, Android, Web) and toggle
/// hardware capability flags (Biometrics, NFC, GPS, Camera) in the toolbar.
/// The live Craft surface below re-renders reactively, adapting its payment
/// actions, capability badges, and platform metadata in place.
class FeatureDetectionDemo extends StatefulComponent {
  const FeatureDetectionDemo({super.key});

  @override
  State<FeatureDetectionDemo> createState() => _FeatureDetectionDemoState();
}

class _FeatureDetectionDemoState extends State<FeatureDetectionDemo> {
  String _platformLabel = 'iOS';
  HostPlatform _platform = HostPlatform.ios;
  final Set<String> _capabilities = <String>{'biometrics', 'camera', 'gps'};

  static const Map<String, String> _capLabels = <String, String>{
    'biometrics': 'FaceID',
    'nfc': 'NFC',
    'gps': 'GPS',
    'camera': 'Camera',
  };

  void _setPlatform(String label) {
    _platformLabel = label;
    switch (label) {
      case 'iOS':
        _platform = HostPlatform.ios;
        _capabilities
          ..clear()
          ..addAll(<String>['biometrics', 'camera', 'gps']);
      case 'Android':
        _platform = HostPlatform.android;
        _capabilities
          ..clear()
          ..addAll(<String>['nfc', 'camera', 'gps']);
      case 'Web':
      default:
        _platform = HostPlatform.web;
        _capabilities
          ..clear()
          ..addAll(<String>['camera']);
    }
  }

  void _toggleCapability(String cap) {
    if (_capabilities.contains(cap)) {
      _capabilities.remove(cap);
    } else {
      _capabilities.add(cap);
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      classes: 'engine-demo',
      <Component>[
        div(
          classes: 'engine-demo-bar',
          <Component>[
            span(
              classes: 'engine-demo-caption wide-only',
              <Component>[Component.text('Platform')],
            ),
            CraftSegmented(
              options: const <String>['iOS', 'Android', 'Web'],
              selected: _platformLabel,
              onSelect: (String label) => setState(() {
                _setPlatform(label);
              }),
              ariaLabel: 'Simulated platform',
            ),
            span(
              classes: 'engine-demo-caption wide-only',
              styles: Styles(raw: <String, String>{'margin-left': '8px'}),
              <Component>[Component.text('Hardware')],
            ),
            div(
              classes: 'segmented',
              attributes: const <String, String>{
                'aria-label': 'Simulated hardware capabilities'
              },
              <Component>[
                for (final String cap in _capLabels.keys)
                  button(
                    classes: 'segmented-item',
                    onClick: () => setState(() => _toggleCapability(cap)),
                    attributes: <String, String>{
                      'role': 'checkbox',
                      'aria-checked': '${_capabilities.contains(cap)}',
                    },
                    <Component>[
                      Component.text(_capLabels[cap]!),
                    ],
                  ),
              ],
            ),
          ],
        ),
        div(
          classes: 'engine-demo-surface',
          <Component>[
            LandingSurface(
              surfaceId: 'landing-feature-detection',
              rootComponent: 'FeatureDetectionDemo',
              template: featureDetectionSample.template,
              media: MediaContext(
                width: WindowSizeClass.compact,
                platform: _platform,
                capabilities: Set<String>.unmodifiable(_capabilities),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
