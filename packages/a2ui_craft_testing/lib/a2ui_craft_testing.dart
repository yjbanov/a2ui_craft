// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shared, framework-neutral testing support for A2UI Craft adapters.
///
/// Exposes the core component **catalog** (the contract every adapter must
/// implement) and the cross-framework **conformance suite** (the shared
/// behavioral spec each adapter runs against its own renderer). This package is
/// test-only and not published.
library a2ui_craft_testing;

export 'src/catalog.dart';
export 'src/conformance.dart';
export 'src/geometry.dart';
