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
// fallback is **adaptive** — a `light-dark()` pair that follows the host
// page's `color-scheme`, the CSS analogue of Flutter's `Theme.of` fallback
// (a dark host must not get a light card under dark-mode body text). The
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

    expect(_styleValues('background-color'), <String>[
      'rgba(250, 251, 252, 1.0)', // Card ← surface
      'rgba(34, 51, 68, 1.0)', // Divider ← outline
      'rgba(170, 0, 0, 1.0)', // checked Checkbox glyph ← primary (full fill)
      'transparent', // TextField chrome — the surface shows through
    ]);
    // Nothing tints via accent-color any more: every themed control is
    // adapter-painted (accent-color can only tint, never fill per the role
    // mapping). The slider's track is a primary→outline gradient split at
    // the bound value (0 here), its thumb inked via the custom property the
    // control stylesheet's pseudo-element thumbs read.
    expect(_styleValues('accent-color'), isEmpty);
    expect(_styleValues('background'), <String>[
      'linear-gradient(to right, rgba(170, 0, 0, 1.0) 0%, '
          'rgba(170, 0, 0, 1.0) 0%, rgba(34, 51, 68, 1.0) 0%, '
          'rgba(34, 51, 68, 1.0) 100%)',
    ]);
    expect(
        _styleValues('--craft-slider-thumb'), <String>['rgba(170, 0, 0, 1.0)']);
    // The checked box's glyph border ← primary; the TextField chrome ←
    // outline (1px box border; its focus border/caret ride primary). The
    // leading 'none' is the Divider resetting the UA hr border.
    expect(_styleValues('border'), <String>[
      'none',
      '2px solid rgba(170, 0, 0, 1.0)',
      '1px solid rgba(34, 51, 68, 1.0)',
    ]);
    expect(_styleValues('caret-color'), <String>['rgba(170, 0, 0, 1.0)']);
    expect(_styleValues('--craft-focus'), <String>['rgba(170, 0, 0, 1.0)']);
  });

  testComponents('themed Checkbox/Radio glyphs are adapter-painted per role',
      (ComponentTester tester) async {
    // The painted-glyph controls (DESIGN.md §8): `outline` inks the unchecked
    // box/ring, `primary` fully fills the checked state (and draws the
    // radio's dot), `onPrimary` strokes the checkmark — appearance: none, so
    // the UA look cannot leak through a themed control.
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Checkbox(value: true),
        Checkbox(value: false),
        Radio(selected: true, onChanged: event "a" {}),
        Radio(selected: false, onChanged: event "b" {}),
      ]);
    ''',
        theme: _fullTheme);

    expect(_styleValues('appearance'), everyElement('none'));
    expect(_styleValues('appearance'), hasLength(4));
    expect(_styleValues('border'), <String>[
      '2px solid rgba(170, 0, 0, 1.0)', // checked box ← primary
      '2px solid rgba(34, 51, 68, 1.0)', // unchecked box ← outline
      '2px solid rgba(170, 0, 0, 1.0)', // selected ring ← primary
      '2px solid rgba(34, 51, 68, 1.0)', // unselected ring ← outline
    ]);
    final List<String> images = _styleValues('background-image');
    expect(images, hasLength(2));
    // The checkmark is an inline SVG stroked with onPrimary; _fullTheme names
    // no onPrimary, so the white fallback strokes it.
    expect(images[0], contains('data:image/svg+xml'));
    expect(images[0], contains(Uri.encodeComponent('#ffffff')));
    // The radio dot is a primary radial fill.
    expect(images[1],
        'radial-gradient(circle, rgba(170, 0, 0, 1.0) 0 40%, transparent 45%)');
  });

  testComponents('Switch/Select follow the role mapping; Switch never UA',
      (ComponentTester tester) async {
    // Switch is the one control with no native fallback (the web has no
    // stock switch), so it is adapter-painted in every state: primary fills
    // the active track (the thumb keeps the scheme-adaptive fallback —
    // _fullTheme names no onPrimary), outline the inactive track. Select
    // shares the TextField chrome roles.
    await _mount(
        tester,
        '''
      import core;
      widget root = Column(children: [
        Switch(value: true, onChanged: event "a" {}),
        Switch(value: false, onChanged: event "b" {}),
        Select(value: "B", options: ["A", "B"], onChanged: event "c" {}),
      ]);
    ''',
        theme: _fullTheme);

    expect(_styleValues('background'), <String>[
      'radial-gradient(circle at 25px 10px, light-dark(#ffffff, #202124) '
          '0 7px, transparent 8px), rgba(170, 0, 0, 1.0)',
      'radial-gradient(circle at 11px 10px, light-dark(#ffffff, #202124) '
          '0 7px, transparent 8px), rgba(34, 51, 68, 1.0)',
    ]);
    expect(_styleValues('border'),
        <String>['none', 'none', '1px solid rgba(34, 51, 68, 1.0)']);
    expect(_styleValues('--craft-focus'), <String>['rgba(170, 0, 0, 1.0)']);
    expect(_styleValues('color'), <String>['rgba(17, 34, 51, 1.0)']);

    // Unthemed, the Switch still paints — with the scheme-adaptive fallback
    // pair — while the Select reverts to the native UA control.
    await _mount(tester, '''
      import core;
      widget root = Column(children: [
        Switch(value: true, onChanged: event "a" {}),
        Select(value: "B", options: ["A", "B"], onChanged: event "c" {}),
      ]);
    ''');
    expect(_styleValues('background'), <String>[
      'radial-gradient(circle at 25px 10px, light-dark(#ffffff, #202124) '
          '0 7px, transparent 8px), light-dark(#1a73e8, #8ab4f8)',
    ]);
    expect(_styleValues('border'), <String>['none']);
  });

  testComponents('unthemed Checkbox/Radio stay the native UA controls',
      (ComponentTester tester) async {
    // No theme: blend in (§9.1) — the web idiom's stock look is the UA
    // control itself, so the inputs carry no styling at all.
    await _mount(tester, '''
      import core;
      widget root = Column(children: [
        Checkbox(value: true),
        Radio(selected: true, onChanged: event "a" {}),
      ]);
    ''');
    expect(_styleValues('appearance'), isEmpty);
    expect(_styleValues('background-color'), isEmpty);
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
    // Unthemed: a bare h2 (browser styling is the host default here); the
    // Card and Divider fall back to scheme-adaptive `light-dark()` pairs so a
    // dark host re-inks them (the root cause of light cards on dark pages).
    await _mount(tester, '''
      import core;
      widget root = Column(children: [
        Heading(text: "Sub", level: 2),
        Card(child: Text(text: "in card")),
        Divider(),
      ]);
    ''');
    expect(_styleValues('font-size'), isEmpty);
    expect(_styleValues('background-color'), <String>[
      'light-dark(#ffffff, #2a2b2e)', // Card ← surface host default
      'light-dark(rgba(0, 0, 0, 0.12), rgba(255, 255, 255, 0.16))', // Divider
    ]);

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

  testComponents('an unthemed Button is the web idiom stock button',
      (ComponentTester tester) async {
    // The control paint model (DESIGN.md §8) unthemed: the surface/ink pair
    // falls back to scheme-adaptive `light-dark()` blues (the link-fallback
    // family), the stock 6px corner + 8/16 padding land, and the UA chrome is
    // stripped (`appearance: none`, no border) so the web idiom is
    // adapter-owned rather than UA-owned.
    await _mount(tester, '''
      import core;
      widget root = Button(onPressed: event "go" {}, child: Text(text: "Go"));
    ''');
    expect(_styleValues('background-color'), <String>[
      'light-dark(#1a73e8, #8ab4f8)', // surface ← primary host default
    ]);
    expect(_styleValues('color'), <String>[
      // The content ink (← onPrimary host default) lands twice: on the button
      // element (bare text nodes inherit it) and on the label, whose Text
      // consults the control's content ink before the ambient roles.
      'light-dark(#ffffff, #202124)',
      'light-dark(#ffffff, #202124)',
    ]);
    expect(_styleValues('border-radius'), <String>['6px']);
    expect(_styleValues('padding'), <String>['8px 16px 8px 16px']);
    expect(_styleValues('appearance'), <String>['none']);
  });
}
