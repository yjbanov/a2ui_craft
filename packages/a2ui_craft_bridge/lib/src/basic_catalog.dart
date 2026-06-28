// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Renders the **A2UI Basic Catalog** with A2UI Craft's primitives.
///
/// A2UI's Basic Catalog (Card, Row, Text, Image, …) names its components the same
/// as our core primitives, so a surface authored against it renders **directly
/// against the `core` primitives** — no template indirection. The only work is a
/// small **prop transform** ([a2uiBasicCatalogCall]): A2UI uses `justify`/`align`
/// where the primitives use `mainAxisAlignment`/`crossAxisAlignment`, `name` where
/// `Icon` uses `icon`, and `action` where `Button` uses `onPressed`. Everything
/// else (`text`, `url`, `fit`, `variant`, `child`, `children`) already matches.
///
/// This is a code mapping, not a Craft template: the Basic Catalog is generic
/// infrastructure (essentially the primitives re-propped), so it is mechanical to
/// translate. App-defined *catalogs* of domain widgets are the thing authored as
/// templates (DESIGN.md §2, "Bias to templatize").
///
/// Scope is the static-card subset for now; controls (`TextField`/`CheckBox`/
/// `Slider` with labels), `weight`, and the stateful components are future work.
library;

import 'package:a2ui_core/a2ui_core.dart';
import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:json_schema_builder/json_schema_builder.dart';

/// The `catalogId` A2UI Basic Catalog surfaces reference.
const String basicCatalogId =
    'https://a2ui.org/specification/v1_0/catalogs/basic/catalog.json';

/// The library the transformed components resolve against (the core primitives).
const LibraryName basicCatalogScope = LibraryName(<String>['core']);

/// Maps an A2UI Basic Catalog component (its `type` and the RFW-arg form of its
/// resolved props) to a primitive [ConstructorCall].
///
/// Child slots (`child`/`children`) are already-injected host nodes in [args] and
/// pass through unchanged; only scalar/style props are renamed.
///
/// A2UI's schema declares the cross-axis default (`align`) as `stretch`, but a
/// `stretch` cross-axis is invalid for a `Row` whose height is unbounded (e.g. a
/// `Row` nested in a `Column`), so a blanket default would crash real surfaces.
/// We therefore do **not** inject it: an absent `align` falls through to the
/// primitive's safe `center` default. This matches the genui reference Flutter
/// renderer, which likewise maps an absent `align` to `start`, not `stretch`.
ConstructorCall a2uiBasicCatalogCall(String type, DynamicMap args) {
  switch (type) {
    case 'Row':
    case 'Column':
      return ConstructorCall(
        type,
        _remap(args, const <String, String>{
          'justify': 'mainAxisAlignment',
          'align': 'crossAxisAlignment',
        }),
      );
    case 'List':
      return ConstructorCall(
        'List',
        _remap(args, const <String, String>{'align': 'crossAxisAlignment'}),
      );
    case 'Icon':
      return ConstructorCall(
          'Icon', _remap(args, const <String, String>{'name': 'icon'}));
    case 'Button':
      return ConstructorCall('Button',
          _remap(args, const <String, String>{'action': 'onPressed'}));
    default:
      // Card, Text, Image, Divider, …: names and props already match.
      return ConstructorCall(type, args);
  }
}

/// Returns [args] with keys in [rename] renamed (other keys pass through).
DynamicMap _remap(DynamicMap args, Map<String, String> rename) {
  final DynamicMap out = <String, Object?>{};
  args.forEach((String key, Object? value) {
    out[rename[key] ?? key] = value;
  });
  return out;
}

/// The `a2ui_core` [Catalog] for the supported A2UI Basic Catalog components, so
/// a `MessageProcessor` can ingest real Basic-Catalog surfaces (resolving which
/// props are data-bound, actions, functions, or child slots).
///
/// Hand-written for the supported subset rather than loaded from the real
/// `catalog.json` (whose full-URL `$ref`s and `allOf`/`unevaluatedProperties`
/// shape the bridge's `loadCatalog` does not target).
///
/// Registers [FormatStringFunction] — the one A2UI text function the pinned
/// `a2ui_core` ships. The Basic Catalog's other functions (`formatCurrency`,
/// `formatNumber`, `formatDate`, `pluralize`) have no implementation here yet, so
/// surfaces that call them throw on resolution; see DESIGN.md's gap list.
Catalog<ComponentApi> a2uiBasicCatalog() => Catalog<ComponentApi>(
      id: basicCatalogId,
      functions: <FunctionImplementation>[FormatStringFunction()],
      components: <ComponentApi>[
        _Comp('Card', <String, Schema>{'child': CommonSchemas.componentId},
            <String>['child']),
        _Comp('Row', _flexProps(), const <String>['children']),
        _Comp('Column', _flexProps(), const <String>['children']),
        _Comp('List', <String, Schema>{
          'children': CommonSchemas.childList,
          'direction': Schema.string(),
          'align': Schema.string(),
        }, const <String>[
          'children'
        ]),
        _Comp('Text', <String, Schema>{
          'text': CommonSchemas.dynamicString,
          'variant': Schema.string(),
        }, const <String>[
          'text'
        ]),
        _Comp('Image', <String, Schema>{
          'url': CommonSchemas.dynamicString,
          'description': CommonSchemas.dynamicString,
          'fit': Schema.string(),
          'variant': Schema.string(),
        }, const <String>[
          'url'
        ]),
        _Comp('Icon', <String, Schema>{'name': Schema.string()},
            const <String>['name']),
        _Comp('Divider', <String, Schema>{'axis': Schema.string()},
            const <String>[]),
        _Comp('Button', <String, Schema>{
          'child': CommonSchemas.componentId,
          'action': CommonSchemas.action,
          'variant': Schema.string(),
        }, const <String>[
          'child',
          'action'
        ]),
      ],
    );

Map<String, Schema> _flexProps() => <String, Schema>{
      'children': CommonSchemas.childList,
      'justify': Schema.string(),
      'align': Schema.string(),
    };

/// A [ComponentApi] built from a property map (the bridge's hand-written Basic
/// Catalog subset).
class _Comp extends ComponentApi {
  _Comp(this.name, Map<String, Schema> properties, List<String> required)
      : schema = Schema.object(properties: properties, required: required);

  @override
  final String name;

  @override
  final Schema schema;
}
