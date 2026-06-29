// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shared, framework-neutral A2UI Craft sample definitions.
///
/// Each sample is a self-contained demo as **code-free data** — an RFW template
/// (`.craft`), its component API as JSON Schema, and an A2UI message script —
/// authored under `samples/<id>/` and baked into [rawSamples] by
/// `tool/gen_samples.dart`. [SampleSpec.fromData] decodes the trio (the site's
/// editor uses it for live preview); the Flutter and Jaspr galleries render a
/// [SampleSpec] through a thin per-framework `Sample` widget.
library a2ui_craft_examples;

export 'src/sample_spec.dart';
export 'src/samples.dart';
