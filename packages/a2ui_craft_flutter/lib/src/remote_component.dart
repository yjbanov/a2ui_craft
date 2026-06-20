// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is hand-formatted.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/widgets.dart';

import 'runtime.dart';

export 'package:a2ui_craft/a2ui_craft.dart' show DynamicMap, LibraryName;

/// Injection point for a remote component.
///
/// This widget combines an A2UI Craft [Runtime] and [DynamicContent], inserting
/// a specified [component] into the tree.
///
/// The public API of this class is intentionally identical across framework
/// adapters (see the `a2ui_craft_jaspr` package's `RemoteComponent`). Only the
/// node type it ultimately produces — here a Flutter [Widget] — differs.
class RemoteComponent extends StatefulWidget {
  /// Inserts the specified [component] into the tree.
  ///
  /// The [onEvent] argument is optional. When omitted, events are discarded.
  const RemoteComponent({
    super.key,
    required this.runtime,
    required this.component,
    required this.data,
    this.onEvent,
  });

  /// The [Runtime] to use to render the component specified by [component].
  ///
  /// This should update rarely (doing so is relatively expensive), but it is
  /// fine to update it. For example, a client could update this on the fly when
  /// the server deploys a new version of the component library.
  ///
  /// Frequent updates (e.g. animations) should be done by updating [data].
  final Runtime runtime;

  /// The name of the component to display, and the library from which to obtain
  /// it.
  ///
  /// The component must be declared either in the specified library, or one of
  /// its dependencies.
  final FullyQualifiedWidgetName component;

  /// The data to which the component specified by [component] will be bound.
  ///
  /// This can be updated frequently (once per frame) using
  /// [DynamicContent.update].
  final DynamicContent data;

  /// Called when there's an event triggered by a remote component.
  ///
  /// If this is null, events are discarded.
  final RemoteEventHandler? onEvent;

  @override
  State<RemoteComponent> createState() => _RemoteComponentState();
}

class _RemoteComponentState extends State<RemoteComponent> {
  @override
  void initState() {
    super.initState();
    widget.runtime.addListener(_runtimeChanged);
  }

  @override
  void didUpdateWidget(RemoteComponent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.runtime != widget.runtime) {
      oldWidget.runtime.removeListener(_runtimeChanged);
      widget.runtime.addListener(_runtimeChanged);
    }
  }

  @override
  void dispose() {
    widget.runtime.removeListener(_runtimeChanged);
    super.dispose();
  }

  void _runtimeChanged() {
    setState(() {/* component probably changed */});
  }

  void _eventHandler(String eventName, DynamicMap eventArguments) {
    widget.onEvent?.call(eventName, eventArguments);
  }

  @override
  Widget build(BuildContext context) {
    return widget.runtime
        .build(context, widget.component, widget.data, _eventHandler);
  }
}
