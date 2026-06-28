// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// A two-way bound form: a `Field` (text input) and a `Toggle` (checkbox), each
/// bound to a path in the data model. a2ui_core resolves a `setValue` for the
/// bound prop, the template wires it to the widget's `onChanged`, and edits
/// write straight back to the data model — so the `greeting` Label, bound to the
/// same `/name` path, mirrors whatever is typed.
SampleSpec formSpec(String framework) => SampleSpec(
      label: 'Form',
      catalogSource: '''
import core;

widget Stack = Column(children: args.children);
widget Label = Text(text: args.text);
widget Field = Column(children: [
  Text(text: args.label, variant: "caption"),
  TextField(value: args.value, onChanged: args.setValue),
]);
widget Toggle = Checkbox(value: args.value, onChanged: args.setValue);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Stack': <String, Object?>{
            'properties': <String, Object?>{
              'children': <String, Object?>{r'$ref': 'ChildList'},
            },
            'required': <Object?>['children'],
          },
          'Label': <String, Object?>{
            'properties': <String, Object?>{
              'text': <String, Object?>{r'$ref': 'DynamicString'},
            },
            'required': <Object?>['text'],
          },
          'Field': <String, Object?>{
            'properties': <String, Object?>{
              'label': <String, Object?>{r'$ref': 'DynamicString'},
              'value': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
          'Toggle': <String, Object?>{
            'properties': <String, Object?>{
              'value': <String, Object?>{r'$ref': 'DynamicBoolean'},
            },
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateDataModelMessage(
          surfaceId: surfaceId,
          path: '/',
          value: <String, Object?>{'name': '', 'agree': false},
        ),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'Stack',
              'children': <Object?>['field', 'greeting', 'toggle'],
            },
            <String, dynamic>{
              'id': 'field',
              'component': 'Field',
              'label': 'Your name',
              'value': <String, dynamic>{'path': '/name'},
            },
            <String, dynamic>{
              'id': 'greeting',
              'component': 'Label',
              'text': <String, dynamic>{'path': '/name'},
            },
            <String, dynamic>{
              'id': 'toggle',
              'component': 'Toggle',
              'value': <String, dynamic>{'path': '/agree'},
            },
          ],
        ),
      ],
    );
