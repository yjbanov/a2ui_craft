// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

/// The content ink a control installs over its subtree — layer 3 of the
/// control paint model (DESIGN.md §8): a `Button` painting its default
/// `primary` surface inks its content `onPrimary`, overriding the ambient
/// `onSurface`/`onSurfaceVariant` role defaults that the body and caption
/// styles and `Icon` would otherwise read. Content primitives consult this
/// *before* the ambient roles; explicit per-widget props still win over both
/// (the cascade, DESIGN.md §9.5).
class ContentInk extends InheritedComponent {
  const ContentInk({super.key, required this.color, required super.child});

  final String color;

  static String? of(BuildContext context) =>
      context.dependOnInheritedComponentOfExactType<ContentInk>()?.color;

  @override
  bool updateShouldNotify(ContentInk oldComponent) =>
      color != oldComponent.color;
}
