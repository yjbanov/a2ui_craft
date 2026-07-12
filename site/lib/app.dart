// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/jaspr.dart';
import 'package:jaspr_router/jaspr_router.dart';

import 'gallery.dart';
import 'kitchen_sink.dart';
import 'load_screen.dart';
import 'sample_screen.dart';

/// The A2UI Craft demo site: a gallery of samples, each openable on its own
/// screen and renderable with either the Jaspr or the (embedded) Flutter adapter.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return Router(
      routes: <RouteBase>[
        Route(
          path: '/',
          title: 'A2UI Craft',
          builder: (BuildContext context, RouteState state) =>
              const GalleryScreen(),
        ),
        Route(
          path: '/sample/:id',
          builder: (BuildContext context, RouteState state) =>
              SampleScreen(id: state.params['id'] ?? ''),
        ),
        Route(
          path: '/load',
          title: 'Load a project',
          builder: (BuildContext context, RouteState state) =>
              const LoadScreen(),
        ),
        Route(
          path: '/primitives',
          title: 'Core primitives',
          builder: (BuildContext context, RouteState state) =>
              const KitchenSinkScreen(),
        ),
      ],
    );
  }
}
