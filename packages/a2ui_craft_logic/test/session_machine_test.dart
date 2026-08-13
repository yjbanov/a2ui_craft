// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

LogicSessionMachine _host() => LogicSessionMachine(role: LogicRole.host);
LogicSessionMachine _driver() => LogicSessionMachine(role: LogicRole.driver);

/// Drives both ends through a complete handshake, returning them ready.
(LogicSessionMachine, LogicSessionMachine) _handshaken() {
  final LogicSessionMachine host = _host();
  final LogicSessionMachine driver = _driver();
  host.receive(driver.send(const HelloMessage()));
  driver.receive(host.send(const InitMessage(surfaceId: 's')));
  return (host, driver);
}

Matcher _faults(SessionFaultCode code) => throwsA(
      isA<SessionFault>().having((SessionFault f) => f.code, 'code', code),
    );

void main() {
  group('handshake', () {
    test('driver speaks first, host answers, both reach ready', () {
      final LogicSessionMachine host = _host();
      final LogicSessionMachine driver = _driver();
      expect(host.state, LogicSessionState.connecting);
      expect(driver.state, LogicSessionState.connecting);

      final LogicFrame hello = driver.send(const HelloMessage());
      expect(driver.state, LogicSessionState.handshaking);
      host.receive(hello);
      expect(host.state, LogicSessionState.handshaking);

      final LogicFrame init = host.send(const InitMessage(surfaceId: 's'));
      expect(host.state, LogicSessionState.ready);
      driver.receive(init);
      expect(driver.state, LogicSessionState.ready);
      expect(driver.isReady, isTrue);
    });

    test('version skew fails the handshake loudly, on both ends', () {
      final LogicSessionMachine host = _host();
      expect(
        () => host.receive(const LogicFrame(
          seq: 1,
          message: HelloMessage(protocolVersion: '99.0'),
        )),
        _faults(SessionFaultCode.versionSkew),
      );
      expect(host.state, LogicSessionState.faulted);

      final LogicSessionMachine driver = _driver();
      driver.send(const HelloMessage());
      expect(
        () => driver.receive(const LogicFrame(
          seq: 1,
          message: InitMessage(surfaceId: 's', protocolVersion: '99.0'),
        )),
        _faults(SessionFaultCode.versionSkew),
      );
    });
  });

  group('legality', () {
    test('steady-state traffic before init is refused', () {
      final LogicSessionMachine host = _host();
      expect(
        () => host.send(const EventMessage(
          name: 'tap',
          surfaceId: 's',
          sourceComponentId: 'b',
        )),
        _faults(SessionFaultCode.illegalMessage),
      );
    });

    test('a second hello is refused', () {
      final LogicSessionMachine host = _host();
      host.receive(const LogicFrame(seq: 1, message: HelloMessage()));
      expect(
        () => host.receive(const LogicFrame(seq: 2, message: HelloMessage())),
        _faults(SessionFaultCode.illegalMessage),
      );
    });

    test('an update before init is refused', () {
      final LogicSessionMachine host = _host();
      host.receive(const LogicFrame(seq: 1, message: HelloMessage()));
      expect(
        () => host.receive(LogicFrame(
          seq: 2,
          message: UpdateMessage(<A2uiMessage>[
            UpdateDataModelMessage(surfaceId: 's', path: '/x', value: 1),
          ]),
        )),
        _faults(SessionFaultCode.illegalMessage),
      );
    });

    test('a message sent by the wrong role is refused', () {
      // A host must never send `hello`; only the driver announces itself.
      final LogicSessionMachine host = _host();
      expect(
        () => host.send(const HelloMessage()),
        _faults(SessionFaultCode.illegalMessage),
      );

      // Symmetrically, a driver must never send `event`.
      final LogicSessionMachine driver = _driver();
      driver.send(const HelloMessage());
      driver.receive(const LogicFrame(
        seq: 1,
        message: InitMessage(surfaceId: 's'),
      ));
      expect(
        () => driver.send(const EventMessage(
          name: 'tap',
          surfaceId: 's',
          sourceComponentId: 'b',
        )),
        _faults(SessionFaultCode.illegalMessage),
      );
    });

    test('error and terminate are legal mid-handshake', () {
      final LogicSessionMachine host = _host();
      host.send(const TerminateMessage(reason: 'host went away'));
      expect(host.state, LogicSessionState.terminated);
    });
  });

  group('ordering', () {
    test('a gap in the inbound stream faults the session', () {
      final (LogicSessionMachine host, LogicSessionMachine driver) =
          _handshaken();
      driver.send(const PongMessage(nonce: 1)); // seq 2, never delivered
      final LogicFrame third = driver.send(const PongMessage(nonce: 2));
      expect(third.seq, 3);
      expect(() => host.receive(third), _faults(SessionFaultCode.outOfOrder));
    });

    test('a replayed frame faults the session', () {
      final (LogicSessionMachine host, LogicSessionMachine driver) =
          _handshaken();
      final LogicFrame pong = driver.send(const PongMessage(nonce: 1));
      host.receive(pong);
      expect(() => host.receive(pong), _faults(SessionFaultCode.outOfOrder));
    });

    test('each end numbers its own stream from 1, without gaps', () {
      final (LogicSessionMachine host, LogicSessionMachine driver) =
          _handshaken();
      // The host has sent exactly one frame so far (init).
      expect(
        host.send(const PingMessage(nonce: 1)).seq,
        2,
      );
      // The driver's own numbering is independent of the host's.
      expect(driver.send(const PongMessage(nonce: 1)).seq, 2);
    });
  });

  group('terminal states latch', () {
    test('a faulted session refuses all later traffic with the same fault', () {
      final LogicSessionMachine host = _host();
      expect(
        () => host.receive(const LogicFrame(
          seq: 1,
          message: HelloMessage(protocolVersion: '99.0'),
        )),
        _faults(SessionFaultCode.versionSkew),
      );
      // The original cause survives; it is not overwritten by the consequence.
      expect(
        () => host.send(const TerminateMessage(reason: 'cleanup')),
        _faults(SessionFaultCode.versionSkew),
      );
      expect(host.fault!.code, SessionFaultCode.versionSkew);
    });

    test('a received error message is terminal in this version', () {
      final (LogicSessionMachine host, LogicSessionMachine driver) =
          _handshaken();
      host.receive(driver.send(const ErrorMessage(
        code: 'handlerThrew',
        message: 'checkout blew up',
      )));
      expect(host.state, LogicSessionState.faulted);
      expect(host.fault!.code, SessionFaultCode.driverError);
      expect(host.fault!.message, contains('checkout blew up'));
    });

    test('a terminated session refuses to keep talking', () {
      final (LogicSessionMachine host, LogicSessionMachine driver) =
          _handshaken();
      host.receive(driver.send(const TerminateMessage(reason: 'done')));
      expect(host.state, LogicSessionState.terminated);
      expect(
        () => host.send(const PingMessage(nonce: 1)),
        throwsA(isA<SessionFault>()),
      );
    });
  });

  group('raising faults from outside the machine', () {
    test('budget exhaustion and heartbeat loss latch like protocol faults', () {
      final (LogicSessionMachine host, _) = _handshaken();
      expect(
        () => host.raise(
          SessionFaultCode.budgetExhausted,
          'event budget drained',
        ),
        _faults(SessionFaultCode.budgetExhausted),
      );
      expect(host.isOpen, isFalse);
    });
  });

  group('decoding straight off the wire', () {
    test('a malformed payload faults as malformed, not as a crash', () {
      final LogicSessionMachine host = _host();
      expect(
        () => host.receiveJson(<String, Object?>{'nonsense': true}),
        _faults(SessionFaultCode.malformed),
      );
    });

    test('a well-formed payload is accepted and advances the machine', () {
      final LogicSessionMachine host = _host();
      final LogicMessage message = host.receiveJson(
        const LogicFrame(seq: 1, message: HelloMessage()).toJson(),
      );
      expect(message, isA<HelloMessage>());
      expect(host.state, LogicSessionState.handshaking);
    });
  });
}
