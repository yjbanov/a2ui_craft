// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// M5 spike (DESIGN.md §6 "template layer"): prove the two-level catalog renders
// via the M1-M4 machinery re-pointed at a high-level template library.
//
// - Low-level catalog: `core` (Text/Row/Column/Button) — the primitives.
// - High-level catalog: `catalog`, an RFW RemoteWidgetLibrary authored over
//   `core`. A2UI would reference these names; props become template `args`,
//   and a layout widget's `children` are injected host widgets.
//
// The flagged uncertainty: invoking a *named* template with runtime-injected
// host-widget `children` (M2's tests injected into a bare Column, not through a
// named template's `args.children`). Tests 2 and 3 exercise exactly that.

const LibraryName _core = LibraryName(<String>['core']);
const LibraryName _catalog = LibraryName(<String>['catalog']);

const String _catalogSource = '''
import core;

widget ProductCard = Column(children: [
  Text(text: args.title),
  Text(text: args.price),
]);

widget Grid = Column(children: args.children);

widget Tappable = Button(onPressed: args.action, child: Text(text: args.label));
''';

void _noEvents(String name, DynamicMap arguments) {}

Runtime _runtime() => Runtime()
  ..update(_core, createCoreComponents())
  ..update(_catalog, parseLibraryFile(_catalogSource));

Widget _host(Runtime runtime, ConstructorCall node) {
  return Directionality(
    textDirection: TextDirection.ltr,
    child: Builder(
      builder: (BuildContext context) => runtime.buildNode(
        context,
        node,
        DynamicContent(),
        _noEvents,
        scope: _catalog,
      ),
    ),
  );
}

void main() {
  testWidgets('a high-level template composes low-level widgets from args', (
    WidgetTester tester,
  ) async {
    final Runtime runtime = _runtime();

    await tester.pumpWidget(
      _host(
        runtime,
        const ConstructorCall('ProductCard', <String, Object?>{
          'title': 'Sprocket',
          'price': r'$9.99',
        }),
      ),
    );

    expect(find.text('Sprocket'), findsOneWidget);
    expect(find.text(r'$9.99'), findsOneWidget);
  });

  testWidgets('a layout template renders injected host-widget children', (
    WidgetTester tester,
  ) async {
    final Runtime runtime = _runtime();

    await tester.pumpWidget(
      _host(
        runtime,
        const ConstructorCall('Grid', <String, Object?>{
          'children': <Object?>[
            Text('alpha', textDirection: TextDirection.ltr),
            Text('beta', textDirection: TextDirection.ltr),
          ],
        }),
      ),
    );

    expect(find.text('alpha'), findsOneWidget);
    expect(find.text('beta'), findsOneWidget);
  });

  testWidgets('a layout template composes high-level templates as children', (
    WidgetTester tester,
  ) async {
    final Runtime runtime = _runtime();

    // Render each ProductCard (a high-level template) to a host widget, then
    // inject them as a layout template's children — the two-level stack.
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (BuildContext context) {
            Widget card(String title, String price) => runtime.buildNode(
                  context,
                  ConstructorCall('ProductCard', <String, Object?>{
                    'title': title,
                    'price': price,
                  }),
                  DynamicContent(),
                  _noEvents,
                  scope: _catalog,
                );
            return runtime.buildNode(
              context,
              ConstructorCall('Grid', <String, Object?>{
                'children': <Object?>[
                  card('Sprocket', r'$9.99'),
                  card('Gizmo', r'$14.99'),
                ],
              }),
              DynamicContent(),
              _noEvents,
              scope: _catalog,
            );
          },
        ),
      ),
    );

    expect(find.text('Sprocket'), findsOneWidget);
    expect(find.text(r'$9.99'), findsOneWidget);
    expect(find.text('Gizmo'), findsOneWidget);
    expect(find.text(r'$14.99'), findsOneWidget);
  });

  testWidgets('a template wires an EventHandler arg to a low-level widget', (
    WidgetTester tester,
  ) async {
    final Runtime runtime = _runtime();
    final List<String> dispatched = <String>[];

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (BuildContext context) => runtime.buildNode(
            context,
            const ConstructorCall('Tappable', <String, Object?>{
              'label': 'Go',
              'action': EventHandler('addToCart', <String, Object?>{}),
            }),
            DynamicContent(),
            (String name, DynamicMap arguments) => dispatched.add(name),
            scope: _catalog,
          ),
        ),
      ),
    );

    expect(dispatched, isEmpty);
    await tester.tap(find.text('Go'));
    await tester.pump();
    expect(dispatched, <String>['addToCart']);
  });
}
