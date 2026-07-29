// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:js_interop';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:jaspr_router/jaspr_router.dart';
import 'package:web/web.dart' as web;

import 'brand_themes.dart';
import 'flutter_host.dart';
import 'icons.dart';
import 'menu.dart';
import 'segmented.dart';
import 'theme_mode.dart';

/// Width of the editor sidebar when open, in CSS px. Subtracted from the
/// viewport to decide whether the preview pane is wide enough for side-by-side.
const int _editorWidth = 420;

/// Minimum preview-pane width (viewport minus the editor) to show the Jaspr and
/// Flutter renders side by side. Below it, the two collapse into a Jaspr/Flutter
/// tab toggle.
const int _sideBySideMin = 800;

/// Viewport width (CSS px) at or below which this screen is in its phone
/// layout. Mirrors the `wide-only` / `narrow-only` breakpoint in
/// `web/index.html`, which is where the *chrome's* visibility is decided — a
/// media query keeps that correct through a resize with no rebuild. The panes
/// cannot be done in CSS, though: side by side with a 420px editor there is no
/// room left for a preview, so below this width the editor takes the screen
/// and the preview steps aside. That swap is a build-time decision, hence the
/// duplicated number.
const int _phoneMax = 720;

/// One render pane: its label strip's text, the render itself, and an optional
/// control that rides in the strip (only the Flutter pane has one — the idiom
/// picker). Header and body are placed into the grid separately, so they
/// travel together as data rather than as one nested component.
typedef _Pane = ({String label, Component child, Component? trailing});

/// One sample on its own screen: a toolbar (back, title, edit, Jaspr/Flutter
/// toggle) over the rendered surface and an action log, with an optional editor
/// sidebar — one tab per project file (template / schema / app bootstrap, plus
/// the theme for a themed project) with live Preview.
///
/// When the preview pane (viewport minus the editor) is at least
/// [_sideBySideMin] wide, the Jaspr and Flutter renders show side by side;
/// otherwise they collapse into a tab toggle.
///
/// A themed project's mode follows the browser/system dark-light preference
/// until the user picks a mode explicitly; the site chrome follows it always
/// (CSS variables in `web/index.html`).
class SampleScreen extends StatefulComponent {
  const SampleScreen({required this.id, super.key});

  final String id;

  @override
  State<SampleScreen> createState() => _SampleScreenState();
}

class _SampleScreenState extends State<SampleScreen> {
  late final RawSample _raw = rawSamples.firstWhere(
    (RawSample r) => r.id == component.id,
    orElse: () => rawSamples.first,
  );

  String _framework = 'Jaspr';
  bool _editorOpen = false;
  bool _wide = false;
  bool _phone = false;
  // The Flutter pane previews a *mobile platform* (DESIGN.md §8); this picks
  // which idiom the embedded app renders its controls in.
  bool _cupertino = false;
  int _renderKey = 0;
  // The Jaspr pane's element identity — a *global* key, because the pane
  // re-parents when [_wide] flips (one pane ⇄ two) and a local key cannot
  // match across parents: with a ValueKey the flip silently remounted
  // SampleView, re-processing the messages and wiping any interaction state
  // in the surface's data model (observed when the Flutter embed's boot
  // coincided with a window resize). Theme and mode changes keep this key
  // too — the Jaspr pane re-themes in place via SampleView's `theme` prop —
  // so only Preview, which commits a genuinely new spec, replaces it.
  GlobalKey _jasprKey = GlobalKey();
  String? _error;
  final List<String> _log = <String>[];

  // The project's theme, if it ships one (its manifest theme block, §10), and
  // the mode the host has selected — the render-time n-ary mode input (§9.5).
  // Null theme ⇒ no picker, surface blends into the host. The mode tracks the
  // system dark-light preference until the user touches the picker.
  late ProjectTheme? _project = ProjectTheme.tryParse(_raw.theme);
  late CraftThemeMode? _mode = _project?.modeFor(dark: SiteTheme.effectiveDark);
  bool _modeTouched = false;

  // The theme resolves for the active mode *and* size class — the second cascade
  // axis (RESPONSIVE_DESIGN.md §4.4): a brand's type scale bumps at `expanded`+.
  // Non-responsive samples resolve at the base (compact) scale.
  CraftTheme? get _theme => _project?.resolve(
      _mode, _usesResponsive ? _sizeClass : WindowSizeClass.compact);

