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

/// The Dart stand-ins the *Flutter pane* substitutes for a mini-app's shipped
/// JavaScript, keyed by mini-app id.
///
/// A registry, not a hardcoded constructor: the route resolves any mini-app
/// by id, and wiring whichever one arrives to the cart's driver would run the
/// wrong logic against the wrong template — silently. An id with no entry
/// renders an honest note instead.
final Map<String, Driver Function()> _dartDrivers = <String, Driver Function()>{
  'cart': CartDriver.new,
};

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

  // Resolved once: `build` re-runs on every height report, and re-parsing the
  // manifest and schema JSON each time buys nothing — the panes consume them
  // only on first mount anyway.
  late final RawMiniApp? _app = () {
    for (final RawMiniApp a in rawMiniApps) {
      if (a.id == component.id) return a;
    }
    return null;
  }();

  late final LogicManifest? _logic = _app == null
      ? null
      // The baked block, decoded and read by the one manifest reader — no
      // fake document spliced together from strings.
      : LogicManifest.read(<String, Object?>{
          'logic': jsonDecode(_app.logic),
        });

  late final Map<String, Object?>? _schema =
      _app == null ? null : jsonDecode(_app.schema) as Map<String, Object?>;

  @override
  Component build(BuildContext context) {
    final RawMiniApp? app = _app;
    final LogicManifest? logic = _logic;
    if (app == null || logic == null) {
      return div([Component.text('No such mini-app: ${component.id}')]);
    }

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
              JasprMiniAppPane(
                template: app.template,
                schema: _schema!,
                coldBoot: () => _decodeMessages(app.messages),
                // The shipped driver source, run as it ships. Nothing is
                // compiled, nothing is bundled: the worker is started from
                // the file the project publishes.
                createTransport: () =>
                    WorkerDriverRunner.fromSource(app.driverJs),
              ),
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

  String _describeLogic(LogicManifest logic) => logic.isRemote
      ? 'its logic lives at ${logic.url}'
      : 'its logic is ${logic.language?.id}, in ${logic.entry}';

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
          'The same project, driven twice. Its manifest says only that '
          '${_describeLogic(logic)} — never where to run it. This Jaspr pane '
          'chooses a web worker and runs that file verbatim; the Flutter '
          'pane, which cannot start one, substitutes a Dart port of the same '
          'logic compiled in. Expanding a row and formatting money never '
          'reach either driver — those are the template\'s job. Stock limits '
          'and the order are the driver\'s, because they have to survive the '
          'surface.',
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
    final Driver Function()? createDriver = _dartDrivers[app.id];
    if (createDriver == null) {
      return div(
        styles: Styles(raw: <String, String>{
          'padding': '20px',
          'color': 'var(--subtle)',
          'font': '13px/1.5 system-ui',
        }),
        <Component>[
          Component.text(
            'No Dart port of this mini-app\'s logic ships with the site, so '
            'this pane has nothing to substitute. The Jaspr pane runs the '
            'shipped JavaScript.',
          ),
        ],
      );
    }
    return FlutterEmbedView(
      styles: Styles(raw: <String, String>{
        'width': '100%',
        'box-sizing': 'border-box',
        'height': '${(_flutterHeight ?? 520).ceil()}px',
      }),
      widget: flutterMiniAppApp(
        template: app.template,
        schema: _schema!,
        coldBoot: () => _decodeMessages(app.messages),
        createTransport: () => InProcessDriverRunner(createDriver()),
        dark: SiteTheme.effectiveDark,
        onContentHeight: (double h) {
          if (!h.isFinite || h == _flutterHeight) return;
          setState(() => _flutterHeight = h);
        },
      ) as dynamic,
    );
  }
}

/// A Jaspr-rendered mini-app pane: the project's surface, driven over
/// whatever transport the caller connects — the shipped JavaScript in a
/// worker for the gallery's mini-apps and for projects fetched over HTTP.
class JasprMiniAppPane extends StatefulComponent {
  const JasprMiniAppPane({
    required this.template,
    required this.schema,
    required this.coldBoot,
    required this.createTransport,
    super.key,
  });

  /// The project's `template.craft` source.
  final String template;

  /// The project's decoded `schema.json`.
  final Map<String, Object?> schema;

  /// The project's `app.json` bootstrap stream.
  final List<A2uiMessage> Function() coldBoot;

  /// Connects a driver — the host's choice of sandbox, not the project's.
  final DriverTransport Function() createTransport;

  @override
  State<JasprMiniAppPane> createState() => _JasprMiniAppPaneState();
}

class _JasprMiniAppPaneState extends State<JasprMiniAppPane> {
  late final Runtime _runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(_projectScope, parseLibraryFile(component.template));

  late final MiniAppRunner _runner = MiniAppRunner(
    createProcessor: () => MessageProcessor<ComponentApi>(
      catalogs: <Catalog<ComponentApi>>[loadCatalog(component.schema)],
    ),
    coldBoot: component.coldBoot,
    createTransport: component.createTransport,
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
    final SurfaceModel<ComponentApi>? surface = _runner.surface;
    if (surface == null) {
      // Unreachable when the runner booted (a surface-less boot stream is a
      // fault), but a null check that renders nothing beats one that throws.
      return div(const <Component>[]);
    }
    return div(
      styles: Styles(raw: <String, String>{'padding': '12px'}),
      <Component>[
        A2uiToRfwAdapter(
          id: 'root',
          surface: surface,
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
