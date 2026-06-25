// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

/// The high-level demo catalog used by [runA2uiConformance], authored as RFW
/// templates over the low-level `core` library. A2UI components reference these
/// names; each template maps the component's props (`args`) onto the low-level
/// catalog. Adapters parse this with `parseLibraryFile` and register it under
/// [a2uiDemoCatalogName], then render A2UI components with that as their scope.
const String a2uiDemoCatalogSource = '''
import core;

widget Label = Text(text: args.text);

widget Stack = Column(children: args.children);

widget Tappable = Button(onPressed: args.action, child: Text(text: args.label));
''';

/// The library name under which [a2uiDemoCatalogSource] is registered.
const LibraryName a2uiDemoCatalogName = LibraryName(<String>['catalog']);

/// The `a2ui_core` catalog id that A2UI `createSurface` messages reference.
const String a2uiDemoCatalogId = 'demo';

/// The `a2ui_core` component schemas mirroring [a2uiDemoCatalogSource]. These
/// drive `GenericBinder`'s behavior scraping (which prop is data-bound, an
/// action, or a structural child list).
class _LabelApi extends ComponentApi {
  @override
  String get name => 'Label';
  @override
  Schema get schema => Schema.object(
        properties: {'text': CommonSchemas.dynamicString},
        required: ['text'],
      );
}

class _StackApi extends ComponentApi {
  @override
  String get name => 'Stack';
  @override
  Schema get schema => Schema.object(
        properties: {'children': CommonSchemas.childList},
        required: ['children'],
      );
}

class _TappableApi extends ComponentApi {
  @override
  String get name => 'Tappable';
  @override
  Schema get schema => Schema.object(
        properties: {
          'label': CommonSchemas.dynamicString,
          'action': CommonSchemas.action,
        },
        required: ['label', 'action'],
      );
}

