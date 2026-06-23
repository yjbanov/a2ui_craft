// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

// Verifies M2 (DESIGN.md §6): `Runtime.buildNode` renders an ad-hoc composition
// against the registered libraries, and host components injected as slot
// arguments are rendered transparently (no `_Widget` wrapper) so they keep their
// own key at the reconciliation position.

const LibraryName _core = LibraryName(<String>['core']);

void _noEvents(String name, DynamicMap arguments) {}

int _probeCreations = 0;

class _Probe extends StatefulComponent {
  const _Probe({super.key, required this.label});
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

class _AdHoc extends StatelessComponent {
  const _AdHoc({required this.runtime, required this.composition});
  final Runtime runtime;
  final ConstructorCall composition;
  @override
  Iterable<Component> build(BuildContext context) sync* {
    yield runtime.buildNode(
      context,
      composition,
      DynamicContent(),
      _noEvents,
      scope: _core,
    );
  }
}

/// Renders [_Probe]s (host components) injected into a buildNode composition;
/// the button reverses their order.
class _Harness extends StatefulComponent {
  const _Harness({required this.runtime});
  final Runtime runtime;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _reversed = false;

  @override
  Iterable<Component> build(BuildContext context) sync* {
    final List<Component> probes = <Component>[
      const _Probe(key: ValueKey<String>('a'), label: 'A'),
      const _Probe(key: ValueKey<String>('b'), label: 'B'),
    ];
    final ConstructorCall composition =
        ConstructorCall('Column', <String, Object?>{
      'children': _reversed ? probes.reversed.toList() : probes,
    });
    yield div(<Component>[
      component.runtime.buildNode(
        context,
        composition,
        DynamicContent(),
        _noEvents,
        scope: _core,
      ),
      button(
        <Component>[const Text('reverse')],
        onClick: () => setState(() => _reversed = true),
      ),
    ]);
  }
}

void main() {
  testComponents(
      'buildNode renders an ad-hoc composition of predefined widgets',
      (ComponentTester tester) async {
    final Runtime runtime = Runtime()..update(_core, createCoreComponents());

    final ConstructorCall composition =
        ConstructorCall('Column', <String, Object?>{
      'children': <Object?>[
        ConstructorCall('Text', <String, Object?>{'text': 'hi'}),
      ],
    });

    tester.pumpComponent(_AdHoc(runtime: runtime, composition: composition));
    await tester.pump();

    expect(find.text('hi'), findsOneComponent);
  });

  testComponents('injected host components keep their key across reorder',
      (ComponentTester tester) async {
    _probeCreations = 0;
    final Runtime runtime = Runtime()..update(_core, createCoreComponents());

    tester.pumpComponent(_Harness(runtime: runtime));
    await tester.pump();

    expect(find.text('A#0'), findsOneComponent);
    expect(find.text('B#1'), findsOneComponent);

    await tester.click(find.tag('button'));

    // State followed the injected component's key, not its position.
    expect(find.text('B#1'), findsOneComponent);
    expect(find.text('A#0'), findsOneComponent);
    expect(find.text('B#0'), findsNothing);
  });
}
