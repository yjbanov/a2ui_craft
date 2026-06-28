// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `00_simple-login-form` — a `Column`
/// of a title, two labelled text fields, and a submit `Button`.
///
/// The A2UI `TextField` bundles its own `label`; our `TextField` primitive is
/// the bare input, so the label is composed as a sibling `Text` *in the
/// template* (DESIGN.md §2, "Bias to templatize"). The button's action is a
/// host concern, omitted from this static layout.
SampleSpec loginFormSpec(String framework) => SampleSpec(
      label: 'Login Form',
      catalogSource: '''
import core;

widget Labelled = Column(gap: 4.0, children: [
  Text(text: args.label, variant: "caption"),
  TextField(value: args.value),
]);

widget LoginForm = Column(gap: 12.0, crossAxisAlignment: "stretch", children: [
  Text(text: args.title),
  Labelled(label: args.usernameLabel, value: args.username),
  Labelled(label: args.passwordLabel, value: args.password),
  Button(child: Text(text: args.submitLabel)),
]);
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'Labelled': <String, Object?>{
            'properties': <String, Object?>{
              'label': <String, Object?>{r'$ref': 'DynamicString'},
              'value': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
          'LoginForm': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'usernameLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'username': <String, Object?>{r'$ref': 'DynamicString'},
              'passwordLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'password': <String, Object?>{r'$ref': 'DynamicString'},
              'submitLabel': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'LoginForm',
              'title': 'Login',
              'usernameLabel': 'Username',
              'username': '',
              'passwordLabel': 'Password',
              'password': '',
              'submitLabel': 'Sign In',
            },
          ],
        ),
      ],
    );
