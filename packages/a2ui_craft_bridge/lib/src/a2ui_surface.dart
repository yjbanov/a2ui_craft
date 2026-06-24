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
/// two: it accumulates messages with [apply], then exposes each component's
/// evaluated definition as a per-id [SurfaceListenable] via
/// [componentDefinition], plus a [data] model. Framework adapters
/// (`A2uiToRfwAdapter`) subscribe to a single id and render its definition with
/// [Runtime.buildNode]; child slots are themselves host adapters injected via
/// [adapterBuilder]. The core component library *is* the catalog — there is no
/// A2UI-specific rendering code.
///
/// Each adapter keys itself by its A2UI component `id`, so a control can be
/// located (and its identity preserved across reorders) by that id.
///
/// Supported envelopes: `createSurface`, `updateComponents`, `updateDataModel`.
/// Supported components: the seed catalog (`Text`, `Row`, `Column`, `Button`).
/// Functions/`formatString`, `checks`, `theme`, `deleteSurface`, and richer
/// catalogs are intentionally out of scope for this slice.
class A2uiSurface {
  /// Creates an A2UI surface.
  ///
  /// The [adapterBuilder] is a framework-provided callback that wraps an A2UI
  /// component ID in a framework-specific host component (e.g. Flutter `Widget`
  /// or Jaspr `Component`).
  A2uiSurface({required this.adapterBuilder});

  /// The factory for creating host adapter components for child slots.
  final Object Function(String id) adapterBuilder;

  // Known limitation: these two maps grow monotonically — entries are never
  // pruned when a component is dropped (e.g. a container's children are
  // replaced), so a long-lived surface that churns component ids retains them
  // unboundedly. Listeners themselves are cleaned up (adapters remove theirs on
  // dispose); it is the cached per-id definitions that linger. This is fixed by
  // component-removal/`deleteSurface` semantics (prune both maps on removal) —
  // tracked in DESIGN.md §8 ("Then"), out of scope for the current slice.
  final Map<String, Map<String, Object?>> _components =
      <String, Map<String, Object?>>{};
  final Map<String, SurfaceListenable<ConstructorCall?>> _componentListenables =
      <String, SurfaceListenable<ConstructorCall?>>{};
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

  /// Returns a listenable for the evaluated [ConstructorCall] definition of the
  /// component with the given [id].
  ///
  /// Host adapters (`A2uiToRfwAdapter`) use this to subscribe to updates for
  /// their specific component.
  SurfaceListenable<ConstructorCall?> componentDefinition(String id) {
    return _componentListenables.putIfAbsent(
      id,
      () => SurfaceListenable<ConstructorCall?>(
        _components.containsKey(id)
            ? _buildComponent(_components[id]!, inLoop: false)
            : null,
      ),
    );
  }

  // --- ingest -------------------------------------------------------------

  void _ingestComponents(Object? components) {
    if (components is List<Object?>) {
      for (final Object? component in components) {
        if (component is Map<String, Object?>) {
          final String id = component['id'] as String;
          _components[id] = component;
          // Notify the specific listener if it exists.
          if (_componentListenables.containsKey(id)) {
            _componentListenables[id]!.value =
                _buildComponent(component, inLoop: false);
          }
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

    return ConstructorCall(type, args);
  }

  Object _buildById(String id, {required bool inLoop}) {
    if (inLoop) {
      final Map<String, Object?>? component = _components[id];
      if (component == null) {
        return const ConstructorCall('Column', <String, Object?>{
          'children': <Object?>[],
        });
      }
      return _buildComponent(component, inLoop: inLoop);
    }
    // Inject the host adapter component.
    return adapterBuilder(id);
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

/// A simple framework-neutral value listenable.
///
/// Used by [A2uiSurface] to expose component definition updates to host
/// adapters without taking a UI-framework dependency.
class SurfaceListenable<T> {
  /// Creates a listenable with the initial [value].
  SurfaceListenable(this._value);

  T _value;

  /// The current value.
  T get value => _value;

  /// Updates the value and notifies listeners if it changed.
  set value(T newValue) {
    // We intentionally don't do `_value == newValue` because ConstructorCall
    // doesn't have deep equality, and we want to rebuild on updates anyway.
    _value = newValue;
    // Iterate over a copy so a listener that adds/removes a listener while
    // being notified (e.g. an adapter disposing during the rebuild it triggers)
    // can't concurrently modify the list mid-iteration.
    for (final void Function() listener in _listeners.toList()) {
      listener();
    }
  }

  final List<void Function()> _listeners = <void Function()>[];

  /// Subscribes to updates.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Unsubscribes from updates.
  void removeListener(void Function() listener) => _listeners.remove(listener);
}
