// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'runtime.dart';

/// A library of standard core components (Text, Row, Column, Button)
/// implemented using Jaspr DOM elements.
///
/// This deliberately mirrors, component-for-component, the `createCoreComponents`
/// of the `a2ui_craft_flutter` adapter so that the *same* template renders on
/// both frameworks. The shared behavioral contract is verified by the
/// conformance suite in `package:a2ui_craft_testing`, and the set of names is
/// pinned by its `coreCatalog`.
///
/// Note: the reserved `key` argument is handled by the runtime, which lifts it
/// onto the reconciliation unit (`_Widget`) — see DESIGN.md §6 — so these
/// builders do not read or apply it themselves.
LocalComponentLibrary createCoreComponents() {
  return LocalComponentLibrary(<String, LocalComponentBuilder>{
    'Text': (BuildContext context, DataSource source) {
      return Component.text(source.v<String>(['text']) ?? '');
    },
    'Row': (BuildContext context, DataSource source) {
      return div(
        styles: Styles(display: Display.flex, flexDirection: FlexDirection.row),
        source.childList(['children']),
      );
    },
    'Column': (BuildContext context, DataSource source) {
      return div(
        styles:
            Styles(display: Display.flex, flexDirection: FlexDirection.column),
        source.childList(['children']),
      );
    },
    'Button': (BuildContext context, DataSource source) {
      final onPressed = source.voidHandler(['onPressed']);
      return button(
        onClick: onPressed == null ? null : () => onPressed(),
        [
          source.child(['child'])
        ],
      );
    },
    'Center': (BuildContext context, DataSource source) {
      return div(
        styles: Styles(
          display: Display.flex,
          justifyContent: JustifyContent.center,
          alignItems: AlignItems.center,
        ),
        [
          source.child(['child'])
        ],
      );
    },
    'SizedBox': (BuildContext context, DataSource source) {
      final double? w = source.v<double>(['width']);
      final double? h = source.v<double>(['height']);
      return div(
        styles: Styles(
          width: w != null ? Unit.pixels(w) : null,
          height: h != null ? Unit.pixels(h) : null,
        ),
        [
          source.child(['child'])
        ],
      );
    },
    'Image': (BuildContext context, DataSource source) {
      final String? url = source.v<String>(['url']);
      if (url == null || url.isEmpty) {
        return div([]);
      }
      return img(src: url);
    },
    'Icon': (BuildContext context, DataSource source) {
      final String? iconName = source.v<String>(['icon']);
      final String name = iconName ?? 'star'; // default fallback
      return i(classes: 'material-icons', [Component.text(name)]);
    },
    'Divider': (BuildContext context, DataSource source) {
      return hr();
    },
    'ScrollView': (BuildContext context, DataSource source) {
      return div(
        styles: Styles(
          overflow: Overflow.auto,
        ),
        [
          source.child(['child'])
        ],
      );
    },
    'Card': (BuildContext context, DataSource source) {
      return div(
        styles: Styles(
          padding: Padding.all(Unit.pixels(16)),
          radius: BorderRadius.circular(Unit.pixels(8)),
          shadow: BoxShadow(
            color: Color.rgba(0, 0, 0, 0.25),
            blur: Unit.pixels(4),
            offsetX: Unit.zero,
            offsetY: Unit.pixels(2),
          ),
          backgroundColor: Colors.white,
        ),
        [
          source.child(['child'])
        ],
      );
    },
    'Video': (BuildContext context, DataSource source) {
      final String? url = source.v<String>(['url']);
      if (url == null || url.isEmpty) {
        return div([]);
      }
      return video(src: url, controls: true, []);
    },
  });
}
