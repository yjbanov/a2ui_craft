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
LocalComponentLibrary createCoreComponents() {
  return LocalComponentLibrary(<String, LocalComponentBuilder>{
    'Text': (BuildContext context, DataSource source) {
      return Text(source.v<String>(['text']) ?? '', key: _key(source));
    },
    'Row': (BuildContext context, DataSource source) {
      return Row(
        key: _key(source),
        mainAxisSize: MainAxisSize.min,
        children: source.childList(['children']),
      );
    },
    'Column': (BuildContext context, DataSource source) {
      return Column(
        key: _key(source),
        mainAxisSize: MainAxisSize.min,
        children: source.childList(['children']),
      );
    },
    'Button': (BuildContext context, DataSource source) {
      final VoidCallback? onPressed = source.voidHandler(['onPressed']);
      return GestureDetector(
        key: _key(source),
        onTap: onPressed,
        child: source.child(['child']),
      );
    },
  });
}

/// Reads the optional `key` argument shared by all core components and maps it
/// to a framework key, enabling stable, framework-neutral test location.
Key? _key(DataSource source) {
  final String? key = source.v<String>(['key']);
  return key == null ? null : ValueKey<String>(key);
}
