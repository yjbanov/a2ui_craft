// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:flutter/widgets.dart';

import 'runtime.dart';

/// Renders a single A2UI component as a Flutter [Widget].
///
/// Subscribes to the component's definition in the [surface] and rebuilds only
/// when the definition changes. The component is rendered by evaluating the
/// definition via [Runtime.buildNode].
///
/// It strictly sets its own [key] to a [ValueKey] containing the A2UI [id].
/// This ensures identity is preserved during A2UI component reorders.
class A2uiToRfwAdapter extends StatefulWidget {
  /// Creates an adapter for the A2UI component with the given [id].
  A2uiToRfwAdapter({
    required this.id,
    required this.surface,
    required this.runtime,
    this.onEvent,
  }) : super(key: ValueKey<String>(id));

  /// The A2UI component ID.
  final String id;

  /// The surface managing the A2UI state.
  final A2uiSurface surface;

  /// The engine evaluating the RFW template.
  final Runtime runtime;

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
    _definition = widget.surface.componentDefinition(widget.id);
    _definition.addListener(_onDefinitionChanged);
  }

  @override
  void didUpdateWidget(A2uiToRfwAdapter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id || oldWidget.surface != widget.surface) {
      _definition.removeListener(_onDefinitionChanged);
      _definition = widget.surface.componentDefinition(widget.id);
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
  Widget build(BuildContext context) {
    final ConstructorCall? call = _definition.value;
    if (call == null) {
      return const SizedBox.shrink();
    }
    return widget.runtime.buildNode(
      context,
      call,
      widget.surface.data,
      widget.onEvent ?? (String name, DynamicMap arguments) {},
      scope: const LibraryName(<String>['core']),
    );
  }
}
