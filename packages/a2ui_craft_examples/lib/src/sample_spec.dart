// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';

import 'project.dart';

/// The `a2ui_core` catalog id and surface id the samples' messages reference.
const String catalogId = 'demo';
const String surfaceId = 'demo';

/// A self-contained, **framework-neutral** A2UI Craft demo, as **data**: an RFW
/// catalog [catalogSource] (template), its component API [catalogSchema] (a JSON
/// Schema catalog document), and a script of A2UI [messages].
///
/// Samples are authored as code-free data files under `samples/<id>/`
/// (`template.craft` / `schema.json` / `messages.json`) and decoded with
/// [SampleSpec.fromData]; the Flutter and Jaspr adapters each render one through
/// their reusable `SampleView`. Action handling (e.g. a host action log) is the
/// host's concern, supplied to `SampleView`, not part of the data.
class SampleSpec {
  SampleSpec({
    required this.label,
    required this.catalogSource,
    required this.catalogSchema,
    required this.messages,
    this.theme,
  });

  /// Decodes a sample from its three **code-free data files**: the RFW
  /// [template] (a `.craft` source string), the component API [schemaJson]
  /// (a JSON Schema catalog document), and [messagesJson] (a JSON array of A2UI
  /// messages). The inverse of authoring a sample in Dart — the example apps and
  /// the site build every built-in sample this way, and the site's editor
  /// rebuilds an edited sample with it for live preview.
  ///
  /// A `{{framework}}` token in any of the three strings is replaced with
  /// [framework] when given (so a sample can show which engine renders it).
  ///
  /// An optional [themeJson] is the project's 4th trio file (`theme.json`);
  /// when present and recognized it becomes [theme] (see [ProjectTheme]).
  factory SampleSpec.fromData({
    required String label,
    required String template,
    required String schemaJson,
    required String messagesJson,
    String? framework,
    String? themeJson,
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
      theme: ProjectTheme.tryParse(themeJson),
    );
  }

  /// A short name for the gallery's navigation.
  final String label;

  /// The catalog as RFW template source (`import core; widget Foo = …;`).
  final String catalogSource;

  /// The component API as a raw JSON Schema catalog document
  /// (`{catalogId, components: {...}}`), loaded ephemerally via `loadCatalog`.
  final Map<String, Object?> catalogSchema;

  /// The A2UI messages that build the surface (root id `root`).
  final List<A2uiMessage> messages;

  /// The project's theme (from its `theme.json`), or null when the project
  /// ships no theme and should blend into its host.
  final ProjectTheme? theme;
}
