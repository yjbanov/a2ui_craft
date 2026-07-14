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
/// **Self-sizing via view constraints.** A Flutter view has no intrinsic DOM
/// size, so the view is given *unbounded-height* view constraints
/// (https://docs.flutter.dev/platform-integration/web/embedding-flutter-web#view-constraints):
/// the engine then sizes the view to its content along the vertical axis while
/// filling the host element's width, and grows the host element to match — no
/// measurement loop, no fixed canvas. `flutterSampleApp(autoSize: true)` pairs
/// this with a hug-height Material shell (a `MaterialApp`/`Scaffold` would fill
/// the unbounded height instead).
///
/// **Lazy-mounted.** Every live Flutter view is a full CanvasKit surface
/// competing for frames; a page like the kitchen sink stacks many. So the view
/// mounts only while this element is near the viewport (an
/// `IntersectionObserver`, with a margin so it is warm before scrolling in) and
/// unmounts once well past it; off-screen, a plain spacer holds the last
/// rendered height so the page doesn't jump.
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
    this.minHeight = 120,
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

  /// The spacer height (px) held before this specimen has ever rendered — only
  /// affects the scrollbar length until the first mount measures the real one.
  final double minHeight;

  @override
  State<FlutterSpecimen> createState() => _FlutterSpecimenState();
}

/// Distinguishes each specimen's observed host element.
int _specimenSeq = 0;

/// How far outside the viewport (px) the Flutter view boots ahead of / lingers
/// past scrolling — wide enough that it is warm by the time it is on screen.
const String _mountMargin = '600px 0px';

class _FlutterSpecimenState extends State<FlutterSpecimen> {
  late final String _domId = 'flutter-specimen-${_specimenSeq++}';

  // Whether the host element is near the viewport — gates the (heavy) embed.
  bool _visible = false;

  // The embedded Flutter widget is memoized so an unrelated parent rebuild
  // doesn't tear down and re-run the Flutter surface; it is recreated only
  // when the theme or dark-light input changes (or the view is remounted).
  Object? _widget;

  // The rendered height captured just before the view is unmounted, so the
  // off-screen spacer holds the same space and the page doesn't jump.
  double? _placeholderHeight;

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
          // Capture the auto-sized height before dropping the view, so the
          // spacer that replaces it holds the same space.
          if (!near) {
            final double h = host.getBoundingClientRect().height;
            if (h > 0) _placeholderHeight = h;
          }
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
      autoSize: true,
    );
  }

  @override
  Component build(BuildContext context) {
    // The host (#_domId) is stable so the observer stays attached across
    // mount/unmount. While visible it is auto-height (the embedded view sizes
    // itself and grows it); off-screen a spacer holds the last rendered height.
    if (_visible) {
      _widget ??= _make();
      return div(
        id: _domId,
        styles: Styles(raw: const <String, String>{'width': '100%'}),
        [
          FlutterEmbedView(
            key: ValueKey<String>('flutter-$_renderKey'),
            // Unbounded height → the engine sizes the view to its content and
            // grows the host element; width fills the host (its `100%`).
            constraints:
                ViewConstraints(minHeight: 0, maxHeight: double.infinity),
            styles: Styles(raw: const <String, String>{'width': '100%'}),
            widget: _widget as dynamic,
          ),
        ],
      );
    }
    // Dropped the view: recreate the widget on the next reveal so it boots
    // fresh (a removed Flutter view cannot be re-added).
    _widget = null;
    return div(
      id: _domId,
      styles: Styles(raw: <String, String>{
        'width': '100%',
        'height': '${(_placeholderHeight ?? component.minHeight).ceil()}px',
      }),
      const [_Spacer()],
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
