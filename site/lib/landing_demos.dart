// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'brand_themes.dart';
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
    this.theme,
    super.key,
  });

  /// Unique per demo: each surface must be unmistakably its own.
  final String surfaceId;

  /// RFW source defining a `Root` widget.
  final String template;

  /// The theme to render under, or null to blend into the host.
  final CraftTheme? theme;

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
      'Root': <String, Object?>{'properties': <String, Object?>{}},
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
          <String, Object?>{'id': 'root', 'component': 'Root'},
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
