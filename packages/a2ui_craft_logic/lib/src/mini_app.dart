// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import 'fault.dart';
import 'session.dart';
import 'transport.dart';

/// Runs a mini-app: cold-boot, drive, fail, restart.
///
/// A [DriverSession] is deliberately one-shot — every terminal state latches,
/// because a session that has lost the thread does not get to keep talking.
/// That leaves someone holding the *next* one, and this is that someone: it
/// owns the surface's lifecycle so a host only has to answer one question each
/// time it renders — is [fault] null?
///
/// The MVP failure policy is the simplest honest thing (freeze beats betray):
/// on a fault the host takes the surface out of service and offers [restart],
/// which cold-boots from scratch. There is no restoration — no snapshot, no
/// replay of driver state — because a half-restored mini-app that *looks*
/// recovered is worse than one that plainly starts over.
class MiniAppRunner {
  /// Creates a runner for the mini-app on [surfaceId].
  ///
  /// Each of the three factories is called afresh on every boot, so a restart
  /// is a genuine cold start rather than a reset of something that survived:
  /// [createProcessor] builds an empty surface group, [coldBoot] supplies the
  /// recorded Transport stream that composes the surface (the project's
  /// `app.json`), and [createTransport] connects a new driver.
  MiniAppRunner({
    required this.createProcessor,
    required this.coldBoot,
    required this.createTransport,
    required this.surfaceId,
    this.hostContext = const <String, Object?>{},
    this.heartbeat = const Duration(seconds: 5),
  });

  /// Builds a fresh processor, with the host's catalogs registered.
  final MessageProcessor<ComponentApi> Function() createProcessor;

  /// The recorded Transport stream that composes the surface before any driver
  /// connects — first paint without a round trip.
  final List<A2uiMessage> Function() coldBoot;

  /// Connects a new driver.
  final DriverTransport Function() createTransport;

  /// The surface the mini-app occupies.
  final String surfaceId;

  /// Host-owned context published to the surface and handed to the driver.
  final Map<String, Object?> hostContext;

  /// The liveness probe interval passed to each session; see
  /// [DriverSession.heartbeat]. `null` disables it.
  final Duration? heartbeat;

  final EventNotifier<MiniAppRunner> _onChanged =
      EventNotifier<MiniAppRunner>();

  MessageProcessor<ComponentApi>? _processor;
  DriverSession? _session;
  SessionFault? _fault;

  /// Fires whenever the host should re-read this runner — a boot, a restart, a
  /// fault.
  EventListenable<MiniAppRunner> get onChanged => _onChanged;

  /// The current processor, or null before the first [start].
  MessageProcessor<ComponentApi>? get processor => _processor;

  /// The mini-app's surface, or null before the first [start].
  SurfaceModel<ComponentApi>? get surface =>
      _processor?.groupModel.getSurface(surfaceId);

  /// The current session, or null before the first [start].
  DriverSession? get session => _session;

  /// Why the mini-app stopped, or null while it is running.
  ///
  /// A host renders its own full-surface failure state when this is non-null.
  /// The message is developer-facing; what a user needs to be told is that the
  /// mini-app stopped and that they can start it again.
  SessionFault? get fault => _fault;

  /// Whether the mini-app is live.
  bool get isRunning => _session != null && _fault == null;

  /// Cold-boots the mini-app. Does nothing if it is already running.
  void start() {
    if (_session != null) return;
    _boot();
  }

  /// Kills both sides and cold-boots a new mini-app in place of the old one.
  ///
  /// The restart affordance behind the failure state — and safe to call while
  /// the mini-app is healthy, which is what makes it usable as a plain "reset".
  void restart() {
    _teardown();
    _boot();
  }

  /// Tears everything down for good.
  void dispose() {
    _teardown();
    _onChanged.dispose();
  }

  void _boot() {
    _fault = null;
    final MessageProcessor<ComponentApi> processor = createProcessor();
    processor.processMessages(coldBoot());
    final DriverSession session = DriverSession(
      processor: processor,
      surfaceId: surfaceId,
      transport: createTransport(),
      hostContext: hostContext,
      heartbeat: heartbeat,
    );
    session.onFault.addListener(_handleFault);
    _processor = processor;
    _session = session;
    session.start();
    _onChanged.emit(this);
  }

  void _handleFault(SessionFault fault) {
    _fault = fault;
    _onChanged.emit(this);
  }

  void _teardown() {
    _session?.dispose();
    _session = null;
    _processor?.groupModel.dispose();
    _processor = null;
    _fault = null;
  }
}