/// Builds the `a2ui_core` demo catalog (matching [a2uiDemoCatalogSource]).
Catalog<ComponentApi> a2uiDemoCatalog() => Catalog<ComponentApi>(
      id: a2uiDemoCatalogId,
      components: [_StackApi(), _LabelApi(), _TappableApi()],
    );

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

  /// Creates a framework-specific adapter for the A2UI component [id] in
  /// [surface], rendering it against the demo catalog ([a2uiDemoCatalogName]).
  Object buildAdapter(SurfaceModel<ComponentApi> surface, String id);

  /// Renders a host component directly (e.g. an `A2uiToRfwAdapter`).
  Future<void> mountComponent(Object component);
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

  /// Builds a fresh `a2ui_core` processor over the demo catalog, applies
  /// [messages], and returns the processor paired with its surface (id
  /// [surfaceId]). Follow-up messages go through `processor.processMessages`, so
  /// tests exercise the real A2UI message path.
  (MessageProcessor<ComponentApi>, SurfaceModel<ComponentApi>) applyA2ui(
    List<A2uiMessage> messages, {
    String surfaceId = 'conformance',
  }) {
    final MessageProcessor<ComponentApi> processor =
        MessageProcessor<ComponentApi>(catalogs: [a2uiDemoCatalog()]);
    processor.processMessages(messages);
    return (processor, processor.groupModel.getSurface(surfaceId)!);
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

  driver.defineTest('Center and SizedBox provide layout constraints', (
    CraftTester tester,
  ) async {
    await tester.mount('''
      import core;
      widget root = Center(
        child: SizedBox(
          width: 100.0,
          height: 100.0,
          child: Text(text: "centered"),
        ),
      );
    ''');

    expect(tester.hasText('centered'), isTrue);
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
/// end-to-end: A2UI messages → `a2ui_core` (`MessageProcessor` + `GenericBinder`)
/// → the per-id `A2uiToRfwAdapter` tree → the engine.
///
/// Proves the same A2UI surface behaves identically on every framework. Like
/// [runCoreComponentConformance], every adapter runs this against its own
/// renderer.
void runA2uiConformance(CraftConformanceDriver driver) {
  driver.defineTest(
    'A2UI surface renders text, bindings, a list, and dispatches events',
    (CraftTester tester) async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = tester.applyA2ui(_counterMessages());
      final List<String> dispatched = <String>[];
      surface.onAction
          .addListener((A2uiClientAction a) => dispatched.add(a.name));

      await tester.mountComponent(tester.buildAdapter(surface, 'root'));

      // Literal, absolute data binding, list items, and the button label.
      expect(tester.hasText('Hello'), isTrue);
      expect(tester.hasText('Ada'), isTrue);
      expect(tester.hasText('a'), isTrue);
      expect(tester.hasText('b'), isTrue);
      expect(tester.hasText('Go'), isTrue);

      // The Button is located by its A2UI id (the host adapter keys itself by
      // that id). a2ui_core resolves the action and dispatches it.
      expect(dispatched, isEmpty);
      await tester.activate('btn');
      expect(dispatched, <String>['go']);

      // An updateDataModel message re-renders the bound text.
      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
            surfaceId: 'conformance', path: '/name', value: 'Grace'),
      ]);
      await tester.pump();
      expect(tester.hasText('Ada'), isFalse);
      expect(tester.hasText('Grace'), isTrue);
    },
  );

  driver.defineTest(
    'updateComponents updates a single component in place',
    (CraftTester tester) async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = tester.applyA2ui(_counterMessages());
      await tester.mountComponent(tester.buildAdapter(surface, 'root'));

      expect(tester.hasText('Hello'), isTrue);

      // A follow-up updateComponents that touches only `title` by id.
      processor.processMessages(<A2uiMessage>[
        UpdateComponentsMessage(
          surfaceId: 'conformance',
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'title',
              'component': 'Label',
              'text': 'Hi'
            },
          ],
        ),
      ]);
      await tester.pump();

      // The targeted component re-renders; its siblings are untouched.
      expect(tester.hasText('Hello'), isFalse);
      expect(tester.hasText('Hi'), isTrue);
      expect(tester.hasText('Ada'), isTrue);
      expect(tester.hasText('a'), isTrue);
      expect(tester.hasText('Go'), isTrue);
    },
  );

  driver.defineTest(
    "updateComponents replaces a container's children",
    (CraftTester tester) async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = tester.applyA2ui(_counterMessages());
      await tester.mountComponent(tester.buildAdapter(surface, 'root'));

      expect(tester.hasText('Ada'), isTrue); // greeting
      expect(tester.hasText('a'), isTrue); // list item

      // A follow-up updateComponents that re-points root at a different,
      // reordered subset of children. Dropped children must unmount.
      processor.processMessages(<A2uiMessage>[
        UpdateComponentsMessage(
          surfaceId: 'conformance',
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'Stack',
              'children': <Object?>['btn', 'title'],
            },
          ],
        ),
      ]);
      await tester.pump();

      // Surviving children still render...
      expect(tester.hasText('Go'), isTrue); // btn label
      expect(tester.hasText('Hello'), isTrue); // title
      // ...and dropped children are gone.
      expect(tester.hasText('Ada'), isFalse); // greeting removed
      expect(tester.hasText('a'), isFalse); // list removed
      expect(tester.hasText('b'), isFalse);
    },
  );

  driver.defineTest(
    'a data-driven list grows and shrinks with its data array',
    (CraftTester tester) async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = tester.applyA2ui(_counterMessages());
      await tester.mountComponent(tester.buildAdapter(surface, 'root'));

      expect(tester.hasText('a'), isTrue);
      expect(tester.hasText('b'), isTrue);
      expect(tester.hasText('c'), isFalse);

      // Replace the array with a longer one: a new item appears.
      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: 'conformance',
          path: '/items',
          value: <Object?>[
            <String, Object?>{'label': 'a'},
            <String, Object?>{'label': 'b'},
            <String, Object?>{'label': 'c'},
          ],
        ),
      ]);
      await tester.pump();
      expect(tester.hasText('c'), isTrue);

      // Replace with a shorter one: trailing items disappear.
      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
          surfaceId: 'conformance',
          path: '/items',
          value: <Object?>[
            <String, Object?>{'label': 'a'},
          ],
        ),
      ]);
      await tester.pump();
      expect(tester.hasText('a'), isTrue);
      expect(tester.hasText('b'), isFalse);
      expect(tester.hasText('c'), isFalse);
    },
  );

  driver.defineTest(
    'updateDataModel into a list item updates just that row',
    (CraftTester tester) async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = tester.applyA2ui(_counterMessages());
      await tester.mountComponent(tester.buildAdapter(surface, 'root'));

      expect(tester.hasText('a'), isTrue);
      expect(tester.hasText('b'), isTrue);

      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(
            surfaceId: 'conformance', path: '/items/0/label', value: 'A1'),
      ]);
      await tester.pump();

      expect(tester.hasText('a'), isFalse);
      expect(tester.hasText('A1'), isTrue);
      expect(tester.hasText('b'), isTrue); // the other row is untouched
    },
  );

  driver.defineTest(
    'a nested ChildList scopes each inner loop to its outer item',
    (CraftTester tester) async {
      final (_, SurfaceModel<ComponentApi> surface) = tester.applyA2ui(
        <A2uiMessage>[
          CreateSurfaceMessage(surfaceId: 'conformance', catalogId: 'demo'),
          UpdateDataModelMessage(
            surfaceId: 'conformance',
            path: '/',
            value: <String, Object?>{
              'groups': <Object?>[
                <String, Object?>{
                  'members': <Object?>[
                    <String, Object?>{'name': 'alice'},
                    <String, Object?>{'name': 'bob'},
                  ],
                },
                <String, Object?>{
                  'members': <Object?>[
                    <String, Object?>{'name': 'carol'},
                  ],
                },
              ],
            },
          ),
          UpdateComponentsMessage(
            surfaceId: 'conformance',
            components: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'root',
                'component': 'Stack',
                'children': <String, dynamic>{
                  'path': '/groups',
                  'componentId': 'group',
                },
              },
              <String, dynamic>{
                'id': 'group',
                'component': 'Stack',
                'children': <String, dynamic>{
                  'path': 'members',
                  'componentId': 'member',
                },
              },
              <String, dynamic>{
                'id': 'member',
                'component': 'Label',
                'text': <String, dynamic>{'path': 'name'},
              },
            ],
          ),
        ],
      );
      await tester.mountComponent(tester.buildAdapter(surface, 'root'));

      expect(tester.hasText('alice'), isTrue);
      expect(tester.hasText('bob'), isTrue);
      expect(tester.hasText('carol'), isTrue);
    },
  );
}

