// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The web-only half of A2UI Craft's driver support: running a driver in a
/// **web worker**.
///
/// Kept out of the main library so a host that never sandboxes a driver — a
/// Flutter app running compiled-in Dart logic, say — does not drag `package:web`
/// in behind it. Nothing here is specific to a rendering framework: a host
/// *composes* a runner with a surface, so the adapters know nothing about any
/// of it.
library;

export 'src/driver_sdk.g.dart';
export 'src/worker_runner.dart';
