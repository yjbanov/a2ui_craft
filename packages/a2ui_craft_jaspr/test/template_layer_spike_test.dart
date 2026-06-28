// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

// M5 spike (DESIGN.md §6 "template layer") — Jaspr parity with the Flutter
// spike. Proves the two-level model renders via the M1-M4 machinery
// re-pointed at a catalog template library:
//
// - Primitives: `core` (Text/Row/Column/Button) — the primitives.
// - Catalog: `catalog`, an RFW RemoteWidgetLibrary authored over
//   `core`. Props become template `args`; a layout widget's `children` are
//   injected host components.
//
// The flagged uncertainty: invoking a *named* template with runtime-injected
// host-component `children`. Tests 2 and 3 exercise exactly that.

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

class _AdHoc extends StatelessComponent {
  const _AdHoc(this.builder);
  final Component Function(BuildContext) builder;
  @override
  Component build(BuildContext context) {
    return builder(context);
  }
}

void main() {
  testComponents('a catalog template composes primitives from args', (
    ComponentTester tester,
  ) async {
    final Runtime runtime = _runtime();

    tester.pumpComponent(
      _AdHoc(
        (BuildContext context) => runtime.buildNode(
          context,
          const ConstructorCall('ProductCard', <String, Object?>{
            'title': 'Sprocket',
            'price': r'$9.99',
          }),
          DynamicContent(),
          _noEvents,
          scope: _catalog,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('Sprocket'), findsOneComponent);
    expect(find.text(r'$9.99'), findsOneComponent);
  });

  testComponents('a layout template renders injected host-component children', (
    ComponentTester tester,
  ) async {
    final Runtime runtime = _runtime();

    tester.pumpComponent(
      _AdHoc(
        (BuildContext context) => runtime.buildNode(
          context,
          const ConstructorCall('Grid', <String, Object?>{
            'children': <Object?>[
              Component.text('alpha'),
              Component.text('beta')
            ],
          }),
          DynamicContent(),
          _noEvents,
          scope: _catalog,
        ),
      ),
    );
    await tester.pump();

    expect(find.text('alpha'), findsOneComponent);
    expect(find.text('beta'), findsOneComponent);
  });

  testComponents('a layout template composes catalog templates as children', (
    ComponentTester tester,
  ) async {
    final Runtime runtime = _runtime();

    tester.pumpComponent(
      _AdHoc((BuildContext context) {
        Component card(String title, String price) => runtime.buildNode(
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
      }),
    );
    await tester.pump();

    expect(find.text('Sprocket'), findsOneComponent);
    expect(find.text(r'$9.99'), findsOneComponent);
    expect(find.text('Gizmo'), findsOneComponent);
    expect(find.text(r'$14.99'), findsOneComponent);
  });

  testComponents('a template wires an EventHandler arg to a primitive', (
    ComponentTester tester,
  ) async {
    final Runtime runtime = _runtime();
    final List<String> dispatched = <String>[];

    tester.pumpComponent(
      _AdHoc(
        (BuildContext context) => runtime.buildNode(
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
    );
    await tester.pump();

    expect(dispatched, isEmpty);
    await tester.click(find.tag('button'));
    expect(dispatched, <String>['addToCart']);
  });
}
