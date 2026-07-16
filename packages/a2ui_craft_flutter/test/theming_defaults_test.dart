// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart' hide Switch;
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// The Flutter half of the ambient role-default wiring (the semantic contract,
// DESIGN.md §9.4) for the primitives the shared painted-text probes can't
// reach: which widget property each role lands on, and that the unthemed
// fallback is this adapter's pre-theming value (the heading ramp). The
// cross-adapter text-color/size behavior is pinned by the conformance suite.

CraftTheme _theme(Map<String, Object?> document) =>
    CraftTheme(resolveDesignTokens(<DesignTokenSet>[
      parseDesignTokens(document),
    ]));

final CraftTheme _fullTheme = _theme(<String, Object?>{
  'color': <String, Object?>{
    r'$type': 'color',
    'surface': <String, Object?>{r'$value': '#FAFBFC'},
    'onSurface': <String, Object?>{r'$value': '#112233'},
    'primary': <String, Object?>{r'$value': '#AA0000'},
    'outline': <String, Object?>{r'$value': '#223344'},
    'link': <String, Object?>{r'$value': '#00AA00'},
  },
});

Future<void> _mount(WidgetTester tester, String template,
    {CraftTheme? theme,
    Brightness brightness = Brightness.light,
    TargetPlatform? platform}) async {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(const LibraryName(<String>['main']), parseLibraryFile(template));
  await tester.pumpWidget(MaterialApp(
    theme: ThemeData(
        useMaterial3: true, brightness: brightness, platform: platform),
    home: Scaffold(
      body: RemoteWidget(
        runtime: runtime,
        widget: const FullyQualifiedWidgetName(
          LibraryName(<String>['main']),
          'root',
        ),
        data: DynamicContent(),
        theme: theme,
      ),
    ),
  ));
}

