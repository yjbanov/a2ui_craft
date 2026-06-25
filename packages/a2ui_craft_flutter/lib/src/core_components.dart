// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/widgets.dart';

import 'runtime.dart';

/// A minimal library of standard core components (Text, Row, Column, Button)
/// implemented using Flutter widgets.
///
/// This deliberately mirrors, component-for-component, the `createCoreComponents`
/// of the `a2ui_craft_jaspr` adapter so that the *same* template renders on both
/// frameworks. The shared behavioral contract is verified by the conformance
/// suite in `package:a2ui_craft_testing`, and the set of names is pinned by its
/// `coreCatalog`. This set is intentionally small: the real, cross-platform core
/// component/type library is a separate, in-progress effort (see DESIGN.md).
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
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: source.childList(['children']),
      );
    },
    'Column': (BuildContext context, DataSource source) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: source.childList(['children']),
      );
    },
    'Button': (BuildContext context, DataSource source) {
      final VoidCallback? onPressed = source.voidHandler(['onPressed']);
      return GestureDetector(
        onTap: onPressed,
        child: source.child(['child']),
      );
    },
    'Center': (BuildContext context, DataSource source) {
      return Center(
        child: source.child(['child']),
      );
    },
    'SizedBox': (BuildContext context, DataSource source) {
      return SizedBox(
        width: source.v<double>(['width']),
        height: source.v<double>(['height']),
        child: source.child(['child']),
      );
    },
  });
}
