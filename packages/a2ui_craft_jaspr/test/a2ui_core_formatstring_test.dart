// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// a2ui_core `formatString` integration (DESIGN.md §5): drives the **real**
// `A2uiToRfwAdapter` over `a2ui_core`, exercising the one binding feature the
// cross-adapter conformance suite does not — a `formatString` function resolving
// a value that is fed to a template as an arg, and re-resolving reactively on
// `updateDataModel`. (The broader seam — child injection, actions, partial
// updates — is covered by `runA2uiConformance`.)
//
//   A2UI messages
//     → a2ui_core: MessageProcessor + GenericBinder (resolves formatString)
//     → A2uiToRfwAdapter: resolved props → template args
//     → RFW: buildNode(ProductCard/Grid over `core`)
//     → Jaspr DOM

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName, parseLibraryFile;
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// A catalog authored as RFW templates over `core`.
const String _catalogSource = '''
import core;

widget ProductCard = Column(children: [
  Text(text: args.title),
  Text(text: args.price),
]);

widget Grid = Column(children: args.children);
''';

const LibraryName _catalogName = LibraryName(<String>['catalog']);

class _ProductCardApi extends ComponentApi {
  @override
  String get name => 'ProductCard';
  @override
  Schema get schema => Schema.object(
        properties: {
          'title': CommonSchemas.dynamicString,
          'price': CommonSchemas.dynamicString,
        },
        required: ['title'],
      );
}

class _GridApi extends ComponentApi {
  @override
  String get name => 'Grid';
  @override
  Schema get schema => Schema.object(
        properties: {'children': CommonSchemas.childList},
        required: ['children'],
      );
}

Catalog<ComponentApi> _catalog() => Catalog<ComponentApi>(
      id: 'spike',
      components: [_GridApi(), _ProductCardApi()],
      functions: [FormatStringFunction()],
    );

/// Two product cards in a grid; each card's price is a `formatString` over the
/// data model, so it resolves reactively.
List<A2uiMessage> _messages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 's', catalogId: 'spike'),
      UpdateDataModelMessage(
        surfaceId: 's',
        path: '/',
        value: <String, Object?>{
          'products': <Object?>[
            <String, Object?>{'price': 19.99},
            <String, Object?>{'price': 5.0},
          ],
        },
      ),
      UpdateComponentsMessage(
        surfaceId: 's',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Grid',
            'children': <Object?>['p1', 'p2'],
          },
          <String, dynamic>{
            'id': 'p1',
            'component': 'ProductCard',
            'title': 'Widget A',
            'price': <String, dynamic>{
              'call': 'formatString',
              'args': <String, dynamic>{
                'value': r'Price: ${/products/0/price}'
              },
            },
          },
          <String, dynamic>{
            'id': 'p2',
            'component': 'ProductCard',
            'title': 'Widget B',
            'price': <String, dynamic>{
              'call': 'formatString',
              'args': <String, dynamic>{
                'value': r'Price: ${/products/1/price}'
              },
            },
          },
        ],
      ),
    ];

void main() {
  late Runtime runtime;
  late MessageProcessor<ComponentApi> processor;
  late SurfaceModel<ComponentApi> surface;

  setUp(() {
    runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(_catalogName, parseLibraryFile(_catalogSource));
    processor = MessageProcessor<ComponentApi>(catalogs: [_catalog()]);
    processor.processMessages(_messages());
    surface = processor.groupModel.getSurface('s')!;
  });

  testComponents(
    'formatString resolves into a template arg via the real adapter',
    (ComponentTester tester) async {
      tester.pumpComponent(
        A2uiToRfwAdapter(
          id: 'root',
          surface: surface,
          runtime: runtime,
          scope: _catalogName,
        ),
      );
      await tester.pump();

      expect(find.text('Widget A').evaluate(), isNotEmpty);
      expect(find.text('Widget B').evaluate(), isNotEmpty);
      expect(find.text('Price: 19.99').evaluate(), isNotEmpty);
      expect(find.text('Price: 5.0').evaluate(), isNotEmpty);
    },
  );

  testComponents(
    'a formatString price re-resolves on updateDataModel',
    (ComponentTester tester) async {
      tester.pumpComponent(
        A2uiToRfwAdapter(
          id: 'root',
          surface: surface,
          runtime: runtime,
          scope: _catalogName,
        ),
      );
      await tester.pump();
      expect(find.text('Price: 19.99').evaluate(), isNotEmpty);

      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
            surfaceId: 's', path: '/products/0/price', value: 25.0),
      ]);
      await tester.pump();

      expect(find.text('Price: 25.0').evaluate(), isNotEmpty);
      expect(find.text('Price: 19.99').evaluate(), isEmpty);
      expect(find.text('Price: 5.0').evaluate(), isNotEmpty); // p2 untouched
    },
  );
}
