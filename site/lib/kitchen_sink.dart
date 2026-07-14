// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart' show A2uiMessage;
import 'package:a2ui_craft/a2ui_craft.dart' show CraftTheme, CraftThemeMode;
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart' show SampleView;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:web/web.dart' as web;

import 'brand_themes.dart';
import 'flutter_specimen.dart';
import 'theme_mode.dart';

/// The kitchen sink: every core primitive, rendered live under the **default
/// theme** (DESIGN.md §9.5), one specimen card per primitive family — the
/// layout of the design-language showcase page.
///
/// Nothing on this page is hand-written HTML posing as a primitive: each
/// specimen is a real `.craft` template rendered by the real runtime, so what
/// it shows is what a template author gets. A page-level Jaspr/Flutter toggle
/// swaps *which adapter* renders every specimen — the Jaspr DOM render or an
/// embedded Flutter render of the same trio — proving the framework-agnostic
/// claim primitive by primitive. The interactive specimens (buttons, controls,
/// the slider) run on the same two data flows as the samples — template state
/// and the A2UI data model — on whichever adapter is active.
class KitchenSinkScreen extends StatefulComponent {
  const KitchenSinkScreen({super.key});

  @override
  State<KitchenSinkScreen> createState() => _KitchenSinkScreenState();
}

class _KitchenSinkScreenState extends State<KitchenSinkScreen> {
  /// The page-local high-contrast axis; combined with the site's light-dark
  /// choice it selects one of the default theme's four n-ary modes.
  bool _highContrast = false;

  /// Which adapter renders every specimen: `'Jaspr'` (DOM) or `'Flutter'`
  /// (embedded). Flipping it swaps all specimens at once.
  String _framework = 'Jaspr';