  // The responsive window size class the host feeds the surface — the second
  // render-time input axis (research/responsive/RESPONSIVE_DESIGN.md), driving
  // both the `Responsive`/`media.` layout and the theme's size-class overlay.
  // Only supplied to samples that use responsiveness (others stay size-agnostic);
  // the picker appears only for them. Defaults to `expanded` so the demo opens
  // on its side-by-side layout.
  WindowSizeClass _sizeClass = WindowSizeClass.expanded;

  bool get _usesResponsive =>
      _template.contains('Responsive(') || _template.contains('media.');

  MediaContext? get _media =>
      _usesResponsive ? MediaContext(width: _sizeClass) : null;

  // The rendered (active) sources; the editor edits drafts and commits them on
  // Preview. Drafts are what the editor fields display, so switching tabs
  // never discards unprevewed edits.
  late String _template = _raw.template;
  late String _schema = _raw.schema;
  late String _messages = _raw.messages;
  late String _dTemplate = _template;
  late String _dSchema = _schema;
  late String _dMessages = _messages;
  late String _dTheme = _raw.theme ?? '';

  /// The active editor tab.
  String _tab = 'Template';

  // The embedded Flutter widget is memoized so an action-log rebuild doesn't
  // tear down and re-run the Flutter surface; it is recreated only on Preview.
  Object? _flutterWidget;

  // The Flutter content's self-measured height (see flutterSampleApp): the
  // host element is sized to it, so the embed hugs its content like the Jaspr
  // pane does. Null until the first report lands (the fallback height shows).
  double? _flutterHeight;

  JSFunction? _resizeListener;
  void Function()? _unsubscribeTheme;

  @override
  void initState() {
    super.initState();
    _wide = _computeWide();
    _phone = _computePhone();
    _resizeListener = ((web.Event _) => _updateLayout()).toJS;
    web.window.addEventListener('resize', _resizeListener);
    // Re-theme when the effective scheme changes (the global toggle, or the
    // system preference flipping in System mode). The Jaspr pane re-inks via
    // CSS; the embedded Flutter shell needs a rebuild (its ThemeMode is
    // passed explicitly), and a themed project re-picks its mode unless the
    // user has taken over the mode picker.
    _unsubscribeTheme = SiteTheme.onChange(() {
      setState(() {
        final ProjectTheme? project = _project;
        if (project != null && !_modeTouched) {
          _mode = project.modeFor(dark: SiteTheme.effectiveDark);
        }
        _flutterWidget = null;
        _renderKey++;
      });
    });
  }

  @override
  void dispose() {
    if (_resizeListener != null) {
      web.window.removeEventListener('resize', _resizeListener);
    }
    _unsubscribeTheme?.call();
    super.dispose();
  }

  bool _computeWide() {
    // On a phone the editor is an overlay rather than a sidebar, so it takes
    // nothing away from the preview's width.
    final int avail = web.window.innerWidth -
        (_editorOpen && !_computePhone() ? _editorWidth : 0);
    return avail >= _sideBySideMin;
  }

  bool _computePhone() => web.window.innerWidth <= _phoneMax;

  void _updateLayout() {
    final bool wide = _computeWide();
    final bool phone = _computePhone();
    if (wide == _wide && phone == _phone) return;
    setState(() {
      _wide = wide;
      _phone = phone;
    });
  }

  void _onAction(A2uiClientAction a) {
    setState(() {
      _log.insert(
        0,
        '▸ ${a.name}  ·  ${a.sourceComponentId}'
        '${a.context.isEmpty ? '' : '  ·  ${jsonEncode(a.context)}'}',
      );
      if (_log.length > 50) _log.removeLast();
    });
  }

