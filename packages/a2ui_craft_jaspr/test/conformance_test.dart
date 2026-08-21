// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The shared conformance suites, run against the Jaspr adapter on the VM.
///
/// The driver dimension runs here against the **in-process Dart** runner;
/// `driver_worker_test.dart` runs the same cases in a browser against a
/// JavaScript driver in a worker.
library;

import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';

import 'conformance_harness.dart';

void main() {
  runCoreComponentConformance(jasprConformanceDriver());
  runA2uiConformance(jasprConformanceDriver());
  runDriverConformance(jasprConformanceDriver());
}
