// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:web/web.dart' as web;

/// The element id marking the installed control stylesheet, so repeated
/// installs (one per control build) stay idempotent.
const String _kStyleElementId = 'craft-control-styles';

/// Installs the core controls' state-layer stylesheet into `document.head`
/// once. Called from every control builder — the first one wins; the id
/// check makes the rest free.
///
/// Imperative rather than a component: controls render under several roots
/// (`RemoteWidget`, `A2uiToRfwAdapter` — which nests per A2UI component), so
/// a component-tree injection point would either miss paths or duplicate the
/// sheet per component.
void ensureCoreControlStyleSheet(String css) {
  if (web.document.getElementById(_kStyleElementId) != null) {
    return;
  }
  final web.Element style = web.document.createElement('style')
    ..id = _kStyleElementId
    ..textContent = css;
  web.document.head!.append(style);
}
