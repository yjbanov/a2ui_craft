// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart' show LibraryName, parseLibraryFile;
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';

/// The library name each sample registers its high-level catalog under. Because
/// every sample owns its own [Runtime], they can all reuse this name without
/// clashing.
const LibraryName _catalogName = LibraryName(<String>['catalog']);

/// The `a2ui_core` catalog id and surface id the samples' messages reference.
/// Shared so a sample's [Sample.buildCatalog] and [Sample.buildMessages] agree.
const String catalogId = 'demo';
const String surfaceId = 'demo';

/// Lets a sample's [Sample.onAction] push follow-up data updates (and read
/// current values) without touching the engine plumbing.
class SampleHost {
  SampleHost._(this._processor, this._surface);

  final MessageProcessor<ComponentApi> _processor;
  final SurfaceModel<ComponentApi> _surface;

  /// Reads the current value at [path] in the surface's data model.
  Object? read(String path) => _surface.dataModel.get(path);

  /// Writes [value] at [path] (an `updateDataModel` message); bound widgets
  /// re-render reactively.
  void updateData(String path, Object? value) {
    _processor.processMessages(<A2uiMessage>[
      UpdateDataModelMessage(surfaceId: surfaceId, path: path, value: value),
    ]);
  }
}

/// A self-contained A2UI Craft demo.
///
/// Each sample owns its **own** high-level catalog ([catalogSource] +
/// [buildCatalog]), A2UI message script ([buildMessages]), [Runtime], and
/// surface — so samples are fully isolated from one another (itself part of the
/// demo). Subclass this and fill in the four hooks; the shared [State] wires up
/// `a2ui_core` + the engine and renders the surface's `root` component.
abstract class Sample extends StatefulWidget {
  const Sample({super.key});

  /// This sample's high-level catalog as RFW template source
  /// (`import core; widget Foo = …;`).
  String get catalogSource;

  /// This sample's component API as a **raw JSON Schema catalog document**
  /// (`{catalogId, components: {...}}`, with props referencing A2UI common types
  /// by `$ref`). Loaded ephemerally via [loadCatalog] — the client knows nothing
  /// about it ahead of time. Its `catalogId` must be [catalogId].
  Map<String, Object?> get catalogSchema;

  /// The A2UI messages that build the sample's surface (root id `root`).
  List<A2uiMessage> buildMessages();

  /// Handles an action dispatched by the rendered UI. Default: ignore.
  void onAction(A2uiClientAction action, SampleHost host) {}

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
      ..update(_catalogName, parseLibraryFile(widget.catalogSource));
    _processor = MessageProcessor<ComponentApi>(
        catalogs: [loadCatalog(widget.catalogSchema)]);
    _processor.processMessages(widget.buildMessages());
    _surface = _processor.groupModel.getSurface(surfaceId)!;
    _surface.onAction.addListener(_onAction);
  }

  void _onAction(A2uiClientAction action) {
    widget.onAction(action, SampleHost._(_processor, _surface));
  }

  @override
  void dispose() {
    _surface.onAction.removeListener(_onAction);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return A2uiToRfwAdapter(
      id: 'root',
      surface: _surface,
      runtime: _runtime,
      scope: _catalogName,
    );
  }
}
