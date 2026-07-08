// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

// The Flutter half of the Button/Radio accessibility contract: the exact
// semantics a screen reader sees (role, merged label, enabled/checked state)
// and the keyboard-activation path (Tab to focus; Space/Enter arrive as
// activate intents through the app-level shortcuts). The cross-adapter role
// announcement is covered by the shared conformance suite
// (CraftTester.buttonCount); the Jaspr adapter gets role and keyboard natively
// from <button>/<input type=radio>, pinned in its own a11y test.

Future<void> _mount(WidgetTester tester, String template) async {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(const LibraryName(<String>['main']), parseLibraryFile(template));
  await tester.pumpWidget(MaterialApp(
    home: Scaffold(
      body: RemoteWidget(
        runtime: runtime,
        widget: const FullyQualifiedWidgetName(
          LibraryName(<String>['main']),
          'root',
        ),
        data: DynamicContent(),
      ),
    ),
  ));
}

void main() {
  testWidgets('Button exposes role, merged label, state, tap, and focus',
      (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await _mount(tester, '''
      import core;
      widget root = Column(children: [
        Button(onPressed: event "press" {}, child: Text(text: "Go")),
        Button(child: Text(text: "Stop")),
      ]);
    ''');

    // The child's text merges into a single button node — no extra
    // `semanticLabel` plumbing needed by templates.
    expect(
      tester.getSemantics(find.text('Go')),
      isSemantics(
        isButton: true,
        label: 'Go',
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    // A handler-less button is announced as a disabled button, not silently
    // inert (and not focusable — matching a <button disabled>).
    expect(
      tester.getSemantics(find.text('Stop')),
      isSemantics(
        isButton: true,
        label: 'Stop',
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });

  testWidgets('Button activates from the keyboard (Space and Enter)',
      (WidgetTester tester) async {
    await _mount(tester, '''
      import core;
      widget root { count: 0 } = Column(children: [
        Button(
          onPressed: set state.count = add(a: state.count, b: 1),
          child: Text(text: "inc"),
        ),
        Text(text: concat(a: "n=", b: state.count)),
      ]);
    ''');
    expect(find.text('n=0'), findsOneWidget);

    // Tab reaches the button (the only focusable in the surface)…
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    // …Space activates…
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text('n=1'), findsOneWidget);

    // …and so does Enter.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text('n=2'), findsOneWidget);
  });

  testWidgets('Radio exposes checked state in a mutually exclusive group',
      (WidgetTester tester) async {
    final semantics = tester.ensureSemantics();
    await _mount(tester, '''
      import core;
      widget root = Column(children: [
        Radio(selected: true, onChanged: event "a" {}, key: "on"),
        Radio(selected: false, onChanged: event "b" {}, key: "off"),
        Radio(selected: false, key: "inert"),
      ]);
    ''');

    expect(
      tester.getSemantics(find.byKey(const ValueKey<String>('on'))),
      isSemantics(
        hasCheckedState: true,
        isChecked: true,
        isInMutuallyExclusiveGroup: true,
        hasEnabledState: true,
        isEnabled: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey<String>('off'))),
      isSemantics(
        hasCheckedState: true,
        isChecked: false,
        isInMutuallyExclusiveGroup: true,
      ),
    );
    expect(
      tester.getSemantics(find.byKey(const ValueKey<String>('inert'))),
      isSemantics(
        hasCheckedState: true,
        isChecked: false,
        hasEnabledState: true,
        isEnabled: false,
      ),
    );
    semantics.dispose();
  });
}
