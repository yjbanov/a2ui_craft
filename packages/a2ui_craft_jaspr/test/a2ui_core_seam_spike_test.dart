// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// M6 de-risking spike (DESIGN.md §10): prove that the **real** `a2ui_core` can
// drive an RFW template through `Runtime.buildNode`, with no changes to the
// vendored runtime. This validates the seam before we delete the bridge's own
// protocol/data half:
//
//   A2UI messages
//     → a2ui_core: MessageProcessor + SurfaceModel + DataModel + GenericBinder
//     → resolvedProps (concrete scalars + List<ChildNode>)
//     → seam (this file): props → RFW template ARGS; ChildNodes → child adapters
//     → RFW: buildNode(ConstructorCall(templateName, args), scope: catalog)
//     → Jaspr DOM
//
// Scope per §10: a `ProductCard` + `Grid` library over `core`, a surface placing
// two cards in a grid, a2ui_core resolving one `formatString` and one
// `updateDataModel`. Actions/two-way setters are intentionally out of scope here
// (the next, smaller seam — wiring a2ui_core callbacks to RFW voidHandler).

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The high-level catalog, authored once as RFW templates over `core`.
const String _catalogSource = '''
import core;

widget ProductCard = Column(children: [
  Text(text: args.title),
  Text(text: args.price),
]);

widget Grid = Column(children: args.children);
''';

const LibraryName _catalogName = LibraryName(<String>['catalog']);

/// a2ui_core component API definitions (schemas drive GenericBinder's behavior
/// scraping). These mirror the high-level catalog above.
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

Catalog<ComponentApi> _buildCatalog() => Catalog<ComponentApi>(
      id: 'spike',
      components: [_GridApi(), _ProductCardApi()],
      functions: [FormatStringFunction()],
    );

/// The A2UI conversation: create a surface, seed the data model, then place two
/// product cards in a grid. Each card's price is a `formatString` over the data
/// model, so it resolves reactively.
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

/// The seam under test: one Jaspr component per A2UI component, keyed by id.
///
/// It owns a [GenericBinder] for its component, subscribes to `resolvedProps`
/// (the preact_signals → setState bridge), and renders the corresponding RFW
/// template via [Runtime.buildNode] — feeding resolved scalars as template args
/// and injecting child adapters for structural [ChildNode] lists.
class _SeamAdapter extends StatefulComponent {
  _SeamAdapter({
    required this.id,
    required this.basePath,
    required this.surface,
    required this.runtime,
  }) : super(key: ValueKey<String>(id));

  final String id;
  final String basePath;
  final SurfaceModel<ComponentApi> surface;
  final Runtime runtime;

  @override
  State<_SeamAdapter> createState() => _SeamAdapterState();
}

class _SeamAdapterState extends State<_SeamAdapter> {
  late final GenericBinder _binder;
  late final void Function() _unsubscribe;
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    final ComponentModel model = component.surface.componentsModel.get(
      component.id,
    )!;
    final Schema schema =
        component.surface.catalog.components[model.type]!.schema;
    final ComponentContext context = ComponentContext(
      component.surface,
      model,
      basePath: component.basePath,
    );
    _binder = GenericBinder(context, schema);
    // preact_signals fires the callback immediately on subscribe; the `_ready`
    // guard skips that synchronous initial call (we are still in initState).
    _unsubscribe = _binder.resolvedProps.subscribe((_) {
      if (_ready) setState(() {});
    });
    _ready = true;
  }

  @override
  void dispose() {
    _unsubscribe();
    _binder.dispose();
    super.dispose();
  }

  @override
  Iterable<Component> build(BuildContext context) {
    final ComponentModel model = component.surface.componentsModel.get(
      component.id,
    )!;
    final Map<String, dynamic> props = _binder.resolvedProps.value;

    final DynamicMap args = <String, Object?>{};
    for (final MapEntry<String, dynamic> entry in props.entries) {
      final Object? value = entry.value;
      if (value is List && value.isNotEmpty && value.first is ChildNode) {
        args[entry.key] = value
            .cast<ChildNode>()
            .map((ChildNode child) => _SeamAdapter(
                  id: child.id,
                  basePath: child.basePath,
                  surface: component.surface,
                  runtime: component.runtime,
                ))
            .toList();
      } else {
        args[entry.key] = value;
      }
    }

    return <Component>[
      component.runtime.buildNode(
        context,
        ConstructorCall(model.type, args),
        DynamicContent(),
        (String name, DynamicMap arguments) {},
        scope: _catalogName,
      ),
    ];
  }
}

void main() {
  late Runtime runtime;
  late MessageProcessor<ComponentApi> processor;
  late SurfaceModel<ComponentApi> surface;

  setUp(() {
    runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(_catalogName, parseLibraryFile(_catalogSource));

    processor = MessageProcessor<ComponentApi>(catalogs: [_buildCatalog()]);
    processor.processMessages(_messages());
    surface = processor.groupModel.getSurface('s')!;
  });

  testComponents(
    'a2ui_core resolvedProps drive an RFW template through buildNode',
    (ComponentTester tester) async {
      tester.pumpComponent(
        _SeamAdapter(
          id: 'root',
          basePath: '/',
          surface: surface,
          runtime: runtime,
        ),
      );
      await tester.pump();

      // Both cards rendered (child injection through Grid's args.children).
      expect(find.text('Widget A').evaluate(), isNotEmpty);
      expect(find.text('Widget B').evaluate(), isNotEmpty);
      // formatString resolved against the data model, fed as a template arg.
      expect(find.text('Price: 19.99').evaluate(), isNotEmpty);
      expect(find.text('Price: 5.0').evaluate(), isNotEmpty);
    },
  );

  testComponents(
    'updateDataModel re-renders the affected card (component-granular signal)',
    (ComponentTester tester) async {
      tester.pumpComponent(
        _SeamAdapter(
          id: 'root',
          basePath: '/',
          surface: surface,
          runtime: runtime,
        ),
      );
      await tester.pump();
      expect(find.text('Price: 19.99').evaluate(), isNotEmpty);

      // An agent streams an updateDataModel: a2ui_core writes the DataModel, the
      // formatString computed re-fires, p1's resolvedProps signal updates, and
      // only p1's adapter rebuilds.
      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: 's',
          path: '/products/0/price',
          value: 25.0,
        ),
      ]);
      await tester.pump();

      expect(find.text('Price: 25.0').evaluate(), isNotEmpty);
      expect(find.text('Price: 19.99').evaluate(), isEmpty);
      // p2 untouched.
      expect(find.text('Price: 5.0').evaluate(), isNotEmpty);
    },
  );
}
