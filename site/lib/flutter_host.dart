// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show CraftTheme, Rgba;
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';

/// Builds the Flutter widget embedded via `FlutterEmbedView`: a minimal Material
/// shell around the Flutter [SampleView]. This file is the only one that imports
/// `package:flutter`, keeping the rest of the site pure Jaspr.
///
/// A [theme] (the project's, resolved for the active mode) renders the surface
/// under it; the shell background follows suit so the themed surface doesn't sit
/// on a mismatched page.
Widget flutterSampleApp({
  required String template,
  required Map<String, Object?> schema,
  required List<A2uiMessage> messages,
  void Function(A2uiClientAction action)? onAction,
  CraftTheme? theme,
}) {
  final Rgba? surface = theme?.tokens.color('color.surface');
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      backgroundColor: surface == null ? Colors.white : Color(surface.value),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SampleView(
            template: template,
            schema: schema,
            messages: messages,
            onAction: onAction,
            theme: theme,
          ),
        ),
      ),
    ),
  );
}
