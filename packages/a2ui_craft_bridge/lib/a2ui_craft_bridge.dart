// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Renders A2UI surfaces with the A2UI Craft engine, layered on `a2ui_core`.
///
/// `a2ui_core` (`MessageProcessor` + `SurfaceModel` + `GenericBinder`) owns the
/// A2UI protocol, the data model, and the resolution of bindings, functions, and
/// `checks`. This package is the thin, framework-neutral bridge that turns a
/// component's resolved props into RFW template args: see [A2uiComponentBinding]
/// (one per A2UI component id) and [a2uiArgsFromProps]. Framework adapters render
/// each binding's component via `Runtime.buildNode`.
library a2ui_craft_bridge;

export 'src/a2ui_binding.dart';
export 'src/basic_catalog.dart';
export 'src/catalog_loader.dart';
