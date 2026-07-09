// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/client.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:site/app.dart';
import 'package:site/theme_mode.dart';

void main() {
  // Restore the persisted dark-light override (and start following the
  // system preference) before anything renders.
  SiteTheme.init();
  // Warm the embedded Flutter engine at page load. The deferred Flutter library
  // loads reliably when triggered eagerly here; triggering it lazily (only when
  // a sample is first toggled to Flutter) fails to load. The cost is the engine
  // boots up front even for visitors who never switch to Flutter.
  FlutterEmbedView.preload();
  runApp(const App());
}
