// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is hand-formatted.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/jaspr.dart';

import 'runtime.dart';

export 'package:a2ui_craft/a2ui_craft.dart' show DynamicMap, LibraryName;

/// Injection point for a remote component.
///
/// This component combines an RFW [Runtime] and [DynamicData], inserting a
/// specified [widget] into the tree.
class RemoteWidget extends StatefulComponent {
  /// Inserts the specified [widget] into the tree.
  ///
  /// The [onEvent] argument is optional. When omitted, events are discarded.
  const RemoteWidget(
      {super.key,
      required this.runtime,
      required this.widget,
      required this.data,
      this.onEvent});

  /// The [Runtime] to use to render the widget specified by [widget].
  ///
  /// This should update rarely (doing so is relatively expensive), but it is
  /// fine to update it. For example, a client could update this on the fly when
  /// the server deploys a new version of the component library.
  ///
  /// Frequent updates (e.g. animations) should be done by updating [data] instead.
  final Runtime runtime;

  /// The name of the component to display, and the library from which to obtain
  /// it.
  ///
  /// The component must be declared either in the specified library, or one of its
  /// dependencies.
  ///
  /// The data to show in the component is specified using [data].
  final FullyQualifiedWidgetName widget;

  /// The data to which the widget specified by [widget] will be bound.
  ///
  /// This includes data that comes from the application, e.g. a description of
  /// the user's device, the current time, or an animation controller's value,
  /// and data that comes from the server, e.g. the contents of the user's
  /// shopping cart.
  ///
  /// This can be updated frequently (once per frame) using
  /// [DynamicContent.update].
  final DynamicContent data;

  /// Called when there's an event triggered by a remote component.
  ///
  /// If this is null, events are discarded.
  final RemoteEventHandler? onEvent;

  @override
  State<RemoteWidget> createState() => _RemoteWidgetState();
}

class _RemoteWidgetState extends State<RemoteWidget> {
  @override
  void initState() {
    super.initState();
    component.runtime.addListener(_runtimeChanged);
  }

  @override
  void didUpdateComponent(RemoteWidget oldWidget) {
    super.didUpdateComponent(oldWidget);
    if (oldWidget.runtime != component.runtime) {
      oldWidget.runtime.removeListener(_runtimeChanged);
      component.runtime.addListener(_runtimeChanged);
    }
  }

  @override
  void dispose() {
    component.runtime.removeListener(_runtimeChanged);
    super.dispose();
  }

  void _runtimeChanged() {
    setState(() {/* component probably changed */});
  }

  void _eventHandler(String eventName, DynamicMap eventArguments) {
    if (component.onEvent != null) {
      component.onEvent!(eventName, eventArguments);
    }
  }

  @override
  Component build(BuildContext context) {
    return component.runtime
        .build(context, component.widget, component.data, _eventHandler);
  }
}
