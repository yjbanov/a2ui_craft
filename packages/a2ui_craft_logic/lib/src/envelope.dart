// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import 'fault.dart';

/// The version of the driver session protocol this package speaks.
///
/// The two ends must agree exactly. While the protocol is at `0.x` a mismatch
/// is a hard handshake failure rather than a negotiated downgrade — breaking
/// the envelope during development should be cheap and *visible*.
const String logicProtocolVersion = '0.1';

/// Message type names this version reserves but does not implement.
///
/// Session restoration is designed (a driver returns a snapshot value; the host
/// hands it back at init) but deliberately unbuilt: a lost driver kills the
/// session on both sides and the mini-app cold-boots. These names are spoken
/// for so that adding them later cannot collide with a driver's own
/// extensions.
const List<String> reservedLogicMessageTypes = <String>[
  'suspend',
  'resume',
  'snapshot',
];

/// Which end of a driver session a participant is.
enum LogicRole {
  /// The side that renders the surface and forwards its user events.
  host,

  /// The side that runs the author's business logic and answers with A2UI
  /// Transport messages.
  driver,
}

/// The discriminator carried by every frame on the wire.
enum LogicMessageType {
  /// Driver → host. Announces the driver is alive and names the protocol
  /// version it speaks.
  hello,

  /// Host → driver. Completes the handshake and delivers host context.
  init,

  /// Host → driver. A user action from the surface.
  event,

  /// Driver → host. A batch of A2UI Transport messages to apply.
  update,

  /// Either direction. A failure the peer should know about.
  error,

  /// Either direction. This session is over.
  terminate,

  /// Host → driver. Liveness probe.
  ping,

  /// Driver → host. Liveness answer.
  pong,
}

/// A message in the driver session protocol.
///
/// Messages are values: they carry no sequence number, because ordering is the
/// channel's concern. [LogicFrame] pairs a message with its sequence number for
/// transmission.
sealed class LogicMessage {
  const LogicMessage();

  /// Reconstructs a message from its wire [type] and [body].
  ///
  /// Throws [LogicProtocolError] if the body does not match the type.
  factory LogicMessage.fromWire(
    LogicMessageType type,
    Map<String, Object?> body,
  ) {
    switch (type) {
      case LogicMessageType.hello:
        return HelloMessage(
          protocolVersion: _string(body, 'protocolVersion'),
          capabilities: _stringList(body, 'capabilities'),
        );
      case LogicMessageType.init:
        return InitMessage(
          protocolVersion: _string(body, 'protocolVersion'),
          surfaceId: _string(body, 'surfaceId'),
          context: _map(body, 'context'),
          capabilities: _stringList(body, 'capabilities'),
          snapshot: body['snapshot'],
        );
      case LogicMessageType.event:
        return EventMessage(
          name: _string(body, 'name'),
          surfaceId: _string(body, 'surfaceId'),
          sourceComponentId: _string(body, 'sourceComponentId'),
          context: _map(body, 'context'),
          values: _map(body, 'values'),
        );
      case LogicMessageType.update:
        final Object? raw = body['messages'];
        if (raw is! List) {
          throw LogicProtocolError(
            "An 'update' body needs a 'messages' list.",
            details: body,
          );
        }
        return UpdateMessage(<A2uiMessage>[
          for (final Object? entry in raw)
            if (entry is Map<String, dynamic>)
              A2uiMessage.fromJson(entry)
            else
              throw LogicProtocolError(
                'Each entry of an update must be an A2UI message object.',
                details: entry,
              ),
        ]);
      case LogicMessageType.error:
        return ErrorMessage(
          code: _string(body, 'code'),
          message: _string(body, 'message'),
          details: body['details'],
        );
      case LogicMessageType.terminate:
        return TerminateMessage(reason: _string(body, 'reason'));
      case LogicMessageType.ping:
        return PingMessage(nonce: _int(body, 'nonce'));
      case LogicMessageType.pong:
        return PongMessage(nonce: _int(body, 'nonce'));
    }
  }

  /// This message's wire discriminator.
  LogicMessageType get type;

  /// This message's wire payload, in the JSON-isomorphic value vocabulary A2UI
  /// data models use (maps, lists, strings, numbers, booleans, null).
  Map<String, Object?> get body;

  /// The role permitted to *send* this message.
  ///
  /// `null` means either end may send it.
  LogicRole? get sender;
}

