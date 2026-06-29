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
import 'package:jaspr_router/jaspr_router.dart';

import 'flutter_host.dart';

/// One sample on its own screen: a toolbar (back, title, edit, Jaspr/Flutter
/// toggle) over the rendered surface and an action log, with an optional editor
/// sidebar for the template / schema / messages with live Preview.
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
  int _renderKey = 0;
  String? _error;
  final List<String> _log = <String>[];

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
        'overflow': 'auto',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{'padding': '24px', 'flex': '1'}),
          [_renderArea()],
        ),
        _logPanel(),
      ],
    );
  }

  Component _renderArea() {
    if (_framework == 'Jaspr') {
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
      );
    }
    _flutterWidget ??= _makeFlutterWidget();
    return FlutterEmbedView(
      key: ValueKey<String>('flutter-$_renderKey'),
      styles: Styles(raw: <String, String>{
        'width': '480px',
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
        button(
          onClick: () => setState(() => _editorOpen = !_editorOpen),
          styles: _btn(_editorOpen),
          [Component.text('✎ Code')],
        ),
        _toggle('Jaspr'),
        _toggle('Flutter'),
      ],
    );
  }

  Component _toggle(String fw) => button(
        onClick: () => setState(() => _framework = fw),
        styles: _btn(_framework == fw),
        [Component.text(fw)],
      );

  Component _editor() {
    return div(
      styles: Styles(raw: <String, String>{
        'width': '420px',
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
        _field('Messages (JSON)', _messages, (String v) => _dMessages = v),
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
