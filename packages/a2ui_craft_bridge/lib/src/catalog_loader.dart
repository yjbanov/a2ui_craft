// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// Loads an A2UI catalog delivered as **raw JSON Schema**, so a client can be
/// taught a template's component API at runtime — knowing nothing about it
/// ahead of time.
///
/// This is the ephemeral counterpart to `a2ui_core`'s in-capability catalog
/// serialization: a template ships as RFW text, its messages as
/// JSON, and its **component API as JSON Schema** parsed here. Only the A2UI
/// *protocol* (the common-type vocabulary below + the RFW grammar) is
/// precompiled; per-template schemas arrive as data.
///
/// The document shape is deliberately slim:
/// ```json
/// {
///   "catalogId": "demo",
///   "components": {
///     "Greeting": {
///       "properties": {
///         "title":   { "$ref": "DynamicString" },
///         "message": { "$ref": "DynamicString" },
///         "action":  { "$ref": "Action" }
///       },
///       "required": ["title"]
///     }
///   }
/// }
/// ```
/// Each property is ordinary JSON Schema. A `$ref` naming an **A2UI common type**
/// — `DynamicString`, `DynamicBoolean`, `DataBinding`, `FunctionCall`, `Action`,
/// `ChildList`, `ComponentId`, or `Checkable` (the bare name or the canonical
/// `common_types.json#/$defs/<Name>` form) — is resolved to that type's inline
/// schema so `a2ui_core`'s `GenericBinder` can scrape its behavior (data binding,
/// action, child list, …). Any other JSON Schema passes through unchanged.
Catalog<ComponentApi> loadCatalog(Map<String, Object?> json) {
  final Object? id = json['catalogId'];
  if (id is! String) {
    throw ArgumentError("Catalog is missing a string 'catalogId'.");
  }
  final Object? components = json['components'];
  if (components is! Map) {
    throw ArgumentError("Catalog is missing a 'components' object.");
  }

  return Catalog<ComponentApi>(
    id: id,
    components: <ComponentApi>[
      for (final MapEntry<Object?, Object?> entry in components.entries)
        _JsonComponentApi(
          entry.key as String,
          Schema.fromMap(_resolveRefs(entry.value) as Map<String, Object?>),
        ),
    ],
  );
}

/// A [ComponentApi] whose schema was parsed from JSON rather than declared in
/// code.
class _JsonComponentApi extends ComponentApi {
  _JsonComponentApi(this.name, this.schema);

  @override
  final String name;

  @override
  final Schema schema;
}

/// The A2UI common-type vocabulary, taken from `a2ui_core`'s [CommonSchemas] so
/// the two stay in lockstep. Each maps a `$ref` name to its inline schema.
final Map<String, Map<String, Object?>> _commonTypes =
    <String, Map<String, Object?>>{
  'DynamicString': CommonSchemas.dynamicString.value,
  'DynamicBoolean': CommonSchemas.dynamicBoolean.value,
  'DataBinding': CommonSchemas.dataBinding.value,
  'FunctionCall': CommonSchemas.functionCall.value,
  'Action': CommonSchemas.action.value,
  'ChildList': CommonSchemas.childList.value,
  'ComponentId': CommonSchemas.componentId.value,
  'Checkable': CommonSchemas.checkable.value,
};

/// Recursively replaces `{"$ref": "<CommonType>"}` nodes with the common type's
/// inline schema (deep-copied), leaving all other JSON unchanged.
Object? _resolveRefs(Object? node) {
  if (node is Map) {
    final Object? ref = node[r'$ref'];
    if (ref is String) {
      final Map<String, Object?>? def = _commonTypes[_refName(ref)];
      if (def != null) {
        return _deepCopy(def);
      }
    }
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> e in node.entries)
        e.key as String: _resolveRefs(e.value),
    };
  }
  if (node is List) {
    return <Object?>[for (final Object? e in node) _resolveRefs(e)];
  }
  return node;
}

/// Reduces a `$ref` to its common-type name: `common_types.json#/$defs/Action`
/// and a bare `Action` both yield `Action`.
String _refName(String ref) {
  const String marker = r'$defs/';
  final int i = ref.indexOf(marker);
  return i >= 0 ? ref.substring(i + marker.length) : ref;
}

Object? _deepCopy(Object? node) {
  if (node is Map) {
    return <String, Object?>{
      for (final MapEntry<Object?, Object?> e in node.entries)
        e.key as String: _deepCopy(e.value),
    };
  }
  if (node is List) {
    return <Object?>[for (final Object? e in node) _deepCopy(e)];
  }
  return node;
}
