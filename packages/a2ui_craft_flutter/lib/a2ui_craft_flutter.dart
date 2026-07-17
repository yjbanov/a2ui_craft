// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// # A2UI Craft — Flutter adapter
///
/// Renders A2UI Craft (RFW-format) templates using Flutter widgets. The public
/// API (`Runtime`, `RemoteWidget`, `LocalWidgetLibrary`,
/// `createCoreComponents`, ...) is intentionally identical to the other
/// framework adapters; only the rendered node type (Flutter [Widget]) differs.
library a2ui_craft_flutter;

// Re-export the framework-agnostic engine so this adapter is a single
// entrypoint: one dependency and one import give an app both the rendering
// layer and the engine's value types, theming, media context, and functions.
//
// `Switch` is hidden: it names the engine's RFW control-flow node, which would
// shadow Flutter's `Switch` widget for any app that also imports material (the
// common case). Apps that need the RFW node import `package:a2ui_craft` directly
// — the same `hide Switch` convention this repo's own tests already follow.
export 'package:a2ui_craft/a2ui_craft.dart' hide Switch;

export 'src/a2ui_to_rfw_adapter.dart';
export 'src/primitives.dart';
export 'src/remote_component.dart';
export 'src/runtime.dart';
export 'src/sample_view.dart';
