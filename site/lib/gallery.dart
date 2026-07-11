// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'theme_mode.dart';

/// The landing screen: a filter bar over a grid of sample cards. Each checkbox
/// is one demonstrated property of the templating system (the vocabulary in
/// `demo_properties.dart`); checking several narrows to samples that
/// demonstrate **all** of them. Cards show their property tags, and each
/// checkbox label carries its sample count — so thin coverage is visible at a
/// glance. Clicking a card routes to its dedicated sample screen.
class GalleryScreen extends StatefulComponent {
  const GalleryScreen({super.key});

  @override
  State<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends State<GalleryScreen> {
  /// The checked property ids; empty shows every sample.
  final Set<String> _active = <String>{};

  List<RawSample> get _visible => <RawSample>[
        for (final RawSample s in rawSamples)
          if (_active.every(s.demonstrates.contains)) s,
      ];

  int _countFor(String propertyId) => rawSamples
      .where((RawSample s) => s.demonstrates.contains(propertyId))
      .length;

  @override
  Component build(BuildContext context) {
    final List<RawSample> visible = _visible;
    return div(
      styles: Styles(raw: <String, String>{
        'max-width': '1100px',
        'margin': '0 auto',
        'padding': '32px 20px',
        'font-family': 'system-ui, -apple-system, sans-serif',
      }),
      [
        div(
          styles: Styles(raw: <String, String>{
            'display': 'flex',
            'align-items': 'center',
            'justify-content': 'space-between',
            'gap': '10px',
          }),
          [
            h1(
                styles: Styles(raw: <String, String>{'margin': '0 0 4px'}),
                [Component.text('A2UI Craft')]),
            const ThemeToggle(),
          ],
        ),
        p(
          styles: Styles(
              raw: <String, String>{'color': 'var(--muted)', 'margin': '0'}),
          [
            Component.text(
                'One UI protocol, two rendering engines. Open a sample, flip '
                'it between Flutter and Jaspr, and edit its template, schema, '
                'and messages live.'),
          ],
        ),
        // The production path: load a *deployed* project over HTTP, the way a
        // real host app would — proof it's a separate, ephemeral artifact.
        Link(
          to: '/load',
          styles: Styles(raw: <String, String>{
            'display': 'inline-block',
            'margin-top': '12px',
            'padding': '8px 14px',
            'border': '1px solid var(--accent)',
            'border-radius': '8px',
            'color': 'var(--accent)',
            'text-decoration': 'none',
            'font-weight': '600',
          }),
          child: Component.text('Load a project from a URL →'),
        ),
        _filterBar(visible.length),
        div(
          styles: Styles(raw: <String, String>{
            'display': 'grid',
            'grid-template-columns': 'repeat(auto-fill, minmax(180px, 1fr))',
            'gap': '12px',
            'margin-top': '16px',
          }),
          [
            // A real anchor (jaspr_router's Link → `<a href>`), not a div with a
            // click handler: anchors are natively tappable on mobile (a bare div's
            // synthesized click is unreliable there) and accessible — focusable,
            // keyboard-activatable, open-in-new-tab — while still doing
            // client-side navigation.
            for (final RawSample s in visible)
              Link(
                to: '/sample/${s.id}',
                styles: Styles(raw: <String, String>{
                  'display': 'flex',
                  'flex-direction': 'column',
                  'gap': '8px',
                  'border': '1px solid var(--border)',
                  'border-radius': '10px',
                  'padding': '16px',
                  'cursor': 'pointer',
                  'background': 'var(--card)',
                  'color': 'inherit',
                  'text-decoration': 'none',
                  'transition': 'box-shadow .15s, border-color .15s',
                }),
                child: div(
                  styles: Styles(raw: <String, String>{
                    'display': 'flex',
                    'flex-direction': 'column',
                    'gap': '8px',
                  }),
                  [
                    Component.text(s.label),
                    if (s.demonstrates.isNotEmpty)
                      div(
                        styles: Styles(raw: <String, String>{
                          'display': 'flex',
                          'flex-wrap': 'wrap',
                          'gap': '4px',
                        }),
                        [
                          for (final String id in s.demonstrates)
                            _tagChip(demoPropertyById(id)?.label ?? id),
                        ],
                      ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// The demonstrated-property filter: one labeled checkbox per property (with
  /// its sample count), plus a visible-count readout.
  Component _filterBar(int visibleCount) {
    return div(
      styles: Styles(raw: <String, String>{
        'display': 'flex',
        'align-items': 'center',
        'flex-wrap': 'wrap',
        'gap': '4px 14px',
        'margin-top': '20px',
        'padding': '10px 14px',
        'border': '1px solid var(--border)',
        'border-radius': '10px',
        'background': 'var(--panel)',
      }),
      [
        span(
          styles: Styles(raw: <String, String>{
            'font': '600 12px system-ui',
            'letter-spacing': '.05em',
            'text-transform': 'uppercase',
            'color': 'var(--subtle)',
          }),
          [Component.text('Demonstrates')],
        ),
        for (final DemoProperty property in demoProperties)
          _filterCheckbox(property),
        span(
          styles: Styles(raw: <String, String>{
            'margin-left': 'auto',
            'font': '12px system-ui',
            'color': 'var(--subtle)',
          }),
          [Component.text('$visibleCount of ${rawSamples.length}')],
        ),
      ],
    );
  }

  Component _filterCheckbox(DemoProperty property) {
    final bool checked = _active.contains(property.id);
    return label(
      attributes: <String, String>{'title': property.description},
      styles: Styles(raw: <String, String>{
        'display': 'inline-flex',
        'align-items': 'center',
        'gap': '6px',
        'cursor': 'pointer',
        'font': '14px system-ui',
        'color': checked ? 'var(--fg)' : 'var(--muted)',
        'user-select': 'none',
      }),
      [
        input(
          // Keyed by state: `checked` is only the DOM default, so a reused
          // input element would keep its own click state across rebuilds;
          // remounting pins the glyph to the filter state.
          key: ValueKey<String>('filter-${property.id}-$checked'),
          type: InputType.checkbox,
          checked: checked,
          onChange: (dynamic _) => setState(() {
            checked ? _active.remove(property.id) : _active.add(property.id);
          }),
          styles: Styles(raw: <String, String>{
            'accent-color': 'var(--accent)',
            'cursor': 'pointer',
          }),
        ),
        Component.text('${property.label} (${_countFor(property.id)})'),
      ],
    );
  }

  Component _tagChip(String text) {
    return span(
      styles: Styles(raw: <String, String>{
        'font': '11px system-ui',
        'color': 'var(--subtle)',
        'border': '1px solid var(--border)',
        'border-radius': '999px',
        'padding': '1px 8px',
        'white-space': 'nowrap',
      }),
      [Component.text(text)],
    );
  }
}
