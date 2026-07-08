// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_test/jaspr_test.dart';

// The Jaspr half of the ambient role-default wiring (the semantic contract,
// DESIGN.md §9.4) for the primitives the shared painted-text probes can't
// reach: which CSS property each role lands on, and that the unthemed
// fallback is this adapter's pre-theming rendering (browser-default headings,
// the rgba(0,0,0,0.12) divider). The cross-adapter text-color/size behavior
// is pinned by the conformance suite.

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

Future<void> _mount(ComponentTester tester, String template,
    {CraftTheme? theme}) async {
  final Runtime runtime = Runtime()
    ..update(const LibraryName(<String>['core']), createCoreComponents())
    ..registerFunctions(createCoreFunctions())
    ..update(const LibraryName(<String>['main']), parseLibraryFile(template));
  tester.pumpComponent(RemoteWidget(
    runtime: runtime,
    widget: const FullyQualifiedWidgetName(
      LibraryName(<String>['main']),
      'root',
    ),
    data: DynamicContent(),
    theme: theme,
  ));
  await tester.pump();
}

/// All values of the CSS [property] explicitly set by rendered DOM components.
List<String> _styleValues(String property) => <String>[
      for (final Element element in find
          .byComponentPredicate((Component c) =>
              c is DomComponent &&
              (c.styles?.properties.containsKey(property) ?? false))
          .evaluate())
        (element.component as DomComponent).styles!.properties[property]!,
    ];

void main() {
  testComponents('surface, outline, and primary land on their CSS properties',
      (ComponentTester tester) async {
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

    expect(_styleValues('background-color'),
        <String>['rgba(250, 251, 252, 1.0)', 'rgba(34, 51, 68, 1.0)']);
    // Checkbox and Slider both carry the accent.
    expect(_styleValues('accent-color'),
        <String>['rgba(170, 0, 0, 1.0)', 'rgba(170, 0, 0, 1.0)']);
    expect(_styleValues('border-color'), <String>['rgba(34, 51, 68, 1.0)']);
  });

  testComponents('onSurface inks the Icon; link inks Markdown hyperlinks',
      (ComponentTester tester) async {
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Icon(icon: "add"),
        Markdown(text: "a [tap me](https://example.com) link"),
      ]);
    ''',
        theme: _fullTheme);

    // The icon's own color, the Markdown wrapper's inherited body color, and
    // the link's color (in document order).
    expect(_styleValues('color'), <String>[
      'rgba(17, 34, 51, 1.0)', // Icon ← onSurface
      'rgba(17, 34, 51, 1.0)', // Markdown wrapper ← onSurface
      'rgba(0, 170, 0, 1.0)', // link ← link
    ]);
  });

  testComponents(
      'headings use the type.heading token; unthemed keeps browser defaults',
      (ComponentTester tester) async {
    // Unthemed: a bare h2 (browser styling is the host default here) and the
    // divider keeps its built-in separator color.
    await _mount(tester, '''
      import core;
      widget root = Column(children: [
        Heading(text: "Sub", level: 2),
        Divider(),
      ]);
    ''');
    expect(_styleValues('font-size'), isEmpty);
    expect(_styleValues('background-color'), <String>['rgba(0, 0, 0, 0.12)']);

    // A themed level styles only itself.
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
    expect(_styleValues('font-size'), <String>['30px']);
  });
}
