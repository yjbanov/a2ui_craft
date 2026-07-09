// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// The browser/system dark-light preference — the host's render-time mode
/// input (DESIGN.md §9.5). The site's own chrome follows it via CSS variables
/// (`web/index.html`); screens use these helpers to pick a themed project's
/// mode to match.
bool systemPrefersDark() =>
    web.window.matchMedia('(prefers-color-scheme: dark)').matches;

/// Invokes [onChange] whenever the preference flips (e.g. the OS schedules
/// dark mode at dusk). Returns a subscription handle; call [SystemDarkWatch
/// .cancel] in `dispose`.
SystemDarkWatch watchSystemDark(void Function(bool dark) onChange) {
  final web.MediaQueryList query =
      web.window.matchMedia('(prefers-color-scheme: dark)');
  final JSFunction listener = ((web.Event _) => onChange(query.matches)).toJS;
  query.addEventListener('change', listener);
  return SystemDarkWatch._(query, listener);
}

class SystemDarkWatch {
  SystemDarkWatch._(this._query, this._listener);

  final web.MediaQueryList _query;
  final JSFunction _listener;

  void cancel() => _query.removeEventListener('change', _listener);
}
