// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

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
      return Text(source.v<String>(['text']) ?? '');
    },
    'Row': (BuildContext context, DataSource source) {
      return div(
        styles: Styles.flexbox(direction: FlexDirection.row),
        source.childList(['children']),
      );
    },
    'Column': (BuildContext context, DataSource source) {
      return div(
        styles: Styles.flexbox(direction: FlexDirection.column),
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
  });
}
