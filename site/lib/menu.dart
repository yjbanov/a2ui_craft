// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The site's **dropdown menu** — one trigger button plus a popup list.
///
/// The toolbars used to spell every choice out inline: segmented controls with
/// one button per brand, per size class, per adapter, next to a native `select`
/// per axis. That reads well at desk width and falls apart on a phone, where the
/// bar wraps into three rows before the sample is even visible. A menu trades
/// horizontal space for one tap, which is the right trade for a control you
/// touch occasionally (the brand, the window size class) rather than constantly.
///
/// Native `<select>` can't do this job: it renders the *selected* option's text
/// in the closed state, so an icon-only trigger would mean icon-only options
/// too. [CraftMenu] keeps the trigger compact and the items fully labelled.
library;

import 'dart:js_interop';

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

/// One row of a [CraftMenu] — a selectable item, or a section heading when
/// [onSelect] is null (the hamburger stacks several axes in one panel, and
/// unlabelled groups would read as one long undifferentiated list).
class MenuItem {
  const MenuItem({
    required this.label,
    required this.onSelect,
    this.icon,
    this.selected = false,
    this.toggle = false,
  });

  /// A non-interactive group heading.
  const MenuItem.heading(this.label)
      : onSelect = null,
        icon = null,
        selected = false,
        toggle = false;

  /// The row's text. Always present, even when the trigger shows only an icon —
  /// the menu is where the vocabulary is discoverable.
  final String label;

  /// An optional leading glyph.
  final String? icon;

  /// Whether this row is the current value (shown checked).
  final bool selected;

  /// Whether this row is an independent on/off switch rather than one of
  /// several mutually exclusive values. Only the ARIA role differs — a
  /// screen reader announcing "radio, 1 of 3" for a lone standalone toggle
  /// (high contrast, the code editor) would be a lie about the group.
  final bool toggle;

  final void Function()? onSelect;
}

int _nextMenuId = 0;

/// A dropdown: [icon] and/or [label] on the trigger, [items] in the popup.
///
/// Set [iconOnly] to drop the trigger's text (and the caret) for a square icon
/// button — what the color-scheme and hamburger triggers use at every width.
class CraftMenu extends StatefulComponent {
  const CraftMenu({
    super.key,
    required this.items,
    required this.ariaLabel,
    this.label,
    this.icon,
    this.iconOnly = false,
    this.alignEnd = true,
    this.active = false,
    this.className,
  });

  final List<MenuItem> items;

  /// The accessible name of the trigger — required, since the trigger may show
  /// nothing but a glyph.
  final String ariaLabel;

  /// Trigger text; omitted when [iconOnly].
  final String? label;

  /// Trigger glyph.
  final String? icon;

  /// Whether the trigger is a square icon button.
  final bool iconOnly;

  /// Whether the popup's right edge aligns with the trigger's (the default —
  /// these live at the right end of a toolbar, so a left-aligned popup would
  /// overflow the viewport).
  final bool alignEnd;

  /// Whether the trigger renders in the "on" style (used when the menu holds a
  /// non-default selection).
  final bool active;

  /// An extra class on the menu root — how a toolbar marks a menu `wide-only`
  /// or `narrow-only`, since the visibility rule has to land on the same
  /// element that carries `display: inline-flex`.
  final String? className;

  @override
  State<CraftMenu> createState() => _CraftMenuState();
}

class _CraftMenuState extends State<CraftMenu> {
  final String _id = 'craft-menu-${_nextMenuId++}';
  bool _open = false;

  web.EventListener? _onDocPointerDown;
  web.EventListener? _onDocKeyDown;

  @override
  void initState() {
    super.initState();
    // Dismissal is handled on the document rather than with a blur handler: a
    // blur would fire before an item's click could land. Pointerdown (not
    // click) so a press that starts outside closes immediately, matching how
    // native popups feel.
    _onDocPointerDown = (web.Event event) {
      if (!_open || _containsTarget(event)) return;
      setState(() => _open = false);
    }.toJS;
    _onDocKeyDown = (web.Event event) {
      if (!_open || !event.isA<web.KeyboardEvent>()) return;
      if ((event as web.KeyboardEvent).key != 'Escape') return;
      setState(() => _open = false);
    }.toJS;
    web.document.addEventListener('pointerdown', _onDocPointerDown);
    web.document.addEventListener('keydown', _onDocKeyDown);
  }

  @override
  void dispose() {
    web.document.removeEventListener('pointerdown', _onDocPointerDown);
    web.document.removeEventListener('keydown', _onDocKeyDown);
    super.dispose();
  }

  /// Whether [event] landed inside this menu — so the document listener leaves
  /// the trigger's own click alone (otherwise closing here and toggling there
  /// would fight, and the menu could never be dismissed by its own button).
  bool _containsTarget(web.Event event) {
    final web.Element? root = web.document.getElementById(_id);
    if (root == null) return false;
    final web.EventTarget? target = event.target;
    return target != null &&
        target.isA<web.Node>() &&
        root.contains(target as web.Node);
  }

  @override
  Component build(BuildContext context) {
    return div(
      id: _id,
      classes:
          component.className == null ? 'menu' : 'menu ${component.className}',
      [
        button(
          classes: component.iconOnly
              ? 'menu-trigger menu-trigger-icon'
              : 'menu-trigger',
          onClick: () => setState(() => _open = !_open),
          attributes: <String, String>{
            'aria-label': component.ariaLabel,
            'title': component.ariaLabel,
            'aria-haspopup': 'menu',
            'aria-expanded': '$_open',
            if (component.active) 'data-active': 'true',
          },
          <Component>[
            if (component.icon != null) Component.text(component.icon!),
            if (!component.iconOnly && component.label != null)
              span([Component.text(component.label!)]),
            if (!component.iconOnly)
              span(classes: 'menu-caret', [Component.text('▾')]),
          ],
        ),
        if (_open)
          div(
            classes:
                component.alignEnd ? 'menu-panel menu-panel-end' : 'menu-panel',
            attributes: const <String, String>{'role': 'menu'},
            <Component>[
              for (final MenuItem item in component.items)
                if (item.onSelect == null)
                  div(classes: 'menu-label', [Component.text(item.label)])
                else
                  button(
                    classes: 'menu-item',
                    onClick: () {
                      setState(() => _open = false);
                      item.onSelect!();
                    },
                    attributes: <String, String>{
                      'role':
                          item.toggle ? 'menuitemcheckbox' : 'menuitemradio',
                      'aria-checked': '${item.selected}',
                    },
                    <Component>[
                      span(
                          classes: 'menu-check',
                          [Component.text(item.selected ? '✓' : '')]),
                      if (item.icon != null)
                        span(
                            classes: 'menu-icon', [Component.text(item.icon!)]),
                      span([Component.text(item.label)]),
                    ],
                  ),
            ],
          ),
      ],
    );
  }
}
