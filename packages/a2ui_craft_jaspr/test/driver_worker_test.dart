// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The language-neutrality proof.
///
/// This file re-runs the **entire driver conformance suite** — the same cases
/// the in-process Dart runner passes — against drivers written in JavaScript,
/// running in a web worker. Nothing is imported from the suite but its entry
/// point and a different runner factory: no case is redefined, relaxed, or
/// skipped.
///
/// If a sandboxed, foreign-language driver ever needs its own copy of these
/// cases, the claim that the coupling surface is the protocol has failed, and
/// this file is where that shows up.
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
