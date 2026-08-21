// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

/// Round-trips a frame through actual JSON text, not just the map form — the
/// protocol's whole premise is that any language with a JSON codec can speak
/// it, so anything that survives only as Dart objects does not count.
LogicFrame _roundTrip(LogicFrame frame) {
  final Object? decoded = jsonDecode(jsonEncode(frame.toJson()));
  return LogicFrame.fromJson(decoded! as Map<String, Object?>);
}

void main() {
  group('codec round-trips', () {
    test('hello carries version and requested capabilities', () {
      final LogicFrame frame = _roundTrip(
        const LogicFrame(seq: 1, message: HelloMessage()),
      );
      expect(frame.seq, 1);
      final HelloMessage hello = frame.message as HelloMessage;
      expect(hello.protocolVersion, logicProtocolVersion);
      expect(hello.capabilities, isEmpty);
    });

    test('init carries host context and the reserved snapshot slot', () {
      final LogicFrame frame = _roundTrip(
        const LogicFrame(
          seq: 7,
          message: InitMessage(
            surfaceId: 'cart',
            context: <String, Object?>{'locale': 'en-US', 'mode': 'dark'},
          ),
        ),
      );
      final InitMessage init = frame.message as InitMessage;
      expect(init.surfaceId, 'cart');
      expect(init.context, <String, Object?>{
        'locale': 'en-US',
        'mode': 'dark',
      });
      expect(init.snapshot, isNull,
          reason: 'restoration is designed but unbuilt; the slot stays empty');
    });

    test('event carries action context and current two-way values', () {
      final LogicFrame frame = _roundTrip(
        const LogicFrame(
          seq: 2,
          message: EventMessage(
            name: 'setQuantity',
            surfaceId: 's',
            sourceComponentId: 'qtyField',
            context: <String, Object?>{'sku': 'A-1'},
            values: <String, Object?>{'/cart/0/qty': 12},
          ),
        ),
      );
      final EventMessage event = frame.message as EventMessage;
      expect(event.name, 'setQuantity');
      expect(event.sourceComponentId, 'qtyField');
      expect(event.context, <String, Object?>{'sku': 'A-1'});
      expect(event.values, <String, Object?>{'/cart/0/qty': 12});
    });

    test('update carries A2UI Transport messages verbatim', () {
      final LogicFrame frame = _roundTrip(
        LogicFrame(
          seq: 3,
          message: UpdateMessage(<A2uiMessage>[
            CreateSurfaceMessage(surfaceId: 's', catalogId: 'demo'),
            UpdateDataModelMessage(surfaceId: 's', path: '/total', value: 42),
          ]),
        ),
      );
      final UpdateMessage update = frame.message as UpdateMessage;
      expect(update.messages, hasLength(2));
      expect(update.messages.first, isA<CreateSurfaceMessage>());
      final UpdateDataModelMessage write =
          update.messages.last as UpdateDataModelMessage;
      expect(write.path, '/total');
      expect(write.value, 42);
    });

    test('error, terminate, and heartbeat round-trip', () {
      final LogicFrame error = _roundTrip(
        const LogicFrame(
          seq: 1,
          message: ErrorMessage(
            code: 'handlerThrew',
            message: 'checkout failed',
            details: <String, Object?>{'sku': 'A-1'},
          ),
        ),
      );
      expect((error.message as ErrorMessage).code, 'handlerThrew');
      expect((error.message as ErrorMessage).details,
          <String, Object?>{'sku': 'A-1'});

      final LogicFrame terminate = _roundTrip(
        const LogicFrame(
          seq: 2,
          message: TerminateMessage(reason: 'surface disposed'),
        ),
      );
      expect(
          (terminate.message as TerminateMessage).reason, 'surface disposed');

      final LogicFrame ping =
          _roundTrip(const LogicFrame(seq: 3, message: PingMessage(nonce: 9)));
      expect((ping.message as PingMessage).nonce, 9);
      final LogicFrame pong =
          _roundTrip(const LogicFrame(seq: 4, message: PongMessage(nonce: 9)));
      expect((pong.message as PongMessage).nonce, 9);
    });
  });

  group('codec refuses malformed frames', () {
    test('a missing sequence number is not a frame', () {
      expect(
        () => LogicFrame.fromJson(<String, Object?>{
          'type': 'ping',
          'body': <String, Object?>{'nonce': 1},
        }),
        throwsA(isA<LogicProtocolError>()),
      );
    });

    test('an unknown type is refused', () {
      expect(
        () => LogicFrame.fromJson(<String, Object?>{
          'seq': 1,
          'type': 'teleport',
          'body': <String, Object?>{},
        }),
        throwsA(isA<LogicProtocolError>()),
      );
    });

    test('a reserved-but-unimplemented type is refused, and says so', () {
      expect(reservedLogicMessageTypes, contains('snapshot'));
      expect(
        () => LogicFrame.fromJson(<String, Object?>{
          'seq': 1,
          'type': 'snapshot',
          'body': <String, Object?>{},
        }),
        throwsA(
          isA<LogicProtocolError>().having(
            (LogicProtocolError e) => e.message,
            'message',
            contains('reserved'),
          ),
        ),
      );
    });

    test('a body whose fields have the wrong types is refused', () {
      expect(
        () => LogicFrame.fromJson(<String, Object?>{
          'seq': 1,
          'type': 'event',
          'body': <String, Object?>{
            'name': 42,
            'surfaceId': 's',
            'sourceComponentId': 'b',
          },
        }),
        throwsA(isA<LogicProtocolError>()),
      );
    });

    test(
        'an update entry that is not a decodable A2UI message is refused '
        'as a protocol error, not as whatever the A2UI codec throws', () {
      // The session machinery converts LogicProtocolError into a `malformed`
      // fault and catches nothing else — so the envelope must be the place
      // where every decode failure, the A2UI codec's included, takes that
      // type. Unwrapped, this would escape as an unhandled async error and
      // the session would stay `ready`.
      expect(
        () => LogicFrame.fromJson(<String, Object?>{
          'seq': 1,
          'type': 'update',
          'body': <String, Object?>{
            'messages': <Object?>[
              <String, Object?>{
                'version': 'v0.9',
                'noSuchMessage': <String, Object?>{},
              },
            ],
          },
        }),
        throwsA(
          isA<LogicProtocolError>().having(
            (LogicProtocolError e) => e.message,
            'message',
            contains('A2UI'),
          ),
        ),
      );
    });
  });
}
