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
export 'src/samples/account_balance.dart';
export 'src/samples/boxes.dart';
export 'src/samples/contact_card.dart';
export 'src/samples/counter.dart';
export 'src/samples/form.dart';
export 'src/samples/gallery.dart';
export 'src/samples/greeting.dart';
export 'src/samples/layout.dart';
export 'src/samples/login_form.dart';
export 'src/samples/product_card.dart';
export 'src/samples/profile_card.dart';
export 'src/samples/restaurant_card.dart';
export 'src/samples/shipping_status.dart';
export 'src/samples/simple_text.dart';
export 'src/samples/stats_card.dart';
export 'src/samples/weather.dart';
