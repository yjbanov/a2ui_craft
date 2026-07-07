// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

// The Jaspr half of the Button a11y contract: the primitive must render a real
// <button type=button> — the platform then provides the role, focusability,
// and Space/Enter activation — and must be `disabled` when it has no handler
// (out of the tab order, announced as disabled), matching the Flutter
// adapter's Semantics(enabled: false). Radio is already a native
// <input type=radio>. The cross-adapter role announcement is covered by the
// shared conformance suite (CraftTester.buttonCount).

Future<void> _mount(ComponentTester tester, String template) async {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(const LibraryName(<String>['main']), parseLibraryFile(template));
  tester.pumpComponent(RemoteWidget(
    runtime: runtime,
    widget: const FullyQualifiedWidgetName(
      LibraryName(<String>['main']),
      'root',
    ),
    data: DynamicContent(),
  ));
  await tester.pump();
}

void main() {
  testComponents(
      'Button renders a native <button type=button>, disabled without a handler',
      (ComponentTester tester) async {
    await _mount(tester, '''
      import core;
      widget root = Column(children: [
        Button(onPressed: event "press" {}, child: Text(text: "Go")),
        Button(child: Text(text: "Stop")),
      ]);
    ''');

    expect(
      find.byComponentPredicate((Component c) =>
          c is button && !c.disabled && c.type == ButtonType.button),
      findsOneComponent,
    );
    expect(
      find.byComponentPredicate((Component c) =>
          c is button && c.disabled && c.type == ButtonType.button),
      findsOneComponent,
    );
  });
}
