// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// Two-way control writes in a REAL browser under compiled JS, end to end
// through a [SampleView] inline trio (the demo site's kitchen-sink specimen
// shape): the interaction writes through `args.setValue` into the data model
// and the controlled element (plus a bound readout Text on the same path)
// re-renders from it. Real-browser only: the browser's typed event values —
// e.g. a range input delivering `valueAsNumber` (a num, not a string) — are
// exactly what the VM's DOM emulation cannot reproduce.
@TestOn('browser')
library;

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:a2ui_craft/a2ui_craft.dart' show CraftThemeMode, DefaultTheme;
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

List<A2uiMessage> _messages(Map<String, Object?> data) => <A2uiMessage>[
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
          'value': data,
        },
      }),
      A2uiMessage.fromJson(<String, dynamic>{
        'version': 'v0.9',
        'updateComponents': <String, Object?>{
          'surfaceId': 'sink',
          'components': <Object?>[
            <String, Object?>{
              'id': 'root',
              'component': 'Root',
              'value': <String, Object?>{'path': '/bound'},
            },
          ],
        },
      }),
    ];

Map<String, Object?> _schema(String valueRef) => <String, Object?>{
      'catalogId': 'sink',
      'components': <String, Object?>{
        'Root': <String, Object?>{
          'properties': <String, Object?>{
            'value': <String, Object?>{r'$ref': valueRef},
          },
        },
      },
    };

List<String> _spanTexts() => <String>[
      for (int i = 0; i < web.document.querySelectorAll('span').length; i++)
        web.document
            .querySelectorAll('span')
            .item(i)!
            .textContent
            .toString()
            .trim(),
    ];

void main() {
  testClient('root-bound select write round-trips in a real browser',
      (ClientTester tester) async {
    tester.pumpComponent(SampleView(
      template: '''
import core;
widget Root = Column(children: [
  Select(value: args.value, options: ["Small", "Medium", "Large"],
    onChanged: args.setValue),
  Text(text: args.value, variant: "caption"),
]);
''',
      schema: _schema('DynamicString'),
      messages: _messages(<String, Object?>{'bound': 'Medium'}),
      theme: DefaultTheme.of(CraftThemeMode.light),
    ));
    await pumpEventQueue();

    final web.HTMLSelectElement select =
        web.document.querySelector('select')! as web.HTMLSelectElement;
    expect(select.value, 'Medium', reason: 'initial bound read');
    expect(_spanTexts(), contains('Medium'), reason: 'initial bound readout');

    select.value = 'Large';
    select.dispatchEvent(web.Event('change', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    // The bound readout Text follows the same binding: if the write reached
    // the data model, the re-render shows "Large".
    expect(_spanTexts(), contains('Large'),
        reason: 'write round-trips to the bound readout');
  });

  testClient('root-bound slider write round-trips in a real browser',
      (ClientTester tester) async {
    // The browser delivers a range input's value as `valueAsNumber` (a num) —
    // jaspr types the `input` event value by InputType — so this only breaks
    // (or holds) in a real browser.
    tester.pumpComponent(SampleView(
      template: '''
import core;
widget Root = Column(children: [
  Slider(min: 0.0, max: 100.0, value: args.value, onChanged: args.setValue),
  Text(text: args.value, variant: "caption"),
]);
''',
      schema: _schema('DataBinding'),
      messages: _messages(<String, Object?>{'bound': 64}),
      theme: DefaultTheme.of(CraftThemeMode.light),
    ));
    await pumpEventQueue();

    final web.HTMLInputElement slider = web.document
        .querySelector('input[type=range]')! as web.HTMLInputElement;
    // dart2js renders the whole-valued double 64.0 as '64'.
    expect(slider.value, '64', reason: 'initial bound read');
    expect(_spanTexts(), contains('64'), reason: 'initial bound readout');

    slider.value = '85';
    slider.dispatchEvent(web.Event('input', web.EventInit(bubbles: true)));
    await pumpEventQueue();

    expect(_spanTexts(), contains('85'),
        reason: 'write round-trips to the bound readout');
  });
}
