// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

library a2ui_craft_jaspr;

// Re-export the framework-agnostic engine so this adapter is a single
// entrypoint: one dependency and one import give an app both the rendering
// layer and the engine's value types, theming, media context, and functions.
//
// `Switch` is hidden to keep the adapters' re-export surface symmetric with the
// Flutter adapter (where the engine's RFW `Switch` node would shadow Flutter's
// `Switch` widget). Apps that need the RFW node import `package:a2ui_craft`
// directly.
export 'package:a2ui_craft/a2ui_craft.dart' hide Switch;

export 'src/a2ui_to_rfw_adapter.dart';
export 'src/primitives.dart';
export 'src/remote_component.dart';
export 'src/runtime.dart';
export 'src/sample_view.dart';
