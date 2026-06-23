// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:test/test.dart';

/// Framework-neutral signature for an event dispatched by a rendered component.
///
/// Mirrors each adapter's `RemoteEventHandler` (which this package cannot name
/// directly, since that type lives in the per-framework adapters).
typedef CraftEventHandler = void Function(String name, DynamicMap arguments);

/// A framework-neutral handle to a *mounted* A2UI Craft surface.
///
/// Each adapter implements this by wrapping its own test driver (e.g. Flutter's
/// `WidgetTester`, Jaspr's `ComponentTester`) and its own `Runtime`. The
/// conformance suite then drives behavior through this interface only, so the
/// exact same expectations run against every framework.
///
/// The probes are deliberately *behavioral*, not pixel- or structure-based:
/// "is this text visible?", "did activating this control fire its event?".
/// Behavioral identity across frameworks is the goal; pixel identity is not.
abstract interface class CraftTester {
  /// Renders [main]'s `root` component (with the core component library
  /// available as `core`), bound to [data], routing events to [onEvent].
  ///
  /// This is the primitive; [CraftTesterQueries.mount] is a convenience that
  /// parses an RFW template into a library first.
  Future<void> mountLibrary(
    RemoteWidgetLibrary main, {
    DynamicContent? data,
    CraftEventHandler? onEvent,
  });

  /// Processes pending frames after an out-of-band change (e.g. a [data] update).
  Future<void> pump();

  /// The number of currently displayed text nodes whose content equals [text].
  int textCount(String text);

  /// Activates (taps/clicks) the interactive element carrying the given
  /// component `key`.
  Future<void> activate(String key);
}

/// Convenience queries and entry points layered on the minimal [CraftTester]
/// surface.
extension CraftTesterQueries on CraftTester {
  /// Whether any displayed text node equals [text].
  bool hasText(String text) => textCount(text) > 0;

  /// Parses [template] as the `main` library and renders its `root` component.
  Future<void> mount(
    String template, {
    DynamicContent? data,
    CraftEventHandler? onEvent,
  }) {
    return mountLibrary(parseLibraryFile(template),
        data: data, onEvent: onEvent);
  }
}

/// Registers conformance test cases with a framework's test runner.
///
/// Adapters implement this using their native registration function
/// (`testWidgets`, `testComponents`, …), constructing a [CraftTester] for each
/// case and passing it to [body].
abstract interface class CraftConformanceDriver {
  void defineTest(
    String description,
    Future<void> Function(CraftTester tester) body,
  );
}

