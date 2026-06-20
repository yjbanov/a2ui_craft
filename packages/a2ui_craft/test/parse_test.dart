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
}
