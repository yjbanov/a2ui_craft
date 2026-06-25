// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';

/// Binds a single A2UI component (addressed by [id]) in an `a2ui_core`
/// [SurfaceModel] so a framework adapter can render it as an RFW template.
///
/// This is the thin, framework-neutral half of the bridge under the `a2ui_core`
/// layering (DESIGN.md §10). `a2ui_core` owns ingest, the data model, and the
/// resolution of bindings/functions/`checks`; this object owns a
/// [GenericBinder] for one component and surfaces its **resolved props**
/// (concrete scalars + `List<ChildNode>`), re-notifying whenever the component
/// is (re)created, updated, removed, or its resolved props change. The adapter
/// turns those props into RFW template args (see [a2uiArgsFromProps]) and
/// renders via `Runtime.buildNode`.
///
/// Reactivity is **component-granular**: a change to this component's properties
/// or to any data it binds fires [addListener] once, and the adapter rebuilds
/// the whole component (not per-binding). For the small, vetted high-level
/// catalog this is the right granularity.
class A2uiComponentBinding {
  /// Binds component [id] in [surface], resolving the component's bindings
  /// relative to [basePath] (the JSON Pointer of the enclosing data scope; `/`
  /// at the surface root, or the item path for a component inside a `ChildList`).
  A2uiComponentBinding(this.surface, this.id, {this.basePath = '/'}) {
    surface.componentsModel.onCreated.addListener(_onCreated);
    surface.componentsModel.onDeleted.addListener(_onDeleted);
    _connect();
  }

  /// The `a2ui_core` surface this component lives on.
  final SurfaceModel surface;

  /// The A2UI component id.
  final String id;

  /// The data scope this component's relative bindings resolve against.
  final String basePath;

  GenericBinder? _binder;
  void Function()? _unsubscribe;
  Set<String> _childRefs = const <String>{};
  final List<void Function()> _listeners = <void Function()>[];

  /// The component's resolved props (concrete values + `List<ChildNode>`), or
  /// `null` if the component has not been ingested yet.
  Map<String, dynamic>? get resolvedProps => _binder?.resolvedProps.value;

  /// The component's catalog type (the high-level template name), or `null` if
  /// the component has not been ingested yet.
  String? get type => surface.componentsModel.get(id)?.type;

  /// The names of props that are **single child references** — a `componentId`
  /// naming one other component (e.g. a `Card`'s `child`), as opposed to a
  /// `children` list. `a2ui_core` resolves these to a plain id string, so the
  /// adapter consults this set (via [a2uiArgsFromProps]) to inject one child
  /// adapter for them. Empty until the component is ingested.
  Set<String> get childRefs => _childRefs;

  /// Subscribes to render-affecting changes for this component.
  void addListener(void Function() listener) => _listeners.add(listener);

  /// Unsubscribes a previously added [listener].
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _connect() {
    final ComponentModel? model = surface.componentsModel.get(id);
    if (model == null) {
      return;
    }
    final ComponentApi? api = surface.catalog.components[model.type];
    if (api == null) {
      return;
    }
    _childRefs = _componentIdProps(api.schema.value);
    final GenericBinder binder = GenericBinder(
      ComponentContext(surface, model, basePath: basePath),
      api.schema,
    );
    _binder = binder;
    // preact_signals invokes the callback synchronously on subscribe; that first
    // call happens here during construction (before any adapter has subscribed),
    // so it is a harmless no-op. Later resolved-prop changes notify the adapter.
    _unsubscribe = binder.resolvedProps.subscribe((_) => _notify());
  }

  void _disconnect() {
    _unsubscribe?.call();
    _unsubscribe = null;
    _binder?.dispose();
    _binder = null;
    _childRefs = const <String>{};
  }

  void _onCreated(ComponentModel model) {
    // The component (or a same-id replacement after a type change) arrived.
    if (model.id == id) {
      _disconnect();
      _connect();
      _notify();
    }
  }

  void _onDeleted(String deletedId) {
    if (deletedId == id) {
      _disconnect();
      _notify();
    }
  }

  void _notify() {
    for (final void Function() listener
        in List<void Function()>.of(_listeners)) {
      listener();
    }
  }

  /// Releases the underlying binder and surface subscriptions.
  void dispose() {
    surface.componentsModel.onCreated.removeListener(_onCreated);
    surface.componentsModel.onDeleted.removeListener(_onDeleted);
    _disconnect();
  }
}

/// The names of a schema's top-level properties that are `componentId`
/// references (single child slots). `a2ui_core`'s schemas tag a `componentId`
/// with a `REF:…#/$defs/ComponentId` description; properties carrying it (incl.
/// those merged via `allOf`/`anyOf`/`oneOf`) are single child references.
/// Takes the schema's raw value map so the bridge needn't depend on the schema
/// library directly.
Set<String> _componentIdProps(Map<String, Object?> schemaValue) {
  const String marker = r'#/$defs/ComponentId';
  final Set<String> result = <String>{};
  void visit(Object? node) {
    if (node is! Map) {
      return;
    }
    final Object? properties = node['properties'];
    if (properties is Map) {
      properties.forEach((Object? key, Object? propSchema) {
        if (key is String &&
            propSchema is Map &&
            propSchema['description'] is String &&
            (propSchema['description'] as String).contains(marker)) {
          result.add(key);
        }
      });
    }
    for (final String combinator in const <String>['allOf', 'anyOf', 'oneOf']) {
      final Object? branches = node[combinator];
      if (branches is List) {
        branches.forEach(visit);
      }
    }
  }

  visit(schemaValue);
  return result;
}

/// Maps `a2ui_core`'s resolved [props] onto RFW template **args**, delegating
/// child injection to [injectChild].
///
/// Scalars (already-resolved strings/numbers/bools), action callbacks, and
/// two-way setters pass through by name. A `List<ChildNode>` (the resolved form
/// of a `children` slot — both a static id list and a `ChildList` template) is
/// turned into a list of framework nodes via [injectChild], which the adapter
/// implements by building a child adapter per [ChildNode]. A prop named in
/// [childRefs] is a **single child reference** (a `componentId`): its resolved
/// value is a plain id string, which becomes one injected child sharing the
/// owner's data scope ([basePath]). The bridge stays **catalog-agnostic**: it
/// knows no widget's arg schema (that is the template's concern); props map to
/// args by name, and a high-level template maps those args onto the low-level
/// catalog.
DynamicMap a2uiArgsFromProps(
  Map<String, dynamic> props,
  Object Function(ChildNode child) injectChild, {
  Set<String> childRefs = const <String>{},
  String basePath = '/',
}) {
  final DynamicMap args = <String, Object?>{};
  for (final MapEntry<String, dynamic> entry in props.entries) {
    final Object? value = entry.value;
    if (value is List && value.isNotEmpty && value.first is ChildNode) {
      args[entry.key] = <Object?>[
        for (final ChildNode child in value.cast<ChildNode>())
          injectChild(child),
      ];
    } else if (childRefs.contains(entry.key) && value is String) {
      args[entry.key] = injectChild(ChildNode(value, basePath));
    } else {
      args[entry.key] = value;
    }
  }
  return args;
}
