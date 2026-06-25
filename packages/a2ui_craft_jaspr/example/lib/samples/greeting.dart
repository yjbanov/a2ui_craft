// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

import '../sample.dart';

/// A high-level `Greeting` widget: the agent supplies a title, a data-bound
/// message, and a button; the template builds the whole subtree. Pressing the
/// button dispatches `greet`, which updates the bound message.
class GreetingSample extends Sample {
  const GreetingSample({super.key});

  @override
  String get catalogSource => '''
import core;

widget Greeting = Column(children: [
  Text(text: args.title),
  Text(text: args.message),
  Button(onPressed: args.action, child: Text(text: args.buttonLabel)),
]);
''';

  @override
  Catalog<ComponentApi> buildCatalog() => Catalog<ComponentApi>(
        id: catalogId,
        components: [_GreetingApi()],
      );

  @override
  List<A2uiMessage> buildMessages() => <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateDataModelMessage(
          surfaceId: surfaceId,
          path: '/',
          value: <String, Object?>{'greeting': 'Press the button.'},
        ),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'Greeting',
              'title': 'A2UI Craft × Jaspr',
              'message': <String, dynamic>{'path': '/greeting'},
              'buttonLabel': 'Say hi',
              'action': <String, dynamic>{
                'event': <String, dynamic>{
                  'name': 'greet',
                  'context': <String, dynamic>{},
                },
              },
            },
          ],
        ),
      ];

  @override
  void onAction(A2uiClientAction action, SampleHost host) {
    if (action.name == 'greet') {
      host.updateData('/greeting', 'Hello from an A2UI event!');
    }
  }
}

class _GreetingApi extends ComponentApi {
  @override
  String get name => 'Greeting';
  @override
  Schema get schema => Schema.object(
        properties: {
          'title': CommonSchemas.dynamicString,
          'message': CommonSchemas.dynamicString,
          'buttonLabel': CommonSchemas.dynamicString,
          'action': CommonSchemas.action,
        },
      );
}
