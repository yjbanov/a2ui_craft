// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:json_schema_builder/json_schema_builder.dart';
import 'package:test/test.dart';

/// The demo **catalog** used by [runA2uiConformance], authored as RFW templates
/// over the `core` primitives. A2UI components reference these names; each
/// template maps the component's props (`args`) onto the primitives. Adapters
/// parse this with `parseLibraryFile` and register it under
/// [a2uiDemoCatalogName], then render A2UI components with that as their scope.
const String a2uiDemoCatalogSource = '''
import core;

widget Label = Text(text: args.text);

widget Stack = Column(children: args.children);

widget Tappable = Button(onPressed: args.action, child: Text(text: args.label));

widget Check = Checkbox(value: args.value, onChanged: args.setValue);
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

class _CheckApi extends ComponentApi {
  @override
  String get name => 'Check';
  @override
  Schema get schema => Schema.object(
        properties: {'value': CommonSchemas.dynamicBoolean},
        required: ['value'],
      );
}

/// Builds the `a2ui_core` demo catalog (matching [a2uiDemoCatalogSource]).
Catalog<ComponentApi> a2uiDemoCatalog() => Catalog<ComponentApi>(
      id: a2uiDemoCatalogId,
      components: [_StackApi(), _LabelApi(), _TappableApi(), _CheckApi()],
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

  /// Toggles the (single) rendered checkbox, as a user click would.
  Future<void> toggleCheckbox();

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

  driver.defineTest(
    'Heading renders its text (default level and an explicit level)',
    (CraftTester tester) async {
      // Heading is a distinct primitive (a real heading role + level for
      // assistive tech), defaulting to level 1; the level is author-set.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Heading(text: "Top Heading"),
          Heading(text: "Subsection", level: 2),
        ]);
      ''');

      expect(tester.hasText('Top Heading'), isTrue); // default level 1
      expect(tester.hasText('Subsection'), isTrue); // explicit level 2
    },
  );

  driver.defineTest(
    'Markdown renders headings, a styled paragraph, and list items',
    (CraftTester tester) async {
      // The Markdown source is passed via the data model (real newlines) rather
      // than a template literal. Each asserted block is a *single* styled run, so
      // it renders as one discrete text node on both adapters (a heading, an
      // all-bold paragraph, and plain list items).
      final DynamicContent data = DynamicContent();
      data.update('md',
          '# Heading One\n\n**BoldPara**\n\n- Item A\n- Item B\n\n1. First');
      await tester.mount('''
        import core;
        widget root = Markdown(text: data.md);
      ''', data: data);

      expect(tester.hasText('Heading One'), isTrue); // # heading
      expect(tester.hasText('BoldPara'), isTrue); // **bold** paragraph
      expect(tester.hasText('Item A'), isTrue); // unordered item
      expect(tester.hasText('Item B'), isTrue);
      expect(tester.hasText('First'), isTrue); // ordered item
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

  driver.defineTest('Box renders its child through size, padding, and color', (
    CraftTester tester,
  ) async {
    // A fast behavioral smoke test (geometry is covered separately by
    // runBoxGeometryConformance): a fully-configured Box still renders its child.
    await tester.mount('''
      import core;
      widget root = Box(
        width: 80.0, height: 80.0,
        padding: [8.0, 8.0, 8.0, 8.0],
        margin: [4.0, 4.0, 4.0, 4.0],
        color: "#3366cc",
        child: Text(text: "inside"),
      );
    ''');

    expect(tester.hasText('inside'), isTrue);
  });

  driver.defineTest('Atoms render: Text variants, Image, Icon, Divider, List', (
    CraftTester tester,
  ) async {
    // A behavioral smoke test for the atoms slice (geometry is covered by
    // runAtomGeometryConformance): the atoms mount inside a List and their text
    // renders. Image uses an example.com URL, which renders a placeholder.
    await tester.mount('''
      import core;
      widget root = List(direction: "vertical", children: [
        Text(text: "headline"),
        Text(text: "secondary", variant: "caption"),
        Image(url: "https://example.com/a.png", variant: "avatar"),
        Icon(icon: "phone"),
        Divider(),
        Text(text: "footer"),
      ]);
    ''');

    expect(tester.hasText('headline'), isTrue);
    expect(tester.hasText('secondary'), isTrue);
    expect(tester.hasText('footer'), isTrue);
  });

  driver.defineTest('ScrollView and Card render their nested child content', (
    CraftTester tester,
  ) async {
    // ScrollView and Card are single-child containers. Assert the child subtree
    // actually renders *through* them — not merely "doesn't crash".
    // (Image/Icon/Divider are covered by the atoms case above.)
    await tester.mount('''
      import core;
      widget root = ScrollView(
        child: Card(
          child: Column(
            children: [
              Text(text: "card body"),
              Divider(),
            ],
          ),
        ),
      );
    ''');

    expect(tester.hasText('card body'), isTrue);
  });

  driver
      .defineTest('Align, AspectRatio, Wrap, and Opacity render their children',
          (CraftTester tester) async {
    // A behavioral smoke test for the layout-depth primitives (geometry is
    // covered by runLayoutGeometryConformance): each wraps a child whose text
    // must remain visible through it.
    await tester.mount('''
      import core;
      widget root = Column(children: [
        Align(alignment: "bottomRight", width: 80.0, height: 40.0,
          child: Text(text: "aligned")),
        AspectRatio(ratio: 2.0, child: Text(text: "ratio")),
        Wrap(gap: 8.0, children: [
          Text(text: "w1"),
          Text(text: "w2"),
          Text(text: "w3"),
        ]),
        Opacity(opacity: 0.5, child: Text(text: "faded")),
      ]);
    ''');

    expect(tester.hasText('aligned'), isTrue);
    expect(tester.hasText('ratio'), isTrue);
    expect(tester.hasText('w1'), isTrue);
    expect(tester.hasText('w3'), isTrue);
    expect(tester.hasText('faded'), isTrue);
  });

  driver.defineTest('TextField and Checkbox mount; the label is templatized', (
    CraftTester tester,
  ) async {
    final DynamicContent data = DynamicContent();
    data.update('name', 'Ada');
    data.update('agree', true);
    // The TextField primitive is the bare input — no label. A label is a
    // template's choice, composed as a sibling Text (DESIGN.md §2 / §11).
    await tester.mount('''
      import core;
      widget root = Column(children: [
        Text(text: "Your name"),
        TextField(value: data.name),
        Checkbox(value: data.agree),
      ]);
    ''', data: data);

    // The templatized label renders; the field and checkbox mount.
    expect(tester.hasText('Your name'), isTrue);
  });

  driver.defineTest('Radio reflects selection and fires its event on tap', (
    CraftTester tester,
  ) async {
    final List<String> dispatched = <String>[];
    await tester.mount('''
      import core;
      widget root = Radio(key: "r", selected: false, onChanged: event "picked" {});
    ''', onEvent: (String name, DynamicMap arguments) => dispatched.add(name));

    expect(dispatched, isEmpty);
    await tester.activate('r');
    expect(dispatched, <String>['picked']);
  });

  driver.defineTest('Slider mounts with its bound value', (
    CraftTester tester,
  ) async {
    final DynamicContent data = DynamicContent();
    data.update('volume', 0.5);
    await tester.mount('''
      import core;
      widget root = Slider(value: data.volume, min: 0.0, max: 1.0, steps: 10);
    ''', data: data);
    // The bare slider mounts and binds without crashing.
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

  driver.defineTest(
    'a stateful template toggles its own UI on tap (no host code)',
    (CraftTester tester) async {
      // Pure-template interactivity: the widget declares local `state`, a tap
      // flips it via `set state.x = switch ...` (there is no `!` operator), and
      // `switch state.x` re-renders. No host/data-model involvement — this is
      // the RFW state axis, and it must behave identically on every adapter.
      await tester.mount('''
        import core;
        widget root { open: false } = Column(crossAxisAlignment: "start", children: [
          Button(
            key: "toggle",
            onPressed: set state.open = switch state.open { true: false, default: true },
            child: Text(text: switch state.open { true: "Hide", default: "Show" }),
          ),
          Text(text: switch state.open { true: "DETAILS", default: "" }),
        ]);
      ''');

      // Closed initially.
      expect(tester.hasText('Show'), isTrue);
      expect(tester.hasText('Hide'), isFalse);
      expect(tester.textCount('DETAILS'), 0);

      // Tap opens it — the template rebuilds from its own state.
      await tester.activate('toggle');
      expect(tester.hasText('Hide'), isTrue);
      expect(tester.hasText('Show'), isFalse);
      expect(tester.textCount('DETAILS'), 1);

      // Tap again closes it.
      await tester.activate('toggle');
      expect(tester.hasText('Show'), isTrue);
      expect(tester.textCount('DETAILS'), 0);
    },
  );

  driver.defineTest(
    'a pure function call computes a value in a value position (and stays total)',
    (CraftTester tester) async {
      // Function calls reuse the `name(arg: …)` call syntax that also builds
      // widgets; a name registered as a standard function (here `add`) is
      // evaluated in any value position instead of built. The numeric result
      // flows into a Text sink, which coerces it to its string form. Both
      // adapters register the identical standard function library, so the
      // computed values — and totality on bad input — must match.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: add(a: 2, b: 3)),
          Text(text: add(a: add(a: 10, b: 5), b: 100)),
          Text(text: add(a: "not a number", b: 3)),
        ]);
      ''');

      expect(tester.hasText('5'), isTrue); // 2 + 3
      expect(tester.hasText('115'), isTrue); // nested: (10 + 5) + 100
      // Total: a non-numeric operand yields null → an absent (empty) text, not a
      // thrown exception, and the bad input is not rendered.
      expect(tester.hasText('not a number'), isFalse);
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

  driver.defineTest(
    'a two-way Checkbox writes its bound value back to the data model',
    (CraftTester tester) async {
      final (_, SurfaceModel<ComponentApi> surface) = tester.applyA2ui(
        <A2uiMessage>[
          CreateSurfaceMessage(surfaceId: 'conformance', catalogId: 'demo'),
          UpdateDataModelMessage(
            surfaceId: 'conformance',
            path: '/',
            value: <String, Object?>{'agree': false},
          ),
          UpdateComponentsMessage(
            surfaceId: 'conformance',
            components: <Map<String, dynamic>>[
              <String, dynamic>{
                'id': 'root',
                'component': 'Check',
                'value': <String, dynamic>{'path': '/agree'},
              },
            ],
          ),
        ],
      );
      await tester.mountComponent(tester.buildAdapter(surface, 'root'));

      // a2ui_core resolved a `setValue` for the bound `value`; the template
      // wired it to the checkbox's `onChanged`, so toggling writes it back.
      expect(surface.dataModel.get('/agree'), false);
      await tester.toggleCheckbox();
      expect(surface.dataModel.get('/agree'), true);
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
