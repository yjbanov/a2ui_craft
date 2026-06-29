// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'flutter_host.dart';

/// One sample on its own screen: a toolbar (back, title, Jaspr/Flutter toggle)
/// over the rendered surface. The selected engine renders the *same* template /
/// schema / messages.
class SampleScreen extends StatefulComponent {
  const SampleScreen({required this.id, super.key});

  final String id;

  @override
  State<SampleScreen> createState() => _SampleScreenState();
}

class _SampleScreenState extends State<SampleScreen> {
  String _framework = 'Jaspr';

  late final RawSample _raw = rawSamples.firstWhere(
    (RawSample r) => r.id == component.id,
    orElse: () => rawSamples.first,
  );

  @override
  Component build(BuildContext context) {
    final SampleSpec spec = SampleSpec.fromData(
      label: _raw.label,
      template: _raw.template,
      schemaJson: _raw.schema,
      messagesJson: _raw.messages,
      framework: _framework,
    );

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
          styles: Styles(raw: <String, String>{'padding': '24px', 'flex': '1'}),
          [
            if (_framework == 'Jaspr')
              SampleView(
                template: spec.catalogSource,
                schema: spec.catalogSchema,
                messages: spec.messages,
              )
            else
              FlutterEmbedView(
                styles: Styles(raw: <String, String>{
                  'width': '480px',
                  'height': '640px',
                  'border': '1px solid #eee',
                  'border-radius': '10px',
                  'overflow': 'hidden',
                }),
                widget: flutterSampleApp(
                  template: spec.catalogSource,
                  schema: spec.catalogSchema,
                  messages: spec.messages,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Component _toolbar(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'gap': '12px',
        'padding': '12px 20px',
        'border-bottom': '1px solid #eee',
      }),
      [
        button(
          onClick: () => context.push('/'),
          styles: _btn(false),
          [text('← Gallery')],
        ),
        h2(
          styles: Styles(raw: <String, String>{'margin': '0', 'flex': '1'}),
          [text(_raw.label)],
        ),
        _toggle('Jaspr'),
        _toggle('Flutter'),
      ],
    );
  }

  Component _toggle(String fw) => button(
        onClick: () => setState(() => _framework = fw),
        styles: _btn(_framework == fw),
        [text(fw)],
      );

  Styles _btn(bool active) => Styles(raw: <String, String>{
        'padding': '6px 12px',
        'border': '1px solid ${active ? '#1a73e8' : '#ccc'}',
        'border-radius': '6px',
        'background': active ? '#1a73e8' : '#fff',
        'color': active ? '#fff' : '#333',
        'cursor': 'pointer',
      });
}
