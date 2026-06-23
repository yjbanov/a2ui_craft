// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Verifies M2 (DESIGN.md §6): `Runtime.buildNode` renders an ad-hoc composition
// against the registered libraries, and host widgets injected as slot arguments
// are rendered transparently (no `_Widget` wrapper) so they keep their own key
// at the reconciliation position.

const LibraryName _core = LibraryName(<String>['core']);

void _noEvents(String name, DynamicMap arguments) {}

int _probeCreations = 0;

class _Probe extends StatefulWidget {
  const _Probe({super.key, required this.label});
  final String label;
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  late final int _id = _probeCreations++;
  @override
  Widget build(BuildContext context) => Text('${widget.label}#$_id');
}

/// Renders [_Probe]s (host widgets) injected into a buildNode composition, and
/// can reverse their order on demand.
class _Harness extends StatefulWidget {
  const _Harness({required this.runtime});
  final Runtime runtime;
  @override
  State<_Harness> createState() => _HarnessState();
}

class _HarnessState extends State<_Harness> {
  bool _reversed = false;
  void reverse() => setState(() => _reversed = true);

  @override
  Widget build(BuildContext context) {
    final List<Widget> probes = <Widget>[
      const _Probe(key: ValueKey<String>('a'), label: 'A'),
      const _Probe(key: ValueKey<String>('b'), label: 'B'),
    ];
    final ConstructorCall composition =
        ConstructorCall('Column', <String, Object?>{
      'children': _reversed ? probes.reversed.toList() : probes,
    });
    return widget.runtime.buildNode(
      context,
      composition,
      DynamicContent(),
      _noEvents,
      scope: _core,
    );
  }
}

void main() {
  testWidgets('buildNode renders an ad-hoc composition of predefined widgets', (
    WidgetTester tester,
  ) async {
    final Runtime runtime = Runtime()..update(_core, createCoreComponents());

    final ConstructorCall composition =
        ConstructorCall('Column', <String, Object?>{
      'children': <Object?>[
        ConstructorCall('Text', <String, Object?>{'text': 'hi'}),
      ],
    });

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (BuildContext context) => runtime.buildNode(
            context,
            composition,
            DynamicContent(),
            _noEvents,
            scope: _core,
          ),
        ),
      ),
    );

    expect(find.text('hi'), findsOneWidget);
  });

  testWidgets('injected host widgets keep their key across reorder', (
    WidgetTester tester,
  ) async {
    _probeCreations = 0;
    final Runtime runtime = Runtime()..update(_core, createCoreComponents());

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: _Harness(runtime: runtime),
      ),
    );

    expect(find.text('A#0'), findsOneWidget);
    expect(find.text('B#1'), findsOneWidget);

    tester.state<_HarnessState>(find.byType(_Harness)).reverse();
    await tester.pump();

    // The order actually changed AND each probe's state followed its key:
    // B (id 1) is now first, A (id 0) second — no probe was recreated.
    final List<String?> texts = tester
        .widgetList<Text>(find.byType(Text))
        .map((Text t) => t.data)
        .toList();
    expect(texts, <String>['B#1', 'A#0']);
  });
}
