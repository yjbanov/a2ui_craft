// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:js_interop';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show CraftTheme, CraftThemeMode;
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:web/web.dart' as web;

import 'flutter_host.dart';

/// Width of the editor sidebar when open, in CSS px. Subtracted from the
/// viewport to decide whether the preview pane is wide enough for side-by-side.
const int _editorWidth = 420;

/// Minimum preview-pane width (viewport minus the editor) to show the Jaspr and
/// Flutter renders side by side. Below it, the two collapse into a Jaspr/Flutter
/// tab toggle.
const int _sideBySideMin = 800;

/// One sample on its own screen: a toolbar (back, title, edit, Jaspr/Flutter
/// toggle) over the rendered surface and an action log, with an optional editor
/// sidebar for the template / schema / messages with live Preview.
///
/// When the preview pane (viewport minus the editor) is at least
/// [_sideBySideMin] wide, the Jaspr and Flutter renders show side by side;
/// otherwise they collapse into a tab toggle.
class SampleScreen extends StatefulComponent {
  const SampleScreen({required this.id, super.key});

  final String id;

  @override
  State<SampleScreen> createState() => _SampleScreenState();
}

class _SampleScreenState extends State<SampleScreen> {
  late final RawSample _raw = rawSamples.firstWhere(
    (RawSample r) => r.id == component.id,
    orElse: () => rawSamples.first,
  );

  String _framework = 'Jaspr';
  bool _editorOpen = false;
  bool _wide = false;
  int _renderKey = 0;
  String? _error;
  final List<String> _log = <String>[];

  // The project's theme, if it ships one (its `theme.json`, §13.9), and the
  // mode the host has selected — the render-time n-ary mode input (§13.5). Null
  // theme ⇒ no picker, surface blends into the host.
  late final ProjectTheme? _project = ProjectTheme.tryParse(_raw.theme);
  late CraftThemeMode? _mode = _project?.defaultMode;

  CraftTheme? get _theme => _project?.resolve(_mode);

  // The rendered (active) data; the editor edits separate drafts and commits
  // them on Preview.
  late String _template = _raw.template;
  late String _schema = _raw.schema;
  late String _messages = _raw.messages;
  late String _dTemplate = _template;
  late String _dSchema = _schema;
  late String _dMessages = _messages;

  // The embedded Flutter widget is memoized so an action-log rebuild doesn't
  // tear down and re-run the Flutter surface; it is recreated only on Preview.
  Object? _flutterWidget;

  JSFunction? _resizeListener;

  @override
  void initState() {
    super.initState();
    _wide = _computeWide();
    _resizeListener = ((web.Event _) => _updateLayout()).toJS;
    web.window.addEventListener('resize', _resizeListener);
  }

  @override
  void dispose() {
    if (_resizeListener != null) {
      web.window.removeEventListener('resize', _resizeListener);
    }
    super.dispose();
  }

  bool _computeWide() {
    final int avail = web.window.innerWidth - (_editorOpen ? _editorWidth : 0);
    return avail >= _sideBySideMin;
  }

  void _updateLayout() {
    final bool wide = _computeWide();
    if (wide != _wide) setState(() => _wide = wide);
  }

  void _onAction(A2uiClientAction a) {
    setState(() {
      _log.insert(
        0,
        '▸ ${a.name}  ·  ${a.sourceComponentId}'
        '${a.context.isEmpty ? '' : '  ·  ${jsonEncode(a.context)}'}',
      );
      if (_log.length > 50) _log.removeLast();
    });
  }

  void _preview() {
    try {
      // Validate by decoding before committing.
      SampleSpec.fromData(
        label: _raw.label,
        template: _dTemplate,
        schemaJson: _dSchema,
        messagesJson: _dMessages,
        framework: _framework,
      );
      setState(() {
        _template = _dTemplate;
        _schema = _dSchema;
        _messages = _dMessages;
        _error = null;
        _flutterWidget = null;
        _log.clear();
        _renderKey++;
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Object _makeFlutterWidget() {
    final SampleSpec spec = SampleSpec.fromData(
      label: _raw.label,
      template: _template,
      schemaJson: _schema,
      messagesJson: _messages,
      framework: 'Flutter',
    );
    return flutterSampleApp(
      template: spec.catalogSource,
      schema: spec.catalogSchema,
      messages: spec.messages,
      onAction: _onAction,
      theme: _theme,
    );
  }

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'font-family': 'system-ui, -apple-system, sans-serif',
        'height': '100vh',
        'display': 'flex',
        'flex-direction': 'column',
      }),
      [
        _toolbar(context),
        div(
          styles: Styles(raw: <String, String>{
            'flex': '1',
            'display': 'flex',
            'min-height': '0',
          }),
          [
            _renderColumn(),
            if (_editorOpen) _editor(),
          ],
        ),
      ],
    );
  }

