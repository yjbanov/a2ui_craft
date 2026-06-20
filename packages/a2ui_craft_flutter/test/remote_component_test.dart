import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// A small template that exercises the whole adapter path: a container
// (Column), a static and a data-bound Text, and a Button that dispatches an
// event. This is intentionally the same shape as the Jaspr adapter's example.
const String _template = '''
  import core;
  widget root = Column(
    children: [
      Text(text: data.greeting),
      Button(
        onPressed: event "increment" {},
        child: Text(text: "Increment"),
      ),
    ],
  );
''';

void main() {
  testWidgets('parses, renders, handles events, and reacts to data updates',
      (WidgetTester tester) async {
    final Runtime runtime = Runtime()
      ..update(const LibraryName(<String>['core']), createCoreComponents())
      ..update(
          const LibraryName(<String>['main']), parseLibraryFile(_template));

    final DynamicContent data = DynamicContent();
    data.update('greeting', 'Hello');

    var count = 0;
    void onEvent(String name, DynamicMap arguments) {
      if (name == 'increment') {
        count += 1;
        data.update('greeting', 'Clicked $count');
      }
    }

    await tester.pumpWidget(
      MaterialApp(
        home: RemoteComponent(
          runtime: runtime,
          component: const FullyQualifiedWidgetName(
              LibraryName(<String>['main']), 'root'),
          data: data,
          onEvent: onEvent,
        ),
      ),
    );

    // Initial render: data binding and static text both resolved.
    expect(find.text('Hello'), findsOneWidget);
    expect(find.text('Increment'), findsOneWidget);

    // Event dispatch reaches the host's onEvent callback.
    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(count, 1);

    // Updating the data model re-renders the bound Text reactively.
    expect(find.text('Clicked 1'), findsOneWidget);
    expect(find.text('Hello'), findsNothing);
  });
}
