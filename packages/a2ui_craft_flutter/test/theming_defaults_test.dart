// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
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
    {CraftTheme? theme}) async {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(const LibraryName(<String>['main']), parseLibraryFile(template));
  await tester.pumpWidget(MaterialApp(
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

    expect(
        tester.widget<Card>(find.byType(Card)).color, const Color(0xFFFAFBFC));
    expect(tester.widget<Divider>(find.byType(Divider)).color,
        const Color(0xFF223344));
    expect(tester.widget<Checkbox>(find.byType(Checkbox)).activeColor,
        const Color(0xFFAA0000));
    expect(tester.widget<Slider>(find.byType(Slider)).activeColor,
        const Color(0xFFAA0000));
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
      ]);
    ''',
        theme: _fullTheme);

    final Icon plain = tester.widget<Icon>(
        find.byWidgetPredicate((Widget w) => w is Icon && w.icon == Icons.add));
    expect(plain.color, const Color(0xFF112233));
    final Icon glyph = tester.widget<Icon>(find.byWidgetPredicate(
        (Widget w) => w is Icon && w.icon == Icons.radio_button_checked));
    expect(glyph.color, const Color(0xFFAA0000));
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
}
