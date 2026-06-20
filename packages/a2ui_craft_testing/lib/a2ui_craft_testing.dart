// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Shared test fixtures for A2UI Craft adapter **parity tests**.
///
/// Every framework adapter (Flutter, Jaspr, …) has a test that renders the
/// *same* template defined here and asserts the *same* behavior. Keeping the
/// template and scenario in one place makes "all adapters render the identical
/// template" a structural guarantee instead of a copy-paste hope. This package
/// is test-only and not published.
library a2ui_craft_testing;

import 'package:a2ui_craft/a2ui_craft.dart';

/// A minimal "counter" scenario exercising the whole engine path: a container
/// (Column), a data-bound Text, a static Text, and a Button that dispatches an
/// event. Adapters wire their framework-specific runtime around these shared
/// definitions.
abstract final class CounterScenario {
  /// The library the template is registered under.
  static const LibraryName mainLibrary = LibraryName(<String>['main']);

  /// The library the core components are registered under.
  static const LibraryName coreLibrary = LibraryName(<String>['core']);

  /// The root widget declared by [template].
  static const String rootWidget = 'root';

  /// Fully-qualified name of the component an adapter should render.
  static const FullyQualifiedWidgetName rootComponent =
      FullyQualifiedWidgetName(mainLibrary, rootWidget);

  /// Data-model key the greeting Text is bound to.
  static const String greetingKey = 'greeting';

  /// Initial value of [greetingKey].
  static const String greetingInitial = 'Hello';

  /// Visible label of the button.
  static const String buttonLabel = 'Increment';

  /// Name of the event the button dispatches.
  static const String eventName = 'increment';

  /// The template source. The literals below are interpolated from the
  /// constants above so the template and the assertions can never drift.
  static const String template = '''
    import core;
    widget $rootWidget = Column(
      children: [
        Text(text: data.$greetingKey),
        Button(
          onPressed: event "$eventName" {},
          child: Text(text: "$buttonLabel"),
        ),
      ],
    );
  ''';

  /// Parses [template] into a library. Every adapter parses identically.
  static RemoteWidgetLibrary library() => parseLibraryFile(template);

  /// The greeting value a host should write after [count] button presses.
  static String greetingAfter(int count) => 'Clicked $count';
}
