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
  /// Creates a runner for a mini-app.
  ///
  /// Each of the three factories is called afresh on every boot, so a restart
  /// is a genuine cold start rather than a reset of something that survived:
  /// [createProcessor] builds an empty surface group, [coldBoot] supplies the
  /// recorded Transport stream that composes the surface (the project's
  /// `app.json`), and [createTransport] connects a new driver.
  ///
  /// The surface id is read from the boot stream's own `createSurface` — the
  /// project already states it there, and a host that repeats it out of band
  /// is a host that can get it wrong (a runner told `'cart'` while the stream
  /// creates `'app'` renders nothing, with nothing to say so). Pass
  /// [surfaceId] only to disambiguate a boot stream that creates several.
  MiniAppRunner({
    required this.createProcessor,
    required this.coldBoot,
    required this.createTransport,
    this.surfaceId,
    this.hostContext = const <String, Object?>{},
    this.heartbeat = const Duration(seconds: 5),
    this.handshakeTimeout = const Duration(seconds: 10),
  });

  /// Builds a fresh processor, with the host's catalogs registered.
  final MessageProcessor<ComponentApi> Function() createProcessor;

  /// The recorded Transport stream that composes the surface before any driver
  /// connects — first paint without a round trip.
  ///
  /// Must return **freshly decoded** messages on every call, never a shared
  /// list of instances: the data model adopts the value objects a message
  /// carries, and a driver's writes may then mutate them in place — so a
  /// restart (or a second runner) booting from the same instances would start
  /// from the previous session's leftovers instead of the recorded stream.
  final List<A2uiMessage> Function() coldBoot;

  /// Connects a new driver.
  final DriverTransport Function() createTransport;

  /// An explicit surface id, for boot streams that create more than one
  /// surface. Usually null — see the constructor.
  final String? surfaceId;

  /// Host-owned context published to the surface and handed to the driver.
  final Map<String, Object?> hostContext;

  /// The liveness probe interval passed to each session; see
  /// [DriverSession.heartbeat]. `null` disables it.
  final Duration? heartbeat;

  /// The handshake deadline passed to each session; see
  /// [DriverSession.handshakeTimeout]. `null` disables it.
  final Duration? handshakeTimeout;

  final EventNotifier<MiniAppRunner> _onChanged =
      EventNotifier<MiniAppRunner>();

  MessageProcessor<ComponentApi>? _processor;
  DriverSession? _session;
  String? _activeSurfaceId;
  SessionFault? _bootFault;

  /// Fires whenever the host should re-read this runner — a boot, a restart, a
  /// fault.
  EventListenable<MiniAppRunner> get onChanged => _onChanged;

  /// The current processor, or null before the first [start].
  MessageProcessor<ComponentApi>? get processor => _processor;

  /// The id of the surface the running mini-app occupies, or null before the
  /// first [start].
  String? get activeSurfaceId => _activeSurfaceId;

  /// The mini-app's surface, or null before the first [start] (or after a
  /// boot stream that created none — see [fault]).
  SurfaceModel<ComponentApi>? get surface {
    final String? id = _activeSurfaceId;
    return id == null ? null : _processor?.groupModel.getSurface(id);
  }

  /// The current session, or null before the first [start].
  DriverSession? get session => _session;

  /// Why the mini-app stopped, or null while it is running.
  ///
  /// Read from the session itself — one source of truth, no mirror to fall
  /// out of sync on a restart. A host renders its own full-surface failure
  /// state when this is non-null. The message is developer-facing; what a
  /// user needs to be told is that the mini-app stopped and that they can
  /// start it again.
  SessionFault? get fault => _bootFault ?? _session?.fault;

  /// Whether the mini-app is live.
  bool get isRunning => _session != null && fault == null;

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
    _bootFault = null;
    final MessageProcessor<ComponentApi> processor = createProcessor();
    _processor = processor;
    final List<A2uiMessage> boot;
    try {
      boot = coldBoot();
      processor.processMessages(boot);
    } on Object catch (error) {
      // A boot stream can decode cleanly and still be a bad program: a
      // component the catalog does not define, a path the data model refuses.
      // Nothing downstream re-checks it — a fetched project's `app.json` is
      // decoded by the loader and applied here for the first time — so letting
      // this escape would leave the runner in the one state it promises is
      // impossible: no surface, no fault, nothing to render and nothing to
      // say. Worse, it escapes from `restart()` too, after teardown has
      // already blanked the runner the failure state was rendering.
      _bootFault = SessionFault(
        SessionFaultCode.malformed,
        'The boot stream could not be applied: $error',
      );
      _onChanged.emit(this);
      return;
    }
    final String? id = surfaceId ??
        boot.whereType<CreateSurfaceMessage>().firstOrNull?.surfaceId;
    _activeSurfaceId = id;
    if (id == null) {
      // No surface, no mini-app: refuse loudly rather than run a driver
      // against nothing.
      _bootFault = const SessionFault(
        SessionFaultCode.malformed,
        'The boot stream created no surface, so there is nothing to drive. '
        "A mini-app's app.json must begin with createSurface.",
      );
      _onChanged.emit(this);
      return;
    }
    final DriverSession session = DriverSession(
      processor: processor,
      surfaceId: id,
      transport: createTransport(),
      hostContext: hostContext,
      heartbeat: heartbeat,
      handshakeTimeout: handshakeTimeout,
    );
    session.onFault.addListener(_handleFault);
    _session = session;
    session.start();
    _onChanged.emit(this);
  }

  void _handleFault(SessionFault fault) => _onChanged.emit(this);

  void _teardown() {
    _session?.dispose();
    _session = null;
    _processor?.groupModel.dispose();
    _processor = null;
    _activeSurfaceId = null;
    _bootFault = null;
  }
}
