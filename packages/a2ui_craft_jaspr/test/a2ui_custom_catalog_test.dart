// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

// Exercises a *developer-provided* catalog (not the seed `core` library) driven
// by a real A2UI surface (via a2ui_core), and proves end-to-end that reordering a
// container's children via `updateComponents` preserves each child's identity
// (and thus its State) — the payoff of keying each `A2uiToRfwAdapter` by its A2UI
// id.
//
// The catalog uses two distinct *stateful* component types, each stamping a
// creation ordinal into its State. If a child is merely moved, its ordinal
// survives; if it is destroyed and rebuilt, a fresh ordinal appears. That makes
// presence assertions alone a strict discriminator — no argument plumbing and
// no ordered-readout needed (so it reads the same on every framework).

const LibraryName _core = LibraryName(<String>['core']);

int _probeCreations = 0;

class _Probe extends StatefulComponent {
  const _Probe({required this.label});
  final String label;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final int _id = _probeCreations++;
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield Text('${component.label}#$_id');
  }
}

/// The RFW low-level catalog: a container plus two stateful leaf types. The
/// adapter resolves names against `core`, so the catalog is registered there.
LocalComponentLibrary _customCatalog() {
  return LocalComponentLibrary(<String, LocalComponentBuilder>{
    'Column': (BuildContext context, DataSource source) {
      return div(
        styles: Styles.flexbox(direction: FlexDirection.column),
        source.childList(<Object>['children']),
      );
    },
    'ProbeA': (BuildContext context, DataSource source) {
      return const _Probe(label: 'A');
    },
    'ProbeB': (BuildContext context, DataSource source) {
      return const _Probe(label: 'B');
    },
  });
}

/// The matching a2ui_core component schemas.
class _ColumnApi extends ComponentApi {
  @override
  String get name => 'Column';
  @override
  Schema get schema => Schema.object(
        properties: {'children': CommonSchemas.childList},
        required: ['children'],
      );
}

class _ProbeAApi extends ComponentApi {
  @override
  String get name => 'ProbeA';
  @override
  Schema get schema => Schema.object(properties: {});
}

class _ProbeBApi extends ComponentApi {
  @override
  String get name => 'ProbeB';
  @override
  Schema get schema => Schema.object(properties: {});
}

Catalog<ComponentApi> _coreCatalog() => Catalog<ComponentApi>(
      id: 'custom',
      components: [_ColumnApi(), _ProbeAApi(), _ProbeBApi()],
    );

List<A2uiMessage> _messages(List<Object?> rootChildren) => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 'custom', catalogId: 'custom'),
      UpdateComponentsMessage(
        surfaceId: 'custom',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Column',
            'children': rootChildren,
          },
          <String, dynamic>{'id': 'pa', 'component': 'ProbeA'},
          <String, dynamic>{'id': 'pb', 'component': 'ProbeB'},
        ],
      ),
    ];

void main() {
  testComponents(
    'custom-catalog children keep their State across an A2UI reorder',
    (ComponentTester tester) async {
      _probeCreations = 0;
      final Runtime runtime = Runtime()..update(_core, _customCatalog());
      final MessageProcessor<ComponentApi> processor =
          MessageProcessor<ComponentApi>(catalogs: [_coreCatalog()]);
      processor.processMessages(_messages(<Object?>['pa', 'pb']));
      final SurfaceModel<ComponentApi> surface =
          processor.groupModel.getSurface('custom')!;

      tester.pumpComponent(
        A2uiToRfwAdapter(id: 'root', surface: surface, runtime: runtime),
      );
      await tester.pump();

      expect(find.text('A#0'), findsOneComponent);
      expect(find.text('B#1'), findsOneComponent);

      // Reorder root's children via a follow-up updateComponents.
      processor.processMessages(<A2uiMessage>[
        UpdateComponentsMessage(
          surfaceId: 'custom',
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'Column',
              'children': <Object?>['pb', 'pa'],
            },
          ],
        ),
      ]);
      await tester.pump();

      // Each child followed its A2UI id: the original ordinals survive (no
      // fresh probe was created). A positional/unkeyed reconcile would instead
      // recreate them, surfacing '#2'/'#3'.
      expect(find.text('A#0'), findsOneComponent);
      expect(find.text('B#1'), findsOneComponent);
      expect(find.text('A#2'), findsNothing);
      expect(find.text('B#2'), findsNothing);
    },
  );
}
