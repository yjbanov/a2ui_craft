// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `09_login-form` — a `Card` with a
/// `Heading` welcome, two labelled fields, a submit `Button`, a `Divider`, and a
/// sign-up prompt. The spec's per-field `checks` (validation) are *behavior*,
/// not layout, so the template reproduces the form's appearance only.
SampleSpec signInSpec(String framework) => SampleSpec(
      label: 'Sign In',
      catalogSource: '''
import core;

widget Labelled = Column(gap: 4.0, children: [
  Text(text: args.label, variant: "caption"),
  TextField(value: args.value),
]);

widget SignIn = Card(child: Column(crossAxisAlignment: "stretch", gap: 10.0,
  children: [
    Column(crossAxisAlignment: "center", gap: 2.0, children: [
      Heading(text: args.title, level: 2),
      Text(text: args.subtitle, variant: "caption"),
    ]),
    Labelled(label: args.emailLabel, value: args.email),
    Labelled(label: args.passwordLabel, value: args.password),
    Button(child: Text(text: args.submitLabel)),
    Divider(),
    Row(mainAxisAlignment: "center", gap: 6.0, crossAxisAlignment: "center",
      children: [
        Text(text: args.signupPrompt, variant: "caption"),
        Button(child: Text(text: args.signupLabel)),
      ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'SignIn': <String, Object?>{
            'properties': <String, Object?>{
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'subtitle': <String, Object?>{r'$ref': 'DynamicString'},
              'emailLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'email': <String, Object?>{r'$ref': 'DynamicString'},
              'passwordLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'password': <String, Object?>{r'$ref': 'DynamicString'},
              'submitLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'signupPrompt': <String, Object?>{r'$ref': 'DynamicString'},
              'signupLabel': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'SignIn',
              'title': 'Welcome back',
              'subtitle': 'Sign in to your account',
              'emailLabel': 'Email',
              'email': '',
              'passwordLabel': 'Password',
              'password': '',
              'submitLabel': 'Sign in',
              'signupPrompt': "Don't have an account?",
              'signupLabel': 'Sign up',
            },
          ],
        ),
      ],
    );
