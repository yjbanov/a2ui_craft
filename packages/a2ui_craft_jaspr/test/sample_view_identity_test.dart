// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

// The demo site hosts SampleView inside a layout that *re-parents* the pane
// when the viewport crosses the side-by-side threshold (one pane ⇄ two), and
// rebuilds it with a new `theme` prop on re-theming. Neither may reset the
// surface: SampleView processes its A2UI messages once, in `initState`, so a
// remount recreates the data model and silently wipes what the user did (the
// site bug: interaction made while the Flutter embed was still booting
// vanished when a resize flipped the layout). A local key cannot protect the
// pane — keys match only among siblings — so the site pins the pane with a
// GlobalKey. These tests pin both halves of that contract.

const String _template = '''
  import core;
  widget Root = Column(children: [
    Switch(value: args.value, onChanged: args.setValue),
    Text(text: switch args.value { true: "ON", default: "OFF" }),
  ]);
''';

final Map<String, Object?> _schema = <String, Object?>{
  'catalogId': 'demo',
  'components': <String, Object?>{
    'Root': <String, Object?>{
      'properties': <String, Object?>{
        'value': <String, Object?>{r'$ref': 'DynamicBoolean'},
      },
    },
  },
};

/// The bootstrap script: one surface, `/value: true`, a Root bound to it.
List<A2uiMessage> _messages() => <A2uiMessage>[
      for (final Object? m in jsonDecode('''
[
  {"version": "v0.9",
   "createSurface": {"surfaceId": "demo", "catalogId": "demo", "sendDataModel": false}},
  {"version": "v0.9",
   "updateDataModel": {"surfaceId": "demo", "path": "/", "value": {"value": true}}},
  {"version": "v0.9",
   "updateComponents": {"surfaceId": "demo", "components": [
     {"id": "root", "component": "Root", "value": {"path": "/value"}}]}}
]
''') as List<Object?>) A2uiMessage.fromJson(m as Map<String, dynamic>),
    ];

_ShellState? _shell;

/// Mimics the site's SampleScreen layout: narrow renders the sample pane
/// alone; wide re-parents it (one level deeper) beside a sibling pane.
class _Shell extends StatefulComponent {
  const _Shell({required this.sampleKey});

  final Key sampleKey;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> {
  bool _wide = false;

  @override
  void initState() {
    super.initState();
    _shell = this;
  }

  void setWide(bool wide) => setState(() => _wide = wide);

  Component _sample() => SampleView(
        key: component.sampleKey,
        template: _template,
        schema: _schema,
        messages: _messages(),
      );

  @override
  Component build(BuildContext context) {
    if (!_wide) return div([_sample()]);
    return div([
      div([_sample()]),
      div([Component.text('sibling pane')]),
    ]);
  }
}

Finder get _switch => find.byComponentPredicate(
    (Component c) => c is DomComponent && c.attributes?['role'] == 'switch');

void main() {
  testComponents(
      'a GlobalKey-ed SampleView keeps its data model when the layout '
      're-parents it (the site pattern)', (ComponentTester tester) async {
    tester.pumpComponent(_Shell(sampleKey: GlobalKey()));
    await tester.pump();
    expect(find.text('ON'), findsOneComponent);

    // Interact: the switch's two-way binding writes `/value = false`.
    tester.dispatchEvent(_switch, 'change');
    await tester.pump();
    expect(find.text('OFF'), findsOneComponent);

    // Re-parent (narrow -> wide) and back, as a viewport flip does.
    _shell!.setWide(true);
    await tester.pump();
    expect(find.text('OFF'), findsOneComponent,
        reason: 'the re-parented SampleView must keep its data model');

    _shell!.setWide(false);
    await tester.pump();
    expect(find.text('OFF'), findsOneComponent);
  });

  testComponents(
      'a locally keyed SampleView is remounted by the same re-parent '
      '(why the site must use a GlobalKey)', (ComponentTester tester) async {
    tester.pumpComponent(const _Shell(sampleKey: ValueKey<String>('jaspr-0')));
    await tester.pump();
    tester.dispatchEvent(_switch, 'change');
    await tester.pump();
    expect(find.text('OFF'), findsOneComponent);

    _shell!.setWide(true);
    await tester.pump();
    // The remount re-processed the messages: the model reset to `true`. If
    // this ever finds OFF, local keys started surviving re-parenting and the
    // GlobalKey ceased to be load-bearing — revisit the site's key choice.
    expect(find.text('ON'), findsOneComponent);
  });
}
