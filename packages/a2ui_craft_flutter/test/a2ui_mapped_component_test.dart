// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

// Proves the "bespoke widget" path: an existing local widget is surfaced
// *directly* as an A2UI component via `mapComponent`, renaming the component's
// props onto the widget's args — with no template wrapper, and with no
// dependence on the core primitives or any particular catalog. This is a normal,
// self-contained test scenario; the capability lives in the adapter, not in any
// catalog-specific package API.

const LibraryName _core = LibraryName(<String>['core']);

/// A bespoke local widget whose arg is named `title` — deliberately different
/// from the A2UI component's `heading` prop, so the mapping must rename it.
LocalWidgetLibrary _appWidgets() =>
    LocalWidgetLibrary(<String, LocalWidgetBuilder>{
      'Banner': (BuildContext context, DataSource source) =>
          Text(source.v<String>(<Object>['title']) ?? ''),
    });

/// The A2UI catalog component `Hero`, with a single bindable `heading` prop.
class _HeroApi extends ComponentApi {
  @override
  String get name => 'Hero';

  @override
  Schema get schema => Schema.object(
        properties: <String, Schema>{'heading': CommonSchemas.dynamicString},
        required: <String>['heading'],
      );
}

Catalog<ComponentApi> _appCatalog() =>
    Catalog<ComponentApi>(id: 'app', components: <ComponentApi>[_HeroApi()]);

/// The embedder's per-component choice: render `Hero` as the local `Banner`,
/// renaming `heading` -> `title`. Anything else passes through unchanged.
ConstructorCall _heroToBanner(String type, DynamicMap args) => type == 'Hero'
    ? ConstructorCall('Banner', <String, Object?>{'title': args['heading']})
    : ConstructorCall(type, args);

Future<SurfaceModel<ComponentApi>> _surface(List<A2uiMessage> messages) async {
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(catalogs: <Catalog<ComponentApi>>[
    _appCatalog(),
  ]);
  processor.processMessages(messages);
  return processor.groupModel.getSurface('app')!;
}

Future<void> _pump(
  WidgetTester tester,
  SurfaceModel<ComponentApi> surface,
) async {
  final Runtime runtime = Runtime()..update(_core, _appWidgets());
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: A2uiToRfwAdapter(
        id: 'root',
        surface: surface,
        runtime: runtime,
        mapComponent: _heroToBanner,
      ),
    ),
  );
}

void main() {
  testWidgets('maps an A2UI component directly onto a bespoke local widget',
      (WidgetTester tester) async {
    final SurfaceModel<ComponentApi> surface = await _surface(<A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 'app', catalogId: 'app'),
      UpdateComponentsMessage(
        surfaceId: 'app',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Hero',
            'heading': 'Hello, bespoke widget',
          },
        ],
      ),
    ]);

    await _pump(tester, surface);

    // The component named `Hero` rendered the local `Banner`, and its `heading`
    // prop reached `Banner`'s `title` arg through the rename.
    expect(find.text('Hello, bespoke widget'), findsOneWidget);
  });

  testWidgets('a data-bound prop flows through the direct mapping',
      (WidgetTester tester) async {
    final SurfaceModel<ComponentApi> surface = await _surface(<A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 'app', catalogId: 'app'),
      UpdateComponentsMessage(
        surfaceId: 'app',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Hero',
            'heading': <String, dynamic>{'path': '/title'},
          },
        ],
      ),
      UpdateDataModelMessage(
        surfaceId: 'app',
        value: <String, dynamic>{'title': 'Bound heading'},
      ),
    ]);

    await _pump(tester, surface);

    expect(find.text('Bound heading'), findsOneWidget);
  });
}
