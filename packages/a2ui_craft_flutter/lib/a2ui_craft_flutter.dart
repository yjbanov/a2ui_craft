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

export 'src/a2ui_to_rfw_adapter.dart';
export 'src/primitives.dart';
export 'src/remote_component.dart';
export 'src/runtime.dart';
export 'src/sample_view.dart';
