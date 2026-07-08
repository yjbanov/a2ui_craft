// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

// Smoke test for the framework-agnostic core: parsing the RFW text format and
// using DynamicContent must work with no UI-framework dependency in scope. If
// this file ever needs a Flutter/Jaspr import to compile, the core has leaked a
// framework dependency.
void main() {
  test('parseLibraryFile parses widgets and imports', () {
    final RemoteWidgetLibrary library = parseLibraryFile('''
      import core;
      widget root = Column(
        children: [
          Text(text: data.greeting),
        ],
      );
    ''');

    expect(library.imports.single.name.parts, <String>['core']);
    expect(library.widgets.single.name, 'root');
  });

  test('DynamicContent stores values readable by subscription', () {
    final DynamicContent data = DynamicContent();
    data.update('greeting', 'Hello');

    // subscribe() returns the current value at the key (and registers the
    // callback for future changes).
    final Object current =
        data.subscribe(<Object>['greeting'], (Object value) {});
    expect(current, 'Hello');
  });

  test('theme references parse in value positions, like data references', () {
    final RemoteWidgetLibrary library = parseLibraryFile('''
      import core;
      widget root = Box(
        color: theme.color.action,
        child: Text(text: theme.type.body.size),
      );
    ''');

    final ConstructorCall root = library.widgets.single.root as ConstructorCall;
    final ThemeReference color = root.arguments['color']! as ThemeReference;
    expect(color.parts, <Object>['color', 'action']);
    final ConstructorCall child = root.arguments['child']! as ConstructorCall;
    final ThemeReference text = child.arguments['text']! as ThemeReference;
    expect(text.parts, <Object>['type', 'body', 'size']);
  });

  test('theme is a reserved word for user-chosen identifiers', () {
    // Like `data`/`state`, reserved-ness guards the identifier positions a
    // user names (loop variables, builder arguments) — a loop variable named
    // `theme` would shadow the reference scope. Widget declaration names are
    // a separate namespace and are unaffected, as with the other scopes.
    expect(
      () => parseLibraryFile(
          'widget root = Column(children: [...for theme in args.list: '
          'Text(text: theme)]);'),
      throwsA(isA<ParserException>()),
    );
  });

  test('theme references survive a binary round trip (tag 0x14)', () {
    final RemoteWidgetLibrary library = parseLibraryFile('''
      widget root = Box(color: theme.color.action);
    ''');
    final RemoteWidgetLibrary decoded =
        decodeLibraryBlob(encodeLibraryBlob(library));

    final ConstructorCall root = decoded.widgets.single.root as ConstructorCall;
    final ThemeReference color = root.arguments['color']! as ThemeReference;
    expect(color.parts, <Object>['color', 'action']);
  });
}
