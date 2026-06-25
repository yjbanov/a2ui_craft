// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shared, framework-neutral A2UI Craft sample definitions.
///
/// Each [SampleSpec] is a self-contained demo as data — an RFW template, its
/// component API as JSON Schema, an A2UI message script, and an action handler.
/// The Flutter and Jaspr example galleries each render these through a thin
/// per-framework `Sample` widget, so the samples are defined exactly once.
library a2ui_craft_examples;

export 'src/sample_spec.dart';
export 'src/samples.dart';
export 'src/samples/counter.dart';
export 'src/samples/gallery.dart';
export 'src/samples/greeting.dart';
export 'src/samples/profile_card.dart';
