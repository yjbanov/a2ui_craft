// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:flutter/widgets.dart';

import 'runtime.dart';

/// Renders a single A2UI component (from an `a2ui_core` [SurfaceModel]) as a
/// Flutter [Widget].
///
/// The host widget tree mirrors the A2UI component tree: one keyed adapter per
/// component id. The adapter owns an [A2uiComponentBinding] (which wraps
/// `a2ui_core`'s `GenericBinder`), rebuilding when the component's resolved props
/// change. It renders the component's catalog template via [Runtime.buildNode]
/// against [scope], feeding resolved props as template args and injecting a child
/// adapter for each structural [ChildNode] slot.
///
/// Reconciliation identity: a **static** child keeps its A2UI id
/// as its key (so a control is locatable by id and survives reorders); a
/// **`ChildList` item** falls back to its positional [ChildNode.basePath], since
/// the A2UI spec attaches no per-item id (see a2ui#1745).
class A2uiToRfwAdapter extends StatefulWidget {
  /// Creates an adapter for the A2UI component with the given [id] in [surface].
  A2uiToRfwAdapter({
    required this.id,
    required this.surface,
    required this.runtime,
    this.basePath = '/',
    this.scope = const LibraryName(<String>['core']),
    this.mapComponent,
    this.theme,
    String? reconcileKey,
  }) : super(key: ValueKey<String>(reconcileKey ?? id));

  /// The A2UI component id.
  final String id;

  /// The `a2ui_core` surface that owns this component, its data model, and the
  /// resolution of its bindings/functions/`checks`.
  final SurfaceModel<ComponentApi> surface;

  /// The engine that materializes the component's template.
  final Runtime runtime;

  /// The data scope this component's relative bindings resolve against — `/` at
  /// the surface root, or the item path when nested inside a `ChildList`.
  final String basePath;

  /// The library whose names the component resolves against — the **catalog**
  /// (which imports the `core` primitives).
  final LibraryName scope;

  /// Optional mapping from an A2UI component (its `type` and RFW-arg props) to the
  /// [ConstructorCall] to render. Defaults to `ConstructorCall(type, args)` — the
  /// component name *is* the widget name in [scope].
  ///
  /// Set it to expose a component under a different widget name and/or to rename
  /// its props — e.g. to surface an existing local widget directly as an A2UI
  /// component without authoring a template (the "bespoke widget" path), mapping
  /// the component's prop names onto the widget's arg names. The mapping is the
  /// embedder's choice per component; this adapter ships no catalog-specific
  /// default.
  final ConstructorCall Function(String type, DynamicMap args)? mapComponent;

  /// The theme this surface renders under (§9), or null to blend into the host.
  ///
  /// Set on the **root** adapter only: it wraps the rendered tree in the ambient
  /// theme scope, from which every descendant adapter's primitives read their
  /// role defaults — so nested adapters leave this null and inherit it.
  final CraftTheme? theme;

  @override
  State<A2uiToRfwAdapter> createState() => _A2uiToRfwAdapterState();
}

class _A2uiToRfwAdapterState extends State<A2uiToRfwAdapter> {
  late A2uiComponentBinding _binding;

  @override
  void initState() {
    super.initState();
    _binding = _bind();
  }

  @override
  void didUpdateWidget(A2uiToRfwAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id ||
        oldWidget.surface != widget.surface ||
        oldWidget.basePath != widget.basePath) {
      _binding
        ..removeListener(_onChanged)
        ..dispose();
      _binding = _bind();
    }
  }

  A2uiComponentBinding _bind() {
    return A2uiComponentBinding(widget.surface, widget.id,
        basePath: widget.basePath)
      ..addListener(_onChanged);
  }

  void _onChanged() => setState(() {});

  @override
  void dispose() {
    _binding
      ..removeListener(_onChanged)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Map<String, dynamic>? props = _binding.resolvedProps;
    final String? type = _binding.type;
    if (props == null || type == null) {
      // The component has not been ingested yet; render nothing until it
      // arrives (the binding notifies us via onCreated).
      return const SizedBox.shrink();
    }

    final DynamicMap args = a2uiArgsFromProps(
      props,
      _injectChild,
      childRefs: _binding.childRefs,
      basePath: widget.basePath,
    );
    final ConstructorCall call =
        (widget.mapComponent ?? _identityCall)(type, args);
    return widget.runtime.buildNode(
      context,
      call,
      DynamicContent(),
      _noEvent,
      scope: widget.scope,
      theme: widget.theme,
    );
  }

  static ConstructorCall _identityCall(String type, DynamicMap args) =>
      ConstructorCall(type, args);

  Object _injectChild(ChildNode child) {
    // Static siblings share this component's data scope and are keyed by their
    // (unique) A2UI id; ChildList items have a deeper, positional basePath and
    // are keyed by it.
    final String reconcileKey =
        child.basePath == widget.basePath ? child.id : child.basePath;
    return A2uiToRfwAdapter(
      id: child.id,
      surface: widget.surface,
      runtime: widget.runtime,
      basePath: child.basePath,
      scope: widget.scope,
      mapComponent: widget.mapComponent,
      reconcileKey: reconcileKey,
    );
  }

  // A2UI actions are dispatched by a2ui_core (the resolved action callback fed
  // as a template arg), so the RFW event channel is unused here.
  void _noEvent(String name, DynamicMap arguments) {}
}
