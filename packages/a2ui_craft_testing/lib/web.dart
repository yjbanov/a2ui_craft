// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The web-only half of the driver conformance dimension: the same suite,
/// pointed at drivers running in a **web worker** and written in **JavaScript**.
///
/// Kept out of the main testing library so a VM test suite never reaches
/// `package:web`.
library;

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:a2ui_craft_logic/web.dart';

/// The JavaScript implementations of the conformance fixtures.
///
/// Deliberately *ports*, not bindings: each is written against the JavaScript
/// driver SDK with no knowledge of Dart, and must produce the same writes and
/// the same status strings as the Dart fixture of the same name. The suite is
/// what holds them to it.
String conformanceDriverJs(String fixtureName) => switch (fixtureName) {
      'counter' => _counterJs,
      'clamp' => _clampJs,
      'cart' => cartMiniApp.driverJs,
      _ => throw ArgumentError.value(
          fixtureName,
          'fixtureName',
          'Unknown conformance driver fixture',
        ),
    };

/// Runs the named fixture as JavaScript, in a worker.
///
/// Pass this as `runDriverConformance`'s `makeRunner` to re-run the identical
/// cases against a sandboxed, foreign-language driver. Re-running them
/// *unmodified* is the proof; a suite that needed edits here would be
/// demonstrating the opposite.
DriverTransport workerConformanceRunner(String fixtureName) =>
    WorkerDriverRunner.fromSource(conformanceDriverJs(fixtureName));

const String _counterJs = r'''
var count = 0;
a2uiDriver({
  onInit: function (ctx) { ctx.write('/status', 'ready'); },
  handlers: {
    go: function (ctx, event) {
      count += 1;
      ctx.write('/status', 'go ' + count);
    },
  },
});
''';

const String _clampJs = r'''
a2uiDriver({
  onInit: function (ctx) { ctx.write('/status', 'ready'); },
  handlers: {
    submit: function (ctx, event) {
      ctx.write('/status', 'agreed: ' + event.values['/agreed']);
      ctx.write('/agreed', false);
    },
  },
});
''';
