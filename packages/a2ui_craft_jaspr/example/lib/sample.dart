// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName, parseLibraryFile;
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';

/// The library name the sample's high-level catalog is registered under. Each
/// sample owns its own [Runtime], so they can all reuse this name.
const LibraryName _catalogName = LibraryName(<String>['catalog']);

/// Renders a framework-neutral [SampleSpec] with the Jaspr adapter.
///
/// Each sample is fully self-contained: its own catalog (parsed from
/// [SampleSpec.catalogSource]), component API (loaded from
/// [SampleSpec.catalogSchema] via [loadCatalog]), `a2ui_core` surface, and
/// [Runtime] — so samples stay isolated from one another.
class Sample extends StatefulComponent {
  const Sample(this.spec, {super.key});

  final SampleSpec spec;

  @override
  State<Sample> createState() => _SampleState();
}

class _SampleState extends State<Sample> {
  late final Runtime _runtime;
  late final MessageProcessor<ComponentApi> _processor;
  late final SurfaceModel<ComponentApi> _surface;

  @override
  void initState() {
    super.initState();
    _runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(_catalogName, parseLibraryFile(component.spec.catalogSource));
    _processor = MessageProcessor<ComponentApi>(
        catalogs: [loadCatalog(component.spec.catalogSchema)]);
    _processor.processMessages(component.spec.messages);
    _surface = _processor.groupModel.getSurface(surfaceId)!;
    _surface.onAction.addListener(_onAction);
  }

  void _onAction(A2uiClientAction action) {
    component.spec.onAction?.call(action, SampleHost(_processor, _surface));
  }

  @override
  void dispose() {
    _surface.onAction.removeListener(_onAction);
    super.dispose();
  }

  @override
  Component build(BuildContext context) {
    return A2uiToRfwAdapter(
      id: 'root',
      surface: _surface,
      runtime: _runtime,
      scope: _catalogName,
    );
  }
}
