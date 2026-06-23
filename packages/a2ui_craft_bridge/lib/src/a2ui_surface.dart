// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';

/// A live A2UI surface, fed by A2UI Transport messages and rendered by the A2UI
/// Craft engine.
///
/// A2UI Transport delivers a **flat, id-referenced adjacency list** of component
/// instances plus a data model, via stateful messages. The engine renders
/// **nested** RFW templates bound to a [DynamicContent]. This class bridges the
/// two: it accumulates messages with [apply], then exposes a synthesized
/// [library] (one `widget root = …` nesting the components per their child /
/// children references) and a [data] model. The framework adapters render it
/// with no A2UI-specific code — the core component library *is* the catalog.
///
/// Each A2UI component `id` is carried through as the core component's `key`, so
/// tests can locate a control by its A2UI id.
///
/// Supported envelopes: `createSurface`, `updateComponents`, `updateDataModel`.
/// Supported components: the seed catalog (`Text`, `Row`, `Column`, `Button`).
/// Functions/`formatString`, `checks`, `theme`, `deleteSurface`, and richer
/// catalogs are intentionally out of scope for this slice.
class A2uiSurface {
  final Map<String, Map<String, Object?>> _components =
      <String, Map<String, Object?>>{};
  final Map<String, Object?> _model = <String, Object?>{};
  final DynamicContent _data = DynamicContent();

  /// The data model backing this surface, ready to pass to a `RemoteComponent`.
  DynamicContent get data => _data;

  /// Applies a single decoded A2UI Transport envelope.
  void apply(Map<String, Object?> message) {
    final Object? createSurface = message['createSurface'];
    final Object? updateComponents = message['updateComponents'];
    final Object? updateDataModel = message['updateDataModel'];
    if (createSurface is Map<String, Object?>) {
      _ingestComponents(createSurface['components']);
      final Object? dataModel = createSurface['dataModel'];
      if (dataModel is Map<String, Object?>) {
        _replaceModel(dataModel);
      }
    } else if (updateComponents is Map<String, Object?>) {
      _ingestComponents(updateComponents['components']);
    } else if (updateDataModel is Map<String, Object?>) {
      _applyDataUpdate(
          updateDataModel['path'] as String?, updateDataModel['value']);
    }
  }

  /// The synthesized RFW library exposing the surface's `root` widget.
  ///
  /// Register this under a library name (e.g. `main`) and render its `root`
  /// component via the adapter's `Runtime`/`RemoteComponent`.
  RemoteWidgetLibrary get library {
    final Map<String, Object?>? root = _components['root'];
    if (root == null) {
      throw StateError(
        'A2UI surface has no component with id "root" yet; nothing to render.',
      );
    }
    return RemoteWidgetLibrary(
      const <Import>[
        Import(LibraryName(<String>['core']))
      ],
      <WidgetDeclaration>[
        WidgetDeclaration('root', null, _buildComponent(root, inLoop: false)),
      ],
    );
  }

  // --- ingest -------------------------------------------------------------

  void _ingestComponents(Object? components) {
    if (components is List<Object?>) {
      for (final Object? component in components) {
        if (component is Map<String, Object?>) {
          _components[component['id'] as String] = component;
        }
      }
    }
  }

  void _replaceModel(Map<String, Object?> model) {
    _model
      ..clear()
      ..addAll(model);
    for (final MapEntry<String, Object?> entry in _model.entries) {
      final Object? value = entry.value;
      if (value != null) {
        _data.update(entry.key, value);
      }
    }
  }

  void _applyDataUpdate(String? path, Object? value) {
    final List<String> parts = _pathParts(path);
    if (parts.isEmpty) {
      if (value is Map<String, Object?>) {
        _replaceModel(value);
      }
      return;
    }
    Map<String, Object?> node = _model;
    for (int i = 0; i < parts.length - 1; i++) {
      final Object? next = node[parts[i]];
      if (next is Map<String, Object?>) {
        node = next;
      } else {
        final Map<String, Object?> created = <String, Object?>{};
        node[parts[i]] = created;
        node = created;
      }
    }
    if (value == null) {
      node.remove(parts.last);
    } else {
      node[parts.last] = value;
    }
    final Object? rootValue = _model[parts.first];
    if (rootValue != null) {
      _data.update(parts.first, rootValue);
    }
  }

