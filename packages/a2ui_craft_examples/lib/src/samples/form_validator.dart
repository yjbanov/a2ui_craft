// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `32_advanced-form-validator` — a
/// `Card` registration form: a greeting, three labelled fields, a terms
/// checkbox, and a submit `Button`.
///
/// Two things of note: the A2UI `CheckBox` bundles its label, so here it is a
/// `Checkbox` + `Text` *template* (the composite-control pattern, §2); and the
/// spec's `checks` (email/regex/required validation) are *behavior*, not layout,
/// so the template reproduces the form's appearance only.
SampleSpec formValidatorSpec(String framework) => SampleSpec(
      label: 'Form Validator',
      catalogSource: '''
import core;

widget Labelled = Column(gap: 4.0, children: [
  Text(text: args.label, variant: "caption"),
  TextField(value: args.value),
]);

widget FormValidator = Card(child: Column(crossAxisAlignment: "stretch",
  gap: 10.0, children: [
    Text(text: args.welcome),
    Labelled(label: args.emailLabel, value: args.email),
    Labelled(label: args.phoneLabel, value: args.phone),
    Labelled(label: args.zipLabel, value: args.zip),
    Row(gap: 8.0, crossAxisAlignment: "center", children: [
      Checkbox(value: args.agree),
      Expanded(child: Text(text: args.termsLabel, variant: "caption")),
    ]),
    Button(child: Text(text: args.submitLabel)),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'FormValidator': <String, Object?>{
            'properties': <String, Object?>{
              'welcome': <String, Object?>{r'$ref': 'DynamicString'},
              'emailLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'email': <String, Object?>{r'$ref': 'DynamicString'},
              'phoneLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'phone': <String, Object?>{r'$ref': 'DynamicString'},
              'zipLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'zip': <String, Object?>{r'$ref': 'DynamicString'},
              'agree': <String, Object?>{r'$ref': 'DynamicBoolean'},
              'termsLabel': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'FormValidator',
              'welcome': 'Hello! Today is Monday, December 15.',
              'emailLabel': 'Email Address',
              'email': '',
              'phoneLabel': 'Phone Number',
              'phone': '',
              'zipLabel': 'Zip Code',
              'zip': '',
              'agree': false,
              'termsLabel': 'I agree to the terms and conditions',
              'submitLabel': 'Submit Registration',
            },
          ],
        ),
      ],
    );
