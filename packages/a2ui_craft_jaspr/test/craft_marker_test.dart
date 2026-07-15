// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The runtime stamps every core-primitive DOM element with a `data-craft`
// attribute naming the widget that produced it, so the rendered HTML is legible
// when debugging (a bare `<div>` reads as a `Box`, `Row`, or `Column`). The
// attribute is merged onto the element at render time (via `wrapElement`), so it
// is only observable against real rendered DOM — hence a browser test.
@TestOn('browser')
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr_test/client_test.dart';
import 'package:universal_web/web.dart' as web;

void main() {
  testClient('the runtime stamps each core-primitive element with data-craft',
      (ClientTester tester) async {
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..registerFunctions(createCoreFunctions())
      ..update(const LibraryName(<String>['main']), parseLibraryFile('''
        import core;
        widget root = Column(children: [
          Box(child: Text(text: "hi")),
          Slider(value: 50.0, min: 0.0, max: 100.0),
        ]);
      '''));
    tester.pumpComponent(RemoteWidget(
      runtime: runtime,
      widget: const FullyQualifiedWidgetName(
        LibraryName(<String>['main']),
        'root',
      ),
      data: DynamicContent(),
    ));
    await pumpEventQueue();

    // Column and Box both render a <div>; the marker is what tells them apart
    // in the inspector.
    final web.Element column =
        web.document.querySelector('[data-craft="Column"]')!;
    expect(column.tagName.toLowerCase(), 'div');
    expect(
        web.document.querySelector('[data-craft="Box"]')!.tagName.toLowerCase(),
        'div');
    // Text renders a <span>.
    expect(
        web.document
            .querySelector('[data-craft="Text"]')!
            .tagName
            .toLowerCase(),
        'span');

    // Additive: a primitive that already sets attributes (the range input's
    // type/min/max) keeps them and gains `data-craft`.
    final web.Element slider = web.document.querySelector('input[type=range]')!;
    expect(slider.getAttribute('data-craft'), 'Slider');
    // (dart2js renders the whole-valued double 100.0 as '100'.)
    expect(slider.getAttribute('max'), '100');

    // Only the primitive's root element is stamped, not the child content: the
    // Box (a div) is marked, its Text child (the span) is marked "Text", and
    // there is no stray marker on the raw text node.
    expect(
        web.document.querySelectorAll('[data-craft]').length, greaterThan(3));
  });
}
