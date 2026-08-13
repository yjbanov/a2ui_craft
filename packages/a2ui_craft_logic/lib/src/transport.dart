// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A bidirectional pipe carrying encoded [LogicFrame]s between a host and its
/// driver.
///
/// The transport moves JSON-shaped maps and nothing else — the same payload a
/// `postMessage`, a platform channel, or a WebSocket would carry. Even the
/// in-process transport encodes, so that a driver cannot reach a host object by
/// reference and so that a value no sandbox could carry fails in development
/// rather than in production.
///
/// See `InProcessDriverRunner` for the reference implementation.
abstract interface class DriverTransport {
  /// Begins delivering frames.
  ///
  /// Called by the host session once [onFrame] is installed. Implementations
  /// boot their driver here — spawn the worker, open the socket, construct the
  /// in-process runtime.
  void start();

  /// Sends [frame] toward the driver.
  void send(Map<String, Object?> frame);

  /// Installs the handler called for each frame arriving from the driver.
  set onFrame(void Function(Map<String, Object?> frame)? handler);

  /// Reports that the driver's runtime died — a worker crash, a socket close,
  /// an isolate exit.
  ///
  /// Distinct from a [TerminateMessage], which is an orderly goodbye the driver
  /// chose to send.
  set onCrash(void Function(String reason)? handler);

  /// Tears the transport down. Idempotent.
  void close();
}
