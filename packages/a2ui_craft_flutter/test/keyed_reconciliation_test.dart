// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// Verifies M1 (DESIGN.md §6): the runtime lifts a reserved literal `key`
// argument onto the reconciliation unit, so a keyed remote-widget subtree
// preserves its state when its position among siblings changes.
//
// `_Probe` records a creation-order id in `initState` and renders `label#id`.
// If the state follows the key across a reorder, the ids stay attached to their
// labels; under positional reconciliation they would swap.

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

LocalWidgetLibrary _testComponents() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'Column': (BuildContext context, DataSource source) => Column(
          mainAxisSize: MainAxisSize.min,
          children: source.childList(['children']),
        ),
    'Probe': (BuildContext context, DataSource source) =>
        _Probe(label: source.v<String>(['label']) ?? ''),
  });
}

const String _ab = '''
  import test;
  widget root = Column(children: [
    Probe(key: "a", label: "A"),
    Probe(key: "b", label: "B"),
  ]);
''';

const String _ba = '''
  import test;
  widget root = Column(children: [
    Probe(key: "b", label: "B"),
    Probe(key: "a", label: "A"),
  ]);
''';

void main() {
  testWidgets('keyed children preserve state across reorder', (
    WidgetTester tester,
  ) async {
    _probeCreations = 0;
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['test']), _testComponents())
      ..update(const LibraryName(<String>['main']), parseLibraryFile(_ab));

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: RemoteWidget(
          runtime: runtime,
          widget: const FullyQualifiedWidgetName(
            LibraryName(<String>['main']),
            'root',
          ),
          data: DynamicContent(),
        ),
      ),
    );

    expect(find.text('A#0'), findsOneWidget);
    expect(find.text('B#1'), findsOneWidget);

    // Reorder the (keyed) children.
    runtime.update(const LibraryName(<String>['main']), parseLibraryFile(_ba));
    await tester.pump();

    // State followed the key: B keeps id 1, A keeps id 0, no probe recreated.
    expect(find.text('B#1'), findsOneWidget);
    expect(find.text('A#0'), findsOneWidget);
    // Positional (unkeyed) reconciliation would instead produce these:
    expect(find.text('B#0'), findsNothing);
    expect(find.text('A#1'), findsNothing);
  });
}
