// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';

/// Builds the Flutter widget embedded via `FlutterEmbedView`: a minimal Material
/// shell around the Flutter [SampleView]. This file is the only one that imports
/// `package:flutter`, keeping the rest of the site pure Jaspr.
Widget flutterSampleApp({
  required String template,
  required Map<String, Object?> schema,
  required List<A2uiMessage> messages,
  void Function(A2uiClientAction action)? onAction,
}) {
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true),
    home: Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: SampleView(
            template: template,
            schema: schema,
            messages: messages,
            onAction: onAction,
          ),
        ),
      ),
    ),
  );
}
