// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'runtime.dart';

/// Renders a single A2UI component (from an `a2ui_core` [SurfaceModel]) as a
/// Jaspr [Component].
///
/// The host component tree mirrors the A2UI component tree: one keyed adapter per
/// component id. The adapter owns an [A2uiComponentBinding] (which wraps
/// `a2ui_core`'s `GenericBinder`), rebuilding when the component's resolved props
/// change. It renders the component's high-level template via [Runtime.buildNode]
/// against [scope], feeding resolved props as template args and injecting a child
/// adapter for each structural [ChildNode] slot.
///
/// Reconciliation identity (DESIGN.md §6): a **static** child keeps its A2UI id
/// as its key (so a control is locatable by id and survives reorders); a
/// **`ChildList` item** falls back to its positional [ChildNode.basePath], since
/// the A2UI spec attaches no per-item id (see a2ui#1745).
class A2uiToRfwAdapter extends StatefulComponent {
  /// Creates an adapter for the A2UI component with the given [id] in [surface].
  A2uiToRfwAdapter({
    required this.id,
    required this.surface,
    required this.runtime,
    this.basePath = '/',
    this.scope = const LibraryName(<String>['core']),
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

  /// The library whose names the component resolves against — the **high-level
  /// catalog** (which imports the low-level `core` library).
  final LibraryName scope;

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
  void didUpdateComponent(A2uiToRfwAdapter oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.id != component.id ||
        oldComponent.surface != component.surface ||
        oldComponent.basePath != component.basePath) {
      _binding
        ..removeListener(_onChanged)
        ..dispose();
      _binding = _bind();
    }
  }

  A2uiComponentBinding _bind() {
    return A2uiComponentBinding(component.surface, component.id,
        basePath: component.basePath)
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
  Component build(BuildContext context) {
    final Map<String, dynamic>? props = _binding.resolvedProps;
    final String? type = _binding.type;
    if (props == null || type == null) {
      // The component has not been ingested yet; render nothing until it
      // arrives (the binding notifies us via onCreated).
      return div([]);
    }

    final DynamicMap args = a2uiArgsFromProps(
      props,
      _injectChild,
      childRefs: _binding.childRefs,
      basePath: component.basePath,
    );
    return component.runtime.buildNode(
      context,
      ConstructorCall(type, args),
      DynamicContent(),
      _noEvent,
      scope: component.scope,
    );
  }

  Object _injectChild(ChildNode child) {
    // Static siblings share this component's data scope and are keyed by their
    // (unique) A2UI id; ChildList items have a deeper, positional basePath and
    // are keyed by it.
    final String reconcileKey =
        child.basePath == component.basePath ? child.id : child.basePath;
    return A2uiToRfwAdapter(
      id: child.id,
      surface: component.surface,
      runtime: component.runtime,
      basePath: child.basePath,
      scope: component.scope,
      reconcileKey: reconcileKey,
    );
  }

  // A2UI actions are dispatched by a2ui_core (the resolved action callback fed
  // as a template arg), so the RFW event channel is unused here.
  void _noEvent(String name, DynamicMap arguments) {}
}