/// Driver → host: the driver is alive and speaks [protocolVersion].
///
/// The driver speaks first because in every sandboxed transport it is the side
/// whose readiness the host cannot observe — a worker is not addressable until
/// it has booted.
final class HelloMessage extends LogicMessage {
  /// Announces a driver speaking [protocolVersion] and requesting
  /// [capabilities].
  const HelloMessage({
    this.protocolVersion = logicProtocolVersion,
    this.capabilities = const <String>[],
  });

  /// The protocol version the driver implements.
  final String protocolVersion;

  /// Capabilities the driver requests. Always empty in this version; the host
  /// grants nothing but the channel.
  final List<String> capabilities;

  @override
  LogicMessageType get type => LogicMessageType.hello;

  @override
  LogicRole? get sender => LogicRole.driver;

  @override
  Map<String, Object?> get body => <String, Object?>{
        'protocolVersion': protocolVersion,
        'capabilities': capabilities,
      };
}

/// Host → driver: the handshake is accepted; here is the world.
final class InitMessage extends LogicMessage {
  /// Completes the handshake for [surfaceId].
  const InitMessage({
    required this.surfaceId,
    this.protocolVersion = logicProtocolVersion,
    this.context = const <String, Object?>{},
    this.capabilities = const <String>[],
    this.snapshot,
  });

  /// The surface this driver drives.
  final String surfaceId;

  /// The protocol version the host implements.
  final String protocolVersion;

  /// Host-owned context the driver may read but never write — locale, display
  /// mode, theme selection. These land under a reserved key the host defends.
  final Map<String, Object?> context;

  /// Capabilities the host granted. Always empty in this version.
  final List<String> capabilities;

  /// Reserved for session restoration; always `null` in this version.
  final Object? snapshot;

  @override
  LogicMessageType get type => LogicMessageType.init;

  @override
  LogicRole? get sender => LogicRole.host;

  @override
  Map<String, Object?> get body => <String, Object?>{
        'protocolVersion': protocolVersion,
        'surfaceId': surfaceId,
        'context': context,
        'capabilities': capabilities,
        if (snapshot != null) 'snapshot': snapshot,
      };
}

/// Host → driver: a user acted on the surface.
final class EventMessage extends LogicMessage {
  /// Reports the action [name] dispatched by [sourceComponentId].
  const EventMessage({
    required this.name,
    required this.surfaceId,
    required this.sourceComponentId,
    this.context = const <String, Object?>{},
    this.values = const <String, Object?>{},
  });

  /// The event name the template dispatched.
  final String name;

  /// The surface the event came from.
  final String surfaceId;

  /// The component that dispatched it.
  final String sourceComponentId;

  /// The arguments the template attached to the event.
  final Map<String, Object?> context;

  /// Current values of the surface's bound data paths, keyed by path.
  ///
  /// A two-way binding writes the local data model immediately — the
  /// optimistic echo — and that write is invisible to the driver, which never
  /// saw it happen. Carrying the values with the event is how the driver learns
  /// what the user typed or dragged without a separate notification channel.
  final Map<String, Object?> values;

  @override
  LogicMessageType get type => LogicMessageType.event;

  @override
  LogicRole? get sender => LogicRole.host;

  @override
  Map<String, Object?> get body => <String, Object?>{
        'name': name,
        'surfaceId': surfaceId,
        'sourceComponentId': sourceComponentId,
        'context': context,
        'values': values,
      };
}

/// Driver → host: apply these A2UI Transport messages.
final class UpdateMessage extends LogicMessage {
  /// Carries [messages] to be applied to the surface in order.
  const UpdateMessage(this.messages);

  /// The Transport messages — data model writes, and component updates when
  /// structure genuinely changes.
  final List<A2uiMessage> messages;

  @override
  LogicMessageType get type => LogicMessageType.update;

  @override
  LogicRole? get sender => LogicRole.driver;

  @override
  Map<String, Object?> get body => <String, Object?>{
        'messages': <Object?>[for (final A2uiMessage m in messages) m.toJson()],
      };
}

/// Either direction: something went wrong that the peer should know about.
final class ErrorMessage extends LogicMessage {
  /// Reports a failure with a machine-readable [code].
  const ErrorMessage({
    required this.code,
    required this.message,
    this.details,
  });

  /// A short, stable identifier for the failure.
  final String code;

  /// A human-readable explanation.
  final String message;

  /// Optional structured context.
  final Object? details;

  @override
  LogicMessageType get type => LogicMessageType.error;

  @override
  LogicRole? get sender => null;

  @override
  Map<String, Object?> get body => <String, Object?>{
        'code': code,
        'message': message,
        if (details != null) 'details': details,
      };
}

