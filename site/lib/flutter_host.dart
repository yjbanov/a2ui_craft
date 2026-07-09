// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show CraftTheme, Rgba;
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Builds the Flutter widget embedded via `FlutterEmbedView`: a minimal Material
/// shell around the Flutter [SampleView]. This file is the only one that imports
/// `package:flutter`, keeping the rest of the site pure Jaspr.
///
/// A [theme] (the project's, resolved for the active mode) renders the surface
/// under it; the shell background follows suit so the themed surface doesn't sit
/// on a mismatched page.
///
/// The embed's host element has no intrinsic size (to the DOM it is a canvas),
/// so the browser cannot lay it out from the Flutter content. Instead the
/// content measures *itself* — the scroll view gives it unbounded height, so it
/// takes its intrinsic height under the host width — and reports it through
/// [onContentHeight]; the Jaspr side then sizes the host element to match.
/// (The widget and the Jaspr host compile into one Dart app, so this is a
/// plain callback, not a JS bridge.) Re-reports on any layout change: a width
/// resize, or the sample's own content growing at runtime.
Widget flutterSampleApp({
  required String template,
  required Map<String, Object?> schema,
  required List<A2uiMessage> messages,
  required bool dark,
  void Function(A2uiClientAction action)? onAction,
  ValueChanged<double>? onContentHeight,
  CraftTheme? theme,
}) {
  final Rgba? surface = theme?.tokens.color('color.surface');
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // [dark] is the site's effective scheme (system preference + the global
    // toggle's override) — explicit rather than ThemeMode.system, because the
    // embedded engine only sees the browser preference, never the override. A
    // themed project's surface color overrides the scaffold either way.
    theme: ThemeData(useMaterial3: true),
    darkTheme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    themeMode: dark ? ThemeMode.dark : ThemeMode.light,
    home: Scaffold(
      backgroundColor: surface == null ? null : Color(surface.value),
      body: SafeArea(
        // The scroll view keeps the sample usable while the host box is (still)
        // shorter than the content — before the first height report lands, or
        // if the host clamps the reported height.
        child: SingleChildScrollView(
          child: _ReportHeight(
            onHeight: onContentHeight,
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
    ),
  );
}

/// The vertical padding [_ReportHeight] wraps around the sample, included in
/// the reported height.
const double _samplePadding = 16;

/// Measures its child's laid-out height (padding included) and reports it
/// after the frame whenever it changes.
class _ReportHeight extends StatelessWidget {
  const _ReportHeight({required this.onHeight, required this.child});

  final ValueChanged<double>? onHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _MeasureBox(
      onHeight: onHeight,
      child: Padding(
        padding: const EdgeInsets.all(_samplePadding),
        child: child,
      ),
    );
  }
}

class _MeasureBox extends SingleChildRenderObjectWidget {
  const _MeasureBox({required this.onHeight, super.child});

  final ValueChanged<double>? onHeight;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasureBox(onHeight);

  @override
  void updateRenderObject(
          BuildContext context, _RenderMeasureBox renderObject) =>
      renderObject.onHeight = onHeight;
}

class _RenderMeasureBox extends RenderProxyBox {
  _RenderMeasureBox(this.onHeight);

  ValueChanged<double>? onHeight;
  double? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final double height = size.height;
    if (onHeight == null || _reported == height) return;
    _reported = height;
    // Out of layout: the listener resizes the host element, which feeds a new
    // frame back into the engine. Same width → same measured height, so the
    // cycle converges after one report.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ValueChanged<double>? report = onHeight;
      if (report != null && _reported == height) report(height);
    });
  }
}