  void _preview() {
    try {
      // Validate by decoding before committing.
      SampleSpec.fromData(
        label: _raw.label,
        template: _dTemplate,
        schemaJson: _dSchema,
        messagesJson: _dMessages,
        framework: _framework,
      );
      // ProjectTheme.tryParse is total (a broken theme silently unthemes), so
      // surface JSON syntax errors here where the author can see them. An
      // emptied theme editor deliberately unthemes the project.
      if (_dTheme.trim().isNotEmpty) {
        jsonDecode(_dTheme);
      }
      final ProjectTheme? project = ProjectTheme.tryParse(_dTheme);
      setState(() {
        _template = _dTemplate;
        _schema = _dSchema;
        _messages = _dMessages;
        _project = project;
        if (project == null) {
          _mode = null;
        } else if (_mode == null || !project.availableModes.contains(_mode)) {
          _mode = _modeTouched
              ? project.defaultMode
              : project.modeFor(dark: SiteTheme.effectiveDark);
        }
        _error = null;
        _flutterWidget = null;
        _log.clear();
        _renderKey++;
        // On a phone the editor covers the preview, so committing hands the
        // screen back — otherwise "Preview ▸" would look like it did nothing.
        if (_phone) _editorOpen = false;
        // A new spec must re-process from scratch: swap the Jaspr pane's
        // identity so a fresh SampleView (and data model) mounts.
        _jasprKey = GlobalKey();
      });
    } catch (e) {
      setState(() => _error = '$e');
    }
  }

