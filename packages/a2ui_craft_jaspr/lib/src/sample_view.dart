// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName, parseLibraryFile;
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:jaspr/jaspr.dart';

import 'a2ui_to_rfw_adapter.dart';
import 'core_components.dart';
import 'runtime.dart';

const LibraryName _coreName = LibraryName(<String>['core']);
const LibraryName _catalogName = LibraryName(<String>['catalog']);

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

  /// The component id to render as the surface root.
  final String rootId;

  @override
  State<SampleView> createState() => _SampleViewState();
}

class _SampleViewState extends State<SampleView> {
  late final Runtime _runtime;
  late final MessageProcessor<ComponentApi> _processor;
  SurfaceModel<ComponentApi>? _surface;

  @override
  void initState() {
    super.initState();
    _runtime = Runtime()
      ..update(_coreName, createCoreComponents())
      ..update(_catalogName, parseLibraryFile(component.template));
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

  void _onAction(A2uiClientAction action) => component.onAction?.call(action);

  @override
  void dispose() {
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
    );
  }
}
