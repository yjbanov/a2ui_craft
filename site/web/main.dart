// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/client.dart';
import 'package:site/app.dart';
import 'package:site/back_link.dart';
import 'package:site/theme_mode.dart';

void main() {
  // Restore the persisted dark-light override (and start following the
  // system preference) before anything renders.
  SiteTheme.init();
  // Records the URL this tab loaded with, so the back arrow can tell a step
  // back through the site from a step off it. Must run before the first
  // client-side navigation.
  SiteNav.init();
  // The embedded Flutter engine is **not** warmed here any more. It used to be,
  // because a lazy first load was recorded as failing — but that was a load
  // triggered implicitly, by mounting a view and letting the embed touch its
  // deferred library. Screens now call `FlutterEmbedView.preload()` themselves
  // when the user asks for Flutter, and hold a pending state until it resolves.
  // The landing page is the reason: a visitor should not spend their first
  // second downloading CanvasKit for an engine they may never switch to.
  runApp(const App());
}
