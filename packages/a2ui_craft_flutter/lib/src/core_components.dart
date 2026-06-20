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
/// frameworks. It is intentionally small: the real, cross-platform core
/// component/type library is a separate, future effort (see DESIGN.md). This
/// set exists only to exercise the adapter harness end-to-end.
LocalComponentLibrary createCoreComponents() {
  return LocalComponentLibrary(
    <String, LocalComponentBuilder>{
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
    },
  );
}