/// The shared behavioral specification for the core component library.
///
/// Every adapter calls this with its own [CraftConformanceDriver]; passing this
/// suite proves the adapter renders and behaves like all the others. To cover a
/// new core component or behavior, add a case here — never in a single adapter's
/// tests.
void runCoreComponentConformance(CraftConformanceDriver driver) {
  driver.defineTest(
    'Text renders literal and data-bound values, and updates reactively',
    (CraftTester tester) async {
      final DynamicContent data = DynamicContent();
      data.update('name', 'Ada');
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: "Hello"),
          Text(text: data.name),
        ]);
      ''', data: data);

      expect(tester.hasText('Hello'), isTrue);
      expect(tester.hasText('Ada'), isTrue);

      data.update('name', 'Grace');
      await tester.pump();
      expect(tester.hasText('Ada'), isFalse);
      expect(tester.hasText('Grace'), isTrue);
    },
  );

  driver.defineTest('Row and Column render their children', (
    CraftTester tester,
  ) async {
    await tester.mount('''
      import core;
      widget root = Column(children: [
        Text(text: "top"),
        Row(children: [
          Text(text: "left"),
          Text(text: "right"),
        ]),
      ]);
    ''');

    expect(tester.hasText('top'), isTrue);
    expect(tester.hasText('left'), isTrue);
    expect(tester.hasText('right'), isTrue);
  });

  driver.defineTest('Button dispatches its event only when activated', (
    CraftTester tester,
  ) async {
    final List<String> dispatched = <String>[];
    await tester.mount('''
      import core;
      widget root = Button(
        key: "act",
        onPressed: event "pressed" {},
        child: Text(text: "Go"),
      );
    ''', onEvent: (String name, DynamicMap arguments) => dispatched.add(name));

    expect(dispatched, isEmpty);

    await tester.activate('act');
    expect(dispatched, <String>['pressed']);
  });

  driver.defineTest(
    '...for renders one child per data item and reacts to changes',
    (CraftTester tester) async {
      final DynamicContent data = DynamicContent();
      data.update('items', <Object?>['a', 'b', 'c']);
      await tester.mount('''
        import core;
        widget root = Column(children: [
          ...for item in data.items: Text(text: item),
        ]);
      ''', data: data);

      expect(tester.textCount('a'), 1);
      expect(tester.textCount('b'), 1);
      expect(tester.textCount('c'), 1);
      expect(tester.hasText('d'), isFalse);

      data.update('items', <Object?>['a', 'b', 'c', 'd']);
      await tester.pump();
      expect(tester.hasText('d'), isTrue);
      expect(tester.textCount('a'), 1);
    },
  );
}

/// The shared behavioral specification for rendering an **A2UI surface**
/// end-to-end: A2UI Transport messages → `A2uiSurface` → the engine.
///
/// Proves the same A2UI surface behaves identically on every framework. Like
/// [runCoreComponentConformance], every adapter runs this against its own
/// renderer.
void runA2uiConformance(CraftConformanceDriver driver) {
  driver.defineTest(
    'A2UI surface renders text, bindings, a list, and dispatches events',
    (CraftTester tester) async {
      final A2uiSurface surface = A2uiSurface()..apply(_a2uiCounterSurface());
      final List<String> dispatched = <String>[];
      await tester.mountLibrary(
        surface.library,
        data: surface.data,
        onEvent: (String name, DynamicMap arguments) => dispatched.add(name),
      );

      // Literal, absolute data binding, list items, and the button label.
      expect(tester.hasText('Hello'), isTrue);
      expect(tester.hasText('Ada'), isTrue);
      expect(tester.hasText('a'), isTrue);
      expect(tester.hasText('b'), isTrue);
      expect(tester.hasText('Go'), isTrue);

      // The Button is located by its A2UI id (carried through as the key).
      expect(dispatched, isEmpty);
      await tester.activate('btn');
      expect(dispatched, <String>['go']);

      // An updateDataModel message re-renders the bound text.
      surface.apply(<String, Object?>{
        'updateDataModel': <String, Object?>{'path': '/name', 'value': 'Grace'},
      });
      await tester.pump();
      expect(tester.hasText('Ada'), isFalse);
      expect(tester.hasText('Grace'), isTrue);
    },
  );
}

Map<String, Object?> _a2uiCounterSurface() => <String, Object?>{
      'createSurface': <String, Object?>{
        'surfaceId': 'conformance',
        'components': <Object?>[
          <String, Object?>{
            'id': 'root',
            'component': 'Column',
            'children': <Object?>['title', 'greeting', 'list', 'btn'],
          },
          <String, Object?>{
            'id': 'title',
            'component': 'Text',
            'text': 'Hello'
          },
          <String, Object?>{
            'id': 'greeting',
            'component': 'Text',
            'text': <String, Object?>{'path': '/name'},
          },
          <String, Object?>{
            'id': 'list',
            'component': 'Column',
            'children': <String, Object?>{
              'path': '/items',
              'componentId': 'itemTmpl',
            },
          },
          <String, Object?>{
            'id': 'itemTmpl',
            'component': 'Text',
            'text': <String, Object?>{'path': 'label'},
          },
          <String, Object?>{
            'id': 'btn',
            'component': 'Button',
            'child': 'btnLabel',
            'action': <String, Object?>{
              'event': <String, Object?>{
                'name': 'go',
                'context': <String, Object?>{}
              },
            },
          },
          <String, Object?>{
            'id': 'btnLabel',
            'component': 'Text',
            'text': 'Go'
          },
        ],
        'dataModel': <String, Object?>{
          'name': 'Ada',
          'items': <Object?>[
            <String, Object?>{'label': 'a'},
            <String, Object?>{'label': 'b'},
          ],
        },
      },
    };
