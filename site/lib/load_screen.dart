// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show CraftTheme, CraftThemeMode;
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'flutter_host.dart';

/// The "URL bar" screen: type the base URL of a **deployed** A2UI Craft project
/// (e.g. `https://my-app.web.app/`) and load it over HTTP, exactly as a host app
/// would. It proves the project is a separate, ephemerally loadable artifact:
/// re-publish the project to its CDN, hit Load again, and the UI changes with no
/// host redeploy. A text field (not a URL query param) so it carries to future
/// mobile/desktop app modes that have no address bar.
class LoadScreen extends StatefulComponent {
  const LoadScreen({super.key});

  @override
  State<LoadScreen> createState() => _LoadScreenState();
}

class _LoadScreenState extends State<LoadScreen> {
  final CraftProjectLoader _loader = CraftProjectLoader();

  String _url = '';
  bool _loading = false;
  String? _error;
  LoadedProject? _project;

  String _framework = 'Jaspr';
  CraftThemeMode? _mode;
  String? _scenario; // null → the app.json bootstrap
  int _renderKey = 0;
  Object? _flutterWidget;
  final List<String> _log = <String>[];

  Future<void> _doLoad() async {
    final String url = _url.trim();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final LoadedProject project = await _loader.load(url);
      setState(() {
        _project = project;
        _mode = project.manifest.theme?.defaultMode;
        _scenario = null;
        _log.clear();
        _bumpRender();
        _loading = false;
      });
    } on ProjectLoadException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _bumpRender() {
    _flutterWidget = null;
    _renderKey++;
  }

  List<A2uiMessage> get _messages {
    final LoadedProject project = _project!;
    final String? scenario = _scenario;
    if (scenario != null && project.tests.containsKey(scenario)) {
      return project.tests[scenario]!;
    }
    return project.spec.messages;
  }

  CraftTheme? get _theme => _project?.manifest.theme?.resolve(_mode);