/// The shared "counter" surface as a2ui_core messages: createSurface, seed the
/// data model, then a static tree (title/greeting/list/btn) plus a data-driven
/// list of `itemTmpl`.
List<A2uiMessage> _counterMessages() => <A2uiMessage>[
      CreateSurfaceMessage(surfaceId: 'conformance', catalogId: 'demo'),
      UpdateDataModelMessage(
        surfaceId: 'conformance',
        path: '/',
        value: <String, Object?>{
          'name': 'Ada',
          'items': <Object?>[
            <String, Object?>{'label': 'a'},
            <String, Object?>{'label': 'b'},
          ],
        },
      ),
      UpdateComponentsMessage(
        surfaceId: 'conformance',
        components: <Map<String, dynamic>>[
          <String, dynamic>{
            'id': 'root',
            'component': 'Stack',
            'children': <Object?>['title', 'greeting', 'list', 'btn'],
          },
          <String, dynamic>{
            'id': 'title',
            'component': 'Label',
            'text': 'Hello'
          },
          <String, dynamic>{
            'id': 'greeting',
            'component': 'Label',
            'text': <String, dynamic>{'path': '/name'},
          },
          <String, dynamic>{
            'id': 'list',
            'component': 'Stack',
            'children': <String, dynamic>{
              'path': '/items',
              'componentId': 'itemTmpl',
            },
          },
          <String, dynamic>{
            'id': 'itemTmpl',
            'component': 'Label',
            'text': <String, dynamic>{'path': 'label'},
          },
          <String, dynamic>{
            'id': 'btn',
            'component': 'Tappable',
            'label': 'Go',
            'action': <String, dynamic>{
              'event': <String, dynamic>{
                'name': 'go',
                'context': <String, dynamic>{}
              },
            },
          },
        ],
      ),
    ];
