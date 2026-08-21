// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:async';

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft_logic/a2ui_craft_logic.dart';
import 'package:test/test.dart';

(MessageProcessor<ComponentApi>, SurfaceModel<ComponentApi>) _surface() {
  final MessageProcessor<ComponentApi> processor =
      MessageProcessor<ComponentApi>(
    catalogs: <Catalog<ComponentApi>>[MinimalCatalog()],
  );
  processor.processMessages(<A2uiMessage>[
    CreateSurfaceMessage(surfaceId: 's', catalogId: MinimalCatalog().id),
  ]);
  return (processor, processor.groupModel.getSurface('s')!);
}

Future<void> _settle([int rounds = 8]) async {
  for (var i = 0; i < rounds; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// Writes whatever it is constructed with, at init.
class _WritingDriver extends Driver {
  _WritingDriver(this.writes);

  /// Path/value pairs, applied in order within one handler.
  final List<(String, Object?)> writes;

  @override
  void onInit(DriverContext context) {
    for (final (String path, Object? value) in writes) {
      context.write(path, value);
    }
  }

  @override
  void onEvent(DriverContext context, DriverEvent event) {}
}

/// Sends a raw message at init — the structural escape hatch, aimed wherever
/// it is told.
class _RawDriver extends Driver {
  _RawDriver(this.messages);

  final List<A2uiMessage> messages;

  @override
  void onInit(DriverContext context) => context.send(messages);

  @override
  void onEvent(DriverContext context, DriverEvent event) {}
}

class _CheckoutDriver extends HandlerDriver {
  @override
  Map<String, DriverHandler> get handlers => <String, DriverHandler>{
        'checkout': (DriverContext c, DriverEvent e) =>
            c.write('/state', 'ordered'),
        'clear': (DriverContext c, DriverEvent e) => c.write('/state', 'empty'),
      };
}

(DriverSession, List<SessionFault>) _session(
  MessageProcessor<ComponentApi> processor,
  Driver driver, {
  Map<String, Object?> hostContext = const <String, Object?>{},
}) {
  final DriverSession session = DriverSession(
    processor: processor,
    surfaceId: 's',
    transport: InProcessDriverRunner(driver, diagnostics: silentDiagnostics),
    hostContext: hostContext,
  );
  final List<SessionFault> faults = <SessionFault>[];
  session.onFault.addListener(faults.add);
  return (session, faults);
}

void main() {
  group('the host-owned namespace', () {
    test('is published to the surface so templates can bind it', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final (DriverSession session, _) = _session(
        processor,
        _WritingDriver(const <(String, Object?)>[]),
        hostContext: const <String, Object?>{'locale': 'en-US'},
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      expect(surface.dataModel.get('$hostReservedNamespace/locale'), 'en-US');
    });

    test('refuses a driver write inside it, before the model is touched',
        () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final (DriverSession session, List<SessionFault> faults) = _session(
        processor,
        // The offending write is second: if enforcement ran per-message
        // instead of per-batch, the first write would already have landed.
        _WritingDriver(<(String, Object?)>[
          ('/legitimate', 'landed'),
          ('$hostReservedNamespace/locale', 'fr-FR'),
        ]),
        hostContext: const <String, Object?>{'locale': 'en-US'},
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.hostKeyViolation);
      expect(faults.single.message, contains(hostReservedNamespace));
      expect(surface.dataModel.get('$hostReservedNamespace/locale'), 'en-US',
          reason: 'the host key is untouched');
      expect(surface.dataModel.get('/legitimate'), isNull,
          reason: 'and so is the rest of the batch — a refused update is '
              'refused whole, never half-applied');
    });

    test('refuses a root write, which would swallow the namespace', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final (DriverSession session, List<SessionFault> faults) = _session(
        processor,
        _WritingDriver(<(String, Object?)>[('/', <String, Object?>{})]),
        hostContext: const <String, Object?>{'locale': 'en-US'},
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.hostKeyViolation);
      expect(surface.dataModel.get('$hostReservedNamespace/locale'), 'en-US');
    });

    test('refuses every spelling that resolves inside it', () async {
      // The data model's own parser is forgiving: a leading slash is optional,
      // a trailing one is dropped, and '' and '//' both mean the root. Each of
      // these writes lands exactly where '/host/locale' or '/' would, so a
      // guard that compared the string it was handed would be guarding one
      // spelling and waving through the rest.
      for (final String path in <String>[
        'host/locale',
        'host',
        '/host/',
        '',
        '//',
      ]) {
        final (
          MessageProcessor<ComponentApi> processor,
          SurfaceModel<ComponentApi> surface,
        ) = _surface();
        final (DriverSession session, List<SessionFault> faults) = _session(
          processor,
          _WritingDriver(<(String, Object?)>[(path, 'PWNED')]),
          hostContext: const <String, Object?>{'locale': 'en-US'},
        );
        addTearDown(session.dispose);
        session.start();
        await _settle();

        expect(faults.single.code, SessionFaultCode.hostKeyViolation,
            reason: "a write to '$path' was let through");
        expect(surface.dataModel.get('$hostReservedNamespace/locale'), 'en-US',
            reason: "a write to '$path' reached the host's namespace");
      }
    });

    test('lets ordinary writes through — the guard is not a blanket', () async {
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final (DriverSession session, List<SessionFault> faults) = _session(
        processor,
        // Adjacent to the reserved prefix without being inside it: a driver
        // key called `/hostile` is nobody's business but the driver's.
        _WritingDriver(<(String, Object?)>[('/hostile', 1), ('/cart/qty', 2)]),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      expect(faults, isEmpty);
      expect(surface.dataModel.get('/hostile'), 1);
      expect(surface.dataModel.get('/cart/qty'), 2);
    });
  });

  group('surface scope', () {
    test('a driver may not address a surface it was not given', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      processor.processMessages(<A2uiMessage>[
        CreateSurfaceMessage(
            surfaceId: 'other', catalogId: MinimalCatalog().id),
        UpdateDataModelMessage(surfaceId: 'other', path: '/x', value: 'mine'),
      ]);
      final (DriverSession session, List<SessionFault> faults) = _session(
        processor,
        _RawDriver(<A2uiMessage>[
          UpdateDataModelMessage(
              surfaceId: 'other', path: '/x', value: 'stolen'),
        ]),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.scopeViolation);
      expect(
        processor.groupModel.getSurface('other')!.dataModel.get('/x'),
        'mine',
      );
    });

    test('a driver may not delete a surface it was not given', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      processor.processMessages(<A2uiMessage>[
        CreateSurfaceMessage(
            surfaceId: 'other', catalogId: MinimalCatalog().id),
      ]);
      final (DriverSession session, List<SessionFault> faults) = _session(
        processor,
        _RawDriver(<A2uiMessage>[DeleteSurfaceMessage(surfaceId: 'other')]),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.scopeViolation);
      expect(processor.groupModel.getSurface('other'), isNotNull);
    });

    test('a driver may not delete its own surface either', () async {
      // In scope, still refused: the host is *rendering* this surface, and a
      // surface that vanishes under the renderer takes the host down with a
      // null dereference instead of the stopped-card the failure policy
      // promises. The lifecycle belongs to the host; a driver that wants a
      // clean slate replaces with createSurface.
      final (
        MessageProcessor<ComponentApi> processor,
        SurfaceModel<ComponentApi> surface,
      ) = _surface();
      final (DriverSession session, List<SessionFault> faults) = _session(
        processor,
        _RawDriver(<A2uiMessage>[DeleteSurfaceMessage(surfaceId: 's')]),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      expect(faults.single.code, SessionFaultCode.scopeViolation);
      expect(faults.single.message, contains('lifecycle'));
      expect(processor.groupModel.getSurface('s'), same(surface),
          reason: 'the rendered surface is untouched');
    });
  });

  group('development-time diagnostics', () {
    test('an event with no handler is reported, naming what is handled',
        () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final List<String> reported = <String>[];
      final DriverSession session = DriverSession(
        processor: processor,
        surfaceId: 's',
        transport: InProcessDriverRunner(
          _CheckoutDriver(),
          diagnostics: reported.add,
        ),
      );
      addTearDown(session.dispose);
      session.start();
      await _settle();

      await processor.groupModel.getSurface('s')!.dispatchAction(
        <String, dynamic>{
          'event': <String, dynamic>{'name': 'chekout'}, // typo
        },
        'btn',
      );
      await _settle();

      expect(reported, hasLength(1));
      expect(reported.single, contains("No handler for event 'chekout'"));
      expect(reported.single, contains('checkout, clear'),
          reason: 'the report names what the driver does handle, so a typo is '
              'obvious on sight');
    });

    test('an unhandled event is a diagnostic, not a fault', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final (DriverSession session, List<SessionFault> faults) =
          _session(processor, _CheckoutDriver());
      addTearDown(session.dispose);
      session.start();
      await _settle();

      await processor.groupModel.getSurface('s')!.dispatchAction(
        <String, dynamic>{
          'event': <String, dynamic>{'name': 'nope'},
        },
        'btn',
      );
      await _settle();

      // A dead control is a wiring mistake, not a crash: the session stays up
      // so the rest of the mini-app keeps working while the author fixes it.
      expect(faults, isEmpty);
      expect(session.state, LogicSessionState.ready);
    });

    test('unusedHandlers names the other half of the same mistake', () async {
      final (MessageProcessor<ComponentApi> processor, _) = _surface();
      final _CheckoutDriver driver = _CheckoutDriver();
      final (DriverSession session, _) = _session(processor, driver);
      addTearDown(session.dispose);
      session.start();
      await _settle();
      expect(driver.unusedHandlers, <String>{'checkout', 'clear'});

      await processor.groupModel.getSurface('s')!.dispatchAction(
        <String, dynamic>{
          'event': <String, dynamic>{'name': 'checkout'},
        },
        'btn',
      );
      await _settle();
      expect(driver.unusedHandlers, <String>{'clear'});
    });
  });

  group('the inference catalog', () {
    test('parses action entries alongside the component schemas', () {
      final InferenceCatalog catalog = InferenceCatalog.parse(<String, Object?>{
        'catalogId': 'cart',
        'components': <String, Object?>{
          'CartView': <String, Object?>{'properties': <String, Object?>{}},
        },
        'actions': <Object?>[
          <String, Object?>{
            'name': 'checkout',
            'description': 'Places the order for everything in the cart.',
            'parameters': <String, Object?>{
              'type': 'object',
              'properties': <String, Object?>{
                'note': <String, Object?>{'type': 'string'},
              },
            },
          },
        ],
      });

      expect(catalog.catalogId, 'cart');
      expect(catalog.components, <String>['CartView']);
      expect(catalog.actions.single.name, 'checkout');
      expect(catalog.actions.single.description, contains('Places the order'));
      expect(catalog.actions.single.parameters['type'], 'object');
    });

    test('a project with no actions is a valid catalog with no actions', () {
      final InferenceCatalog catalog = InferenceCatalog.parse(
        <String, Object?>{
          'catalogId': 'demo',
          'components': <String, Object?>{'Dashboard': <String, Object?>{}},
        },
      );
      expect(catalog.actions, isEmpty);
      expect(catalog.components, <String>['Dashboard']);
    });

    test('an action without a description is refused', () {
      expect(
        () => InferenceCatalog.parse(<String, Object?>{
          'catalogId': 'cart',
          'actions': <Object?>[
            <String, Object?>{'name': 'checkout'},
          ],
        }),
        throwsArgumentError,
      );
    });

    test('duplicate action names are refused', () {
      expect(
        () => InferenceCatalog.parse(<String, Object?>{
          'catalogId': 'cart',
          'actions': <Object?>[
            <String, Object?>{'name': 'go', 'description': 'a'},
            <String, Object?>{'name': 'go', 'description': 'b'},
          ],
        }),
        throwsArgumentError,
      );
    });

    test('round-trips through its own encoding', () {
      const InferenceCatalog catalog = InferenceCatalog(
        catalogId: 'cart',
        actions: <InferenceAction>[
          InferenceAction(name: 'checkout', description: 'Places the order.'),
        ],
      );
      final InferenceCatalog decoded = InferenceCatalog.parse(catalog.toJson());
      expect(decoded.actionNames, <String>{'checkout'});
      expect(decoded.actions.single.description, 'Places the order.');
    });

    group('verifiability on both ends', () {
      const InferenceCatalog catalog = InferenceCatalog(
        catalogId: 'cart',
        actions: <InferenceAction>[
          InferenceAction(name: 'checkout', description: 'Places the order.'),
          InferenceAction(name: 'clear', description: 'Empties the cart.'),
        ],
      );

      test('the mini-app author sees an action nothing implements', () {
        expect(
          catalog.unimplementedActions(<String>{'checkout'}),
          <String>['clear'],
        );
        expect(
          catalog.unimplementedActions(<String>{'checkout', 'clear'}),
          isEmpty,
        );
      });

      test('and an implemented event it never advertised', () {
        expect(
          catalog.undeclaredActions(<String>{'checkout', 'clear', 'setQty'}),
          <String>['setQty'],
        );
      });

      test('the host author sees anything outside what the platform allows',
          () {
        expect(catalog.actionsOutside(<String>{'checkout'}), <String>['clear']);
        expect(
          catalog.actionsOutside(<String>{'checkout', 'clear', 'other'}),
          isEmpty,
        );
      });

      test('a driver can check itself against its own declaration', () {
        // The check a mini-app runs in its own tests: everything advertised to
        // an agent is actually answered.
        expect(
          catalog.unimplementedActions(_CheckoutDriver().handledEvents),
          isEmpty,
        );
      });
    });
  });
}
