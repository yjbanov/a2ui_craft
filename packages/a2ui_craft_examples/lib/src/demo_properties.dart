// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A property of the templating system that a sample can demonstrate.
///
/// Each sample project's `manifest.json` labels itself with the properties it
/// meaningfully demonstrates (`"demonstrates": ["layout", …]`) — demo-catalog
/// metadata, not runtime semantics ([ProjectManifest] parsing ignores it).
/// The gallery's filter bar is built from this vocabulary, and the labeling is
/// deliberately strict: a sample that merely *contains* a button is not a
/// controls demo, so gaps in coverage stay visible instead of being diluted.
class DemoProperty {
  const DemoProperty({
    required this.id,
    required this.label,
    required this.description,
  });

  /// The stable identifier used in `manifest.json` `demonstrates` lists.
  final String id;

  /// Short human-facing name (a filter checkbox label).
  final String label;

  /// What a sample carrying this property shows.
  final String description;
}

/// The demonstrated-property vocabulary, in filter-bar order.
const List<DemoProperty> demoProperties = <DemoProperty>[
  DemoProperty(
    id: 'layout',
    label: 'Layout',
    description: 'Diversity of the layout primitives: row/column/flex, '
        'center, alignment, aspect ratio, sized/constrained boxes, padding, '
        'wrap.',
  ),
  DemoProperty(
    id: 'controls',
    label: 'Controls & state',
    description: 'Interactive controls (buttons, checkboxes, sliders, text '
        'fields, …) and how their actions affect the mini-app state.',
  ),
  DemoProperty(
    id: 'theming',
    label: 'Theming',
    description: 'Projects themed via design tokens (default or custom '
        'brands), applied consistently across Jaspr and Flutter.',
  ),
  DemoProperty(
    id: 'functions',
    label: 'Functions',
    description: 'Local function calling: in-template computation over '
        'args and state.',
  ),
  DemoProperty(
    id: 'a2ui',
    label: 'A2UI integration',
    description: 'Richer A2UI Transport composition: multiple components '
        'wired by id references, data-model updates, the full message '
        'lifecycle.',
  ),
];

/// Looks up a property by [id], or null for an unknown id.
DemoProperty? demoPropertyById(String id) {
  for (final DemoProperty property in demoProperties) {
    if (property.id == id) return property;
  }
  return null;
}
