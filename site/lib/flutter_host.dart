// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show CraftTheme, MediaContext, Rgba;
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
/// so it must be told how tall to be. Two strategies, chosen by [autoSize]:
///
/// - **[autoSize] `false` (default).** A full [MaterialApp]/[Scaffold] shell.
///   The host element is sized by the caller, and the content measures
///   *itself* — the scroll view gives it unbounded height, so it takes its
///   intrinsic height under the host width — reporting it through
///   [onContentHeight] for the caller to apply. Re-reports on any layout
///   change: a width resize, or the sample's own content growing at runtime.
///
/// - **[autoSize] `true`.** The embedded view is given *unbounded-height* view
///   constraints (see [FlutterEmbedView.constraints]) so the Flutter engine
///   sizes the view to its content along the vertical axis, filling the host's
///   width — no measurement, no fixed canvas. A `MaterialApp`/`Scaffold`/
///   `Overlay` *fills* its constraints and cannot live under an unbounded
///   height, so this uses a lightweight, **hugging** Material shell
///   ([_AutoSizeSurface]) with a transparent background, so the surface blends
///   into the host card exactly as the Jaspr render does. Suited to a page
///   that stacks many independent specimens (the kitchen sink); [onContentHeight]
///   is unused.
Widget flutterSampleApp({
  required String template,
  required Map<String, Object?> schema,
  required List<A2uiMessage> messages,
  required bool dark,
  bool cupertino = false,
  bool autoSize = false,
  void Function(A2uiClientAction action)? onAction,
  ValueChanged<double>? onContentHeight,
  CraftTheme? theme,
  MediaContext? media,
}) {
  final Rgba? surface = theme?.tokens.color('color.surface');
  // The Flutter pane previews a *mobile platform* (DESIGN.md §8): [cupertino]
  // steers ThemeData.platform, which selects the controls' idiom (the
  // .adaptive renderings, the Button's pressed-fade + superellipse corner).
  final TargetPlatform platform =
      cupertino ? TargetPlatform.iOS : TargetPlatform.android;
  final SampleView sample = SampleView(
    template: template,
    schema: schema,
    messages: messages,
    onAction: onAction,
    theme: theme,
    media: media,
  );

  if (autoSize) {
    return _AutoSizeSurface(
      theme: ThemeData(
        useMaterial3: true,
        brightness: dark ? Brightness.dark : Brightness.light,
        platform: platform,
      ),
      child: sample,
    );
  }

  return MaterialApp(
    debugShowCheckedModeBanner: false,
    // [dark] is the site's effective scheme (system preference + the global
    // toggle's override) — explicit rather than ThemeMode.system, because the
    // embedded engine only sees the browser preference, never the override. A
    // themed project's surface color overrides the scaffold either way.
    theme: ThemeData(useMaterial3: true, platform: platform),
    darkTheme: ThemeData(
        useMaterial3: true, brightness: Brightness.dark, platform: platform),
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
            child: sample,
          ),
        ),
      ),
    ),
  );
}

/// A **hug-height** Material shell for an auto-sizing embedded view: it provides
/// everything the core widgets need (a theme, a [Material] ink surface,
/// localizations, a scroll behavior, a [MediaQuery] and [Directionality]) but,
/// unlike `MaterialApp`/`Scaffold`, sizes itself to its child — so the Flutter
/// engine can size the view to the content when the view height is unbounded.
///
/// The background is transparent so the host card shows through, matching the
/// Jaspr render (the specimen paints no surface of its own — a `Card` primitive
/// inside it still paints its own). A full-width [SizedBox] lets the content
/// fill the available horizontal space, as the block-level Jaspr render does.
///
/// It omits the `Overlay`/`Navigator` (which also fill), so overlay-backed
/// affordances — the `Select` dropdown menu, text-selection toolbars — do not
/// open; the controls still render and take their primary interactions.
///
/// The engine clamps an unbounded view `maxHeight` to a large finite value, so
/// a `sizedByParent` **fill-height** widget (a bare `Slider`) fills that
/// instead of taking its natural height. Such a widget must be given a bounded
/// height by its template (e.g. a fixed-height `Box`); the shell itself only
/// fills the available width and otherwise hugs.
class _AutoSizeSurface extends StatelessWidget {
  const _AutoSizeSurface({required this.theme, required this.child});

  final ThemeData theme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MediaQuery.fromView(
      view: View.of(context),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Localizations(
          locale: const Locale('en', 'US'),
          delegates: const <LocalizationsDelegate<dynamic>>[
            DefaultMaterialLocalizations.delegate,
            DefaultWidgetsLocalizations.delegate,
          ],
          child: ScrollConfiguration(
            behavior: const MaterialScrollBehavior(),
            child: Theme(
              data: theme,
              child: Material(
                type: MaterialType.transparency,
                child: SizedBox(width: double.infinity, child: child),
              ),
            ),
          ),
        ),
      ),
    );
  }
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
