// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Mini-app conformance, **rendered**, against a driver written in JavaScript
/// and running in a web worker.
///
/// It re-runs the shared driver conformance suite with nothing changed but the
/// runner factory: no case redefined, relaxed, or skipped. If a sandboxed,
/// foreign-language driver ever needs its own copy of these cases, the claim
/// that the coupling surface is the protocol has failed, and this file is where
/// that shows up.
///
/// It lives in the Jaspr package for one practical reason — rendering needs a
/// renderer, and this is the only browser-capable harness in the repo. The
/// protocol-level worker cases (crash, hang, one-file SDK) live where they
/// belong, in `a2ui_craft_logic`'s own browser test. Nothing about drivers
/// reaches this package's published library; the dependency is dev-only, via
/// `a2ui_craft_testing`.
@TestOn('browser')
library;

import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:a2ui_craft_testing/web.dart';
import 'package:test/test.dart';

import 'conformance_harness.dart';

void main() {
  runDriverConformance(
    jasprConformanceDriver(),
    makeRunner: workerConformanceRunner,
  );
}
