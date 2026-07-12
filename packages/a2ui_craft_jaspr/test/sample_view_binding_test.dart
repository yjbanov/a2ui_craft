// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Two-way data-model writes through a [SampleView]'s inline trio (the demo
// site's kitchen-sink specimen shape): the write must round-trip whether the
// *root* component carries the binding (a specimen page's shape) or a child
// component does (the settings sample's shape), and beside sibling
// SampleViews sharing a surfaceId.
import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:a2ui_craft/a2ui_craft.dart' show CraftThemeMode, DefaultTheme;
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

List<A2uiMessage> _messages(List<Map<String, Object?>> components) =>
    <A2uiMessage>[
      A2uiMessage.fromJson(<String, dynamic>{
        'version': 'v0.9',
        'createSurface': <String, Object?>{
          'surfaceId': 'sink',
          'catalogId': 'sink',
          'sendDataModel': false,
        },
      }),
      A2uiMessage.fromJson(<String, dynamic>{
        'version': 'v0.9',
        'updateDataModel': <String, Object?>{
          'surfaceId': 'sink',
          'path': '/',
          'value': <String, Object?>{'agree': true},
        },
      }),
      A2uiMessage.fromJson(<String, dynamic>{
        'version': 'v0.9',
        'updateComponents': <String, Object?>{
          'surfaceId': 'sink',
          'components': components,
        },
      }),
    ];

bool _checkboxChecked(ComponentTester tester) {
  final Element el = find
      .byComponentPredicate((Component c) =>
          c is DomComponent && (c.attributes?['type'] == 'checkbox'))
      .evaluate()
      .single;
  final DomComponent dom = el.component as DomComponent;
  return dom.attributes?.containsKey('checked') ?? false;
}

void main() {
  testComponents('root-bound checkbox write round-trips',
      (ComponentTester tester) async {
    tester.pumpComponent(SampleView(
      template: '''
import core;
widget Root = Checkbox(value: args.value, onChanged: args.setValue);
''',
      schema: <String, Object?>{
        'catalogId': 'sink',
        'components': <String, Object?>{
          'Root': <String, Object?>{
            'properties': <String, Object?>{
              'value': <String, Object?>{r'$ref': 'DynamicBoolean'},
            },
          },
        },
      },
      messages: _messages(<Map<String, Object?>>[
        <String, Object?>{
          'id': 'root',
          'component': 'Root',
          'value': <String, Object?>{'path': '/agree'},
        },
      ]),
      theme: DefaultTheme.of(CraftThemeMode.light),
    ));
    await tester.pump();
    expect(_checkboxChecked(tester), isTrue, reason: 'initial bound read');

    tester.dispatchEvent(find.tag('input'), 'change');
    await tester.pump();
    expect(_checkboxChecked(tester), isFalse, reason: 'root-bound write');
  });

  testComponents('root-bound write round-trips beside sibling SampleViews',
      (ComponentTester tester) async {
    tester.pumpComponent(div([
      SampleView(
        template: '''
import core;
widget Root = Text(text: "static sibling");
''',
        schema: <String, Object?>{
          'catalogId': 'sink',
          'components': <String, Object?>{
            'Root': <String, Object?>{'properties': <String, Object?>{}},
          },
        },
        messages: _messages(<Map<String, Object?>>[
          <String, Object?>{'id': 'root', 'component': 'Root'},
        ]),
        theme: DefaultTheme.of(CraftThemeMode.light),
      ),
      SampleView(
        template: '''
import core;
widget Root = Checkbox(value: args.value, onChanged: args.setValue);
''',
        schema: <String, Object?>{
          'catalogId': 'sink',
          'components': <String, Object?>{
            'Root': <String, Object?>{
              'properties': <String, Object?>{
                'value': <String, Object?>{r'$ref': 'DynamicBoolean'},
              },
            },
          },
        },
        messages: _messages(<Map<String, Object?>>[
          <String, Object?>{
            'id': 'root',
            'component': 'Root',
            'value': <String, Object?>{'path': '/agree'},
          },
        ]),
        theme: DefaultTheme.of(CraftThemeMode.light),
      ),
    ]));
    await tester.pump();
    expect(_checkboxChecked(tester), isTrue, reason: 'initial bound read');

    tester.dispatchEvent(find.tag('input'), 'change');
    await tester.pump();
    expect(_checkboxChecked(tester), isFalse,
        reason: 'write beside a sibling surface with the same surfaceId');
  });

  testComponents('child-bound checkbox write round-trips',
      (ComponentTester tester) async {
    tester.pumpComponent(SampleView(
      template: '''
import core;
widget Panel = Column(children: args.children);
widget Agree = Checkbox(value: args.value, onChanged: args.setValue);
''',
      schema: <String, Object?>{
        'catalogId': 'sink',
        'components': <String, Object?>{
          'Panel': <String, Object?>{
            'properties': <String, Object?>{
              'children': <String, Object?>{r'$ref': 'ChildList'},
            },
          },
          'Agree': <String, Object?>{
            'properties': <String, Object?>{
              'value': <String, Object?>{r'$ref': 'DynamicBoolean'},
            },
          },
        },
      },
      messages: _messages(<Map<String, Object?>>[
        <String, Object?>{
          'id': 'root',
          'component': 'Panel',
          'children': <String>['agree'],
        },
        <String, Object?>{
          'id': 'agree',
          'component': 'Agree',
          'value': <String, Object?>{'path': '/agree'},
        },
      ]),
    ));
    await tester.pump();
    expect(_checkboxChecked(tester), isTrue, reason: 'initial bound read');

    tester.dispatchEvent(find.tag('input'), 'change');
    await tester.pump();
    expect(_checkboxChecked(tester), isFalse, reason: 'child-bound write');
  });
}
