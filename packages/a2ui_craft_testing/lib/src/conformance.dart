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
  /// available as `core`), bound to [data], themed by [theme] (an immutable
  /// resolved-token snapshot), routing events to [onEvent].
  ///
  /// This is the primitive; [CraftTesterQueries.mount] is a convenience that
  /// parses an RFW template into a library first.
  Future<void> mountLibrary(
    RemoteWidgetLibrary main, {
    DynamicContent? data,
    CraftTheme? theme,
    CraftEventHandler? onEvent,
  });

  /// Replaces the ambient theme of the currently mounted surface with a new
  /// snapshot, exactly as a host flipping a mode would — **without
  /// remounting**: element state must survive and live `theme.` references
  /// must re-resolve in place.
  Future<void> retheme(CraftTheme? theme);

  /// Processes pending frames after an out-of-band change (e.g. a [data] update).
  Future<void> pump();

  /// The number of currently displayed text nodes whose content equals [text].
  int textCount(String text);

  /// The number of elements exposing a **button role** to assistive technology
  /// whose accessible name is [label] — Flutter: semantics nodes flagged as
  /// buttons; Jaspr: rendered `<button>` elements. Plain text never counts;
  /// this probes the accessibility contract, not the visuals.
  int buttonCount(String label);

  /// The foreground color the primitive **explicitly set** on the (unique)
  /// displayed text node equal to [text], canonicalized to `#AARRGGBB` — or
  /// null when the primitive set none and the host default shows through.
  ///
  /// The painted-decision probe of the theming-conformance dimension (§9.6):
  /// it asserts a token *landed* on the primitive identically on every
  /// adapter, never pixel equality.
  String? textColorOf(String text);

  /// The font size (logical px / CSS px) the primitive explicitly set on the
  /// text node equal to [text], or null when the host default shows through.
  double? textFontSizeOf(String text);

  /// The surface color (layer 1 of the control paint model, DESIGN.md §8)
  /// the `Button` whose accessible name is [label] painted, canonicalized to
  /// `#AARRGGBB` — or null when the button paints no surface (the transparent
  /// "text button" case).
  ///
  /// Like [textColorOf], this probes the decision the primitive made (the
  /// role mapping: the same role inks the same part to the same degree on
  /// every adapter), never pixels.
  String? buttonSurfaceColorOf(String label);

  /// The **fill** of the nearest container painting a background above the
  /// displayed text node equal to [text] (a `Card`'s surface), canonicalized to
  /// `#AARRGGBB`, or null when none paints a fill.
  ///
  /// The container analogue of [buttonSurfaceColorOf]: the painted-decision
  /// probe (§9.6) for surface primitives, asserting `color.surface` lands the
  /// same on every adapter, never pixels.
  String? surfaceColorOf(String text);

  /// The **border color** of the nearest container drawing a border above the
  /// displayed text node equal to [text] (a `Card`'s outline), canonicalized to
  /// `#AARRGGBB`, or null when none draws a border. The painted-decision probe
  /// for `color.outline` on a container.
  String? borderColorOf(String text);

  /// Activates (taps/clicks) the interactive element carrying the given
  /// component `key`.
  Future<void> activate(String key);

  /// Toggles the (single) rendered checkbox, as a user click would.
  Future<void> toggleCheckbox();

  /// Toggles the (single) rendered switch, as a user click would.
  Future<void> toggleSwitch();

  /// Whether the (single) rendered slider is interactive rather than disabled.
  /// Flutter: the `Slider`'s `onChanged` is non-null; Jaspr: the range input is
  /// not `disabled`. A slider with no value listener cannot report changes, so
  /// it must be disabled identically on every adapter (the presence of the
  /// handler drives it, matching the handler-less `Button`).
  bool sliderEnabled();

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
    CraftTheme? theme,
    CraftEventHandler? onEvent,
  }) {
    return mountLibrary(parseLibraryFile(template),
        data: data, theme: theme, onEvent: onEvent);
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
          Heading(text: add(a: 40, b: 2), level: 3),
        ]);
      ''');

      expect(tester.hasText('Top Heading'), isTrue); // default level 1
      expect(tester.hasText('Subsection'), isTrue); // explicit level 2
      // Like Text, a Heading coerces a numeric value to its string form — a
      // computed number can title a section (and a calculator's display).
      expect(tester.hasText('42'), isTrue);
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
    // template's choice, composed as a sibling Text (DESIGN.md §4 / §8).
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

  driver.defineTest('Switch reflects and toggles its bound state', (
    CraftTester tester,
  ) async {
    await tester.mount('''
      import core;
      widget root { on: false } = Column(children: [
        Switch(
          value: state.on,
          onChanged: set state.on = switch state.on { true: false, default: true },
        ),
        Text(text: switch state.on { true: "ON", default: "OFF" }),
      ]);
    ''');

    expect(tester.hasText('OFF'), isTrue);
    await tester.toggleSwitch();
    expect(tester.hasText('ON'), isTrue);
    await tester.toggleSwitch();
    expect(tester.hasText('OFF'), isTrue);
  });

  driver.defineTest('Select shows its bound option', (
    CraftTester tester,
  ) async {
    // The closed control displays the bound choice on every adapter (what
    // the popup/option list looks like is idiom latitude — Flutter renders
    // options only while open, the DOM keeps them mounted — so only the
    // selected option's visibility is cross-adapter behavior).
    final DynamicContent data = DynamicContent();
    data.update('size', 'Medium');
    await tester.mount('''
      import core;
      widget root = Select(
        value: data.size,
        options: ["Small", "Medium", "Large"],
        onChanged: event "sized" {},
      );
    ''', data: data);
    expect(tester.hasText('Medium'), isTrue);

    // The bound value is live: a data update re-selects.
    data.update('size', 'Large');
    await tester.pump();
    expect(tester.hasText('Large'), isTrue);
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
      // computed values — and totality on bad runtime input — must match.
      //
      // The third row exercises *runtime* totality: `data.numeric` is a binding
      // (only known at runtime, possibly agent-controlled), so it is not checked
      // at bind time; a wrong-typed literal is instead a bind-time error, covered
      // per-adapter in each adapter's function-call tests.
      final DynamicContent data = DynamicContent();
      data.update('numeric', '5'); // a numeric-looking String arriving as data
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: add(a: 2, b: 3)),
          Text(text: add(a: add(a: 10, b: 5), b: 100)),
          Text(text: add(a: data.numeric, b: 3)),
        ]);
      ''', data: data);

      expect(tester.hasText('5'), isTrue); // 2 + 3
      expect(tester.hasText('115'), isTrue); // nested: (10 + 5) + 100
      // Strict + total: the bound String "5" is not silently coerced to the
      // number 5, so the third call yields null → an absent (empty) text and the
      // result is NOT 8. This guards against JS-style string→number coercion
      // (which would render "8"), and proves wrong-typed data degrades without
      // crashing.
      expect(tester.hasText('8'), isFalse);
    },
  );

  driver.defineTest(
    'a set-state handler computes its next value with a function (counter)',
    (CraftTester tester) async {
      // The other half of the function slice: a function call on the right-hand
      // side of `set state`. A counter is the canonical case RFW alone cannot
      // express — its expression language has no `+` operator — so `count + 1`
      // becomes `add(a: state.count, b: 1)`. Each tap recomputes and stores the
      // next count purely in-template (no host code, no data-model round-trip,
      // no agent), and both adapters must count identically. `count` is a real
      // number in state; the Text sink coerces it to its string form.
      await tester.mount('''
        import core;
        widget root { count: 0 } = Column(children: [
          Text(text: state.count),
          Button(
            key: "inc",
            onPressed: set state.count = add(a: state.count, b: 1),
            child: Text(text: "Increment"),
          ),
        ]);
      ''');

      expect(tester.hasText('0'), isTrue);

      await tester.activate('inc');
      expect(tester.hasText('1'), isTrue);
      expect(tester.hasText('0'), isFalse);

      await tester.activate('inc');
      expect(tester.hasText('2'), isTrue);
      expect(tester.hasText('1'), isFalse);
    },
  );

  driver.defineTest(
    'a button applies a list of set-state handlers in one press',
    (CraftTester tester) async {
      // A single control can carry a *list* of `set state` handlers, all applied
      // on one activation. Each handler's value is computed against the state as
      // of the last build, so they don't interfere — here `a` and `b` advance
      // independently. This is what lets a richer control (e.g. a calculator's
      // operator key) update several state fields atomically, so both adapters
      // must apply the whole list.
      await tester.mount('''
        import core;
        widget root { a: 0, b: 0 } = Column(children: [
          Text(text: state.a),
          Text(text: state.b),
          Button(
            key: "bump",
            onPressed: [
              set state.a = add(a: state.a, b: 1),
              set state.b = add(a: state.b, b: 10),
            ],
            child: Text(text: "Bump"),
          ),
        ]);
      ''');

      expect(tester.textCount('0'), 2); // a and b both 0

      await tester.activate('bump');
      expect(tester.hasText('1'), isTrue); // a: 0 -> 1
      expect(tester.hasText('10'), isTrue); // b: 0 -> 10

      await tester.activate('bump');
      expect(tester.hasText('2'), isTrue); // a: 1 -> 2
      expect(tester.hasText('20'), isTrue); // b: 10 -> 20
    },
  );

  driver.defineTest(
    'the standard math functions compute identically on every adapter',
    (CraftTester tester) async {
      // The rest of the basic arithmetic set beyond `add`. Determinism across
      // adapters is the point: same operands → same rendered result. Division
      // yields a double (20 / 5 = 4.0), but the text coercion renders a whole
      // value without a trailing ".0" so it reads "4" identically on the Dart VM
      // (Flutter) and dart2js (Jaspr), which disagree on `(4.0).toString()`.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: subtract(a: 10, b: 4)),
          Text(text: multiply(a: 6, b: 7)),
          Text(text: divide(a: 20, b: 5)),
          Text(text: divide(a: 1, b: 0)),
        ]);
      ''');

      expect(tester.hasText('6'), isTrue); // 10 - 4
      expect(tester.hasText('42'), isTrue); // 6 * 7
      expect(tester.hasText('4'), isTrue); // 20 / 5 → 4.0, rendered as "4"
      // Divide-by-zero has no numeric result → null → absent (no crash). Only
      // the three results above render; nothing shows for the 4th (and "4"
      // appears once — not also from "42").
      expect(tester.textCount('4'), 1);
    },
  );

  driver.defineTest(
    'the extended number functions compute identically on every adapter',
    (CraftTester tester) async {
      // mod/min/max/abs plus the double→int roundings (round/floor/ceil), which
      // are handy for turning a division result into a whole number. Operands are
      // chosen so every result is distinct.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: mod(a: 17, b: 5)),
          Text(text: min(a: 9, b: 4)),
          Text(text: max(a: 9, b: 4)),
          Text(text: abs(value: subtract(a: 3, b: 10))),
          Text(text: round(value: divide(a: 11, b: 2))),
          Text(text: floor(value: divide(a: 11, b: 2))),
          Text(text: ceil(value: divide(a: 11, b: 4))),
        ]);
      ''');

      expect(tester.hasText('2'), isTrue); // 17 mod 5
      expect(tester.hasText('4'), isTrue); // min(9, 4)
      expect(tester.hasText('9'), isTrue); // max(9, 4)
      expect(tester.hasText('7'), isTrue); // abs(3 - 10)
      expect(tester.hasText('6'), isTrue); // round(5.5)
      expect(tester.hasText('5'), isTrue); // floor(5.5)
      expect(tester.hasText('3'), isTrue); // ceil(2.75)
    },
  );

  driver.defineTest(
    'comparison and boolean logic functions drive a switch on every adapter',
    (CraftTester tester) async {
      // Comparison/logic functions return a boolean, which is meant to feed a
      // `switch` (RFW has no `if`); a bare boolean in a Text sink renders empty.
      // Also covers cross-type equality (5 ≠ "5", no coercion) and nesting a
      // comparison inside `and`.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: switch greaterThan(a: 5, b: 3) { true: "gt-yes", default: "gt-no" }),
          Text(text: switch lessThan(a: 5, b: 3) { true: "lt-yes", default: "lt-no" }),
          Text(text: switch greaterThanOrEqual(a: 3, b: 3) { true: "gte-yes", default: "gte-no" }),
          Text(text: switch equals(a: "x", b: "x") { true: "eq-yes", default: "eq-no" }),
          Text(text: switch equals(a: 5, b: "5") { true: "cross-yes", default: "cross-no" }),
          Text(text: switch and(a: true, b: greaterThan(a: 2, b: 1)) { true: "and-yes", default: "and-no" }),
          Text(text: switch or(a: false, b: false) { true: "or-yes", default: "or-no" }),
          Text(text: switch not(value: false) { true: "not-yes", default: "not-no" }),
        ]);
      ''');

      expect(tester.hasText('gt-yes'), isTrue); // 5 > 3
      expect(tester.hasText('lt-no'), isTrue); // 5 < 3 is false
      expect(tester.hasText('gte-yes'), isTrue); // 3 >= 3
      expect(tester.hasText('eq-yes'), isTrue); // "x" == "x"
      expect(tester.hasText('cross-no'), isTrue); // 5 != "5" (no coercion)
      expect(tester.hasText('and-yes'), isTrue); // true && (2 > 1)
      expect(tester.hasText('or-no'), isTrue); // false || false is false
      expect(tester.hasText('not-yes'), isTrue); // !false
    },
  );

  driver.defineTest(
    'the string functions compute identically on every adapter',
    (CraftTester tester) async {
      // concat accepts any operand (a nested number is stringified the same way
      // a Text sink would render it); the rest require a string and are total.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: concat(a: "Hello, ", b: "World")),
          Text(text: uppercase(value: "abc")),
          Text(text: lowercase(value: "XYZ")),
          Text(text: trim(value: "  spaced  ")),
          Text(text: length(value: "hello")),
          Text(text: concat(a: "n=", b: add(a: 2, b: 3))),
        ]);
      ''');

      expect(tester.hasText('Hello, World'), isTrue);
      expect(tester.hasText('ABC'), isTrue);
      expect(tester.hasText('xyz'), isTrue);
      expect(tester.hasText('spaced'), isTrue); // trimmed
      expect(tester.hasText('5'), isTrue); // length("hello")
      expect(tester.hasText('n=5'), isTrue); // concat stringifies the number 5
    },
  );

  driver.defineTest(
    'theme references resolve design tokens to their canonical template values',
    (CraftTester tester) async {
      // A DTCG theme with a primitive→semantic alias, a dimension, and a
      // number, resolved by the shared runtime parser and read through the
      // `theme.` scope in canonical template forms (hex string / px double /
      // double) — a theme reference is interchangeable with the literal it
      // canonicalizes to. Text sinks display those forms, which is what lets
      // this suite assert resolution behaviorally on every adapter; that the
      // canonical form feeds a real styling prop is covered by the Box child.
      final CraftTheme theme = CraftTheme(resolveDesignTokens(<DesignTokenSet>[
        parseDesignTokens(<String, Object?>{
          'color': <String, Object?>{
            r'$type': 'color',
            'base': <String, Object?>{
              'blue': <String, Object?>{r'$value': '#0066CC'},
            },
            'action': <String, Object?>{r'$value': '{color.base.blue}'},
          },
          'spacing': <String, Object?>{
            'gap': <String, Object?>{
              r'$type': 'dimension',
              r'$value': <String, Object?>{'value': 12, 'unit': 'px'},
            },
          },
          'emphasis': <String, Object?>{r'$type': 'number', r'$value': 0.5},
        }),
      ]));

      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: theme.color.action),
          Text(text: theme.spacing.gap),
          Text(text: theme.emphasis),
          Box(color: theme.color.action, child: Text(text: "themed box")),
        ]);
      ''', theme: theme);

      expect(tester.hasText('#FF0066CC'), isTrue); // alias → canonical hex
      expect(tester.hasText('12'), isTrue); // {value: 12, unit: px} → 12
      expect(tester.hasText('0.5'), isTrue); // number passes through
      expect(tester.hasText('themed box'), isTrue); // feeds a color prop
    },
  );

  driver.defineTest(
    'a new theme snapshot re-themes the live surface (mode swap, no remount)',
    (CraftTester tester) async {
      // The dark overlay overrides only the *primitive* token; because aliases
      // dereference after the layer merge, the untouched semantic token
      // re-points to the new primitive. The host flips the mode by providing a
      // new immutable snapshot — and the surface re-resolves IN PLACE: the
      // template's own state must survive the swap (that is what
      // distinguishes a re-theme from a remount).
      final DesignTokenSet base = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'base': <String, Object?>{
            'bg': <String, Object?>{r'$value': '#FFFFFF'},
          },
          'surface': <String, Object?>{r'$value': '{color.base.bg}'},
        },
      });
      final DesignTokenSet dark = parseDesignTokens(<String, Object?>{
        'color': <String, Object?>{
          r'$type': 'color',
          'base': <String, Object?>{
            'bg': <String, Object?>{r'$value': '#111111'},
          },
        },
      });

      await tester.mount('''
        import core;
        widget root { count: 0 } = Column(children: [
          Button(
            key: "inc",
            onPressed: set state.count = add(a: state.count, b: 1),
            child: Text(text: "bump"),
          ),
          Text(text: concat(a: "n=", b: state.count)),
          Text(text: theme.color.surface),
        ]);
      ''', theme: CraftTheme(resolveDesignTokens(<DesignTokenSet>[base])));
      expect(tester.hasText('#FFFFFFFF'), isTrue);

      // Accumulate local state, then swap the theme.
      await tester.activate('inc');
      expect(tester.hasText('n=1'), isTrue);

      await tester.retheme(
          CraftTheme(resolveDesignTokens(<DesignTokenSet>[base, dark])));
      expect(tester.hasText('#FF111111'), isTrue);
      expect(tester.hasText('#FFFFFFFF'), isFalse);
      // The counter survived: the swap re-resolved, it did not remount.
      expect(tester.hasText('n=1'), isTrue);
    },
  );

  driver.defineTest(
    'primitives read their ambient role defaults from the theme',
    (CraftTester tester) async {
      // The semantic contract (ThemeRoles, DESIGN.md §9.4): with a theme
      // mounted, primitives whose props are unset read their roles — no
      // theme. reference anywhere in the template. Themed values must land
      // identically on every adapter (§9.6); the probes read the decision
      // the primitive made, not pixels.
      final CraftTheme theme = CraftTheme(resolveDesignTokens(<DesignTokenSet>[
        parseDesignTokens(<String, Object?>{
          'color': <String, Object?>{
            r'$type': 'color',
            'onSurface': <String, Object?>{r'$value': '#112233'},
            'onSurfaceVariant': <String, Object?>{r'$value': '#445566'},
          },
          'type': <String, Object?>{
            r'$type': 'dimension',
            'body': <String, Object?>{
              'size': <String, Object?>{r'$value': '18px'},
            },
            'caption': <String, Object?>{
              'size': <String, Object?>{r'$value': '11px'},
            },
            'heading': <String, Object?>{
              '2': <String, Object?>{
                'size': <String, Object?>{r'$value': '30px'},
              },
            },
          },
        }),
      ]));

      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: "body copy"),
          Text(text: "small print", variant: "caption"),
          Heading(text: "Sub", level: 2),
        ]);
      ''', theme: theme);

      expect(tester.textColorOf('body copy'), '#FF112233');
      expect(tester.textFontSizeOf('body copy'), 18);
      expect(tester.textColorOf('small print'), '#FF445566');
      expect(tester.textFontSizeOf('small print'), 11);
      expect(tester.textColorOf('Sub'), '#FF112233');
      expect(tester.textFontSizeOf('Sub'), 30);
    },
  );

  driver.defineTest(
    'a theme omitting a role falls back to the host default, per role',
    (CraftTester tester) async {
      // Partial themes degrade role-by-role: body picks up the one provided
      // role; the caption keeps its shared built-in default (#5F6368 / 12 on
      // both adapters) because the theme names no caption roles.
      final CraftTheme theme = CraftTheme(resolveDesignTokens(<DesignTokenSet>[
        parseDesignTokens(<String, Object?>{
          'color': <String, Object?>{
            'onSurface': <String, Object?>{
              r'$type': 'color',
              r'$value': '#112233',
            },
          },
        }),
      ]));

      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: "body copy"),
          Text(text: "small print", variant: "caption"),
        ]);
      ''', theme: theme);

      expect(tester.textColorOf('body copy'), '#FF112233');
      expect(tester.textFontSizeOf('body copy'), isNull); // host default
      expect(tester.textColorOf('small print'), '#FF5F6368');
      expect(tester.textFontSizeOf('small print'), 12);
    },
  );

  driver.defineTest(
    'unthemed primitives keep their host defaults (regression guard)',
    (CraftTester tester) async {
      // No theme: the semantic contract must be invisible — body text carries
      // no explicit styling (the host shows through) and the caption keeps
      // exactly its pre-theming values.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: "body copy"),
          Text(text: "small print", variant: "caption"),
        ]);
      ''');

      expect(tester.textColorOf('body copy'), isNull);
      expect(tester.textFontSizeOf('body copy'), isNull);
      expect(tester.textColorOf('small print'), '#FF5F6368');
      expect(tester.textFontSizeOf('small print'), 12);
    },
  );

  driver.defineTest(
    'Button announces a button role, named by its child, on and off',
    (CraftTester tester) async {
      // The *accessibility* contract of the control: a button role whose
      // accessible name derives from the child (the content layer), and an
      // explicit disabled state when there is no handler. Flutter merges the
      // child into a button semantics node; Jaspr renders a native <button> —
      // same announcement either way.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Button(onPressed: event "press" {}, child: Text(text: "Press me")),
          Button(child: Text(text: "Unavailable")),
          Text(text: "Press me"),
        ]);
      ''');

      // Exactly the button announces the role — the identical plain text
      // sibling never does.
      expect(tester.buttonCount('Press me'), 1);
      expect(tester.textCount('Press me'), 2);
      // A handler-less button still announces as a (disabled) button rather
      // than vanishing from the a11y tree.
      expect(tester.buttonCount('Unavailable'), 1);
    },
  );

  driver.defineTest(
    'Button paints the primary surface with onPrimary content ink, per theme',
    (CraftTester tester) async {
      // The control paint model (DESIGN.md §8): an unstyled Button is the
      // idiom's stock button — the `primary` role fully fills the surface
      // (layer 1) and `onPrimary` inks the content (layer 3), overriding the
      // ambient `onSurface` the label would otherwise read. Re-theming
      // re-inks both, in place. Same role → same part, same degree, on every
      // adapter.
      CraftTheme theme(String primary, String onPrimary) =>
          CraftTheme(resolveDesignTokens(<DesignTokenSet>[
            parseDesignTokens(<String, Object?>{
              'color': <String, Object?>{
                r'$type': 'color',
                'primary': <String, Object?>{r'$value': primary},
                'onPrimary': <String, Object?>{r'$value': onPrimary},
                'onSurface': <String, Object?>{r'$value': '#112233'},
              },
            }),
          ]));

      await tester.mount('''
        import core;
        widget root = Column(children: [
          Button(onPressed: event "go" {}, child: Text(text: "Go")),
          Text(text: "outside"),
        ]);
      ''', theme: theme('#6200EE', '#F1F2F3'));

      expect(tester.buttonSurfaceColorOf('Go'), '#FF6200EE');
      expect(tester.textColorOf('Go'), '#FFF1F2F3');
      // The content ink is scoped to the control: siblings keep onSurface.
      expect(tester.textColorOf('outside'), '#FF112233');

      await tester.retheme(theme('#00695C', '#FFFFFF'));
      expect(tester.buttonSurfaceColorOf('Go'), '#FF00695C');
      expect(tester.textColorOf('Go'), '#FFFFFFFF');
    },
  );

  driver.defineTest(
    'an explicit Button color owns the whole surface; the ambient ink stands',
    (CraftTester tester) async {
      // An author-supplied surface fully fills the control on every adapter
      // (never a partial tint), and the author owns the surface/ink pairing:
      // the label keeps the ambient `onSurface`, exactly as it would outside
      // the button (the calculator-keypad pattern).
      final CraftTheme theme = CraftTheme(resolveDesignTokens(<DesignTokenSet>[
        parseDesignTokens(<String, Object?>{
          'color': <String, Object?>{
            r'$type': 'color',
            'primary': <String, Object?>{r'$value': '#6200EE'},
            'onPrimary': <String, Object?>{r'$value': '#FFFFFF'},
            'onSurface': <String, Object?>{r'$value': '#112233'},
          },
        }),
      ]));

      await tester.mount('''
        import core;
        widget root = Column(children: [
          Button(color: "#ABCDEF", child: Text(text: "Custom")),
          Button(color: "#00000000", child: Text(text: "Quiet")),
        ]);
      ''', theme: theme);

      expect(tester.buttonSurfaceColorOf('Custom'), '#FFABCDEF');
      expect(tester.textColorOf('Custom'), '#FF112233');
      // A transparent color is the "text button" degenerate case: no painted
      // surface, ambient ink.
      expect(tester.buttonSurfaceColorOf('Quiet'), isNull);
      expect(tester.textColorOf('Quiet'), '#FF112233');
    },
  );

  driver.defineTest(
    'an unthemed surface renders theme references as missing, without error',
    (CraftTester tester) async {
      // No theme mounted: the references resolve as missing and the consumer
      // falls back (here Text renders nothing) — the §9 totality discipline.
      // The surface itself must render normally.
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Text(text: theme.color.action),
          Box(color: theme.color.action, child: Text(text: "unthemed box")),
          Text(text: "alive"),
        ]);
      ''');

      expect(tester.hasText('alive'), isTrue);
      expect(tester.hasText('unthemed box'), isTrue);
    },
  );

  driver.defineTest(
    'the default theme paints its modes; a mode flip re-themes in place',
    (CraftTester tester) async {
      // Slice 4: the open-source default theme (DefaultTheme) resolves for a
      // host-supplied n-ary mode and lands identically on both adapters. Light
      // restates the pre-contract ink (#202124); flipping to Dark is just
      // handing the surface the next immutable snapshot — the ink re-points and
      // local state survives the swap (a re-theme, not a remount).
      await tester.mount('''
        import core;
        widget root { count: 0 } = Column(children: [
          Button(
            key: "inc",
            onPressed: set state.count = add(a: state.count, b: 1),
            child: Text(text: "bump"),
          ),
          Text(text: concat(a: "n=", b: state.count)),
          Text(text: "body copy"),
        ]);
      ''', theme: DefaultTheme.of(CraftThemeMode.light));
      expect(tester.textColorOf('body copy'), '#FF202124');

      await tester.activate('inc');
      expect(tester.hasText('n=1'), isTrue);

      await tester.retheme(DefaultTheme.of(CraftThemeMode.dark));
      // Dark ink (gray.50) landed, and the counter survived the re-theme.
      expect(tester.textColorOf('body copy'), '#FFF8F9FA');
      expect(tester.hasText('n=1'), isTrue);

      // The high-contrast axis is a distinct mode, not a toggle on Dark.
      await tester.retheme(DefaultTheme.of(CraftThemeMode.darkHighContrast));
      expect(tester.textColorOf('body copy'), '#FFFFFFFF');
    },
  );

  driver.defineTest(
    'a Slider without a value listener is disabled, on both adapters',
    (CraftTester tester) async {
      // The presence of `onChanged` drives the enabled state, identically on
      // every adapter: a slider with no listener cannot report changes, so it
      // is disabled (Flutter's `Slider(onChanged: null)` renders the disabled
      // state; the Jaspr range input carries `disabled`). Behaviorally
      // identical — neither accepts a drag — rather than one adapter dropping
      // drags the other honors. Matches the handler-less `Button`.
      await tester.mount('''
        import core;
        widget root = Slider(value: 0.5, min: 0.0, max: 1.0);
      ''');
      expect(tester.sliderEnabled(), isFalse);
    },
  );

  driver.defineTest(
    'a Slider with a value listener is interactive, on both adapters',
    (CraftTester tester) async {
      await tester.mount('''
        import core;
        widget root =
          Slider(value: 0.5, min: 0.0, max: 1.0, onChanged: event "s" {});
      ''');
      expect(tester.sliderEnabled(), isTrue);
    },
  );

  driver.defineTest(
    'Card inks its surface fill and outline border, per theme, on both adapters',
    (CraftTester tester) async {
      // Card is layer 1 (Surface) of the paint model standalone (DESIGN.md §8):
      // the fill reads `color.surface` and the default hairline border reads
      // `color.outline`. Same role → same part, same degree, every adapter; a
      // re-theme re-inks both in place. Corner and elevation are specified
      // defaults, not roles, so they are not asserted here.
      CraftTheme theme(String surface, String outline) =>
          CraftTheme(resolveDesignTokens(<DesignTokenSet>[
            parseDesignTokens(<String, Object?>{
              'color': <String, Object?>{
                r'$type': 'color',
                'surface': <String, Object?>{r'$value': surface},
                'outline': <String, Object?>{r'$value': outline},
              },
            }),
          ]));

      await tester.mount('''
        import core;
        widget root = Card(child: Text(text: "grouped"));
      ''', theme: theme('#101820', '#33475B'));

      expect(tester.surfaceColorOf('grouped'), '#FF101820');
      expect(tester.borderColorOf('grouped'), '#FF33475B');

      // Re-theming re-inks both parts in place.
      await tester.retheme(theme('#FFFDF7', '#E0D6C4'));
      expect(tester.surfaceColorOf('grouped'), '#FFFFFDF7');
      expect(tester.borderColorOf('grouped'), '#FFE0D6C4');
    },
  );

  driver.defineTest(
    'an explicit Card color and border override the roles; border: 0 removes it',
    (CraftTester tester) async {
      // Author-supplied decoration wins over the role defaults, and `border: 0`
      // is an explicit "no border" (the elevated-only look).
      await tester.mount('''
        import core;
        widget root = Column(children: [
          Card(color: "#ABCDEF", border: { width: 2.0, color: "#123456" },
            child: Text(text: "explicit")),
          Card(border: 0.0, child: Text(text: "borderless")),
        ]);
      ''', theme: DefaultTheme.of(CraftThemeMode.light));

      expect(tester.surfaceColorOf('explicit'), '#FFABCDEF');
      expect(tester.borderColorOf('explicit'), '#FF123456');
      // No border drawn when the author zeroes it.
      expect(tester.borderColorOf('borderless'), isNull);
    },
  );

  driver.defineTest(
    'Box decoration is opt-in; a bordered Box inks outline, per theme',
    (CraftTester tester) async {
      // Box is a bare container: decoration paints nothing unless asked (unlike
      // Card). A `border` with no explicit color inks `color.outline`; an
      // explicit color/border overrides. `color` is always the author's — Box
      // reads no surface role.
      CraftTheme outlineTheme(String outline) =>
          CraftTheme(resolveDesignTokens(<DesignTokenSet>[
            parseDesignTokens(<String, Object?>{
              'color': <String, Object?>{
                r'$type': 'color',
                'outline': <String, Object?>{r'$value': outline},
              },
            }),
          ]));

      await tester.mount('''
        import core;
        widget root = Column(children: [
          Box(color: "#101010", child: Text(text: "plain")),
          Box(border: 1.0, child: Text(text: "outlined")),
          Box(color: "#ABCDEF", border: { width: 2.0, color: "#123456" },
            child: Text(text: "explicit")),
        ]);
      ''', theme: outlineTheme('#33475B'));

      // A bare Box paints its fill but no border.
      expect(tester.surfaceColorOf('plain'), '#FF101010');
      expect(tester.borderColorOf('plain'), isNull);
      // A role-inked border reads outline; no fill was set.
      expect(tester.borderColorOf('outlined'), '#FF33475B');
      expect(tester.surfaceColorOf('outlined'), isNull);
      // Explicit fill and border win over the role.
      expect(tester.surfaceColorOf('explicit'), '#FFABCDEF');
      expect(tester.borderColorOf('explicit'), '#FF123456');

      // Re-theming re-inks the role-driven border in place.
      await tester.retheme(outlineTheme('#E0D6C4'));
      expect(tester.borderColorOf('outlined'), '#FFE0D6C4');
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
