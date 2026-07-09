// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'theme_mode.dart';

/// The landing screen: a grid of sample cards. Clicking one routes to its
/// dedicated sample screen.
class GalleryScreen extends StatelessComponent {
  const GalleryScreen({super.key});

  @override
  Component build(BuildContext context) {
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
        div(
          styles: Styles(raw: <String, String>{
            'display': 'grid',
            'grid-template-columns': 'repeat(auto-fill, minmax(180px, 1fr))',
            'gap': '12px',
            'margin-top': '28px',
          }),
          [
            // A real anchor (jaspr_router's Link → `<a href>`), not a div with a
            // click handler: anchors are natively tappable on mobile (a bare div's
            // synthesized click is unreliable there) and accessible — focusable,
            // keyboard-activatable, open-in-new-tab — while still doing
            // client-side navigation.
            for (final RawSample s in rawSamples)
              Link(
                to: '/sample/${s.id}',
                styles: Styles(raw: <String, String>{
                  'display': 'block',
                  'border': '1px solid var(--border)',
                  'border-radius': '10px',
                  'padding': '16px',
                  'cursor': 'pointer',
                  'background': 'var(--card)',
                  'color': 'inherit',
                  'text-decoration': 'none',
                  'transition': 'box-shadow .15s, border-color .15s',
                }),
                child: Component.text(s.label),
              ),
          ],
        ),
      ],
    );
  }
}