  Object _makeFlutterWidget() {
    final SampleSpec spec = SampleSpec.fromData(
      label: _raw.label,
      template: _template,
      schemaJson: _schema,
      messagesJson: _messages,
      framework: 'Flutter',
    );
    return flutterSampleApp(
      template: spec.catalogSource,
      schema: spec.catalogSchema,
      messages: spec.messages,
      dark: SiteTheme.effectiveDark,
      cupertino: _cupertino,
      onAction: _onAction,
      onContentHeight: (double height) {
        // Reported from Flutter's frame callbacks — may land after this
        // screen unmounted (embed teardown is async).
        if (!mounted) return;
        // Ignore a non-finite report (an intrinsic-height measurement can
        // momentarily yield infinity for an unbounded layout); keep the last
        // good height rather than poisoning the pane's CSS height.
        if (!height.isFinite) return;
        final double px = height.ceilToDouble();
        if (_flutterHeight == px) return;
        setState(() => _flutterHeight = px);
      },
      theme: _theme,
      media: _media,
    );
  }

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(raw: <String, String>{
        'font-family': 'system-ui, -apple-system, sans-serif',
        'height': '100vh',
        'display': 'flex',
        'flex-direction': 'column',
      }),
      [
        _toolbar(context),
        div(
          styles: Styles(raw: <String, String>{
            'flex': '1',
            'display': 'flex',
            'min-height': '0',
          }),
          [
            // On a phone the editor takes the whole screen instead of sharing
            // it: 420px of sidebar beside a ~390px viewport leaves the preview
            // nothing, and a preview squeezed to a sliver is worse than one
            // that's a tap away.
            if (!(_phone && _editorOpen)) _renderColumn(),
            if (_editorOpen) _editor(),
          ],
        ),
      ],
    );
  }

  Component _renderColumn() {
    return div(
      styles: Styles(raw: <String, String>{
        'flex': '1',
        'display': 'flex',
        'flex-direction': 'column',
        'min-width': '0',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'flex': '1',
            'display': 'flex',
            'min-height': '0',
          }),
          [_previewPanes()],
        ),
        _logPanel(),
      ],
    );
  }

  /// Side-by-side Jaspr + Flutter panes when wide; otherwise the single active
  /// (tab-selected) render.
  ///
  /// One **grid**, not a row of self-contained columns. As columns each pane
  /// sized its own header, so the Flutter header — which carries the idiom
  /// picker, and a native `select` is taller than an 11px label — sat a few
  /// pixels lower than Jaspr's, and the divider between them stepped. A
  /// two-row grid (`auto` for the headers, the remainder for the renders)
  /// makes every header share one row and every render start at the same y,
  /// which is the entire point of showing the two adapters side by side.
  Component _previewPanes() {
    final List<_Pane> panes = _wide
        ? <_Pane>[
            (label: 'Jaspr', child: _jasprView(), trailing: null),
            (label: 'Flutter', child: _flutterView(), trailing: _idiomToggle()),
          ]
        : <_Pane>[
            (
              label: _framework,
              child: _framework == 'Jaspr' ? _jasprView() : _flutterView(),
              trailing: _framework == 'Flutter' ? _idiomToggle() : null,
            ),
          ];
    return div(
      styles: Styles(raw: <String, String>{
        'flex': '1',
        'min-width': '0',
        'display': 'grid',
        // minmax(0, 1fr), not 1fr: a bare 1fr floors at the content's minimum
        // size, which a wide render (a long Text, a horizontal List) would
        // push past its share and out of the pane.
        'grid-template-columns': 'repeat(${panes.length}, minmax(0, 1fr))',
        'grid-template-rows': 'auto minmax(0, 1fr)',
      }),
      <Component>[
        // Row-major auto-placement: the headers fill row one, the renders
        // row two.
        for (int i = 0; i < panes.length; i++)
          _paneHeader(panes[i], borderRight: i < panes.length - 1),
        for (int i = 0; i < panes.length; i++)
          _paneBody(panes[i], borderRight: i < panes.length - 1),
      ],
    );
  }

  /// The Flutter pane previews a mobile platform; this picks the idiom the
  /// embedded app renders its controls in (ThemeData.platform steering the
  /// .adaptive constructors, the Button's state layer and corner style).
  Component _idiomToggle() {
    return select(
      styles: Styles(raw: <String, String>{'font': '11px system-ui'}),
      onChange: (List<String> values) {
        final bool next = values.isNotEmpty && values.first == 'cupertino';
        if (next == _cupertino) return;
        setState(() {
          _cupertino = next;
          // Rebuild the embedded app so ThemeData.platform re-resolves.
          _flutterWidget = null;
        });
      },
      [
        option(
            value: 'material',
            selected: !_cupertino,
            [Component.text('Material')]),
        option(
            value: 'cupertino',
            selected: _cupertino,
            [Component.text('Cupertino')]),
      ],
    );
  }

  /// A pane's label strip, with its optional trailing control.
  ///
  /// Grid stretches every cell in a row to the row's height, so this sizes
  /// itself from its own content *and* from its neighbour's — which is what
  /// keeps the two labels on one baseline. The vertical padding is a minimum
  /// rather than the whole story: `align-items: center` re-centres the label
  /// when the other pane's header is the taller one.
  Component _paneHeader(_Pane pane, {required bool borderRight}) {
    return div(
      styles: Styles(raw: <String, String>{
        'font': '600 11px system-ui',
        'letter-spacing': '.05em',
        'text-transform': 'uppercase',
        'color': 'var(--subtle)',
        'padding': '8px 24px',
        'border-bottom': '1px solid var(--border)',
        if (borderRight) 'border-right': '1px solid var(--border)',
        'display': 'flex',
        'align-items': 'center',
        'justify-content': 'space-between',
        'gap': '12px',
      }),
      <Component>[
        Component.text(pane.label),
        if (pane.trailing != null) pane.trailing!,
      ],
    );
  }

  /// A pane's render, scrolling independently of its neighbour.
  Component _paneBody(_Pane pane, {required bool borderRight}) {
    return div(
      styles: Styles(raw: <String, String>{
        'min-width': '0',
        'min-height': '0',
        'overflow': 'auto',
        'padding': '24px',
        if (borderRight) 'border-right': '1px solid var(--border)',
      }),
      <Component>[pane.child],
    );
  }

  Component _jasprView() {
    final SampleSpec spec = SampleSpec.fromData(
      label: _raw.label,
      template: _template,
      schemaJson: _schema,
      messagesJson: _messages,
      framework: 'Jaspr',
    );
    return SampleView(
      key: _jasprKey,
      template: spec.catalogSource,
      schema: spec.catalogSchema,
      messages: spec.messages,
      onAction: _onAction,
      theme: _theme,
      media: _media,
    );
  }

  Component _flutterView() {
    _flutterWidget ??= _makeFlutterWidget();
    return FlutterEmbedView(
      key: ValueKey<String>('flutter-$_renderKey'),
      styles: Styles(raw: <String, String>{
        'width': '100%',
        // Or `width: 100%` plus the border overhangs the pane by the border's
        // two pixels, which was enough to give the Flutter pane a phantom
        // horizontal scrollbar.
        'box-sizing': 'border-box',
        // Sized to the Flutter content's self-measured height; the fixed
        // fallback shows until the first report lands (or if a report was
        // non-finite and thus ignored).
        'height':
            '${(_flutterHeight != null && _flutterHeight!.isFinite ? _flutterHeight! : 640).ceil()}px',
        'border': '1px solid var(--border)',
        'border-radius': '10px',
        'overflow': 'hidden',
      }),
      widget: _flutterWidget as dynamic,
    );
  }

  Component _logPanel() {
    return div(
      styles: Styles(raw: <String, String>{
        'border-top': '1px solid var(--border)',
        'padding': '8px 24px',
        'max-height': '140px',
        'overflow': 'auto',
        'font': '12px ui-monospace, monospace',
        'color': 'var(--fg)',
        'background': 'var(--panel)',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'color': 'var(--subtle)',
            'margin-bottom': '4px',
          }),
          [Component.text('Action log (dispatched A2UI events)')],
        ),
        if (_log.isEmpty)
          div(
              styles: Styles(raw: <String, String>{'color': 'var(--faint)'}),
              [Component.text('No events yet — interact with the sample.')])
        else
          for (final String line in _log)
            div(
                styles: Styles(raw: <String, String>{'white-space': 'pre'}),
                [Component.text(line)]),
      ],
    );
  }

  /// The sample toolbar.
  ///
  /// Six controls compete for this row — window size class, brand, project
  /// mode, color scheme, the editor, and the adapter — next to the back button
  /// and the title. On a desk that fits; on a phone it does not, and the
  /// earlier attempt to keep a chosen few visible still wrapped the bar onto a
  /// second line, which is worse than a menu: it costs vertical space on the
  /// axis a phone has least of, on every screen, whether or not you touch a
  /// control.
  ///
  /// So the narrow bar is exactly three things — back, title, overflow — and
  /// *every* option lives in the menu. Above the breakpoint the axes spread
  /// back out and the overflow disappears.
  Component _toolbar(BuildContext context) {
    return div(
      classes: 'toolbar',
      styles: Styles(raw: <String, String>{
        'padding': '12px 20px',
        'border-bottom': '1px solid var(--border)',
      }),
      [
        // The circled arrow alone: "back" needs no gloss, and the title beside
        // it already says where you are.
        button(
          classes: 'back-btn',
          onClick: () => context.push('/'),
          attributes: const <String, String>{
            'aria-label': 'Back to gallery',
            'title': 'Back to gallery',
          },
          [
            span(classes: 'back-badge', <Component>[backIcon()]),
          ],
        ),
        h2(classes: 'toolbar-title', [Component.text(_raw.label)]),
        div(classes: 'toolbar-actions', <Component>[
          if (_usesResponsive)
            CraftMenu(
              className: 'wide-only',
              ariaLabel: 'Window size class',
              label: _sizeClassLabel(_sizeClass),
              items: _sizeClassItems(),
            ),
          CraftMenu(
            className: 'wide-only',
            ariaLabel: 'Theme',
            label: _brandLabel(),
            items: _brandItems(),
          ),
          if (_project != null)
            CraftMenu(
              className: 'wide-only',
              ariaLabel: 'Theme mode',
              label: (_mode ?? _project!.defaultMode).label,
              items: _modeItems(),
            ),
          const ThemeToggle(className: 'wide-only'),
          button(
            classes: 'wide-only',
            onClick: _toggleEditor,
            styles: _btn(_editorOpen),
            attributes: const <String, String>{
              'aria-label': 'Code editor',
              'title': 'Code editor',
            },
            <Component>[editIcon()],
          ),
          // When wide, both renders show at once, so the adapter switch is
          // hidden — there is nothing to switch between.
          if (!_wide)
            CraftSegmented(
              className: 'wide-only',
              ariaLabel: 'Rendering adapter',
              options: const <String>['Jaspr', 'Flutter'],
              selected: _framework,
              onSelect: (String fw) => setState(() => _framework = fw),
            ),
          // Below the breakpoint every one of the above arrives here instead.
          CraftMenu(
            className: 'narrow-only',
            ariaLabel: 'Options',
            icon: menuIcon(),
            iconOnly: true,
            // Right-anchored (the default): the title's flex-grow pushes this
            // to the bar's right edge, so the panel has to open leftward or it
            // runs off the screen.
            items: _overflowItems(),
          ),
        ]),
      ],
    );
  }

  /// Every toolbar option, flattened into one menu for the narrow layout.
  ///
  /// The adapter switch reads as a two-value axis here rather than a segmented
  /// control: inside a menu panel a segment would be the odd shape out, and
  /// the panel already spells every other axis the same way.
  List<MenuItem> _overflowItems() => <MenuItem>[
        if (!_wide) ...<MenuItem>[
          const MenuItem.heading('Renderer'),
          for (final String fw in const <String>['Jaspr', 'Flutter'])
            MenuItem(
              label: fw,
              selected: _framework == fw,
              onSelect: () => setState(() => _framework = fw),
            ),
        ],
        if (_usesResponsive) ...<MenuItem>[
          const MenuItem.heading('Window size'),
          ..._sizeClassItems(),
        ],
        const MenuItem.heading('Theme'),
        ..._brandItems(),
        if (_project != null) ...<MenuItem>[
          const MenuItem.heading('Mode'),
          ..._modeItems(),
        ],
        const MenuItem.heading('Color scheme'),
        ...siteThemeItems(),
        const MenuItem.heading('Code'),
        MenuItem(
          label: 'Code editor',
          icon: editIcon(),
          toggle: true,
          selected: _editorOpen,
          onSelect: _toggleEditor,
        ),
      ];

  void _toggleEditor() => setState(() {
        _editorOpen = !_editorOpen;
        _wide = _computeWide();
      });

  /// The render-time n-ary **mode** input for a themed project (§9.5): pick
  /// among the project theme's available modes; both renders re-theme to it.
  /// An explicit pick stops the mode from auto-following the system setting.
  List<MenuItem> _modeItems() {
    final ProjectTheme project = _project!;
    final CraftThemeMode active = _mode ?? project.defaultMode;
    return <MenuItem>[
      for (final CraftThemeMode m in project.availableModes)
        MenuItem(
          label: m.label,
          selected: m == active,
          onSelect: () => setState(() {
            _modeTouched = true;
            _mode = m;
            // Recreate the embedded Flutter app so it re-themes; the Jaspr
            // pane re-themes in place via its `theme` prop, keeping its state.
            _flutterWidget = null;
            _renderKey++;
          }),
        ),
    ];
  }

  /// The window size-class picker (shown only for samples that use the
  /// `Responsive` primitive): a menu feeding the surface a
  /// [MediaContext] — the second render-time input axis. Flipping it re-renders
  /// both panes in place (the Jaspr pane via the ambient media scope; the
  /// Flutter embed rebuilds), so a `Responsive` restructures live.
  static const List<(WindowSizeClass, String)> _sizeClasses =
      <(WindowSizeClass, String)>[
    (WindowSizeClass.compact, 'Compact'),
    (WindowSizeClass.medium, 'Medium'),
    (WindowSizeClass.expanded, 'Expanded'),
    (WindowSizeClass.large, 'Large'),
    (WindowSizeClass.extraLarge, 'XL'),
  ];

  String _sizeClassLabel(WindowSizeClass c) =>
      _sizeClasses.firstWhere((rec) => rec.$1 == c).$2;

  List<MenuItem> _sizeClassItems() => <MenuItem>[
        for (final (WindowSizeClass, String) c in _sizeClasses)
          MenuItem(
            label: c.$2,
            selected: c.$1 == _sizeClass,
            onSelect: () {
              if (c.$1 == _sizeClass) return;
              setState(() {
                _sizeClass = c.$1;
                // The Jaspr pane re-renders in place via the ambient media
                // scope; the memoized Flutter embed must be rebuilt to see the
                // new class (like a mode/theme change).
                _flutterWidget = null;
                _renderKey++;
              });
            },
          ),
      ];

  /// The brand-theme picker: a menu (like the `/primitives` page's)
  /// that restyles this sample. Picking a brand drops its theme block into the
  /// editable **Theme** tab and applies it live; **Default** clears the theme,
  /// so the sample blends into the host again. A brand is checked only while the
  /// Theme draft still matches it verbatim — hand-edit the JSON and the trigger
  /// reads `Custom`.
  List<MenuItem> _brandItems() => <MenuItem>[
        for (final Brand b in kBrands)
          MenuItem(
            label: b.label,
            selected: b.id == _selectedBrandId,
            onSelect: () => _pickBrand(b),
          ),
      ];

  /// The brand shown on the closed trigger — or `Custom` once the Theme draft
  /// no longer matches any brand verbatim, which is the menu's way of saying
  /// what the old segmented control said by lighting no segment.
  String _brandLabel() {
    final String? id = _selectedBrandId;
    if (id == null) return 'Custom';
    return kBrands.firstWhere((Brand b) => b.id == id).label;
  }

  /// Applies [brand] to the sample: the theme block goes into the editable
  /// **Theme** tab and the surface re-inks immediately. This is a *theme-only*
  /// commit — the template/schema/messages drafts are left untouched (unlike
  /// Preview, which commits everything).
  void _pickBrand(Brand brand) {
    final String themeJson = brand.themeJson;
    setState(() {
      _dTheme = themeJson;
      // Reveal the freshly-dropped code when the editor is (or gets) opened.
      _tab = 'Theme';
      _applyThemeJson(themeJson);
    });
  }

  /// Commits [themeJson] as the active project theme and re-inks both panes,
  /// mirroring Preview's theme handling. Keeps `_jasprKey` so the Jaspr pane
  /// re-themes in place (via SampleView's `theme` prop) without losing the
  /// surface's interaction state — the same in-place path the mode picker uses.
  void _applyThemeJson(String themeJson) {
    final ProjectTheme? project = ProjectTheme.tryParse(themeJson);
    _project = project;
    if (project == null) {
      _mode = null;
    } else if (_mode == null || !project.availableModes.contains(_mode)) {
      _mode = _modeTouched
          ? project.defaultMode
          : project.modeFor(dark: SiteTheme.effectiveDark);
    }
    _error = null;
    _flutterWidget = null;
    _renderKey++;
  }

  /// The brand whose theme block the current Theme draft matches verbatim, or
  /// null when the draft is a hand-edited (custom) theme. An empty draft is the
  /// **Default** (host-blended) brand. Compared structurally so reformatting the
  /// JSON keeps the brand checked.
  String? get _selectedBrandId {
    final String draft = _dTheme.trim();
    if (draft.isEmpty) return _defaultBrandId;
    for (final Brand b in kBrands) {
      if (b.themeJson.isEmpty) continue;
      if (_jsonEquivalent(draft, b.themeJson)) return b.id;
    }
    return null;
  }

  /// The default (host-blended) brand's id — what an empty theme reads as.
  String get _defaultBrandId =>
      kBrands.firstWhere((Brand b) => b.themeJson.isEmpty).id;

  /// Whether two JSON strings decode to the same structure (whitespace- and
  /// formatting-independent). False for anything that doesn't parse.
  bool _jsonEquivalent(String a, String b) {
    try {
      return jsonEncode(jsonDecode(a)) == jsonEncode(jsonDecode(b));
    } catch (_) {
      return false;
    }
  }

  /// The editor tabs: one per project file. The Theme tab is always present —
  /// an empty draft is an unthemed sample (the Default brand); the theme picker
  /// fills it when a brand is chosen.
  List<(String, String, String, ValueChanged<String>)> get _editorTabs =>
      <(String, String, String, ValueChanged<String>)>[
        (
          'Template',
          'Template (.craft)',
          _dTemplate,
          (String v) => _dTemplate = v
        ),
        ('Schema', 'Schema (JSON)', _dSchema, (String v) => _dSchema = v),
        (
          'App',
          'App bootstrap (app.json)',
          _dMessages,
          (String v) => _dMessages = v
        ),
        (
          'Theme',
          'Theme (manifest theme block)',
          _dTheme,
          (String v) => _dTheme = v
        ),
      ];

  Component _editor() {
    final List<(String, String, String, ValueChanged<String>)> tabs =
        _editorTabs;
    final String activeName = _tabOr(tabs);
    final (String, String, String, ValueChanged<String>) active =
        tabs.firstWhere(
      ((String, String, String, ValueChanged<String>) t) => t.$1 == activeName,
    );
    return div(
      styles: Styles(raw: <String, String>{
        'width': _phone ? '100%' : '${_editorWidth}px',
        if (!_phone) 'border-left': '1px solid var(--border)',
        'display': 'flex',
        'flex-direction': 'column',
        'background': 'var(--panel)',
        'overflow': 'auto',
      }),
      [
        if (_error != null)
          div(
            styles: Styles(raw: <String, String>{
              'background': 'var(--error-bg)',
              'color': 'var(--error-fg)',
              'padding': '8px 12px',
              'font': '12px ui-monospace, monospace',
              'white-space': 'pre-wrap',
            }),
            [Component.text(_error!)],
          ),
        div(
          styles: Styles(raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'gap': '6px',
            'padding': '10px 12px',
            'border-bottom': '1px solid var(--border)',
          }),
          [
            button(
              onClick: _preview,
              styles: Styles(raw: <String, String>{
                'display': 'inline-flex',
                'align-items': 'center',
                'gap': '6px',
                'padding': '8px 16px',
                'border': 'none',
                'border-radius': '6px',
                'background': 'var(--accent)',
                'color': 'var(--accent-fg)',
                'cursor': 'pointer',
                'font-weight': '600',
              }),
              <Component>[Component.text('Preview'), playIcon()],
            ),
          ],
        ),
        _tabBar(tabs, activeName),
        _field(
          active.$2,
          active.$3,
          active.$4,
          placeholder: activeName == 'Theme'
              ? 'No theme — this sample blends into the host.\n'
                  'Pick a theme above, or paste a manifest theme block here.'
              : null,
        ),
      ],
    );
  }

  Component _tabBar(
    List<(String, String, String, ValueChanged<String>)> tabs,
    String activeName,
  ) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'gap': '2px',
        'padding': '8px 12px 0',
        'border-bottom': '1px solid var(--border)',
      }),
      [
        for (final (String, String, String, ValueChanged<String>) t in tabs)
          button(
            onClick: () => setState(() => _tab = t.$1),
            styles: Styles(raw: <String, String>{
              'padding': '7px 12px',
              'border': '1px solid var(--border)',
              'border-bottom': 'none',
              'border-radius': '6px 6px 0 0',
              'background': t.$1 == activeName ? 'var(--card)' : 'transparent',
              'color': t.$1 == activeName ? 'var(--fg)' : 'var(--subtle)',
              'font-weight': t.$1 == activeName ? '600' : '400',
              'cursor': 'pointer',
            }),
            [Component.text(t.$1)],
          ),
      ],
    );
  }

  /// The active tab name, snapped back to the first tab when the current one
  /// no longer exists (e.g. Theme after an unthemed preview).
  String _tabOr(List<(String, String, String, ValueChanged<String>)> tabs) =>
      tabs.any(((String, String, String, ValueChanged<String>) t) =>
              t.$1 == _tab)
          ? _tab
          : tabs.first.$1;

  Component _field(String label, String value, ValueChanged<String> onInput,
      {String? placeholder}) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'flex-direction': 'column',
        'flex': '1',
        'min-height': '0',
        'padding': '8px 12px 12px',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'font': '600 12px system-ui',
            'color': 'var(--muted)',
            'margin': '4px 0',
          }),
          [Component.text(label)],
        ),
        textarea(
          // Keyed per tab so each tab mounts a fresh textarea seeded with its
          // own draft (a reused DOM textarea would keep showing the previous
          // tab's user-typed value).
          key: ValueKey<String>('editor-$label'),
          [Component.text(value)],
          rows: 24,
          placeholder: placeholder,
          onInput: onInput,
          styles: Styles(raw: <String, String>{
            'width': '100%',
            'flex': '1',
            'box-sizing': 'border-box',
            'font': '12px ui-monospace, monospace',
            'border': '1px solid var(--border-strong)',
            'border-radius': '6px',
            'padding': '8px',
            'resize': 'vertical',
            'background': 'var(--card)',
            'color': 'var(--fg)',
          }),
        ),
      ],
    );
  }

  Styles _btn(bool active) => Styles(raw: <String, String>{
        'padding': '6px 12px',
        'border':
            '1px solid ${active ? 'var(--accent)' : 'var(--border-strong)'}',
        'border-radius': '6px',
        'background': active ? 'var(--accent)' : 'var(--card)',
        'color': active ? 'var(--accent-fg)' : 'var(--fg)',
        'cursor': 'pointer',
      });
}
