// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

// Verifies M1 (DESIGN.md §6): the runtime lifts a reserved literal `key`
// argument onto the reconciliation unit, so a keyed remote-component subtree
// preserves its state when its position among siblings changes.
//
// `_Probe` records a creation-order id in `initState` and renders `label#id`.
// If the state follows the key across a reorder, the ids stay attached to their
// labels; under positional reconciliation they would swap.

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

LocalComponentLibrary _testComponents() {
  return LocalComponentLibrary(<String, LocalComponentBuilder>{
    'Column': (BuildContext context, DataSource source) => div(
          styles: Styles.flexbox(direction: FlexDirection.column),
          source.childList(['children']),
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
  testComponents('keyed children preserve state across reorder', (
    ComponentTester tester,
  ) async {
    _probeCreations = 0;
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['test']), _testComponents())
      ..update(const LibraryName(<String>['main']), parseLibraryFile(_ab));

    tester.pumpComponent(
      RemoteComponent(
        runtime: runtime,
        component: const FullyQualifiedWidgetName(
          LibraryName(<String>['main']),
          'root',
        ),
        data: DynamicContent(),
      ),
    );
    await tester.pump();

    expect(find.text('A#0'), findsOneComponent);
    expect(find.text('B#1'), findsOneComponent);

    // Reorder the (keyed) children.
    runtime.update(const LibraryName(<String>['main']), parseLibraryFile(_ba));
    await tester.pump();

    // State followed the key: B keeps id 1, A keeps id 0, no probe recreated.
    expect(find.text('B#1'), findsOneComponent);
    expect(find.text('A#0'), findsOneComponent);
    // Positional (unkeyed) reconciliation would instead produce these:
    expect(find.text('B#0'), findsNothing);
    expect(find.text('A#1'), findsNothing);
  });
}
