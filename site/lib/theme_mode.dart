// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

import 'menu.dart';
import 'system_dark.dart';

/// The site-wide dark-light choice: follow the browser/system preference, or
/// override it explicitly.
enum SiteThemeMode { system, light, dark }

/// The global theme state — the host's render-time dark-light input
/// (DESIGN.md §9.5) with a user override on top of the system preference.
///
/// Setting the mode writes an inline `color-scheme` onto `<html>`; the whole
/// chrome follows because the palette variables (and the primitives' host
/// fallbacks) are `light-dark()` pairs, which resolve against the effective
/// color scheme. Screens read [effectiveDark] for the pieces CSS can't reach
/// (a themed project's mode, the embedded Flutter shell) and subscribe via
/// [onChange].
abstract final class SiteTheme {
  static const String _storageKey = 'craft-theme-mode';

  static SiteThemeMode _mode = SiteThemeMode.system;
  static final List<void Function()> _listeners = <void Function()>[];
  static bool _initialized = false;

  /// Restores the persisted override and starts following the system
  /// preference. Call once, before `runApp`.
  static void init() {
    if (_initialized) return;
    _initialized = true;
    final String? stored = web.window.localStorage.getItem(_storageKey);
    _mode = SiteThemeMode.values.firstWhere(
      (SiteThemeMode m) => m.name == stored,
      orElse: () => SiteThemeMode.system,
    );
    _apply();
    watchSystemDark((bool _) {
      if (_mode == SiteThemeMode.system) _notify();
    });
  }

  static SiteThemeMode get mode => _mode;

  static set mode(SiteThemeMode value) {
    if (value == _mode) return;
    _mode = value;
    web.window.localStorage.setItem(_storageKey, value.name);
    _apply();
    _notify();
  }

  /// Whether the effective scheme is dark: the override when set, else the
  /// system preference.
  static bool get effectiveDark => switch (_mode) {
        SiteThemeMode.system => systemPrefersDark(),
        SiteThemeMode.light => false,
        SiteThemeMode.dark => true,
      };

  /// Subscribes to effective-scheme changes (override picked, or the system
  /// preference flipping while in system mode). Returns an unsubscribe.
  static void Function() onChange(void Function() listener) {
    _listeners.add(listener);
    return () => _listeners.remove(listener);
  }

  static void _apply() {
    // An empty inline value defers to the stylesheet's `light dark`, i.e. the
    // system preference.
    (web.document.documentElement! as web.HTMLElement).style.colorScheme =
        switch (_mode) {
      SiteThemeMode.system => '',
      SiteThemeMode.light => 'light',
      SiteThemeMode.dark => 'dark',
    };
  }

  static void _notify() {
    for (final void Function() listener
        in List<void Function()>.of(_listeners)) {
      listener();
    }
  }
}

/// The three color-scheme choices as menu rows.
///
/// Shared, rather than private to [ThemeToggle], because on a narrow screen
/// this axis has no toolbar button of its own — it folds into the screen's
/// overflow menu along with every other option. Both hosts stay live the same
/// way: picking a row sets [SiteTheme.mode], which notifies the screen's own
/// [SiteTheme.onChange] subscription.
const Map<SiteThemeMode, (String, String)> _schemeChoices =
    <SiteThemeMode, (String, String)>{
  SiteThemeMode.system: ('🌓', 'System'),
  SiteThemeMode.light: ('☀️', 'Light'),
  SiteThemeMode.dark: ('🌙', 'Dark'),
};

List<MenuItem> siteThemeItems() => <MenuItem>[
      for (final MapEntry<SiteThemeMode, (String, String)> entry
          in _schemeChoices.entries)
        MenuItem(
          // Text, not SVG like the rest of the chrome's glyphs: these are
          // emoji, which the platform is meant to render in its own idiom.
          icon: Component.text(entry.value.$1),
          label: entry.value.$2,
          selected: SiteTheme.mode == entry.key,
          onSelect: () => SiteTheme.mode = entry.key,
        ),
    ];

/// The global theme toggle, shown in every screen's toolbar above the narrow
/// breakpoint: System / Light / Dark. "System" follows the browser preference;
/// the other two override it.
///
/// The trigger is the **current scheme's glyph alone** — the three choices are
/// universally understood from their icons, and a toolbar that also carries an
/// adapter toggle, a brand, and a size class cannot afford to spell this one
/// out. The full labels live in the menu, which is where someone unsure of a
/// glyph would look anyway. On a phone even the glyph is gone: see
/// [siteThemeItems].
class ThemeToggle extends StatefulComponent {
  const ThemeToggle({super.key, this.className});

  /// An extra class on the trigger — how a toolbar marks this `wide-only`.
  final String? className;

  @override
  State<ThemeToggle> createState() => _ThemeToggleState();
}

class _ThemeToggleState extends State<ThemeToggle> {
  void Function()? _unsubscribe;

  @override
  void initState() {
    super.initState();
    _unsubscribe = SiteTheme.onChange(() => setState(() {}));
  }

  @override
  void dispose() {
    _unsubscribe?.call();
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return CraftMenu(
      className: component.className,
      ariaLabel: 'Color scheme: ${_schemeChoices[SiteTheme.mode]!.$2}',
      icon: Component.text(_schemeChoices[SiteTheme.mode]!.$1),
      iconOnly: true,
      items: siteThemeItems(),
    );
  }
}