void main() {
  testWidgets('surface, outline, and primary land on their consumers',
      (WidgetTester tester) async {
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Card(child: Text(text: "in card")),
        Divider(),
        Checkbox(value: true),
        Slider(),
        TextField(),
      ]);
    ''',
        theme: _fullTheme);

    // Card owns its paint (a DecoratedBox, not Material's Card): the fill inks
    // surface, the default hairline border inks outline.
    final BoxDecoration cardDecoration = tester
        .widgetList<DecoratedBox>(find.byType(DecoratedBox))
        .map((DecoratedBox d) => d.decoration)
        .whereType<BoxDecoration>()
        .firstWhere((BoxDecoration d) => d.color == const Color(0xFFFAFBFC));
    expect(
        (cardDecoration.border! as Border).top.color, const Color(0xFF223344));
    expect(tester.widget<Divider>(find.byType(Divider)).color,
        const Color(0xFF223344));
    // The Checkbox role mapping (DESIGN.md §8) on Material's knobs: primary
    // fills the checked state, outline inks the unchecked box; _fullTheme
    // names no onPrimary, so the mark keeps the host default (null).
    final Checkbox box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(box.activeColor, const Color(0xFFAA0000));
    expect(box.checkColor, isNull);
    expect(box.side, const BorderSide(color: Color(0xFF223344), width: 2));
    // Slider: primary inks the active track + thumb, outline the inactive
    // track.
    final Slider slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.activeColor, const Color(0xFFAA0000));
    expect(slider.inactiveColor, const Color(0xFF223344));
    final InputDecoration decoration =
        tester.widget<TextField>(find.byType(TextField)).decoration!;
    expect(decoration.enabledBorder!.borderSide.color, const Color(0xFF223344));
  });

  testWidgets('onSurface inks the Icon; primary inks the selected Radio glyph',
      (WidgetTester tester) async {
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Icon(icon: "add"),
        Radio(selected: true, onChanged: event "a" {}),
        Radio(selected: false, onChanged: event "b" {}),
      ]);
    ''',
        theme: _fullTheme);

    final Icon plain = tester.widget<Icon>(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == Icons.add));
    expect(plain.color, const Color(0xFF112233));
    final Icon glyph = tester.widget<Icon>(find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == Icons.radio_button_checked));
    expect(glyph.color, const Color(0xFFAA0000));
    // The unselected ring inks the outline role (DESIGN.md §8) — mirroring
    // the Jaspr adapter's painted glyph.
    final Icon ring = tester.widget<Icon>(find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == Icons.radio_button_off));
    expect(ring.color, const Color(0xFF223344));
  });

  testWidgets('Switch and Select follow the role mapping',
      (WidgetTester tester) async {
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Switch(value: true, onChanged: event "a" {}),
        Select(value: "B", options: ["A", "B"], onChanged: event "c" {}),
      ]);
    ''',
        theme: _fullTheme);

    // Switch: primary fills the active track; outline fills the *inactive*
    // track — the same part the web glyph inks (a role inks one part on every
    // adapter, §8). _fullTheme names no onPrimary → the active thumb keeps the
    // host look; the inactive thumb is a neutral, not a role.
    final Switch sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.activeTrackColor, const Color(0xFFAA0000));
    expect(sw.activeThumbColor, isNull);
    expect(sw.inactiveTrackColor, const Color(0xFF223344));
    // Select: the closed control shows the bound option, chromed like the
    // TextField (the shared _fieldDecoration).
    expect(find.text('B'), findsOneWidget);
  });

  testWidgets(
      'the Cupertino idiom keeps the role mapping; the Button swaps its '
      'state layer', (WidgetTester tester) async {
    // The idiom is host-selected (ThemeData.platform, DESIGN.md §8): the
    // same template and theme, previewed as iOS. The role mapping is
    // idiom-invariant — the same knobs land — while the state layer and
    // corner style change: no ink splash, a composite pressed-fade, and
    // Apple's continuous superellipse corner for the same cornerRadius.
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Button(onPressed: event "go" {}, child: Text(text: "Go")),
        Checkbox(value: true),
        Switch(value: true, onChanged: event "a" {}),
      ]);
    ''',
        theme: _fullTheme,
        platform: TargetPlatform.iOS);

    final Checkbox box = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(box.activeColor, const Color(0xFFAA0000));
    expect(box.side, const BorderSide(color: Color(0xFF223344), width: 2));
    final Switch sw = tester.widget<Switch>(find.byType(Switch));
    expect(sw.activeTrackColor, const Color(0xFFAA0000));

    // The Button surface: same role, superellipse corner style.
    final Material surface = tester.widget<Material>(find
        .ancestor(of: find.text('Go'), matching: find.byType(Material))
        .first);
    expect(surface.color, const Color(0xFFAA0000));
    expect(surface.shape, isA<RoundedSuperellipseBorder>());

    // The state layer: pressing fades the composite (CupertinoButton's 0.4)
    // instead of splashing ink; releasing restores it.
    final TestGesture gesture =
        await tester.startGesture(tester.getCenter(find.text('Go')));
    await tester.pump(const Duration(milliseconds: 200));
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        0.4);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(tester.widget<AnimatedOpacity>(find.byType(AnimatedOpacity)).opacity,
        1.0);
  });

  testWidgets('link inks Markdown hyperlinks; onSurface inks its body',
      (WidgetTester tester) async {
    await _mount(
        tester,
        '''
      import core;
      widget root = Markdown(text: "a [tap me](https://example.com) link");
    ''',
        theme: _fullTheme);

    // The paragraph renders one Text.rich; find its link span's style.
    final Text rich = tester.widget<Text>(
        find.byWidgetPredicate((Widget w) => w is Text && w.textSpan != null));
    final List<TextSpan> spans =
        (rich.textSpan! as TextSpan).children!.cast<TextSpan>();
    final TextSpan link = spans.singleWhere((TextSpan s) => s.text == 'tap me');
    expect(link.style!.color, const Color(0xFF00AA00));
    final TextSpan body = spans.firstWhere((TextSpan s) => s.text != 'tap me');
    expect(body.style!.color, const Color(0xFF112233));
  });

  testWidgets(
      'headings use the type.heading token, falling back to the built-in ramp',
      (WidgetTester tester) async {
    // Unthemed: this adapter's pre-theming ramp (the host default here).
    await _mount(tester, '''
      import core;
      widget root = Heading(text: "Sub", level: 2);
    ''');
    expect(tester.widget<Text>(find.text('Sub')).style!.fontSize, 22);
    expect(tester.widget<Text>(find.text('Sub')).style!.color, isNull);

    // A themed level overrides only itself; other levels keep the ramp.
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Heading(text: "Sub", level: 2),
        Heading(text: "Minor", level: 3),
      ]);
    ''',
        theme: _theme(<String, Object?>{
          'type': <String, Object?>{
            'heading': <String, Object?>{
              '2': <String, Object?>{
                'size': <String, Object?>{
                  r'$type': 'dimension',
                  r'$value': '30px',
                },
              },
            },
          },
        }));
    expect(tester.widget<Text>(find.text('Sub')).style!.fontSize, 30);
    expect(tester.widget<Text>(find.text('Minor')).style!.fontSize, 20);
  });

  testWidgets('unthemed caption and link fallbacks follow the host brightness',
      (WidgetTester tester) async {
    // The host default must adapt like the rest of Material does (Card and
    // Divider get this via null-color pass-through): a dark host re-inks the
    // caption and link fallbacks — mirroring the Jaspr adapter's
    // `light-dark()` pairs, so the pair stays behaviorally identical.
    const String template = '''
      import core;
      widget root = Column(children: [
        Text(text: "small print", variant: "caption"),
        Markdown(text: "a [tap me](https://example.com) link"),
      ]);
    ''';

    await _mount(tester, template);
    expect(tester.widget<Text>(find.text('small print')).style!.color,
        const Color(0xFF5F6368));

    await _mount(tester, template, brightness: Brightness.dark);
    // MaterialApp animates theme changes; settle so Theme.of is fully dark.
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(find.text('small print')).style!.color,
        const Color(0xFF9AA0A6));
    final TextSpan darkLink = tester
        .widget<Text>(find.textContaining('tap me'))
        .textSpan! as TextSpan;
    TextStyle? linkStyle;
    darkLink.visitChildren((InlineSpan span) {
      if (span is TextSpan && span.text == 'tap me') {
        linkStyle = span.style;
        return false;
      }
      return true;
    });
    expect(linkStyle?.color, const Color(0xFF8AB4F8));
  });

  testWidgets('an unthemed Button is the host Material stock button',
      (WidgetTester tester) async {
    // The control paint model (DESIGN.md §8) unthemed: the surface/ink pair
    // resolves through the host's `ColorScheme.primary`/`onPrimary` (per-idiom
    // latitude — the Jaspr side pins its own `light-dark()` blues), so the
    // stock button follows the host theme, brightness included.
    const String template = '''
      import core;
      widget root = Button(onPressed: event "go" {}, child: Text(text: "Go"));
    ''';

    await _mount(tester, template);
    ThemeData host =
        ThemeData(useMaterial3: true, brightness: Brightness.light);
    Material surface = tester.widget<Material>(find
        .ancestor(of: find.text('Go'), matching: find.byType(Material))
        .first);
    expect(surface.color, host.colorScheme.primary);
    expect(tester.widget<Text>(find.text('Go')).style!.color,
        host.colorScheme.onPrimary);

    await _mount(tester, template, brightness: Brightness.dark);
    await tester.pumpAndSettle();
    host = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    surface = tester.widget<Material>(find
        .ancestor(of: find.text('Go'), matching: find.byType(Material))
        .first);
    expect(surface.color, host.colorScheme.primary);
    expect(tester.widget<Text>(find.text('Go')).style!.color,
        host.colorScheme.onPrimary);
  });
}