/// Either direction: this session is over.
final class TerminateMessage extends LogicMessage {
  /// Ends the session, explaining why.
  const TerminateMessage({required this.reason});

  /// Why the session ended.
  final String reason;

  @override
  LogicMessageType get type => LogicMessageType.terminate;

  @override
  LogicRole? get sender => null;

  @override
  Map<String, Object?> get body => <String, Object?>{'reason': reason};
}

/// Host → driver: are you still there?
final class PingMessage extends LogicMessage {
  /// Probes liveness; the driver must answer with a [PongMessage] carrying the
  /// same [nonce].
  const PingMessage({required this.nonce});

  /// Matches this probe to its answer.
  final int nonce;

  @override
  LogicMessageType get type => LogicMessageType.ping;

  @override
  LogicRole? get sender => LogicRole.host;

  @override
  Map<String, Object?> get body => <String, Object?>{'nonce': nonce};
}

/// Driver → host: still here.
final class PongMessage extends LogicMessage {
  /// Answers the [PingMessage] carrying the same [nonce].
  const PongMessage({required this.nonce});

  /// The nonce of the probe being answered.
  final int nonce;

  @override
  LogicMessageType get type => LogicMessageType.pong;

  @override
  LogicRole? get sender => LogicRole.driver;

  @override
  Map<String, Object?> get body => <String, Object?>{'nonce': nonce};
}

/// A [LogicMessage] paired with the sequence number that orders it.
///
/// Each end numbers its own outbound frames from 1, monotonically and without
/// gaps, so a receiver detects loss, duplication, and reordering by arithmetic
/// alone.
final class LogicFrame {
  /// Pairs [message] with its [seq].
  const LogicFrame({required this.seq, required this.message});

  /// Decodes a frame from its JSON form.
  ///
  /// Throws [LogicProtocolError] if the frame is malformed.
  factory LogicFrame.fromJson(Map<String, Object?> json) {
    final Object? seq = json['seq'];
    if (seq is! int) {
      throw LogicProtocolError(
        "A frame needs an integer 'seq'.",
        details: json,
      );
    }
    final Object? rawType = json['type'];
    if (rawType is! String) {
      throw LogicProtocolError(
        "A frame needs a string 'type'.",
        details: json,
      );
    }
    final LogicMessageType? type = _typeByName[rawType];
    if (type == null) {
      final String extra = reservedLogicMessageTypes.contains(rawType)
          ? " — '$rawType' is reserved by protocol $logicProtocolVersion but "
              'not implemented'
          : '';
      throw LogicProtocolError(
        "Unknown frame type '$rawType'$extra.",
        details: json,
      );
    }
    final Object? body = json['body'];
    if (body is! Map<String, Object?>) {
      throw LogicProtocolError(
        "A frame needs a 'body' object.",
        details: json,
      );
    }
    return LogicFrame(seq: seq, message: LogicMessage.fromWire(type, body));
  }

  /// This frame's position in its sender's outbound stream, starting at 1.
  final int seq;

  /// The message being carried.
  final LogicMessage message;

  /// Encodes this frame for transmission.
  Map<String, Object?> toJson() => <String, Object?>{
        'seq': seq,
        'type': message.type.name,
        'body': message.body,
      };

  @override
  String toString() => 'LogicFrame(#$seq ${message.type.name})';
}

final Map<String, LogicMessageType> _typeByName = <String, LogicMessageType>{
  for (final LogicMessageType t in LogicMessageType.values) t.name: t,
};

String _string(Map<String, Object?> body, String key) {
  final Object? value = body[key];
  if (value is! String) {
    throw LogicProtocolError(
      "Field '$key' must be a string.",
      details: body,
    );
  }
  return value;
}

int _int(Map<String, Object?> body, String key) {
  final Object? value = body[key];
  if (value is! int) {
    throw LogicProtocolError(
      "Field '$key' must be an integer.",
      details: body,
    );
  }
  return value;
}

Map<String, Object?> _map(Map<String, Object?> body, String key) {
  final Object? value = body[key];
  if (value == null) return const <String, Object?>{};
  if (value is! Map) {
    throw LogicProtocolError(
      "Field '$key' must be an object.",
      details: body,
    );
  }
  return Map<String, Object?>.from(value);
}

List<String> _stringList(Map<String, Object?> body, String key) {
  final Object? value = body[key];
  if (value == null) return const <String>[];
  if (value is! List) {
    throw LogicProtocolError(
      "Field '$key' must be a list of strings.",
      details: body,
    );
  }
  return <String>[for (final Object? e in value) e.toString()];
}
