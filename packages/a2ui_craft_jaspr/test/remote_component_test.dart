// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:jaspr_test/jaspr_test.dart';

// Parity test: renders the shared CounterScenario template (identical across all
// adapters) and asserts the same behavior the Flutter adapter asserts —
// parse → render → event → reactive data update. Whereas the Flutter adapter
// produces widgets, this one produces HTML DOM via Jaspr.
void main() {
  testComponents('renders the shared scenario and reacts to events/data',
      (ComponentTester tester) async {
    final Runtime runtime = Runtime()
      ..update(CounterScenario.coreLibrary, createCoreComponents())
      ..update(CounterScenario.mainLibrary, CounterScenario.library());

    final DynamicContent data = DynamicContent();
    data.update(CounterScenario.greetingKey, CounterScenario.greetingInitial);

    var count = 0;
    void onEvent(String name, DynamicMap arguments) {
      if (name == CounterScenario.eventName) {
        count += 1;
        data.update(
            CounterScenario.greetingKey, CounterScenario.greetingAfter(count));
      }
    }

    tester.pumpComponent(
      RemoteComponent(
        runtime: runtime,
        component: CounterScenario.rootComponent,
        data: data,
        onEvent: onEvent,
      ),
    );

    expect(find.text(CounterScenario.greetingInitial), findsOneComponent);
    expect(find.text(CounterScenario.buttonLabel), findsOneComponent);

    // The Button core component renders as a <button>; click it.
    await tester.click(find.tag('button'));

    expect(count, 1);
    expect(find.text(CounterScenario.greetingAfter(1)), findsOneComponent);
    expect(find.text(CounterScenario.greetingInitial), findsNothing);
  });
}
