// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';
import 'dart:convert';

import 'driver.dart';
import 'transport.dart';

/// Runs a Dart [Driver] in the host's own isolate, behind a channel that
/// behaves like a sandboxed one.
///
/// This is the reference runner — the one the conformance suite drives — and
/// its job is to be *unobservably different* from a worker. Two rules buy that:
///
/// **Delivery crosses an event-loop turn, in both directions.** A worker's
/// `postMessage` reply physically cannot arrive within the turn that dispatched
/// the event. A microtask-scheduled reply *can*: it lands mid-flush, before
/// same-turn work queued earlier, making an in-process driver observably more
/// prompt than anything it stands in for — and inviting code to grow a
/// dependency on same-turn delivery that a sandboxed runner then breaks. So
/// frames are scheduled as zero-length timers, never microtasks.
///
/// **Frames are encoded, not shared.** Every frame round-trips through JSON
/// text, so a driver cannot reach a host object by reference, and a value no
/// sandbox could carry fails here rather than on the day someone swaps in a
/// worker.
class InProcessDriverRunner implements DriverTransport {
  /// Creates a runner hosting [driver].
  ///
  /// [diagnostics] is forwarded to the driver runtime; see [DriverRuntime].
  InProcessDriverRunner(Driver driver, {DriverDiagnosticSink? diagnostics}) {
    _runtime = DriverRuntime(
      driver,
      send: _fromDriver,
      diagnostics: diagnostics,
    );
  }

  late final DriverRuntime _runtime;
  void Function(Map<String, Object?> frame)? _onFrame;
  void Function(String reason)? _onCrash;
  bool _closed = false;

  @override
  set onFrame(void Function(Map<String, Object?> frame)? handler) =>
      _onFrame = handler;

  @override
  set onCrash(void Function(String reason)? handler) => _onCrash = handler;

  @override
  void start() => _defer(() => _runtime.start());

  @override
  void send(Map<String, Object?> frame) {
    final Map<String, Object?>? encoded = _encode(frame, 'host');
    if (encoded == null) return;
    _defer(() => _runtime.receive(encoded));
  }

  @override
  void close() {
    _closed = true;
    _onFrame = null;
    _onCrash = null;
  }

  void _fromDriver(Map<String, Object?> frame) {
    final Map<String, Object?>? encoded = _encode(frame, 'driver');
    if (encoded == null) return;
    _defer(() => _onFrame?.call(encoded));
  }

  /// Schedules [action] on the event loop — a zero-length timer, not a
  /// microtask. Timers with equal expiry fire in creation order, so frames stay
  /// ordered.
  void _defer(void Function() action) {
    Timer.run(() {
      if (_closed) return;
      action();
    });
  }

  Map<String, Object?>? _encode(Map<String, Object?> frame, String origin) {
    try {
      return jsonDecode(jsonEncode(frame)) as Map<String, Object?>;
    } catch (error) {
      // Nothing that cannot be encoded could have crossed a real sandbox
      // boundary either, so this is the same failure a worker would have had —
      // surfaced at the runner that stands in for it.
      _onCrash?.call(
        'The $origin sent a frame that is not JSON-encodable: $error',
      );
      return null;
    }
  }
}
