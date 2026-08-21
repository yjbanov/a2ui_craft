// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:a2ui_craft_logic/web.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'flutter_host.dart';
import 'icons.dart';
import 'theme_mode.dart';

/// The library name the mini-app's own template is registered under.
const LibraryName _projectScope = LibraryName(<String>['project']);

List<A2uiMessage> _decodeMessages(String json) => <A2uiMessage>[
      for (final Object? m in jsonDecode(json) as List<Object?>)
        A2uiMessage.fromJson(m! as Map<String, dynamic>),
    ];

/// One mini-app, shown twice: the same project driven by logic written in two
/// languages, running in two very different places.
///
/// This is the demonstration the whole design is for. The **Jaspr** pane runs
/// the mini-app's shipped `cart.js` in a **web worker** — a sandbox with no DOM
/// and no access to anything the page holds. The **Flutter** pane runs the Dart
/// port, compiled into the host. Neither the template nor the engine knows
/// which is which, because the only thing between them is the protocol.
class MiniAppScreen extends StatefulComponent {
  const MiniAppScreen({required this.id, super.key});

  /// The mini-app id, from the route.
  final String id;

  @override
  State<MiniAppScreen> createState() => _MiniAppScreenState();
}

class _MiniAppScreenState extends State<MiniAppScreen> {
  double? _flutterHeight;

  RawMiniApp? get _app {
    for (final RawMiniApp a in rawMiniApps) {
      if (a.id == component.id) return a;
    }
    return null;
  }

  @override
  Component build(BuildContext context) {
    final RawMiniApp? app = _app;
    if (app == null) {
      return div([Component.text('No such mini-app: ${component.id}')]);
    }
    final LogicManifest logic = LogicManifest.parse(
      '{"logic": ${app.logic}}',
    )!;

    return div(
      styles: Styles(raw: <String, String>{
        'max-width': '1100px',
        'margin': '0 auto',
        'padding': '24px 20px 48px',
        'font-family': 'system-ui, -apple-system, sans-serif',
      }),
      <Component>[
        _toolbar(app),
        _explainer(logic),
        div(
          styles: Styles(raw: <String, String>{
            'display': 'grid',
            'grid-template-columns': 'repeat(auto-fit, minmax(340px, 1fr))',
            'gap': '20px',
            'align-items': 'start',
          }),
          <Component>[
            _pane(
              'Jaspr · driver in a web worker · JavaScript',
              _JasprMiniAppPane(app: app),
            ),
            _pane('Flutter · driver in-process · Dart', _flutterPane(app)),
          ],
        ),
      ],
    );
  }

  Component _toolbar(RawMiniApp app) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '12px',
        'margin-bottom': '16px',
      }),
      <Component>[
        Link(
          to: '/',
          styles: Styles(raw: <String, String>{
            'display': 'inline-flex',
            'align-items': 'center',
            'color': 'var(--subtle)',
            'text-decoration': 'none',
          }),
          child: backIcon(),
        ),
        h1(
          styles: Styles(raw: <String, String>{
            'font': '600 20px system-ui',
            'margin': '0',
            'color': 'var(--fg)',
          }),
          <Component>[Component.text('${app.label} — a mini-app')],
        ),
      ],
    );
  }

  Component _explainer(LogicManifest logic) {
    return p(
      styles: Styles(raw: <String, String>{
        'color': 'var(--subtle)',
        'font': '14px/1.6 system-ui',
        'margin': '0 0 20px',
        'max-width': '70ch',
      }),
      <Component>[
        Component.text(
          'The same project, driven twice. Its manifest says only that its '
          'logic is ${logic.language!.id}, in ${logic.entry} — never where to '
          'run it. This Jaspr pane chooses a web worker and runs that file '
          'verbatim; the Flutter pane, which cannot start one, substitutes a '
          'Dart port of the same logic compiled in. Expanding a row and '
          'formatting money never reach either driver — those are the '
          'template\'s job. Stock limits and the order are the driver\'s, '
          'because they have to survive the surface.',
        ),
      ],
    );
  }

  Component _pane(String label, Component body) {
    return div(
      styles: Styles(raw: <String, String>{
        'border': '1px solid var(--border)',
        'border-radius': '12px',
        'overflow': 'hidden',
      }),
      <Component>[
        div(
          styles: Styles(raw: <String, String>{
            'padding': '8px 14px',
            'border-bottom': '1px solid var(--border)',
            'font': '600 12px system-ui',
            'letter-spacing': '0.04em',
            'text-transform': 'uppercase',
            'color': 'var(--subtle)',
          }),
          <Component>[Component.text(label)],
        ),
        div(styles: Styles(raw: <String, String>{'padding': '4px'}), [body]),
      ],
    );
  }

  Component _flutterPane(RawMiniApp app) {
    return FlutterEmbedView(
      styles: Styles(raw: <String, String>{
        'width': '100%',
        'box-sizing': 'border-box',
        'height': '${(_flutterHeight ?? 520).ceil()}px',
      }),
      widget: flutterMiniAppApp(
        surfaceId: 'cart',
        template: app.template,
        schema: jsonDecode(app.schema) as Map<String, Object?>,
        coldBoot: () => _decodeMessages(app.messages),
        createDriver: CartDriver.new,
        dark: SiteTheme.effectiveDark,
        onContentHeight: (double h) {
          if (!h.isFinite || h == _flutterHeight) return;
          setState(() => _flutterHeight = h);
        },
      ) as dynamic,
    );
  }
}

