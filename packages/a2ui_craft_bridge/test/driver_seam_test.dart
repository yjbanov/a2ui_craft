// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Drivers Phase 1, slice 0 (research/logic/PHASE_1_PLAN.md): the grounding
/// test that pins the programmatic drive path a `DriverSession` will clip
/// into — no UI, no adapters, just the bridge/`a2ui_core` seam.
///
/// What a driver needs from this seam, and where each half lives today:
///
///  * **Inbound** (driver → surface): `MessageProcessor.processMessages` —
///    creating the surface, composing components, and writing the data model
///    are all Transport messages already.
///  * **Outbound** (surface → driver): `groupModel.onAction` emits an
///    `A2uiClientAction` whenever a bound `action` prop's resolved callback
///    runs.
///
/// The tests also pin the two findings that shape slice 1's envelope:
///
///  1. Action emission is **synchronous** with the callback today. The
///     always-async rule (BUSINESS_LOGIC.md §4) is therefore the session
///     layer's job — nothing below this seam provides it.
///  2. A two-way (`{path}`-bound) setter writes **only the local data model**
///     — the optimistic echo — and emits nothing a driver could hear. The
///     envelope's `event` message must carry current two-way values itself
///     (design §5); there is no write notification to forward.
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:test/test.dart';

(MessageProcessor<ComponentApi>, SurfaceModel<ComponentApi>) _surface(
  List<A2uiMessage> messages, {
  void Function(A2uiClientAction)? onAction,
}) {
  final processor = MessageProcessor<ComponentApi>(
    catalogs: [MinimalCatalog()],
    onAction: onAction,
  );
  processor.processMessages(messages);
  return (processor, processor.groupModel.getSurface('s')!);
}

A2uiMessage _create() =>
    CreateSurfaceMessage(surfaceId: 's', catalogId: MinimalCatalog().id);

void main() {
  group('driver seam: outbound events', () {
    test('a resolved action callback surfaces as an A2uiClientAction', () {
      final actions = <A2uiClientAction>[];
      final (_, surface) = _surface(onAction: actions.add, <A2uiMessage>[
        _create(),
        UpdateComponentsMessage(surfaceId: 's', components: [
          <String, dynamic>{'id': 'lbl', 'component': 'Text', 'text': 'Buy'},
          <String, dynamic>{
            'id': 'btn',
            'component': 'Button',
            'child': 'lbl',
            'action': <String, dynamic>{
              'event': <String, dynamic>{
                'name': 'checkout',
                'context': <String, dynamic>{'total': 42},
              },
            },
          },
        ]),
      ]);

      final binding = A2uiComponentBinding(surface, 'btn');
      addTearDown(binding.dispose);

      final Object? callback = binding.resolvedProps!['action'];
      expect(callback, isA<Function>(),
          reason: 'the action prop resolves to a plain callback (DESIGN.md '
              '§5); this callback is what an adapter wires to the widget');

      (callback! as Function)();

      // Finding 1: emission is synchronous with the invocation — no await
      // needed. The session layer owns making driver delivery async.
      expect(actions, hasLength(1));
      expect(actions.single.name, 'checkout');
      expect(actions.single.surfaceId, 's');
      expect(actions.single.sourceComponentId, 'btn');
      expect(actions.single.context, <String, dynamic>{'total': 42});
    });
  });

  group('driver seam: two-way writes', () {
    test('a {path}-bound setter echoes locally and emits no action', () {
      final actions = <A2uiClientAction>[];
      final (_, surface) = _surface(onAction: actions.add, <A2uiMessage>[
        _create(),
        UpdateDataModelMessage(surfaceId: 's', path: '/draft', value: 'hi'),
        UpdateComponentsMessage(surfaceId: 's', components: [
          <String, dynamic>{
            'id': 'field',
            'component': 'TextField',
            'label': 'Draft',
            'value': <String, dynamic>{'path': '/draft'},
          },
          <String, dynamic>{
            'id': 'echo',
            'component': 'Text',
            'text': <String, dynamic>{'path': '/draft'},
          },
        ]),
      ]);

      final field = A2uiComponentBinding(surface, 'field');
      addTearDown(field.dispose);
      final echo = A2uiComponentBinding(surface, 'echo');
      addTearDown(echo.dispose);
      expect(echo.resolvedProps!['text'], 'hi');

      // GenericBinder injects a `set<Prop>` alongside each {path}-bound prop.
      final Object? setter = field.resolvedProps!['setValue'];
      expect(setter, isA<Function>());
      (setter! as Function)('hello');

      // The write lands in the local model and re-resolves other bindings —
      // the optimistic echo of BUSINESS_LOGIC.md §4, at tier-1 latency.
      expect(field.resolvedProps!['value'], 'hello');
      expect(echo.resolvedProps!['text'], 'hello');

      // Finding 2: nothing observable leaves the surface. The driver learns
      // current two-way values only from the envelope's event messages.
      expect(actions, isEmpty);
    });
  });

  group('driver seam: inbound writes', () {
    test('a data-model message re-resolves bindings — the driver reply path',
        () {
      final (processor, surface) = _surface(<A2uiMessage>[
        _create(),
        UpdateDataModelMessage(surfaceId: 's', path: '/total', value: 0),
        UpdateComponentsMessage(surfaceId: 's', components: [
          <String, dynamic>{
            'id': 'sum',
            'component': 'Text',
            'text': <String, dynamic>{'path': '/total'},
          },
        ]),
      ]);

      final binding = A2uiComponentBinding(surface, 'sum');
      addTearDown(binding.dispose);
      var notifications = 0;
      binding.addListener(() => notifications++);
      expect(binding.resolvedProps!['text'], 0);

      // What a driver's `update` message becomes after envelope decode.
      processor.processMessages(<A2uiMessage>[
        UpdateDataModelMessage(surfaceId: 's', path: '/total', value: 42),
      ]);

      expect(notifications, greaterThan(0));
      expect(binding.resolvedProps!['text'], 42);
    });
  });
}
