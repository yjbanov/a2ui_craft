// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Business logic for A2UI Craft mini-apps.
///
/// A **driver** is anything on the far side of an asynchronous channel that
/// receives a surface's user events and answers with A2UI Transport messages.
/// A live agent is one; a recorded message stream is another; this package adds
/// the third — an author-written program, in any language that can hold state
/// and read and write JSON.
///
/// Logic attaches to the *surface*, not to the template. A template names
/// events and binds data paths, both plain strings, so the entire coupling
/// surface between a template and its logic is the protocol defined here.
library;

export 'src/budget.dart';
export 'src/driver.dart';
export 'src/envelope.dart';
export 'src/fault.dart';
export 'src/in_process_runner.dart';
export 'src/inference_catalog.dart';
export 'src/manifest.dart';
export 'src/mini_app.dart';
export 'src/session.dart';
export 'src/session_machine.dart';
export 'src/transport.dart';