/// The Jaspr half: the mini-app's own JavaScript, in a worker.
class _JasprMiniAppPane extends StatefulComponent {
  const _JasprMiniAppPane({required this.app});

  final RawMiniApp app;

  @override
  State<_JasprMiniAppPane> createState() => _JasprMiniAppPaneState();
}

class _JasprMiniAppPaneState extends State<_JasprMiniAppPane> {
  late final Runtime _runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(_projectScope, parseLibraryFile(component.app.template));

  late final MiniAppRunner _runner = MiniAppRunner(
    surfaceId: 'cart',
    createProcessor: () => MessageProcessor<ComponentApi>(
      catalogs: <Catalog<ComponentApi>>[
        loadCatalog(jsonDecode(component.app.schema) as Map<String, Object?>),
      ],
    ),
    coldBoot: () => _decodeMessages(component.app.messages),
    // The shipped driver source, run as it ships. Nothing is compiled, nothing
    // is bundled: the worker is started from the file the project publishes.
    createTransport: () =>
        WorkerDriverRunner.fromSource(component.app.driverJs),
  );

  @override
  void initState() {
    super.initState();
    _runner.onChanged.addListener(_onChanged);
    _runner.start();
  }

  @override
  void dispose() {
    _runner.onChanged.removeListener(_onChanged);
    _runner.dispose();
    super.dispose();
  }

  void _onChanged(MiniAppRunner _) => setState(() {});

  @override
  Component build(BuildContext context) {
    final SessionFault? fault = _runner.fault;
    if (fault != null) return _stoppedCard(fault);
    return div(
      styles: Styles(raw: <String, String>{'padding': '12px'}),
      <Component>[
        A2uiToRfwAdapter(
          id: 'root',
          surface: _runner.surface!,
          runtime: _runtime,
          scope: _projectScope,
        ),
      ],
    );
  }

  /// The host-owned failure state, matching the Flutter pane's.
  ///
  /// Chrome, not template: a template cannot know its driver is gone, and a
  /// surface that keeps accepting input it can never persist is worse than one
  /// that plainly stops.
  Component _stoppedCard(SessionFault fault) {
    return div(
      styles: Styles(raw: <String, String>{
        'margin': '12px',
        'padding': '20px',
        'border-radius': '12px',
        'background': 'color-mix(in srgb, crimson 12%, transparent)',
        'border': '1px solid color-mix(in srgb, crimson 40%, transparent)',
      }),
      <Component>[
        div(
          styles: Styles(raw: <String, String>{
            'font': '600 15px system-ui',
            'color': 'var(--fg)',
            'margin-bottom': '6px',
          }),
          <Component>[Component.text('This mini-app stopped.')],
        ),
        div(
          styles: Styles(raw: <String, String>{
            'font': '12px/1.5 ui-monospace, monospace',
            'color': 'var(--subtle)',
            'margin-bottom': '14px',
          }),
          <Component>[
            Component.text('${fault.code.name}: ${fault.message}'),
          ],
        ),
        button(
          onClick: _runner.restart,
          styles: Styles(raw: <String, String>{
            'padding': '8px 14px',
            'border-radius': '8px',
            'border': '1px solid var(--accent)',
            'background': 'transparent',
            'color': 'var(--accent)',
            'font': '600 13px system-ui',
            'cursor': 'pointer',
          }),
          <Component>[Component.text('Start over')],
        ),
      ],
    );
  }
}