  void _onAction(A2uiClientAction a) {
    setState(() {
      _log.insert(0, '▸ ${a.name}  ·  ${a.sourceComponentId}');
      if (_log.length > 30) _log.removeLast();
    });
  }

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'font-family': 'system-ui, -apple-system, sans-serif',
        'min-height': '100vh',
        'display': 'flex',
        'flex-direction': 'column',
      }),
      <Component>[
        _bar(context),
        if (_error != null) _errorBanner(_error!),
        if (_project != null) ...<Component>[
          _controls(),
          _renderPane(),
          _logPanel(),
        ] else
          _hint(),
      ],
    );
  }

  Component _bar(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '8px',
        'padding': '12px 20px',
        'border-bottom': '1px solid #eee',
      }),
      <Component>[
        button(
          onClick: () => context.push('/'),
          styles: _btn(false),
          <Component>[Component.text('← Gallery')],
        ),
        input(
          type: InputType.url,
          value: _url,
          attributes: <String, String>{
            'placeholder': 'https://your-project.web.app/',
            'inputmode': 'url',
          },
          onInput: (dynamic v) => _url = '$v',
          styles: Styles(raw: <String, String>{
            'flex': '1',
            'padding': '8px 12px',
            'border': '1px solid #ccc',
            'border-radius': '8px',
            'font': '14px ui-monospace, monospace',
          }),
        ),
        button(
          onClick: _loading ? null : _doLoad,
          styles: _btn(true),
          <Component>[Component.text(_loading ? 'Loading…' : 'Load ▸')],
        ),
      ],
    );
  }

  Component _hint() {
    return div(
      styles: Styles(raw: <String, String>{
        'padding': '48px 20px',
        'color': '#777',
        'max-width': '640px',
        'margin': '0 auto',
        'text-align': 'center',
        'line-height': '1.5',
      }),
      <Component>[
        Component.text('Enter the base URL of a deployed A2UI Craft project '
            '(the folder that holds its manifest.json) and press Load. The '
            'project is fetched over HTTP and rendered here — it is a separate, '
            'independently deployed artifact from this site.'),
      ],
    );
  }

  Component _controls() {
    final LoadedProject project = _project!;
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'flex-wrap': 'wrap',
        'gap': '10px',
        'padding': '10px 20px',
        'border-bottom': '1px solid #f0f0f0',
      }),
      <Component>[
        strong(<Component>[Component.text(project.manifest.name)]),
        _toggle('Jaspr'),
        _toggle('Flutter'),
        if (project.manifest.theme != null)
          _modePicker(project.manifest.theme!),
        if (project.tests.isNotEmpty) _scenarioPicker(project),
      ],
    );
  }

  Component _toggle(String fw) => button(
        onClick: () => setState(() {
          _framework = fw;
          _bumpRender();
        }),
        styles: _btn(_framework == fw),
        <Component>[Component.text(fw)],
      );

  Component _modePicker(ProjectTheme theme) {
    return select(
      value: (_mode ?? theme.defaultMode).id,
      onChange: (List<String> values) {
        final String id = values.isEmpty ? theme.defaultMode.id : values.first;
        setState(() {
          _mode = theme.availableModes.firstWhere(
            (CraftThemeMode m) => m.id == id,
            orElse: () => theme.defaultMode,
          );
          _bumpRender();
        });
      },
      styles: _select(),
      <Component>[
        for (final CraftThemeMode m in theme.availableModes)
          option(value: m.id, <Component>[Component.text(m.label)]),
      ],
    );
  }

  Component _scenarioPicker(LoadedProject project) {
    const String boot = '(app bootstrap)';
    return select(
      value: _scenario ?? boot,
      onChange: (List<String> values) {
        final String choice = values.isEmpty ? boot : values.first;
        setState(() {
          _scenario = choice == boot ? null : choice;
          _bumpRender();
        });
      },
      styles: _select(),
      <Component>[
        option(value: boot, const <Component>[Component.text(boot)]),
        for (final String name in project.tests.keys)
          option(value: name, <Component>[Component.text('test: $name')]),
      ],
    );
  }

  Component _renderPane() {
    return div(
      styles: Styles(raw: <String, String>{
        'flex': '1',
        'overflow': 'auto',
        'padding': '24px',
      }),
      <Component>[_framework == 'Jaspr' ? _jasprView() : _flutterView()],
    );
  }

  Component _jasprView() {
    final LoadedProject project = _project!;
    return SampleView(
      key: ValueKey<String>('jaspr-$_renderKey'),
      template: project.spec.catalogSource,
      schema: project.spec.catalogSchema,
      messages: _messages,
      theme: _theme,
      onAction: _onAction,
    );
  }

  Component _flutterView() {
    final LoadedProject project = _project!;
    _flutterWidget ??= flutterSampleApp(
      template: project.spec.catalogSource,
      schema: project.spec.catalogSchema,
      messages: _messages,
      onAction: _onAction,
      theme: _theme,
    );
    return FlutterEmbedView(
      key: ValueKey<String>('flutter-$_renderKey'),
      styles: Styles(raw: <String, String>{
        'width': '100%',
        'height': '560px',
        'border': '1px solid #eee',
        'border-radius': '10px',
        'overflow': 'hidden',
      }),
      widget: _flutterWidget as dynamic,
    );
  }

  Component _logPanel() {
    return div(
      styles: Styles(raw: <String, String>{
        'border-top': '1px solid #eee',
        'padding': '8px 20px',
        'max-height': '120px',
        'overflow': 'auto',
        'font': '12px ui-monospace, monospace',
        'color': '#444',
        'background': '#fafafa',
      }),
      <Component>[
        if (_log.isEmpty)
          div(
              styles: Styles(raw: <String, String>{'color': '#bbb'}),
              <Component>[
                Component.text('Action log — interact with the surface.')
              ])
        else
          for (final String line in _log)
            div(
                styles: Styles(raw: <String, String>{'white-space': 'pre'}),
                <Component>[Component.text(line)]),
      ],
    );
  }

  Component _errorBanner(String message) {
    return div(
      styles: Styles(raw: <String, String>{
        'background': '#fdecea',
        'color': '#b3261e',
        'padding': '10px 20px',
        'font': '13px ui-monospace, monospace',
        'white-space': 'pre-wrap',
      }),
      <Component>[Component.text('Could not load project: $message')],
    );
  }

  Styles _select() => Styles(raw: <String, String>{
        'padding': '6px 10px',
        'border': '1px solid #ccc',
        'border-radius': '6px',
        'background': '#fff',
        'cursor': 'pointer',
      });

  Styles _btn(bool active) => Styles(raw: <String, String>{
        'padding': '8px 14px',
        'border': '1px solid ${active ? '#1a73e8' : '#ccc'}',
        'border-radius': '8px',
        'background': active ? '#1a73e8' : '#fff',
        'color': active ? '#fff' : '#333',
        'cursor': 'pointer',
      });
}