  /// The active brand — an axis orthogonal to light/dark and high-contrast. It
  /// drives both the specimen [CraftTheme] and the page chrome (corners, border
  /// weights, fonts) via CSS variables on the document root.
  Brand _brand = kBrands.first;

  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    // A dark-light flip re-themes the specimens and re-derives the chrome.
    _unsubscribe = SiteTheme.onChange(() {
      setState(() {});
      _applyChrome();
    });
    _applyChrome();
  }

  @override
  void dispose() {
    _clearChrome();
    _unsubscribe?.call();
    super.dispose();
  }

  CraftThemeMode get _mode =>
      switch ((SiteTheme.effectiveDark, _highContrast)) {
        (false, false) => CraftThemeMode.light,
        (false, true) => CraftThemeMode.lightHighContrast,
        (true, false) => CraftThemeMode.dark,
        (true, true) => CraftThemeMode.darkHighContrast,
      };

  CraftTheme get _theme => _brand.craftTheme(_mode);

  /// Pushes the active brand's chrome variables onto the document root (so the
  /// page background, cards, and controls re-brand), or removes them for the
  /// default brand so the site's stock palette shows through. Deliberately
  /// outside Jaspr's render tree — the same escape hatch [SiteTheme] uses to
  /// drive `color-scheme`.
  void _applyChrome() {
    final web.CSSStyleDeclaration style =
        (web.document.documentElement! as web.HTMLElement).style;
    final Map<String, String> vars = _brand.chromeVars(_mode);
    for (final String key in kChromeVarKeys) {
      final String? value = vars[key];
      if (value == null) {
        style.removeProperty(key);
      } else {
        style.setProperty(key, value);
      }
    }
  }

  /// Restores the site's stock chrome — on unmount, so other screens aren't
  /// left branded.
  void _clearChrome() {
    final web.CSSStyleDeclaration style =
        (web.document.documentElement! as web.HTMLElement).style;
    for (final String key in kChromeVarKeys) {
      style.removeProperty(key);
    }
  }

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'max-width': '860px',
        'margin': '0 auto',
        'padding': '32px 20px 64px',
        'font-family':
            'var(--brand-font, system-ui, -apple-system, sans-serif)',
      }),
      [
        _header(),
        _hero(),
        for (final _Section s in _sections) _sectionCard(s),
      ],
    );
  }

  Component _header() {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'flex-wrap': 'wrap',
        'gap': '10px 16px',
        // Keep the adapter + mode controls reachable after scrolling. Stuck to
        // the viewport top with the page background behind it; the negative
        // side margin + matching padding stretch it to the column's edges (the
        // container insets 20px), and the divider separates it from content
        // that scrolls underneath.
        'position': 'sticky',
        'top': '0',
        'z-index': '20',
        'background': 'var(--bg)',
        'margin': '-32px -20px 0',
        'padding': '20px 20px 12px',
        'border-bottom': '1px solid var(--border)',
      }),
      [
        Link(
          to: '/',
          styles: Styles(raw: <String, String>{
            'color': 'var(--accent)',
            'text-decoration': 'none',
            'font-weight': '600',
          }),
          child: Component.text('← Gallery'),
        ),
        h1(
          styles: Styles(raw: <String, String>{
            'margin': '0',
            'font-size': '20px',
            'flex': '1',
          }),
          [Component.text('A2UI Craft')],
        ),
        _brandPicker(),
        _frameworkToggle(),
        label(
          styles: Styles(raw: <String, String>{
            'display': 'inline-flex',
            'align-items': 'center',
            'gap': '6px',
            'cursor': 'pointer',
            'font': '14px system-ui',
            'color': 'var(--muted)',
            'user-select': 'none',
          }),
          [
            input(
              type: InputType.checkbox,
              checked: _highContrast,
              onChange: (dynamic _) {
                setState(() => _highContrast = !_highContrast);
                // High contrast is a chrome axis too — re-derive the CSS vars.
                _applyChrome();
              },
              styles: Styles(raw: <String, String>{
                'accent-color': 'var(--accent)',
                'cursor': 'pointer',
              }),
            ),
            Component.text('High contrast'),
          ],
        ),
        const ThemeToggle(),
      ],
    );
  }

  /// The brand picker: a segmented control (like the adapter toggle) that swaps
  /// the whole page's brand — the specimen colors and the chrome's corners,
  /// borders, and font — while light/dark and high-contrast stay independent.
  Component _brandPicker() {
    return div(
      attributes: const <String, String>{
        'role': 'group',
        'aria-label': 'Brand theme',
      },
      styles: Styles(raw: <String, String>{
        'display': 'inline-flex',
        'border': '1px solid var(--border-strong)',
        'border-radius': 'var(--control-radius, 6px)',
        'overflow': 'hidden',
      }),
      [
        for (final Brand b in kBrands)
          button(
            onClick: () {
              if (identical(b, _brand)) return;
              setState(() => _brand = b);
              _applyChrome();
            },
            styles: Styles(raw: <String, String>{
              'padding': '6px 12px',
              'border': 'none',
              'background':
                  identical(b, _brand) ? 'var(--accent)' : 'var(--card)',
              'color': identical(b, _brand) ? 'var(--accent-fg)' : 'var(--fg)',
              'font': '13px inherit',
              'cursor': 'pointer',
            }),
            [Component.text(b.label)],
          ),
      ],
    );
  }

  /// The adapter toggle: a segmented Jaspr / Flutter control that swaps which
  /// adapter renders every specimen on the page.
  Component _frameworkToggle() {
    return div(
      attributes: const <String, String>{
        'role': 'group',
        'aria-label': 'Rendering adapter',
      },
      styles: Styles(raw: <String, String>{
        'display': 'inline-flex',
        'border': '1px solid var(--border-strong)',
        'border-radius': 'var(--control-radius, 6px)',
        'overflow': 'hidden',
      }),
      [
        for (final String fw in const <String>['Jaspr', 'Flutter'])
          button(
            onClick: () {
              if (fw == _framework) return;
              setState(() => _framework = fw);
            },
            styles: Styles(raw: <String, String>{
              'padding': '6px 14px',
              'border': 'none',
              'background': _framework == fw ? 'var(--accent)' : 'var(--card)',
              'color': _framework == fw ? 'var(--accent-fg)' : 'var(--fg)',
              'font': '13px inherit',
              'cursor': 'pointer',
            }),
            [Component.text(fw)],
          ),
      ],
    );
  }

  Component _hero() {
    return div(
      styles: Styles(raw: <String, String>{'margin-top': '28px'}),
      [
        div(
          styles: Styles(raw: <String, String>{
            'font': '600 12px system-ui',
            'letter-spacing': '.08em',
            'text-transform': 'uppercase',
            'color': 'var(--subtle)',
          }),
          [Component.text('Core primitives')],
        ),
        h2(
          styles: Styles(raw: <String, String>{
            'margin': '6px 0 10px',
            'font-size': '30px',
          }),
          [Component.text('The kitchen sink, rendered.')],
        ),
        p(
          styles: Styles(raw: <String, String>{
            'color': 'var(--muted)',
            'margin': '0',
            'max-width': '640px',
          }),
          [
            Component.text(
                'Every specimen below is a real template rendered by the '
                'runtime — the same primitives the samples compose, under the '
                'default theme\'s semantic contract. Flip Jaspr / Flutter to '
                'render every one on the other adapter; flip the modes to see '
                'the same roles resolve across light, dark, and high-contrast. '
                'The interactive specimens are live on either adapter.'),
          ],
        ),
        div(
          styles: Styles(raw: <String, String>{
            'margin-top': '12px',
            'font': '12px ui-monospace, SFMono-Regular, Menlo, monospace',
            'color': 'var(--subtle)',
          }),
          [
            Component.text('brand → ${_brand.label}  ·  adapter → $_framework'
                '  ·  active mode → ${_mode.id}')
          ],
        ),
      ],
    );
  }

  Component _sectionCard(_Section s) {
    return section(
      styles: Styles(raw: <String, String>{
        'margin-top': '24px',
        'border':
            'var(--card-border-width, 1px) solid var(--card-border-color, var(--border))',
        'border-radius': 'var(--card-radius, 16px)',
        'padding': '22px 24px',
        'background': 'var(--card)',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'font': '600 12px system-ui',
            'letter-spacing': '.08em',
            'text-transform': 'uppercase',
            'color': 'var(--subtle)',
          }),
          [Component.text(s.title)],
        ),
        p(
          styles: Styles(raw: <String, String>{
            'color': 'var(--muted)',
            'margin': '8px 0 18px',
            'font-size': '14px',
          }),
          [Component.text(s.blurb)],
        ),
        div(
          // The specimen itself. Keyed by section + adapter: stable across
          // mode flips (so control/template state survives re-theming, the
          // same re-theme-in-place contract the sample screens rely on), and
          // remounted when the adapter flips.
          key: ValueKey<String>('specimen-${s.title}-$_framework'),
          [_specimen(s)],
        ),
        if (s.footnote != null)
          div(
            styles: Styles(raw: <String, String>{
              'margin-top': '18px',
              'padding-top': '12px',
              'border-top': '1px solid var(--border)',
              'font': '12px ui-monospace, SFMono-Regular, Menlo, monospace',
              'color': 'var(--subtle)',
            }),
            [Component.text(s.footnote!)],
          ),
      ],
    );
  }

  /// Renders one specimen on the active adapter: the Jaspr [SampleView] DOM
  /// render, or an embedded [FlutterSpecimen] render of the same trio. Both
  /// consume the identical template + schema + messages, so the specimen is
  /// the cross-adapter claim made concrete.
  Component _specimen(_Section s) {
    final Map<String, Object?> schema = <String, Object?>{
      'catalogId': s.surfaceId,
      'components': <String, Object?>{
        'Root': <String, Object?>{'properties': s.schema},
      },
    };
    final List<A2uiMessage> messages = _messagesFor(s);
    if (_framework == 'Flutter') {
      return FlutterSpecimen(
        key: ValueKey<String>('flutter-${s.title}'),
        template: s.template,
        schema: schema,
        messages: messages,
        dark: SiteTheme.effectiveDark,
        theme: _theme,
      );
    }
    return SampleView(
      key: ValueKey<String>('jaspr-${s.title}'),
      template: s.template,
      schema: schema,
      messages: messages,
      theme: _theme,
    );
  }

  /// The A2UI message script that builds one specimen surface: create it, seed
  /// the data model (when the specimen binds one), and place the single `Root`
  /// component — the same shape as a sample trio's `messages.json`.
  static List<A2uiMessage> _messagesFor(_Section s) {
    final String id = s.surfaceId;
    return <A2uiMessage>[
      A2uiMessage.fromJson(<String, dynamic>{
        'version': 'v0.9',
        'createSurface': <String, Object?>{
          'surfaceId': id,
          'catalogId': id,
          'sendDataModel': false,
        },
      }),
      if (s.data.isNotEmpty)
        A2uiMessage.fromJson(<String, dynamic>{
          'version': 'v0.9',
          'updateDataModel': <String, Object?>{
            'surfaceId': id,
            'path': '/',
            // Copied: a2ui_core adopts this map as the live data model and
            // mutates it on two-way writes; [_Section.data] is const.
            'value': <String, Object?>{...s.data},
          },
        }),
      A2uiMessage.fromJson(<String, dynamic>{
        'version': 'v0.9',
        'updateComponents': <String, Object?>{
          'surfaceId': id,
          'components': <Object?>[
            <String, Object?>{'id': 'root', 'component': 'Root', ...s.props},
          ],
        },
      }),
    ];
  }
}

