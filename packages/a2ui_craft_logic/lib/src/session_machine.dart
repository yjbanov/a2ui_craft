// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'envelope.dart';
import 'fault.dart';

/// Where a driver session is in its lifecycle.
enum LogicSessionState {
  /// Nothing has been said yet; the host is waiting for the driver's
  /// [HelloMessage].
  connecting,

  /// Hello has been exchanged; the host owes an [InitMessage].
  handshaking,

  /// The handshake completed. Events flow up, updates flow down.
  ready,

  /// The session failed. Terminal — see [LogicSessionMachine.fault].
  faulted,

  /// The session ended in an orderly way. Terminal.
  terminated,
}

/// The transport-free, surface-free core of a driver session.
///
/// It owns exactly three things — legality, ordering, and version agreement —
/// and nothing else, so both ends of the protocol can run the same machine and
/// so the rules are testable without a surface, a runner, or a channel.
///
/// Every violation is terminal. Once faulted or terminated, the machine
/// answers every later [send] or [receive] with the same [SessionFault]: a
/// session that has lost the thread does not get to keep talking.
class LogicSessionMachine {
  /// Creates a machine for a participant acting as [role].
  LogicSessionMachine({required this.role});

  /// Which end of the session this machine belongs to.
  final LogicRole role;

  LogicSessionState _state = LogicSessionState.connecting;
  SessionFault? _fault;
  int _outboundSeq = 0;
  int _inboundSeq = 0;

  /// The current lifecycle state.
  LogicSessionState get state => _state;

  /// Why the session failed, or `null` if it has not.
  SessionFault? get fault => _fault;

  /// Whether the handshake has completed and steady-state traffic is legal.
  bool get isReady => _state == LogicSessionState.ready;

  /// Whether the session can still carry traffic.
  bool get isOpen =>
      _state != LogicSessionState.faulted &&
      _state != LogicSessionState.terminated;

  /// The sequence number the next inbound frame must carry.
  int get expectedInboundSeq => _inboundSeq + 1;

  /// Validates [message] as outbound and stamps it with the next sequence
  /// number.
  ///
  /// Throws a [SessionFault] if the message is illegal for this role or state —
  /// sending something illegal is a defect on this side, and pretending
  /// otherwise would put the peer into a state this end cannot reason about.
  LogicFrame send(LogicMessage message) {
    _assertOpen();
    _checkLegal(message, outbound: true);
    _outboundSeq += 1;
    final LogicFrame frame = LogicFrame(seq: _outboundSeq, message: message);
    _advance(message);
    return frame;
  }

  /// Validates an inbound [frame]: ordering, legality, and — at handshake —
  /// version agreement.
  ///
  /// Returns the frame's message on success. Throws a [SessionFault] otherwise.
  LogicMessage receive(LogicFrame frame) {
    _assertOpen();
    if (frame.seq != expectedInboundSeq) {
      raise(
        SessionFaultCode.outOfOrder,
        'Expected frame #$expectedInboundSeq, got #${frame.seq}. A message was '
        'lost, duplicated, or reordered.',
        details: frame.toJson(),
      );
    }
    _checkLegal(frame.message, outbound: false);
    _checkVersion(frame.message);
    _inboundSeq = frame.seq;
    _advance(frame.message);
    return frame.message;
  }

  /// Decodes and validates a frame straight off the wire.
  ///
  /// A malformed payload is a [SessionFaultCode.malformed] fault: the peer is
  /// not speaking this protocol, so there is nothing to recover to.
  LogicMessage receiveJson(Map<String, Object?> json) {
    _assertOpen();
    final LogicFrame frame;
    try {
      frame = LogicFrame.fromJson(json);
    } on LogicProtocolError catch (error) {
      raise(
        SessionFaultCode.malformed,
        error.message,
        details: error.details,
      );
    }
    return receive(frame);
  }

  /// Faults the session for a reason the machine cannot see for itself — a
  /// drained budget, a missed heartbeat, a dead worker, a write to a
  /// host-reserved key.
  ///
  /// Always throws the resulting [SessionFault].
  Never raise(
    SessionFaultCode code,
    String message, {
    Object? details,
  }) {
    final SessionFault fault = SessionFault(code, message, details: details);
    _fault ??= fault;
    _state = LogicSessionState.faulted;
    throw _fault!;
  }

  void _assertOpen() {
    switch (_state) {
      case LogicSessionState.faulted:
        throw _fault!;
      case LogicSessionState.terminated:
        throw const SessionFault(
          SessionFaultCode.illegalMessage,
          'The session has already terminated.',
        );
      case LogicSessionState.connecting:
      case LogicSessionState.handshaking:
      case LogicSessionState.ready:
        return;
    }
  }

  void _checkLegal(LogicMessage message, {required bool outbound}) {
    final LogicRole? sender = message.sender;
    if (sender != null) {
      final LogicRole actual = outbound
          ? role
          : (role == LogicRole.host ? LogicRole.driver : LogicRole.host);
      if (sender != actual) {
        raise(
          SessionFaultCode.illegalMessage,
          "A '${message.type.name}' may only be sent by the "
          '${sender.name}, but it came from the ${actual.name}.',
        );
      }
    }

    final bool legal = switch (message.type) {
      LogicMessageType.hello => _state == LogicSessionState.connecting,
      LogicMessageType.init => _state == LogicSessionState.handshaking,
      LogicMessageType.event ||
      LogicMessageType.update ||
      LogicMessageType.ping ||
      LogicMessageType.pong =>
        _state == LogicSessionState.ready,
      // A failure or a shutdown may be announced at any point in the
      // lifecycle — including mid-handshake, which is exactly when version
      // skew is discovered.
      LogicMessageType.error || LogicMessageType.terminate => true,
    };
    if (!legal) {
      raise(
        SessionFaultCode.illegalMessage,
        "A '${message.type.name}' is not legal while the session is "
        '${_state.name}.',
      );
    }
  }

  void _checkVersion(LogicMessage message) {
    final String? peerVersion = switch (message) {
      HelloMessage(:final String protocolVersion) => protocolVersion,
      InitMessage(:final String protocolVersion) => protocolVersion,
      _ => null,
    };
    if (peerVersion == null || peerVersion == logicProtocolVersion) return;
    raise(
      SessionFaultCode.versionSkew,
      'This end speaks driver protocol $logicProtocolVersion; the peer '
      'speaks $peerVersion.',
    );
  }

  void _advance(LogicMessage message) {
    switch (message.type) {
      case LogicMessageType.hello:
        _state = LogicSessionState.handshaking;
      case LogicMessageType.init:
        _state = LogicSessionState.ready;
      case LogicMessageType.terminate:
        _state = LogicSessionState.terminated;
      case LogicMessageType.error:
        // An error is terminal in this version. A driver that threw has
        // indeterminate state, and the MVP failure policy (freeze beats
        // betray) is to take the surface out of service rather than let the
        // user keep building up work that will never persist.
        final ErrorMessage error = message as ErrorMessage;
        final SessionFault fault = SessionFault(
          SessionFaultCode.driverError,
          '${error.code}: ${error.message}',
          details: error.details,
        );
        _fault ??= fault;
        _state = LogicSessionState.faulted;
      case LogicMessageType.event:
      case LogicMessageType.update:
      case LogicMessageType.ping:
      case LogicMessageType.pong:
        break;
    }
  }
}
