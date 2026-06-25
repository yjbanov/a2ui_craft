// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:jaspr/jaspr.dart';

import 'runtime.dart';

/// Renders a single A2UI component as a Jaspr [Component].
///
/// Subscribes to the component's definition in the [surface] and rebuilds only
/// when the definition changes. The component is rendered by evaluating the
/// definition via [Runtime.buildNode].
///
/// It strictly sets its own [key] to a [ValueKey] containing the A2UI [id].
/// This ensures identity is preserved during A2UI component reorders.
class A2uiToRfwAdapter extends StatefulComponent {
  /// Creates an adapter for the A2UI component with the given [id].
  A2uiToRfwAdapter({
    required this.id,
    required this.surface,
    required this.runtime,
    this.scope = const LibraryName(<String>['core']),
    this.onEvent,
  }) : super(key: ValueKey<String>(id));

  /// The A2UI component ID.
  final String id;

  /// The surface managing the A2UI state.
  final A2uiSurface surface;

  /// The engine evaluating the RFW template.
  final Runtime runtime;

  /// The library whose names the component resolves against — the **high-level
  /// catalog** (which imports the low-level `core` library). A2UI `component`
  /// types are looked up here.
  final LibraryName scope;

  /// Event handler for actions dispatched by the rendered component.
  final RemoteEventHandler? onEvent;

  @override
  State<A2uiToRfwAdapter> createState() => _A2uiToRfwAdapterState();
}

class _A2uiToRfwAdapterState extends State<A2uiToRfwAdapter> {
  late SurfaceListenable<ConstructorCall?> _definition;

  @override
  void initState() {
    super.initState();
    _definition = component.surface.componentDefinition(component.id);
    _definition.addListener(_onDefinitionChanged);
  }

  @override
  void didUpdateComponent(A2uiToRfwAdapter oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.id != component.id ||
        oldComponent.surface != component.surface) {
      _definition.removeListener(_onDefinitionChanged);
      _definition = component.surface.componentDefinition(component.id);
      _definition.addListener(_onDefinitionChanged);
    }
  }

  @override
  void dispose() {
    _definition.removeListener(_onDefinitionChanged);
    super.dispose();
  }

  void _onDefinitionChanged() {
    setState(() {});
  }

  @override
  Iterable<Component> build(BuildContext context) {
    final ConstructorCall? call = _definition.value;
    if (call == null) {
      return const <Component>[];
    }
    return <Component>[
      component.runtime.buildNode(
        context,
        call,
        component.surface.data,
        component.onEvent ?? (String name, DynamicMap arguments) {},
        scope: component.scope,
      ),
    ];
  }
}
