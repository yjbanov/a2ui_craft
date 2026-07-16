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
  /// nearest DOM ancestor carrying it (the ancestor finder yields
  /// nearest-first). An enclosing control may legitimately carry the same
  /// property farther out — a Button sets `color` on its own element so bare
  /// text inherits its content ink — and CSS resolves nearest-wins, so the
  /// probe does too.
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
    return (styled.first.component as DomComponent)
        .styles!
        .properties[property];
  }

  @override
  String? buttonSurfaceColorOf(String label) {
    // The `<button>` element is the Button's surface (layer 1 of the paint
    // model); nearest-first, like [_textStyleProperty].
    final Iterable<Element> buttons = find
        .ancestor(of: find.text(label), matching: find.tag('button'))
        .evaluate();
    if (buttons.isEmpty) return null;
    final String? css = (buttons.first.component as DomComponent)
        .styles
        ?.properties['background-color'];
    if (css == null || css == 'transparent') return null;
    return _canonicalCssColor(css);
  }

  @override
  String? surfaceColorOf(String text) =>
      _canonicalCssColor(_textStyleProperty(text, 'background-color'));

  @override
  String? borderColorOf(String text) {
    // The Card writes the `border` shorthand ("<w>px solid <color>"); the color
    // is the token after `solid`.
    final String? border = _textStyleProperty(text, 'border');
    if (border == null) return null;
    final int i = border.indexOf('solid');
    if (i < 0) return null;
    return _canonicalCssColor(border.substring(i + 'solid'.length).trim());
  }

  @override
  String? checkboxFillColorOf() =>
      _canonicalCssColor(_checkboxStyle('background-color', checked: true));

  @override
  String? checkboxBorderColorOf() =>
      _borderColor('craft-checkbox', checked: false);

  @override
  String? checkboxMarkColorOf() {
    // The mark is an inline SVG `background-image` whose `stroke='<color>'` is
    // URL-encoded (data URIs cannot reference CSS values); read it back.
    final String? image = _checkboxStyle('background-image', checked: true);
    if (image == null) return null;
    final Match? m = RegExp("stroke='([^']*)'").firstMatch(image);
    if (m == null) return null;
    return _canonicalCssColor(Uri.decodeComponent(m.group(1)!));
  }

  /// The inline [property] of the painted `craft-checkbox` glyph in the given
  /// [checked] state, or null when absent. A box is checked iff its `checked`
  /// attribute is present and not `'false'` (the VM tester emits `''` when on;
  /// a browser emits `'true'`/`'false'`).
  String? _checkboxStyle(String property, {required bool checked}) =>
      _controlStyle('craft-checkbox', property, checked: checked);

  @override
  String? radioSelectedColorOf() => _borderColor('craft-radio', checked: true);

  @override
  String? radioRingColorOf() => _borderColor('craft-radio', checked: false);

  /// The `border` shorthand color of the painted control glyph of [cssClass] in
  /// the given [checked] state — the ring color for a radio, the box border for
  /// a checkbox ("<w>px solid <color>", the token after `solid`).
  String? _borderColor(String cssClass, {required bool checked}) {
    final String? border = _controlStyle(cssClass, 'border', checked: checked);
    if (border == null) return null;
    final int i = border.indexOf('solid');
    if (i < 0) return null;
    return _canonicalCssColor(border.substring(i + 'solid'.length).trim());
  }

  /// The inline [property] of the painted control glyph of [cssClass] in the
  /// given [checked] state, or null when absent. Checked iff the `checked`
  /// attribute is present and not `'false'` (VM: `''` when on; browser:
  /// `'true'`/`'false'`).
  String? _controlStyle(String cssClass, String property,
      {required bool checked}) {
    for (final Element e in find
        .byComponentPredicate((Component c) =>
            c is DomComponent &&
            (c.classes?.split(' ').contains(cssClass) ?? false))
        .evaluate()) {
      final DomComponent c = e.component as DomComponent;
      final String? ch = c.attributes?['checked'];
      if ((ch != null && ch != 'false') == checked) {
        return c.styles?.properties[property];
      }
    }
    return null;
  }

  /// Canonicalizes the CSS color forms the primitives emit — hex defaults,
  /// `rgba(...)` themed values, and `light-dark(...)` host fallbacks — to
  /// `#AARRGGBB`. This tester is a light host, so `light-dark()` resolves to
  /// its first argument, exactly as a browser with a light `color-scheme`
  /// would.
  String? _canonicalCssColor(String? css) {
    if (css == null) return null;
    if (css.startsWith('light-dark(') && css.endsWith(')')) {
      // Take the light arm — split on the top-level comma (the arms may
      // themselves be `rgba(...)` calls with commas).
      final String inner = css.substring('light-dark('.length, css.length - 1);
      int depth = 0;
      for (int i = 0; i < inner.length; i++) {
        final String ch = inner[i];
        if (ch == '(') depth++;
        if (ch == ')') depth--;
        if (ch == ',' && depth == 0) {
          return _canonicalCssColor(inner.substring(0, i).trim());
        }
      }
    }
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

  @override
  Future<void> toggleSwitch() async {
    // The switch is a checkbox input carrying `role=switch`.
    _tester.dispatchEvent(
      find.byComponentPredicate((Component c) =>
          c is DomComponent && c.attributes?['role'] == 'switch'),
      'change',
    );
    await _tester.pump();
  }

  @override
  bool sliderEnabled() {
    // The typed element flattens to a DomComponent in the built tree; the
    // range input carries `disabled` in its attributes only when disabled.
    for (final Element e in find.tag('input').evaluate()) {
      final DomComponent c = e.component as DomComponent;
      if (c.attributes?['type'] == 'range') {
        return !(c.attributes?.containsKey('disabled') ?? false);
      }
    }
    return false;
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