/// One showcase section: chrome (title, blurb, footnote) around a specimen —
/// a `Root` template plus the schema/props/data that bind it, mirroring a
/// sample trio in miniature.
class _Section {
  const _Section({
    required this.title,
    required this.blurb,
    required this.template,
    this.schema = const <String, Object?>{},
    this.props = const <String, Object?>{},
    this.data = const <String, Object?>{},
    this.footnote,
  });

  final String title;
  final String blurb;

  /// The specimen's surface (and catalog) id — unique per section, so each
  /// [SampleView]'s surface is unmistakably its own.
  String get surfaceId =>
      'sink-${title.toLowerCase().replaceAll(RegExp('[^a-z]+'), '-')}';

  /// The specimen catalog: RFW source defining (at least) a `Root` widget.
  final String template;

  /// `Root`'s schema properties (`$ref`s into the common-type vocabulary).
  final Map<String, Object?> schema;

  /// `Root`'s component-instance JSON (bindings like `{"path": "/name"}`).
  final Map<String, Object?> props;

  /// The initial data model, when the specimen binds one.
  final Map<String, Object?> data;

  final String? footnote;
}

const List<_Section> _sections = <_Section>[
  _Section(
    title: 'Text · Heading',
    blurb: 'Plain leaves over the type scale. Text reads color.onSurface; '
        'Heading carries a real heading role and level for assistive tech.',
    template: r'''
import core;

widget Root = Column(gap: 10.0, crossAxisAlignment: "start", children: [
  Heading(text: "Heading 1", level: 1),
  Heading(text: "Heading 2", level: 2),
  Heading(text: "Heading 3", level: 3),
  Heading(text: "Heading 4", level: 4),
  Heading(text: "Heading 5", level: 5),
  Heading(text: "Heading 6", level: 6),
  Text(text: "Body text is the reading default — comfortable at arm's length on a phone and a laptop alike."),
  Text(text: "Caption / secondary text is the muted foreground for metadata, helper text, and labels.", variant: "caption"),
]);
''',
    footnote: 'body → color.onSurface · caption → color.onSurfaceVariant · '
        'sizes → type.heading.n.size / type.body.size / type.caption.size',
  ),
  _Section(
    title: 'Markdown',
    blurb: 'Structural render — never raw HTML. Headings, paragraphs, and '
        'lists with inline emphasis and links.',
    template: r'''
import core;

widget Root = Markdown(text: "## Trip summary\n\nYour flight is confirmed for **Friday**. Bring a valid *ID* and arrive early.\n\n- Seat 14C, aisle\n- One checked bag\n- Gate closes 30 min prior\n\nManage it any time at [your bookings](https://example.com/bookings).");
''',
    footnote:
        'links → color.link · headings → the same heading roles as Heading',
  ),
  _Section(
    title: 'Icon',
    blurb: 'The shared name → glyph subset, identical on both adapters. '
        'Inherits the ambient ink.',
    template: r'''
import core;

widget Root = Wrap(gap: 18.0, runGap: 14.0, children: [
  Icon(icon: "add"), Icon(icon: "check"), Icon(icon: "close"),
  Icon(icon: "delete"), Icon(icon: "edit"), Icon(icon: "email"),
  Icon(icon: "favorite"), Icon(icon: "favoriteOff"), Icon(icon: "notifications"),
  Icon(icon: "person"), Icon(icon: "play"), Icon(icon: "settings"),
  Icon(icon: "star"), Icon(icon: "download"), Icon(icon: "camera"),
]);
''',
    footnote:
        'ink → color.onSurface · inside a themed Button → the content ink',
  ),
  _Section(
    title: 'Image',
    blurb: 'Canonical size variants shared by both adapters, so an image '
        'occupies the same box everywhere. An empty URL renders the '
        'deterministic placeholder.',
    template: r'''
import core;

widget Root = Wrap(gap: 20.0, runGap: 16.0, children: [
  Column(gap: 6.0, crossAxisAlignment: "start", children: [
    Image(url: "", variant: "smallFeature", fit: "cover"),
    Text(text: "smallFeature · cover", variant: "caption"),
  ]),
  Column(gap: 6.0, crossAxisAlignment: "start", children: [
    Image(url: "", variant: "mediumFeature", fit: "contain"),
    Text(text: "mediumFeature · contain", variant: "caption"),
  ]),
  Column(gap: 6.0, crossAxisAlignment: "start", children: [
    Image(url: "", variant: "avatar"),
    Text(text: "avatar", variant: "caption"),
  ]),
  Column(gap: 6.0, crossAxisAlignment: "start", children: [
    Image(url: "", variant: "icon"),
    Text(text: "icon", variant: "caption"),
  ]),
]);
''',
    footnote: 'variants → icon 24 · avatar 48 (circular) · smallFeature 96 · '
        'mediumFeature 160 · largeFeature 280 · header fill×200',
  ),
  _Section(
    title: 'Row · Column · Flex · Expanded',
    blurb: 'One Flex primitive; Row and Column pin its axis. Sizing is '
        'explicit — a default Flex hugs both axes; width: "fill" opts into '
        'free space for mainAxisAlignment to distribute.',
    template: r'''
import core;

widget Sw = Box(width: 36.0, height: 20.0, color: args.c);

widget Root = Column(gap: 6.0, crossAxisAlignment: "start", children: [
  Text(text: "Row · gap: 8", variant: "caption"),
  Row(gap: 8.0, children: [
    Sw(c: "#1A73E8"), Sw(c: "#669DF6"), Sw(c: "#AECBFA"),
  ]),
  SizedBox(height: 8.0),
  Text(text: "width: \"fill\" · mainAxisAlignment: \"spaceBetween\"", variant: "caption"),
  Row(width: "fill", mainAxisAlignment: "spaceBetween", children: [
    Sw(c: "#1A73E8"), Sw(c: "#669DF6"), Sw(c: "#AECBFA"),
  ]),
  SizedBox(height: 8.0),
  Text(text: "width: \"fill\" · mainAxisAlignment: \"center\"", variant: "caption"),
  Row(width: "fill", mainAxisAlignment: "center", gap: 8.0, children: [
    Sw(c: "#1A73E8"), Sw(c: "#669DF6"), Sw(c: "#AECBFA"),
  ]),
  SizedBox(height: 8.0),
  Text(text: "Expanded takes the free space", variant: "caption"),
  Row(width: "fill", gap: 8.0, children: [
    Sw(c: "#1A73E8"),
    Expanded(child: Box(width: "fill", height: 20.0, color: "#AECBFA")),
    Sw(c: "#1A73E8"),
  ]),
  SizedBox(height: 8.0),
  Text(text: "Flex(direction: \"vertical\") — a Column is exactly this", variant: "caption"),
  Flex(direction: "vertical", gap: 6.0, children: [
    Sw(c: "#1A73E8"), Sw(c: "#669DF6"),
  ]),
]);
''',
    footnote: 'hug is the default on both axes · fill/fixed are opt-in — the '
        'same template lays out identically on Flutter (DESIGN.md §8)',
  ),
  _Section(
    title: 'Box · SizedBox · Center · Align · AspectRatio · Wrap · Opacity',
    blurb: 'The container and placement primitives, on the shared border-box '
        'model. The swatches are explicit author colors, not roles.',
    template: r'''
import core;

widget Sw = Box(width: 36.0, height: 20.0, color: args.c);

widget Root = Column(gap: 6.0, crossAxisAlignment: "start", children: [
  Text(text: "Box · padding: 12 · background", variant: "caption"),
  Box(padding: 12.0, color: "#331A73E8", child: Text(text: "A padded Box")),
  SizedBox(height: 8.0),
  Text(text: "SizedBox as a 32px spacer between swatches", variant: "caption"),
  Row(children: [Sw(c: "#1A73E8"), SizedBox(width: 32.0), Sw(c: "#1A73E8")]),
  SizedBox(height: 8.0),
  Text(text: "Center within a fixed 220×64 Box", variant: "caption"),
  Box(width: 220.0, height: 64.0, color: "#331A73E8",
    child: Center(child: Text(text: "Center"))),
  SizedBox(height: 8.0),
  Text(text: "Align(alignment: \"bottomRight\") in the same box", variant: "caption"),
  Box(color: "#331A73E8", child: Align(alignment: "bottomRight",
    width: 220.0, height: 64.0, child: Sw(c: "#1A73E8"))),
  SizedBox(height: 8.0),
  Text(text: "AspectRatio(ratio: 1.78) under a 160px width", variant: "caption"),
  SizedBox(width: 160.0, child: AspectRatio(ratio: 1.78,
    child: Box(width: "fill", height: "fill", color: "#669DF6"))),
  SizedBox(height: 8.0),
  Text(text: "Wrap · gap: 8 · runGap: 8, forced by a 240px Box", variant: "caption"),
  Box(width: 240.0, child: Wrap(gap: 8.0, runGap: 8.0, children: [
    Sw(c: "#1A73E8"), Sw(c: "#669DF6"), Sw(c: "#AECBFA"),
    Sw(c: "#1A73E8"), Sw(c: "#669DF6"), Sw(c: "#AECBFA"),
    Sw(c: "#1A73E8"), Sw(c: "#669DF6"),
  ])),
  SizedBox(height: 8.0),
  Text(text: "Opacity · 1.0 / 0.7 / 0.4 / 0.15", variant: "caption"),
  Row(gap: 8.0, children: [
    Opacity(opacity: 1.0, child: Sw(c: "#1A73E8")),
    Opacity(opacity: 0.7, child: Sw(c: "#1A73E8")),
    Opacity(opacity: 0.4, child: Sw(c: "#1A73E8")),
    Opacity(opacity: 0.15, child: Sw(c: "#1A73E8")),
  ]),
]);
''',
    footnote: 'Box margin is part of the measured box on both adapters · '
        '#AARRGGBB colors are the author\'s, outside the contract',
  ),
  _Section(
    title: 'Card · Divider',
    blurb: 'Card paints the surface role; Divider inks a hairline with the '
        'outline role, horizontal or vertical.',
    template: r'''
import core;

widget Root = Card(child: Column(gap: 10.0, crossAxisAlignment: "start", children: [
  Heading(text: "Card", level: 5),
  Text(text: "An elevated surface with the stock 16px content padding."),
  Divider(),
  Row(gap: 12.0, crossAxisAlignment: "center", children: [
    Text(text: "Left", variant: "caption"),
    Divider(axis: "vertical"),
    Text(text: "Right of a vertical divider", variant: "caption"),
  ]),
]));
''',
    footnote: 'card surface → color.surface · divider → color.outline',
  ),
  _Section(
    title: 'ScrollView · List',
    blurb: 'Scroll them — ScrollView scrolls a taller column inside a bounded '
        'box; List is the A2UI catalog scroller, shown horizontal here.',
    template: r'''
import core;

widget Tile = Box(padding: [12.0, 20.0], color: args.c,
  child: Text(text: args.t, variant: "caption"));

widget Root = Column(gap: 6.0, crossAxisAlignment: "stretch", children: [
  Text(text: "ScrollView · a 120px box scrolls its taller column", variant: "caption"),
  Box(width: "fill", height: 120.0, color: "#22000000",
    child: ScrollView(child: Column(gap: 6.0, crossAxisAlignment: "stretch", children: [
      Tile(c: "#331A73E8", t: "one"), Tile(c: "#33669DF6", t: "two"),
      Tile(c: "#331A73E8", t: "three"), Tile(c: "#33669DF6", t: "four"),
      Tile(c: "#331A73E8", t: "five"), Tile(c: "#33669DF6", t: "six"),
      Tile(c: "#331A73E8", t: "seven"), Tile(c: "#33669DF6", t: "eight"),
    ]))),
  SizedBox(height: 8.0),
  Text(text: "List(direction: \"horizontal\") — scroll it sideways", variant: "caption"),
  List(direction: "horizontal", align: "center", children: [
    Tile(c: "#331A73E8", t: "alpha"), Tile(c: "#33669DF6", t: "beta"),
    Tile(c: "#331A73E8", t: "gamma"), Tile(c: "#33669DF6", t: "delta"),
    Tile(c: "#331A73E8", t: "epsilon"), Tile(c: "#33669DF6", t: "zeta"),
    Tile(c: "#331A73E8", t: "eta"), Tile(c: "#33669DF6", t: "theta"),
    Tile(c: "#331A73E8", t: "iota"), Tile(c: "#33669DF6", t: "kappa"),
    Tile(c: "#331A73E8", t: "lambda"), Tile(c: "#33669DF6", t: "mu"),
    Tile(c: "#331A73E8", t: "nu"), Tile(c: "#33669DF6", t: "xi"),
  ]),
]);
''',
    footnote: 'ScrollView fills a bounded ancestor and scrolls; List scrolls '
        'along its axis',
  ),
  _Section(
    title: 'Button',
    blurb: 'The control owns all four paint layers: surface, state layer '
        '(hover/press it), content, and composite effects. Every enabled '
        'button below increments the same template-state counter.',
    template: r'''
import core;

widget Root { n: 0 } = Column(gap: 14.0, crossAxisAlignment: "start", children: [
  Wrap(gap: 12.0, runGap: 12.0, children: [
    Button(onPressed: set state.n = add(a: state.n, b: 1),
      child: Text(text: "Default")),
    Button(onPressed: set state.n = add(a: state.n, b: 1), color: "#B3261E",
      child: Text(text: "Explicit color")),
    Button(onPressed: set state.n = add(a: state.n, b: 1), color: "#00000000",
      child: Text(text: "Text button")),
    Button(onPressed: set state.n = add(a: state.n, b: 1), cornerRadius: 999.0,
      child: Text(text: "Pill")),
    Button(onPressed: set state.n = add(a: state.n, b: 1),
      child: Row(gap: 6.0, crossAxisAlignment: "center", children: [
        Icon(icon: "add"), Text(text: "With icon"),
      ])),
    Button(child: Text(text: "Disabled")),
  ]),
  Row(gap: 5.0, children: [
    Text(text: "Pressed", variant: "caption"),
    Text(text: state.n, variant: "caption"),
    Text(text: "times — pure template state, no host code.", variant: "caption"),
  ]),
]);
''',
    footnote: 'default → color.primary / color.onPrimary content ink · an '
        'explicit color owns the surface, the ambient ink stands · '
        'transparent = text button · no handler = disabled',
  ),
  _Section(
    title: 'TextField',
    blurb: 'The bare input — the label is a template composing a caption '
        'above it. Two-way bound: edits round-trip through the A2UI data '
        'model.',
    template: r'''
import core;

widget Root = Column(gap: 6.0, crossAxisAlignment: "start", children: [
  Text(text: "Full name", variant: "caption"),
  TextField(value: args.value, onChanged: args.setValue),
  Text(text: "Shown on your public profile.", variant: "caption"),
]);
''',
    schema: <String, Object?>{
      'value': <String, Object?>{r'$ref': 'DynamicString'},
    },
    props: <String, Object?>{
      'value': <String, Object?>{'path': '/name'},
    },
    data: <String, Object?>{'name': 'Ada Lovelace'},
    footnote: 'box → color.outline · focus border + caret → color.primary · '
        'ink → color.onSurface',
  ),
  _Section(
    title: 'Checkbox · Radio · Switch',
    blurb: 'Interactive — try them. Checked states fill with color.primary '
        'per the role mapping; grouping the radios is the template\'s job.',
    template: r'''
import core;

widget Root { check: true, sync: true, ship: "Standard" } =
  Column(gap: 12.0, crossAxisAlignment: "start", children: [
    Row(gap: 8.0, crossAxisAlignment: "center", children: [
      Checkbox(value: state.check,
        onChanged: set state.check = switch state.check { true: false, false: true }),
      Text(text: "Enable notifications"),
    ]),
    Row(gap: 8.0, crossAxisAlignment: "center", children: [
      Checkbox(value: true),
      Text(text: "Disabled (no handler)", variant: "caption"),
    ]),
    Row(gap: 10.0, crossAxisAlignment: "center", children: [
      Radio(selected: equals(a: state.ship, b: "Standard"),
        onChanged: set state.ship = "Standard"),
      Text(text: "Standard"),
      Radio(selected: equals(a: state.ship, b: "Express"),
        onChanged: set state.ship = "Express"),
      Text(text: "Express"),
      Radio(selected: equals(a: state.ship, b: "Overnight"),
        onChanged: set state.ship = "Overnight"),
      Text(text: "Overnight"),
    ]),
    Row(gap: 8.0, crossAxisAlignment: "center", children: [
      Switch(value: state.sync,
        onChanged: set state.sync = switch state.sync { true: false, false: true }),
      Text(text: "Auto-sync"),
    ]),
    Row(gap: 8.0, crossAxisAlignment: "center", children: [
      Switch(value: true),
      Text(text: "Disabled (no handler)", variant: "caption"),
    ]),
  ]);
''',
    footnote: 'checked fill → color.primary · mark/thumb → color.onPrimary · '
        'unchecked chrome → color.outline · the radio group is template state '
        '+ equals()',
  ),
  _Section(
    title: 'Slider',
    blurb: 'Two-way bound to the data model: drag it and the caption readout '
        'follows the same binding.',
    template: r'''
import core;

widget Root = Row(width: "fill", gap: 12.0, crossAxisAlignment: "center", children: [
  Text(text: "Brightness"),
  Expanded(child: Box(height: 44.0, child: Slider(min: 0.0, max: 100.0,
    steps: 100, value: args.value, onChanged: args.setValue))),
  Text(text: args.value, variant: "caption"),
]);
''',
    schema: <String, Object?>{
      'value': <String, Object?>{r'$ref': 'DataBinding'},
    },
    props: <String, Object?>{
      'value': <String, Object?>{'path': '/brightness'},
    },
    data: <String, Object?>{'brightness': 64},
    footnote: 'active track + thumb → color.primary · inactive track → '
        'color.outline',
  ),
  _Section(
    title: 'Select',
    blurb: 'A single-choice dropdown over string options, sharing the '
        'TextField chrome. Two-way bound to the data model.',
    template: r'''
import core;

widget Root = Row(gap: 10.0, crossAxisAlignment: "center", children: [
  Text(text: "Size"),
  Select(value: args.value, options: ["Small", "Medium", "Large"],
    onChanged: args.setValue),
]);
''',
    schema: <String, Object?>{
      'value': <String, Object?>{r'$ref': 'DynamicString'},
    },
    props: <String, Object?>{
      'value': <String, Object?>{'path': '/size'},
    },
    data: <String, Object?>{'size': 'Medium'},
    footnote: 'chrome → color.outline · focus → color.primary · ink → '
        'color.onSurface',
  ),
];
