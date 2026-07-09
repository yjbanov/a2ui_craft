// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Browser implementation: the `prefers-color-scheme` media query.
bool systemPrefersDark() =>
    web.window.matchMedia('(prefers-color-scheme: dark)').matches;

void watchSystemDark(void Function(bool dark) onChange) {
  final web.MediaQueryList query =
      web.window.matchMedia('(prefers-color-scheme: dark)');
  query.addEventListener(
      'change', ((web.Event _) => onChange(query.matches)).toJS);
}
