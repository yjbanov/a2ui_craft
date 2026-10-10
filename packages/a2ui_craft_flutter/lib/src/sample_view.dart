// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart'
    show
        A2uiCraftSimulator,
        ClientProfile,
        CraftFonts,
        CraftTheme,
        LibraryName,
        MediaContext,
        WidgetLibrary,
        createCoreFunctions,
        parseLibraryFile;
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:flutter/widgets.dart';

import 'a2ui_to_rfw_adapter.dart';
import 'primitives.dart';
import 'runtime.dart';
import 'scanner_library.dart';

const LibraryName _coreName = LibraryName(<String>['core']);
const LibraryName _catalogName = LibraryName(<String>['catalog']);
const LibraryName _scannerName = LibraryName(<String>['Scanner']);

/// Renders a **self-contained A2UI surface** with the Flutter adapter: a catalog
/// [template] (RFW source over the core primitives), its component API [schema]
/// (a JSON Schema catalog document), and a [messages] script that builds the
/// surface. The reusable building block of the example gallery and the demo
/// site; the Jaspr adapter ships the matching `SampleView`.
///
/// Each instance is isolated — its own [Runtime], catalog, and `a2ui_core`
/// surface. The rendered surface is the one the [messages] create; dispatched
/// A2UI actions are forwarded to [onAction] (e.g. a host action log).
class SampleView extends StatefulWidget {
  const SampleView({
    super.key,
    required this.template,
    required this.schema,
    required this.messages,
    this.onAction,
    this.theme,
    this.media,
    this.fonts,
    this.simulator,
    this.extraLibraries,
    this.rootId = 'root',
  });

  /// The catalog as RFW template source (`import core; widget Foo = …;`).
  final String template;

  /// The component API as a raw JSON Schema catalog document.
  final Map<String, Object?> schema;

  /// The A2UI messages that build the surface.
  final List<A2uiMessage> messages;

  /// Called when the rendered surface dispatches an A2UI action.
  final void Function(A2uiClientAction action)? onAction;

  /// The theme to render the surface under (§9), or null to blend into the
  /// host — a project supplies this from its `theme.json` via `ProjectTheme`.
  final CraftTheme? theme;

  /// The responsive environment ([MediaContext]) the host supplies, or null to
  /// stay size-agnostic. The host rebuilds with a new one as the window resizes.
  final MediaContext? media;

  /// The host's font binding — which typefaces answer each [FontRole] — or null
  /// to inherit the enclosing binding (else [CraftFonts.systemUi]).
  final CraftFonts? fonts;

  /// The interactive simulator controller, or null for the real host environment.
  ///
  /// When provided, [SampleView] binds ambient media and version profiles to
  /// the simulator session, dynamically updating when the simulation state changes.
  final A2uiCraftSimulator? simulator;

  /// Optional host-registered primitive widget libraries (such as hardware drivers
  /// or device capabilities).
  final Map<LibraryName, WidgetLibrary>? extraLibraries;

  /// The component id to render as the surface root.
  final String rootId;

  @override
  State<SampleView> createState() => _SampleViewState();
}

class _SampleViewState extends State<SampleView> {
  late final Runtime _runtime;
  late final MessageProcessor<ComponentApi> _processor;
  SurfaceModel<ComponentApi>? _surface;
  ClientProfile? _lastProfile;

  @override
  void initState() {
    super.initState();
    final ClientProfile profile =
        widget.simulator?.clientProfile ?? ClientProfile.v2Modern;
    _lastProfile = profile;
    _runtime = Runtime(appVersion: profile.appVersion)
      ..update(_coreName, createCoreComponents())
      ..registerFunctions(createCoreFunctions());
    if (widget.extraLibraries != null) {
      for (final MapEntry<LibraryName, WidgetLibrary> entry
          in widget.extraLibraries!.entries) {
        _runtime.update(entry.key, entry.value);
      }
    }
    _syncScannerLibrary(profile);
    _runtime.update(_catalogName, parseLibraryFile(widget.template));
    widget.simulator?.addListener(_onSimulatorChanged);

    _processor = MessageProcessor<ComponentApi>(
        catalogs: <Catalog<ComponentApi>>[loadCatalog(widget.schema)]);
    _processor.processMessages(widget.messages);
    final Iterable<CreateSurfaceMessage> created =
        widget.messages.whereType<CreateSurfaceMessage>();
    _surface = created.isEmpty
        ? null
        : _processor.groupModel.getSurface(created.first.surfaceId);
    _surface?.onAction.addListener(_onAction);
  }

  void _syncScannerLibrary(ClientProfile profile) {
    if (profile.id == 'v0') {
      _runtime.removeLibrary(_scannerName);
    } else {
      _runtime.update(_scannerName, createScannerLibrary(profile));
    }
  }

  void _onSimulatorChanged() {
    final ClientProfile? newProfile = widget.simulator?.clientProfile;
    if (newProfile != null && newProfile != _lastProfile) {
      _lastProfile = newProfile;
      _runtime.appVersion = newProfile.appVersion;
      _syncScannerLibrary(newProfile);
    }
    setState(() {});
  }

  @override
  void didUpdateWidget(SampleView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.simulator != widget.simulator) {
      oldWidget.simulator?.removeListener(_onSimulatorChanged);
      widget.simulator?.addListener(_onSimulatorChanged);
      final ClientProfile profile =
          widget.simulator?.clientProfile ?? ClientProfile.v2Modern;
      _lastProfile = profile;
      _runtime.appVersion = profile.appVersion;
      _syncScannerLibrary(profile);
    }
    if (oldWidget.template != widget.template) {
      _runtime.update(_catalogName, parseLibraryFile(widget.template));
    }
  }

  void _onAction(A2uiClientAction action) => widget.onAction?.call(action);

  @override
  void dispose() {
    widget.simulator?.removeListener(_onSimulatorChanged);
    _surface?.onAction.removeListener(_onAction);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SurfaceModel<ComponentApi>? surface = _surface;
    if (surface == null) return const SizedBox.shrink();
    return A2uiToRfwAdapter(
      id: widget.rootId,
      surface: surface,
      runtime: _runtime,
      scope: _catalogName,
      theme: widget.theme,
      media: widget.media ?? widget.simulator?.media,
      fonts: widget.fonts,
    );
  }
}
