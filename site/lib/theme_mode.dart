// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:web/web.dart' as web;

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

/// The global theme toggle, shown in every screen's toolbar: System / Light /
/// Dark. "System" follows the browser preference; the other two override it.
class ThemeToggle extends StatefulComponent {
  const ThemeToggle({super.key});

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
    return select(
      value: SiteTheme.mode.name,
      onChange: (List<String> values) {
        if (values.isEmpty) return;
        SiteTheme.mode = SiteThemeMode.values.firstWhere(
          (SiteThemeMode m) => m.name == values.first,
          orElse: () => SiteThemeMode.system,
        );
      },
      attributes: const <String, String>{
        'aria-label': 'Color scheme',
        'title': 'Color scheme',
      },
      styles: Styles(raw: <String, String>{
        'padding': '6px 10px',
        'border': '1px solid var(--border-strong)',
        'border-radius': '6px',
        'background': 'var(--card)',
        'color': 'var(--fg)',
        'cursor': 'pointer',
      }),
      <Component>[
        for (final (SiteThemeMode, String) entry
            in const <(SiteThemeMode, String)>[
          (SiteThemeMode.system, '🌓 System'),
          (SiteThemeMode.light, '☀️ Light'),
          (SiteThemeMode.dark, '🌙 Dark'),
        ])
          option(
            value: entry.$1.name,
            selected: SiteTheme.mode == entry.$1,
            [Component.text(entry.$2)],
          ),
      ],
    );
  }
}
