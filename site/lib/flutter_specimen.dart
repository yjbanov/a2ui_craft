// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:js_interop';

import 'package:a2ui_core/a2ui_core.dart' show A2uiClientAction, A2uiMessage;
import 'package:a2ui_craft/a2ui_craft.dart' show CraftTheme;
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_flutter_embed/jaspr_flutter_embed.dart';
import 'package:web/web.dart' as web;

import 'flutter_host.dart';

/// One A2UI surface rendered by the **embedded Flutter adapter**, hosted in a
/// DOM element the browser lays out beside its Jaspr siblings.
///
/// The reusable counterpart of a Jaspr `SampleView` for the site: hand it the
/// same catalog trio (template + schema + messages) and it embeds a Flutter
/// render of it via [FlutterEmbedView]. All the site's embeds share one Flutter
/// engine (jaspr_flutter_embed's multi-view mode); this widget is one view on
/// it.
///
/// **Fixed-canvas, clipped to content.** A Flutter view has no intrinsic DOM
/// size, and *resizing* an embedded view re-lays-out its content, which re-runs
/// self-measurement — a feedback loop that, across many multi-view embeds,
/// never settles. So the view canvas is a **constant** [_canvasHeight] and is
/// never resized; the content lays out once and reports its height, and the
/// *container* is clipped (`overflow: hidden`) to that height. The content is
/// top-anchored (a Scaffold), so clipping the empty remainder is exactly right,
/// and the embed ends up hugging its content like the Jaspr render does. Until
/// the first report lands the full canvas shows.
///
/// **Lazy-mounted.** Every live Flutter view is a full CanvasKit surface
/// competing for frames; a page like the kitchen sink stacks many. So the view
/// mounts only while this element is near the viewport (an
/// `IntersectionObserver`, with a margin so it is warm before scrolling in) and
/// unmounts once well past it; off-screen, a plain spacer holds the last
/// measured height so the page doesn't jump.
///
/// The embedded app reads its dark-light input and theme explicitly (the engine
/// only ever sees the browser preference), so a change to either [dark] or
/// [theme] recreates the Flutter widget — [CraftTheme] snapshots are cached per
/// mode, so an unchanged mode is the same instance and does not rebuild.
class FlutterSpecimen extends StatefulComponent {
  const FlutterSpecimen({
    super.key,
    required this.template,
    required this.schema,
    required this.messages,
    required this.dark,
    this.theme,
    this.onAction,
    this.minHeight = 220,
  });

  /// The catalog as RFW template source (`import core; widget Root = …;`).
  final String template;

  /// The component API as a raw JSON Schema catalog document.
  final Map<String, Object?> schema;

  /// The A2UI messages that build the surface.
  final List<A2uiMessage> messages;

  /// The site's effective dark-light scheme, passed to the embedded app's
  /// ThemeMode (the engine only sees the browser preference, never the site
  /// override).
  final bool dark;

  /// The theme to render the surface under (§9), or null to blend into the
  /// host Material defaults.
  final CraftTheme? theme;

  /// Called when the rendered surface dispatches an A2UI action.
  final void Function(A2uiClientAction action)? onAction;

  /// The spacer height (px) for an off-screen, not-yet-measured specimen — a
  /// rough estimate that only affects the scrollbar length before the embed
  /// has ever mounted.
  final double minHeight;

  @override
  State<FlutterSpecimen> createState() => _FlutterSpecimenState();
}

/// Distinguishes each specimen's observed host element.
int _specimenSeq = 0;

/// How far outside the viewport (px) the Flutter view boots ahead of / lingers
/// past scrolling — wide enough that it is warm by the time it is on screen.
const String _mountMargin = '600px 0px';

/// The constant height (px) of every embedded view's canvas. It never changes,
/// so the content lays out exactly once; the container is clipped to the
/// measured content height. Only needs to exceed the tallest specimen — content
/// past it would be clipped (no specimen comes close).
const double _canvasHeight = 900;

class _FlutterSpecimenState extends State<FlutterSpecimen> {
  late final String _domId = 'flutter-specimen-${_specimenSeq++}';

