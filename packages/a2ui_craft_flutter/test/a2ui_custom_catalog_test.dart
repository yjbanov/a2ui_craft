// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Exercises a *developer-provided* catalog (not the seed `core` library) driven
// by a real A2UI surface, and proves end-to-end that reordering a container's
// children via `updateComponents` preserves each child's identity (and thus its
// State) — the payoff of keying each `A2uiToRfwAdapter` by its A2UI id.
//
// The catalog uses two distinct *stateful* component types, each stamping a
// creation ordinal into its State. If a child is merely moved, its ordinal
// survives; if it is destroyed and rebuilt, a fresh ordinal appears. That makes
// presence assertions alone a strict discriminator — no argument plumbing and
// no ordered-readout needed (so it reads the same on every framework).

const LibraryName _core = LibraryName(<String>['core']);

int _probeCreations = 0;

class _Probe extends StatefulWidget {
  const _Probe({required this.label});
  final String label;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final int _id = _probeCreations++;
  @override
  Widget build(BuildContext context) => Text('${widget.label}#$_id');
}

/// A custom catalog: a container plus two stateful leaf component types. The
/// adapter resolves names against `core`, so the catalog is registered there.
LocalComponentLibrary _customCatalog() {
  return LocalComponentLibrary(<String, LocalComponentBuilder>{
    'Column': (BuildContext context, DataSource source) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: source.childList(<Object>['children']),
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

Map<String, Object?> _surfaceMessage(List<Object?> rootChildren) {
  return <String, Object?>{
    'createSurface': <String, Object?>{
      'surfaceId': 'custom',
      'components': <Object?>[
        <String, Object?>{
          'id': 'root',
          'component': 'Column',
          'children': rootChildren,
        },
        <String, Object?>{'id': 'pa', 'component': 'ProbeA'},
        <String, Object?>{'id': 'pb', 'component': 'ProbeB'},
      ],
    },
  };
}

void main() {
  testWidgets(
    'custom-catalog children keep their State across an A2UI reorder',
    (WidgetTester tester) async {
      _probeCreations = 0;
      final Runtime runtime = Runtime()..update(_core, _customCatalog());
      late final A2uiSurface surface;
      surface = A2uiSurface(
        adapterBuilder: (String id) => A2uiToRfwAdapter(
          id: id,
          surface: surface,
          runtime: runtime,
        ),
      );
      surface.apply(_surfaceMessage(<Object?>['pa', 'pb']));

      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child:
              A2uiToRfwAdapter(id: 'root', surface: surface, runtime: runtime),
        ),
      );

      expect(find.text('A#0'), findsOneWidget);
      expect(find.text('B#1'), findsOneWidget);

      // Reorder root's children via a follow-up updateComponents.
      surface.apply(<String, Object?>{
        'updateComponents': <String, Object?>{
          'components': <Object?>[
            <String, Object?>{
              'id': 'root',
              'component': 'Column',
              'children': <Object?>['pb', 'pa'],
            },
          ],
        },
      });
      await tester.pump();

      // Each child followed its A2UI id: the original ordinals survive (no
      // fresh probe was created). A positional/unkeyed reconcile would instead
      // recreate them, surfacing '#2'/'#3'.
      expect(find.text('A#0'), findsOneWidget);
      expect(find.text('B#1'), findsOneWidget);
      expect(find.text('A#2'), findsNothing);
      expect(find.text('B#2'), findsNothing);
    },
  );
}
