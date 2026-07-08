// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

/// Jaspr implementation of the shared [CraftTester], wrapping a
/// [ComponentTester] and a Jaspr [Runtime]. Produces HTML DOM rather than
/// widgets, but answers the same behavioral probes.
class _JasprCraftTester implements CraftTester {
  _JasprCraftTester(this._tester);

  final ComponentTester _tester;

  final Runtime _runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(a2uiDemoCatalogName, parseLibraryFile(a2uiDemoCatalogSource));

  final GlobalStateKey<_RethemeShellState> _shellKey =
      GlobalStateKey<_RethemeShellState>();

  @override
  Future<void> mountLibrary(
    RemoteWidgetLibrary main, {
    DynamicContent? data,
    CraftTheme? theme,
    CraftEventHandler? onEvent,
  }) async {
    _runtime.update(const LibraryName(<String>['main']), main);
    // ComponentTester.pumpComponent attaches a fresh root each call (no
    // reconciliation with the previous tree), so the theme lives in a stateful
    // shell: retheme() swaps it via setState and the surface updates in place
    // — a theme swap must not remount (state survives), which the conformance
    // suite asserts.
    _tester.pumpComponent(
      _RethemeShell(
        key: _shellKey,
        runtime: _runtime,
        data: data ?? DynamicContent(),
        initialTheme: theme,
        onEvent: onEvent,
      ),
    );
    await _tester.pump();
  }

  @override
  Future<void> retheme(CraftTheme? theme) async {
    _shellKey.currentState!.retheme(theme);
    await _tester.pump();
  }

  @override
  Object buildAdapter(SurfaceModel<ComponentApi> surface, String id) {
    return A2uiToRfwAdapter(
      id: id,
      surface: surface,
      runtime: _runtime,
      scope: a2uiDemoCatalogName,
    );
  }

  @override
  Future<void> mountComponent(Object component) async {
    _tester.pumpComponent(component as Component);
    await _tester.pump();
  }

  @override
  Future<void> pump() => _tester.pump();

  @override
  int textCount(String text) => find.text(text).evaluate().length;

  @override
  int buttonCount(String label) => find
      .ancestor(of: find.text(label), matching: find.tag('button'))
      .evaluate()
      .length;

  @override
  String? textColorOf(String text) =>
      _canonicalCssColor(_textStyleProperty(text, 'color'));

  @override
  double? textFontSizeOf(String text) {
    final String? value = _textStyleProperty(text, 'font-size');
    if (value == null || !value.endsWith('px')) return null;
    return double.tryParse(value.substring(0, value.length - 2));
  }

  /// The [property] the primitive explicitly set for [text]: read off the
  /// nearest DOM ancestor carrying it. Conformance templates style a probed
  /// property from exactly one ancestor, so `single` also guards against
  /// ambiguous probes.
  String? _textStyleProperty(String text, String property) {
    final Iterable<Element> styled = find
        .ancestor(
          of: find.text(text),
          matching: find.byComponentPredicate((Component c) =>
              c is DomComponent &&
              (c.styles?.properties.containsKey(property) ?? false)),
        )
        .evaluate();
    if (styled.isEmpty) return null;
    return (styled.single.component as DomComponent)
        .styles!
        .properties[property];
  }

  /// Canonicalizes the two CSS color forms the primitives emit — legacy hex
  /// defaults and `rgba(...)` themed values — to `#AARRGGBB`.
  String? _canonicalCssColor(String? css) {
    if (css == null) return null;
    final Rgba? hex = Rgba.decode(css);
    if (hex != null) return hex.toHexString();
    final Match? m =
        RegExp(r'^rgba\((\d+), (\d+), (\d+), ([\d.]+)\)$').firstMatch(css);
    if (m == null) return null;
    return Rgba(((double.parse(m.group(4)!) * 255).round() << 24) |
            (int.parse(m.group(1)!) << 16) |
            (int.parse(m.group(2)!) << 8) |
            int.parse(m.group(3)!))
        .toHexString();
  }

  @override
  Future<void> activate(String key) {
    final Key k = ValueKey<String>(key);
    return _tester.click(find.byKey(k));
  }

  @override
  Future<void> toggleCheckbox() async {
    _tester.dispatchEvent(find.tag('input'), 'change');
    await _tester.pump();
  }
}

/// Owns the mounted surface's theme so [_JasprCraftTester.retheme] can swap it
/// in place (setState) — pumping a fresh root would remount and reset template
/// state, which is exactly what a re-theme must not do.
class _RethemeShell extends StatefulComponent {
  const _RethemeShell({
    super.key,
    required this.runtime,
    required this.data,
    required this.initialTheme,
    required this.onEvent,
  });

  final Runtime runtime;
  final DynamicContent data;
  final CraftTheme? initialTheme;
  final CraftEventHandler? onEvent;

  @override
  State<_RethemeShell> createState() => _RethemeShellState();
}

class _RethemeShellState extends State<_RethemeShell> {
  late CraftTheme? _theme = component.initialTheme;

  void retheme(CraftTheme? theme) => setState(() => _theme = theme);

  @override
  Component build(BuildContext context) {
    return RemoteWidget(
      runtime: component.runtime,
      widget: const FullyQualifiedWidgetName(
        LibraryName(<String>['main']),
        'root',
      ),
      data: component.data,
      theme: _theme,
      onEvent: component.onEvent,
    );
  }
}

class _JasprConformanceDriver implements CraftConformanceDriver {
  @override
  void defineTest(
    String description,
    Future<void> Function(CraftTester tester) body,
  ) {
    testComponents(
      description,
      (ComponentTester tester) => body(_JasprCraftTester(tester)),
    );
  }
}

void main() {
  runCoreComponentConformance(_JasprConformanceDriver());
  runA2uiConformance(_JasprConformanceDriver());
}
