// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Why a driver session stopped.
///
/// Every value is terminal: a faulted session is never resumed, only replaced
/// by a fresh one. Hosts surface the fault rather than letting a surface go on
/// impersonating a working app.
enum SessionFaultCode {
  /// The two ends do not speak the same protocol version.
  versionSkew,

  /// A frame arrived with an unexpected sequence number — a message was lost,
  /// duplicated, or reordered.
  outOfOrder,

  /// A message that is not legal in the session's current state, or not legal
  /// for the sender's role at all.
  illegalMessage,

  /// A frame could not be decoded.
  malformed,

  /// The channel's token bucket ran dry — a flood of events or updates.
  budgetExhausted,

  /// The peer stopped answering heartbeats.
  heartbeatLost,

  /// The driver reported an error of its own.
  driverError,

  /// The driver's runtime died (worker crash, isolate exit, socket close).
  driverCrash,

  /// The driver tried to write a data key the host reserves for itself.
  hostKeyViolation,
}

/// A terminal session failure.
///
/// Thrown by the session machinery and, once thrown, latched: the session
/// answers every later call with the same fault.
final class SessionFault implements Exception {
  /// Creates a fault with a machine-readable [code] and a human-readable
  /// [message].
  const SessionFault(this.code, this.message, {this.details});

  /// What kind of failure this is.
  final SessionFaultCode code;

  /// A human-readable explanation, suitable for a developer-facing log and for
  /// the host's failure card.
  final String message;

  /// Optional structured context — the offending frame, the exhausted budget's
  /// numbers, the peer's error payload.
  final Object? details;

  @override
  String toString() => 'SessionFault(${code.name}): $message'
      '${details == null ? '' : ' — $details'}';
}

/// A frame could not be decoded into a well-formed message.
///
/// Distinct from [SessionFault] because it is raised by the codec, which has no
/// session to fault; the session converts it into a
/// [SessionFaultCode.malformed] fault.
final class LogicProtocolError implements Exception {
  /// Creates an error describing why a frame could not be decoded.
  const LogicProtocolError(this.message, {this.details});

  /// What was wrong with the frame.
  final String message;

  /// The offending payload, when available.
  final Object? details;

  @override
  String toString() => 'LogicProtocolError: $message'
      '${details == null ? '' : ' — $details'}';
}