  // --- translation: A2UI component map -> RFW model -----------------------

  ConstructorCall _buildComponent(
    Map<String, Object?> component, {
    required bool inLoop,
  }) {
    final String type = component['component'] as String;
    final DynamicMap args = <String, Object?>{};

    switch (type) {
      case 'Text':
        args['text'] = _value(component['text'], inLoop: inLoop);
      case 'Row':
      case 'Column':
        args['children'] = _children(component['children'], inLoop: inLoop);
      case 'Button':
        final Object? child = component['child'];
        if (child is String) {
          args['child'] = _buildById(child, inLoop: inLoop);
        }
        final Object? action = component['action'];
        if (action is Map<String, Object?>) {
          final Object? event = action['event'];
          if (event is Map<String, Object?>) {
            args['onPressed'] = EventHandler(
              event['name'] as String,
              _context(event['context'], inLoop: inLoop),
            );
          }
        }
    }

    // Carry the A2UI id through as the core component's key, so controls can be
    // located by their A2UI id. Skipped inside loops: a template instantiates
    // many times, so its id is not unique among siblings.
    final Object? id = component['id'];
    if (id is String && !inLoop) {
      args['key'] = id;
    }
    return ConstructorCall(type, args);
  }

  ConstructorCall _buildById(String id, {required bool inLoop}) {
    final Map<String, Object?>? component = _components[id];
    if (component == null) {
      // Unresolved reference: render an empty container rather than crash.
      return const ConstructorCall('Column', <String, Object?>{
        'children': <Object?>[],
      });
    }
    return _buildComponent(component, inLoop: inLoop);
  }

  /// Translates a `children` value: either a static array of component ids, or
  /// an A2UI `ChildList` template (`{path, componentId}`) → an RFW [Loop].
  Object _children(Object? children, {required bool inLoop}) {
    if (children is List<Object?>) {
      return <Object?>[
        for (final Object? id in children)
          if (id is String) _buildById(id, inLoop: inLoop),
      ];
    }
    if (children is Map<String, Object?>) {
      final List<Object> pathParts =
          _pathParts(children['path'] as String?).cast<Object>();
      final String templateId = children['componentId'] as String;
      // The template's bindings resolve relative to each list item, hence the
      // inner build runs with inLoop: true (relative paths -> LoopReference).
      // In RFW a `...for` is a list *element*, so the children value is a list
      // containing the Loop (matching `children: [ ...for x in xs: W ]`).
      return <Object?>[
        Loop(DataReference(pathParts), _buildById(templateId, inLoop: true)),
      ];
    }
    return <Object?>[];
  }

  DynamicMap _context(Object? context, {required bool inLoop}) {
    if (context is Map<String, Object?>) {
      return <String, Object?>{
        for (final MapEntry<String, Object?> entry in context.entries)
          entry.key: _value(entry.value, inLoop: inLoop),
      };
    }
    return <String, Object?>{};
  }

  /// Translates an A2UI value (a `Dynamic*`): a literal passes through; a
  /// `{path}` becomes a [DataReference] (absolute) or [LoopReference] (relative,
  /// inside a [Loop]).
  Object? _value(Object? raw, {required bool inLoop}) {
    if (raw is Map<String, Object?> && raw.containsKey('path')) {
      final String path = raw['path'] as String;
      if (path.startsWith('/')) {
        return DataReference(_pathParts(path).cast<Object>());
      }
      final List<Object> parts = _relParts(path).cast<Object>();
      return inLoop ? LoopReference(0, parts) : DataReference(parts);
    }
    return raw;
  }

  // --- path helpers -------------------------------------------------------

  /// Splits a JSON Pointer (`/a/b`) into segments; `/` or null -> empty.
  static List<String> _pathParts(String? pointer) {
    if (pointer == null || pointer.isEmpty || pointer == '/') {
      return <String>[];
    }
    return pointer.split('/').where((String s) => s.isNotEmpty).toList();
  }

  /// Splits a relative path (`a/b`, no leading slash) into segments.
  static List<String> _relParts(String path) {
    return path.split('/').where((String s) => s.isNotEmpty).toList();
  }
}