  Component _renderColumn() {
    return div(
      styles: Styles(raw: <String, String>{
        'flex': '1',
        'display': 'flex',
        'flex-direction': 'column',
        'min-width': '0',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'flex': '1',
            'display': 'flex',
            'min-height': '0',
          }),
          [_previewPanes()],
        ),
        _logPanel(),
      ],
    );
  }

  /// Side-by-side Jaspr + Flutter panes when wide; otherwise the single active
  /// (tab-selected) render.
  Component _previewPanes() {
    if (_wide) {
      return div(
        styles: Styles(raw: <String, String>{
          'flex': '1',
          'display': 'flex',
          'min-width': '0',
        }),
        [
          _pane('Jaspr', _jasprView(), borderRight: true),
          _pane('Flutter', _flutterView(), borderRight: false),
        ],
      );
    }
    return _pane(
      _framework,
      _framework == 'Jaspr' ? _jasprView() : _flutterView(),
      borderRight: false,
    );
  }

  /// A labeled, independently scrolling render column.
  Component _pane(String label, Component child, {required bool borderRight}) {
    return div(
      styles: Styles(raw: <String, String>{
        'flex': '1',
        'min-width': '0',
        'display': 'flex',
        'flex-direction': 'column',
        if (borderRight) 'border-right': '1px solid #eee',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'font': '600 11px system-ui',
            'letter-spacing': '.05em',
            'text-transform': 'uppercase',
            'color': '#888',
            'padding': '8px 24px',
            'border-bottom': '1px solid #f0f0f0',
          }),
          [Component.text(label)],
        ),
        div(
          styles: Styles(raw: <String, String>{
            'flex': '1',
            'min-height': '0',
            'overflow': 'auto',
            'padding': '24px',
          }),
          [child],
        ),
      ],
    );
  }

  Component _jasprView() {
    final SampleSpec spec = SampleSpec.fromData(
      label: _raw.label,
      template: _template,
      schemaJson: _schema,
      messagesJson: _messages,
      framework: 'Jaspr',
    );
    return SampleView(
      key: ValueKey<String>('jaspr-$_renderKey'),
      template: spec.catalogSource,
      schema: spec.catalogSchema,
      messages: spec.messages,
      onAction: _onAction,
      theme: _theme,
    );
  }

  Component _flutterView() {
    _flutterWidget ??= _makeFlutterWidget();
    return FlutterEmbedView(
      key: ValueKey<String>('flutter-$_renderKey'),
      styles: Styles(raw: <String, String>{
        'width': '100%',
        'height': '640px',
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
        'padding': '8px 24px',
        'max-height': '140px',
        'overflow': 'auto',
        'font': '12px ui-monospace, monospace',
        'color': '#444',
        'background': '#fafafa',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'color': '#888',
            'margin-bottom': '4px',
          }),
          [Component.text('Action log (dispatched A2UI events)')],
        ),
        if (_log.isEmpty)
          div(
              styles: Styles(raw: <String, String>{'color': '#bbb'}),
              [Component.text('No events yet — interact with the sample.')])
        else
          for (final String line in _log)
            div(
                styles: Styles(raw: <String, String>{'white-space': 'pre'}),
                [Component.text(line)]),
      ],
    );
  }

  Component _toolbar(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '10px',
        'padding': '12px 20px',
        'border-bottom': '1px solid #eee',
      }),
      [
        button(
          onClick: () => context.push('/'),
          styles: _btn(false),
          [Component.text('← Gallery')],
        ),
        h2(
          styles: Styles(raw: <String, String>{'margin': '0', 'flex': '1'}),
          [Component.text(_raw.label)],
        ),
        if (_project != null) _modePicker(),
        button(
          onClick: () => setState(() {
            _editorOpen = !_editorOpen;
            _wide = _computeWide();
          }),
          styles: _btn(_editorOpen),
          [Component.text('✎ Code')],
        ),
        // When wide, both renders show at once, so the tab toggle is hidden.
        if (!_wide) ...<Component>[
          _toggle('Jaspr'),
          _toggle('Flutter'),
        ],
      ],
    );
  }

  Component _toggle(String fw) => button(
        onClick: () => setState(() => _framework = fw),
        styles: _btn(_framework == fw),
        [Component.text(fw)],
      );

  /// The render-time n-ary **mode** input for a themed project (§13.5): pick
  /// among the project theme's available modes; both renders re-theme to it.
  Component _modePicker() {
    final ProjectTheme project = _project!;
    return select(
      value: (_mode ?? project.defaultMode).id,
      onChange: (List<String> values) {
        final String id =
            values.isEmpty ? project.defaultMode.id : values.first;
        final CraftThemeMode next = project.availableModes.firstWhere(
          (CraftThemeMode m) => m.id == id,
          orElse: () => project.defaultMode,
        );
        setState(() {
          _mode = next;
          // Rebuild both panes so the embedded Flutter render re-themes too.
          _flutterWidget = null;
          _renderKey++;
        });
      },
      styles: Styles(raw: <String, String>{
        'padding': '6px 10px',
        'border': '1px solid #ccc',
        'border-radius': '6px',
        'background': '#fff',
        'color': '#333',
        'cursor': 'pointer',
      }),
      <Component>[
        for (final CraftThemeMode m in project.availableModes)
          option(value: m.id, [Component.text(m.label)]),
      ],
    );
  }

  Component _editor() {
    return div(
      styles: Styles(raw: <String, String>{
        'width': '${_editorWidth}px',
        'border-left': '1px solid #eee',
        'display': 'flex',
        'flex-direction': 'column',
        'background': '#fcfcfc',
        'overflow': 'auto',
      }),
      [
        if (_error != null)
          div(
            styles: Styles(raw: <String, String>{
              'background': '#fdecea',
              'color': '#b3261e',
              'padding': '8px 12px',
              'font': '12px ui-monospace, monospace',
              'white-space': 'pre-wrap',
            }),
            [Component.text(_error!)],
          ),
        div(
          styles: Styles(raw: <String, String>{
            'padding': '10px 12px',
            'border-bottom': '1px solid #eee',
          }),
          [
            button(
              onClick: _preview,
              styles: Styles(raw: <String, String>{
                'padding': '8px 16px',
                'border': 'none',
                'border-radius': '6px',
                'background': '#1a73e8',
                'color': '#fff',
                'cursor': 'pointer',
                'font-weight': '600',
              }),
              [Component.text('Preview ▸')],
            ),
          ],
        ),
        _field('Template (.craft)', _template, (String v) => _dTemplate = v),
        _field('Schema (JSON)', _schema, (String v) => _dSchema = v),
        _field('App bootstrap (app.json)', _messages,
            (String v) => _dMessages = v),
      ],
    );
  }

  Component _field(String label, String value, ValueChanged<String> onInput) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'padding': '8px 12px',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'font': '600 12px system-ui',
            'color': '#555',
            'margin-bottom': '4px',
          }),
          [Component.text(label)],
        ),
        textarea(
          [Component.text(value)],
          rows: 12,
          onInput: onInput,
          styles: Styles(raw: <String, String>{
            'width': '100%',
            'box-sizing': 'border-box',
            'font': '12px ui-monospace, monospace',
            'border': '1px solid #ddd',
            'border-radius': '6px',
            'padding': '8px',
            'resize': 'vertical',
          }),
        ),
      ],
    );
  }

  Styles _btn(bool active) => Styles(raw: <String, String>{
        'padding': '6px 12px',
        'border': '1px solid ${active ? '#1a73e8' : '#ccc'}',
        'border-radius': '6px',
        'background': active ? '#1a73e8' : '#fff',
        'color': active ? '#fff' : '#333',
        'cursor': 'pointer',
      });
}
