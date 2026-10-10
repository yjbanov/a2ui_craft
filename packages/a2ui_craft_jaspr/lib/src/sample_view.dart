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
import 'package:jaspr/jaspr.dart';

import 'a2ui_to_rfw_adapter.dart';
import 'primitives.dart';
import 'runtime.dart';
import 'scanner_library.dart';

const LibraryName _coreName = LibraryName(<String>['core']);
const LibraryName _catalogName = LibraryName(<String>['catalog']);
const LibraryName _scannerName = LibraryName(<String>['Scanner']);

/// Renders a **self-contained A2UI surface** with the Jaspr adapter: a catalog
/// [template] (RFW source over the core primitives), its component API [schema]
/// (a JSON Schema catalog document), and a [messages] script that builds the
/// surface. The reusable building block of the example gallery and the demo
/// site; the Flutter adapter ships the matching `SampleView`.
///
/// Each instance is isolated — its own [Runtime], catalog, and `a2ui_core`
/// surface. The rendered surface is the one the [messages] create; dispatched
/// A2UI actions are forwarded to [onAction] (e.g. a host action log).
class SampleView extends StatefulComponent {
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
        component.simulator?.clientProfile ?? ClientProfile.v2Modern;
    _lastProfile = profile;
    _runtime = Runtime(appVersion: profile.appVersion)
      ..update(_coreName, createCoreComponents())
      ..registerFunctions(createCoreFunctions());
    if (component.extraLibraries != null) {
      for (final MapEntry<LibraryName, WidgetLibrary> entry
          in component.extraLibraries!.entries) {
        _runtime.update(entry.key, entry.value);
      }
    }
    _syncScannerLibrary(profile);
    _runtime.update(_catalogName, parseLibraryFile(component.template));
    component.simulator?.addListener(_onSimulatorChanged);

    _processor = MessageProcessor<ComponentApi>(
        catalogs: <Catalog<ComponentApi>>[loadCatalog(component.schema)]);
    _processor.processMessages(component.messages);
    final Iterable<CreateSurfaceMessage> created =
        component.messages.whereType<CreateSurfaceMessage>();
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
    final ClientProfile? newProfile = component.simulator?.clientProfile;
    if (newProfile != null && newProfile != _lastProfile) {
      _lastProfile = newProfile;
      _runtime.appVersion = newProfile.appVersion;
      _syncScannerLibrary(newProfile);
    }
    setState(() {});
  }

  @override
  void didUpdateComponent(SampleView oldComponent) {
    super.didUpdateComponent(oldComponent);
    if (oldComponent.simulator != component.simulator) {
      oldComponent.simulator?.removeListener(_onSimulatorChanged);
      component.simulator?.addListener(_onSimulatorChanged);
      final ClientProfile profile =
          component.simulator?.clientProfile ?? ClientProfile.v2Modern;
      _lastProfile = profile;
      _runtime.appVersion = profile.appVersion;
      _syncScannerLibrary(profile);
    }
    if (oldComponent.template != component.template) {
      _runtime.update(_catalogName, parseLibraryFile(component.template));
    }
  }

  void _onAction(A2uiClientAction action) => component.onAction?.call(action);

  @override
  void dispose() {
    component.simulator?.removeListener(_onSimulatorChanged);
    _surface?.onAction.removeListener(_onAction);
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    final SurfaceModel<ComponentApi>? surface = _surface;
    if (surface == null) return Component.text('');
    return A2uiToRfwAdapter(
      id: component.rootId,
      surface: surface,
      runtime: _runtime,
      scope: _catalogName,
      theme: component.theme,
      media: component.media ?? component.simulator?.media,
      fonts: component.fonts,
    );
  }
}
