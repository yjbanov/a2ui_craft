// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

/// The `a2ui_core` catalog id and surface id the samples' messages reference.
const String catalogId = 'demo';
const String surfaceId = 'demo';

/// Lets a sample's [SampleSpec.onAction] push follow-up data updates (and read
/// current values) without touching the engine plumbing. Constructed by the
/// per-framework `Sample` host from its processor and surface.
class SampleHost {
  SampleHost(this._processor, this._surface);

  final MessageProcessor<ComponentApi> _processor;
  final SurfaceModel<ComponentApi> _surface;

  /// Reads the current value at [path] in the surface's data model.
  Object? read(String path) => _surface.dataModel.get(path);

  /// Writes [value] at [path] (an `updateDataModel` message); bound widgets
  /// re-render reactively.
  void updateData(String path, Object? value) {
    _processor.processMessages(<A2uiMessage>[
      UpdateDataModelMessage(surfaceId: surfaceId, path: path, value: value),
    ]);
  }
}

/// A self-contained, **framework-neutral** A2UI Craft demo: everything needed to
/// drive a surface, as data plus one action handler.
///
/// This is exactly what a real deployment ships ephemerally — an RFW template
/// ([catalogSource]), its component API as JSON Schema ([catalogSchema]), and a
/// script of A2UI [messages] — with [onAction] standing in for the host app's
/// own response logic. The Flutter and Jaspr galleries each wrap one of these in
/// a tiny per-framework `Sample` widget, so the sample itself is defined once.
class SampleSpec {
  SampleSpec({
    required this.label,
    required this.catalogSource,
    required this.catalogSchema,
    required this.messages,
    this.onAction,
  });

  /// A short name for the gallery's navigation.
  final String label;

  /// The high-level catalog as RFW template source
  /// (`import core; widget Foo = …;`).
  final String catalogSource;

  /// The component API as a raw JSON Schema catalog document
  /// (`{catalogId, components: {...}}`), loaded ephemerally via `loadCatalog`.
  final Map<String, Object?> catalogSchema;

  /// The A2UI messages that build the surface (root id `root`).
  final List<A2uiMessage> messages;

  /// Handles an action dispatched by the rendered UI, if any.
  final void Function(A2uiClientAction action, SampleHost host)? onAction;
}