  // Whether the host element is near the viewport — gates the (heavy) embed.
  bool _visible = false;

  // The embedded Flutter widget is memoized so an unrelated parent rebuild
  // doesn't tear down and re-run the Flutter surface; it is recreated only
  // when the theme or dark-light input changes (or the view is remounted).
  Object? _widget;

  // The Flutter content's self-measured height (see flutterSampleApp) — the
  // height the fixed-canvas view is *clipped* to, and the spacer height while
  // off-screen. Null until the first report lands.
  double? _height;

  // Bumped whenever the widget is recreated, to swap the FlutterEmbedView's
  // key so a fresh view mounts.
  int _renderKey = 0;

  web.IntersectionObserver? _observer;

  @override
  void initState() {
    super.initState();
    // Attach the viewport observer once the host element is in the DOM.
    context.binding.addPostFrameCallback(() {
      final web.Element? host = web.document.getElementById(_domId);
      if (host == null) {
        // No element to observe — fail open so the specimen still renders.
        if (mounted && !_visible) setState(() => _visible = true);
        return;
      }
      final web.IntersectionObserver observer = web.IntersectionObserver(
        (JSArray<web.IntersectionObserverEntry> entries,
            web.IntersectionObserver _) {
          bool near = false;
          for (final web.IntersectionObserverEntry e in entries.toDart) {
            if (e.isIntersecting) near = true;
          }
          if (!mounted || near == _visible) return;
          setState(() => _visible = near);
        }.toJS,
        web.IntersectionObserverInit(rootMargin: _mountMargin),
      );
      observer.observe(host);
      _observer = observer;
    });
  }

  @override
  void didUpdateComponent(FlutterSpecimen oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.dark != component.dark ||
        !identical(oldComponent.theme, component.theme)) {
      _widget = null;
      _height = null;
      _renderKey++;
    }
  }

  @override
  void dispose() {
    _observer?.disconnect();
    super.dispose();
  }

  Object _make() {
    return flutterSampleApp(
      template: component.template,
      schema: component.schema,
      messages: component.messages,
      dark: component.dark,
      onAction: component.onAction,
      theme: component.theme,
      onContentHeight: (double height) {
        // Reported once the content lays out (the fixed canvas never resizes,
        // so it does not re-measure). May land after this element unmounted
        // (embed teardown is async).
        if (!mounted) return;
        // A greedy scroller under the (unbounded) measuring viewport can report
        // an infinite intrinsic height; ignore it (the full canvas shows) — a
        // template that scrolls must bound its own height.
        if (!height.isFinite) return;
        final double px = height.ceilToDouble();
        if (_height == px) return;
        setState(() => _height = px);
      },
    );
  }

  @override
  Component build(BuildContext context) {
    // The host (#_domId) is stable so the observer stays attached across
    // mount/unmount, and is clipped to the measured content height.
    final Component child;
    final double hostHeight;
    if (_visible) {
      _widget ??= _make();
      // Show the full canvas until the content measures, then clip to it.
      hostHeight = _height ?? _canvasHeight;
      // A constant-height canvas (never resized → measures once); the host
      // clips it to the content height.
      child = FlutterEmbedView(
        key: ValueKey<String>('flutter-$_renderKey'),
        styles: Styles(raw: <String, String>{
          'width': '100%',
          'height': '${_canvasHeight.ceil()}px',
        }),
        widget: _widget as dynamic,
      );
    } else {
      // Dropped the view: recreate the widget on the next reveal so it boots
      // fresh (a removed Flutter view cannot be re-added).
      _widget = null;
      hostHeight = _height ?? component.minHeight;
      child = const _Spacer();
    }
    return div(
      id: _domId,
      styles: Styles(raw: <String, String>{
        'height': '${hostHeight.ceil()}px',
        'overflow': 'hidden',
      }),
      [child],
    );
  }
}

/// An empty box that holds vertical space for an unmounted (off-screen) view.
class _Spacer extends StatelessComponent {
  const _Spacer();

  @override
  Component build(BuildContext context) =>
      div(styles: Styles(raw: <String, String>{'height': '100%'}), const []);
}
