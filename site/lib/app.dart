// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart' as flutter;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';

/// Spike: a Jaspr page that embeds a trivial Flutter widget, to verify the
/// `jaspr_flutter_embed` toolchain builds and runs before the full site is built.
class App extends StatelessComponent {
  const App({super.key});

  @override
  Component build(BuildContext context) {
    return div([
      h1([Component.text('A2UI Craft — Flutter embed spike')]),
      p([Component.text('Below is a Flutter widget embedded inside Jaspr:')]),
      FlutterEmbedView(
        styles: Styles(raw: <String, String>{
          'width': '420px',
          'height': '160px',
          'border': '1px solid #ccc',
        }),
        widget: flutter.MaterialApp(
          debugShowCheckedModeBanner: false,
          home: flutter.Scaffold(
            body: flutter.Center(
              child: flutter.Text(
                'Embedded Flutter ✓',
                style: flutter.TextStyle(fontSize: 24),
              ),
            ),
          ),
        ),
      ),
    ]);
  }
}
