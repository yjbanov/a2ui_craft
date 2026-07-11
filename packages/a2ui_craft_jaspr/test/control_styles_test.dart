// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

@TestOn('browser')
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

// The web state layer (layer 2 of the control paint model, DESIGN.md §8):
// hover/pressed feedback needs pseudo-classes, so the first control build
// installs a shared stylesheet into document.head — imperatively, because
// controls render under several roots (RemoteWidget, nested
// A2uiToRfwAdapters) and a component-tree injection point would miss paths
// or duplicate the sheet. This must hold in a REAL browser, which is where
// the earlier component-tree approach silently failed.

Component _surface(String template) {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..update(const LibraryName(<String>['main']), parseLibraryFile(template));
  return RemoteWidget(
    runtime: runtime,
    widget:
        const FullyQualifiedWidgetName(LibraryName(<String>['main']), 'root'),
    data: DynamicContent(),
  );
}

void main() {
  testClient('the first Button installs the control stylesheet once',
      (ClientTester tester) async {
    tester.pumpComponent(_surface('''
      import core;
      widget root = Column(children: [
        Button(key: "b1", onPressed: event "go" {}, child: Text(text: "One")),
        Button(key: "b2", onPressed: event "go" {}, child: Text(text: "Two")),
      ]);
    '''));
    await pumpEventQueue();

    // Installed exactly once, into the head, carrying the state-layer rules.
    final web.Element? sheet =
        web.document.getElementById('craft-control-styles');
    expect(sheet, isNotNull);
    expect(sheet!.textContent, contains('.craft-button'));
    expect(web.document.querySelectorAll('#craft-control-styles').length, 1);

    // The rules actually apply: an enabled button resolves the state-layer
    // cursor (real computed style, not the inline declaration).
    final web.Element button =
        tester.findNode<web.Element>(find.byKey(const ValueKey<String>('b1')))!;
    expect(button.classList.contains('craft-button'), isTrue);
    expect(web.window.getComputedStyle(button).getPropertyValue('cursor'),
        'pointer');
  });
}
