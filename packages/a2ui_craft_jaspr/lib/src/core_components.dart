// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/jaspr.dart';

import 'runtime.dart';

/// A library of standard core components (Text, Row, Column, Button)
/// implemented using Jaspr DOM elements.
LocalComponentLibrary createCoreComponents() {
  return LocalComponentLibrary(
    <String, LocalComponentBuilder>{
      'Text': (BuildContext context, DataSource source) {
        return Text(source.v<String>(['text']) ?? '');
      },
      'Row': (BuildContext context, DataSource source) {
        final children = source.childList(['children']);
        return div(
          styles: Styles.flexbox(
            direction: FlexDirection.row,
          ),
          children,
        );
      },
      'Column': (BuildContext context, DataSource source) {
        final children = source.childList(['children']);
        return div(
          styles: Styles.flexbox(
            direction: FlexDirection.column,
          ),
          children,
        );
      },
      'Button': (BuildContext context, DataSource source) {
        final child = source.child(['child']);
        final onPressed = source.voidHandler(['onPressed']);
        return button(
          onClick: onPressed == null ? null : () => onPressed(),
          [child],
        );
      },
    },
  );
}
