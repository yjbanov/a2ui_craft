// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

import 'flutter_host.dart';
import 'segmented.dart';
import 'theme_mode.dart';

/// One surface, either engine — the landing page's central claim, running.
///
/// The same template, schema, and message stream are handed to the Jaspr
/// adapter or to the embedded Flutter one, and the switch says which is
/// drawing. Not two panes side by side: the claim is that the *same* thing
/// renders on both, which one surface that changes engine under you makes
/// better than two surfaces you have to compare.
///
/// **Jaspr renders on arrival; Flutter loads only if asked.** A landing page
/// that downloads CanvasKit before it settles has spent a visitor's first
/// second on an engine most of them will never switch to. So the engine's
/// deferred library is triggered by [_selectFlutter] — the first flip of the
/// switch — and the surface holds a pending state until it resolves. The site
/// used to preload at page start because a lazy first load was recorded as
/// failing; kicking [FlutterEmbedView.preload] explicitly on intent (rather
/// than relying on a mount to trigger it) is what makes the lazy path work.
class EngineDemo extends StatefulComponent {
  const EngineDemo({required this.sample, super.key});

  /// The sample to render — its real shipped template, schema, and messages.
  final RawSample sample;

  @override
  State<EngineDemo> createState() => _EngineDemoState();
}

class _EngineDemoState extends State<EngineDemo> {
  static const String _jaspr = 'Jaspr';
  static const String _flutter = 'Flutter';

  String _engine = _jaspr;

  /// Whether the Flutter engine's deferred library has finished loading.
  ///
  /// Tracked here rather than left to the embed: the embed renders its own
  /// loader once mounted, but the *first* load is slow enough that a switch
  /// which appears to do nothing is worse than one that says it is working.
  bool _flutterReady = false;
  bool _flutterRequested = false;

  /// The embedded Flutter widget, built once so an unrelated rebuild does not
  /// tear down and re-run the surface (and reset the count the visitor just
  /// clicked up).
  Object? _flutterWidget;

  /// The Flutter content's self-measured height; the fallback holds until the
  /// first report lands.
  double? _flutterHeight;

  late final Map<String, Object?> _schema =
      jsonDecode(component.sample.schema) as Map<String, Object?>;

  /// Freshly decoded per engine: the data model adopts the value objects a
  /// message carries and writes mutate them in place, so handing the same
  /// instances to a second renderer would start it from the first one's state.
  List<A2uiMessage> _messages() => <A2uiMessage>[
        for (final Object? m
            in jsonDecode(component.sample.messages) as List<Object?>)
          A2uiMessage.fromJson(m! as Map<String, dynamic>),
      ];

  void _select(String engine) {
    if (engine == _flutter && !_flutterRequested) {
      _flutterRequested = true;
      // Kick the deferred library on intent. Awaiting it before mounting the
      // view keeps the pending state honest — the switch flips, the surface
      // says it is loading an engine, and the view appears when it can render.
      FlutterEmbedView.preload().then((_) {
        if (!mounted) return;
        setState(() => _flutterReady = true);
      });
    }
    setState(() => _engine = engine);
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
              // Decorative once the segments are self-describing; on a phone
              // the width it costs is width the control needs.
              classes: 'engine-demo-caption wide-only',
              <Component>[Component.text('Rendered by')],
            ),
            CraftSegmented(
              options: const <String>[_jaspr, _flutter],
              selected: _engine,
              onSelect: _select,
              ariaLabel: 'Rendering engine',
            ),
          ],
        ),
        div(classes: 'engine-demo-surface', <Component>[_surface()]),
      ],
    );
  }

  Component _surface() {
    if (_engine == _jaspr) {
      return SampleView(
        key: const ValueKey<String>('landing-jaspr'),
        template: component.sample.template,
        schema: _schema,
        messages: _messages(),
      );
    }
    if (!_flutterReady) return _loading();
    // Mounted directly rather than through `FlutterSpecimen`, whose
    // IntersectionObserver exists to stop a page that stacks *many* CanvasKit
    // surfaces from running them all at once. Here there is exactly one, and it
    // exists only because the visitor asked for it — gating that on scroll
    // position would be a mechanism with nothing to do.
    _flutterWidget ??= flutterSampleApp(
      template: component.sample.template,
      schema: _schema,
      messages: _messages(),
      dark: SiteTheme.effectiveDark,
      onContentHeight: (double h) {
        if (!h.isFinite || h == _flutterHeight) return;
        setState(() => _flutterHeight = h);
      },
    );
    return FlutterEmbedView(
      key: const ValueKey<String>('landing-flutter'),
      styles: Styles(raw: <String, String>{
        'width': '100%',
        'box-sizing': 'border-box',
        'height': '${(_flutterHeight ?? 124).ceil()}px',
      }),
      widget: _flutterWidget as dynamic,
    );
  }

  /// The pending state between flipping the switch and the engine being able
  /// to draw. It reserves the surface's height so the page does not jump, and
  /// it says *why* it is waiting — this is a whole rendering engine arriving,
  /// not a slow network.
  Component _loading() {
    return div(
      classes: 'engine-demo-loading',
      <Component>[
        Component.text('Loading the Flutter engine…'),
      ],
    );
  }
}
