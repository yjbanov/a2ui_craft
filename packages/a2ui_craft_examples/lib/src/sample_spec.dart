// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

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

  /// Decodes a sample from its three **code-free data files**: the RFW
  /// [template] (a `.craft` source string), the component API [schemaJson]
  /// (a JSON Schema catalog document), and [messagesJson] (a JSON array of A2UI
  /// messages). This is the inverse of authoring a sample in Dart — the site and
  /// the example apps build every built-in sample this way, and the site's editor
  /// rebuilds an edited sample with it for live preview.
  ///
  /// A `{{framework}}` token in any of the three strings is replaced with
  /// [framework] when given (so a sample can show which engine renders it).
  /// [onAction] is supplied by the host (e.g. the site's action log); the data
  /// files carry no action logic.
  factory SampleSpec.fromData({
    required String label,
    required String template,
    required String schemaJson,
    required String messagesJson,
    String? framework,
    void Function(A2uiClientAction action, SampleHost host)? onAction,
  }) {
    String sub(String s) =>
        framework == null ? s : s.replaceAll('{{framework}}', framework);
    final Map<String, Object?> schema =
        jsonDecode(sub(schemaJson)) as Map<String, Object?>;
    final List<A2uiMessage> messages = <A2uiMessage>[
      for (final Object? m in jsonDecode(sub(messagesJson)) as List<Object?>)
        A2uiMessage.fromJson(m as Map<String, dynamic>),
    ];
    return SampleSpec(
      label: label,
      catalogSource: sub(template),
      catalogSchema: schema,
      messages: messages,
      onAction: onAction,
    );
  }

  /// A short name for the gallery's navigation.
  final String label;

  /// The catalog as RFW template source
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
