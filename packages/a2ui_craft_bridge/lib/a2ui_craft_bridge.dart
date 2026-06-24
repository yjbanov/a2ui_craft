// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Renders A2UI Transport surfaces with the A2UI Craft engine.
///
/// See [A2uiSurface]: feed it decoded A2UI Transport envelopes, then render each
/// component's definition (via `componentDefinition`) and the `data` model with
/// any framework adapter. Framework-neutral.
library a2ui_craft_bridge;

export 'src/a2ui_surface.dart';
