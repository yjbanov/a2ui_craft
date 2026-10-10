// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:test/test.dart';

void main() {
  group('specializeLibrary', () {
    test('prunes dead switch branch for matched static SymbolReference', () {
      final RemoteWidgetLibrary library = parseLibraryFile('''
        widget root = switch Location.args.latLong {
          true: Location(latLong: args.pos),
          default: FallbackWidget(),
        };
      ''');

      final RemoteWidgetLibrary specialized = specializeLibrary(
        library,
        widgetMetadata: <String, Map<String, Object?>>{
          'Location': <String, Object?>{
            'args': <String, Object?>{'latLong': true},
          },
        },
      );

      expect(specialized.widgets.single.root, isA<ConstructorCall>());
      final ConstructorCall call =
          specialized.widgets.single.root as ConstructorCall;
      expect(call.name, 'Location');
      expect(call.arguments.containsKey('latLong'), isTrue);
    });

    test(
        'prunes dead switch branch for missing static SymbolReference to default',
        () {
      final RemoteWidgetLibrary library = parseLibraryFile('''
        widget root = switch MissingWidget.args.latLong {
          true: Location(latLong: args.pos),
          default: FallbackWidget(),
        };
      ''');

      final RemoteWidgetLibrary specialized = specializeLibrary(
        library,
        widgetMetadata: <String, Map<String, Object?>>{
          'Location': <String, Object?>{
            'args': <String, Object?>{'latLong': true},
          },
        },
      );

      expect(specialized.widgets.single.root, isA<ConstructorCall>());
      final ConstructorCall call =
          specialized.widgets.single.root as ConstructorCall;
      expect(call.name, 'FallbackWidget');
    });

    test('folds static introspection function calls', () {
      final RemoteWidgetLibrary library = parseLibraryFile('''
        widget root = Card(
          hasLoc: hasWidget(name: "Location"),
          hasArg: hasWidgetArg(widget: "Location", arg: "latLong"),
          hasArgWidget: hasArg(widget: "Location", arg: "latLong"),
          hasArgFn: hasArg(function: "add", arg: "a"),
          hasArgNameW: hasArg(name: "Location", arg: "latLong"),
          hasArgNameF: hasArg(name: "add", arg: "a"),
          hasArgMissing: hasArg(widget: "Location", arg: "missing"),
          hasArgFake: hasArg(name: "FakeWidget", arg: "latLong"),
          hasFake: hasWidget(name: "FakeWidget"),
          hasFn: hasFunction(name: "add"),
          runtimeVer: runtimeVersion(),
          metaVal: meta(w: "Location", path: "args.latLong"),
        );
      ''');

      final LocalFunctionLibrary coreFn = createCoreFunctions();
      final RemoteWidgetLibrary specialized = specializeLibrary(
        library,
        widgetMetadata: <String, Map<String, Object?>>{
          'Location': <String, Object?>{
            'args': <String, Object?>{'latLong': true},
          },
        },
        functions: coreFn.functions,
        knownWidgets: <String>{'Location'},
        runtimeVersion: 42,
      );

      final ConstructorCall root =
          specialized.widgets.single.root as ConstructorCall;
      expect(root.arguments['hasLoc'], true);
      expect(root.arguments['hasArg'], true);
      expect(root.arguments['hasArgWidget'], true);
      expect(root.arguments['hasArgFn'], true);
      expect(root.arguments['hasArgNameW'], true);
      expect(root.arguments['hasArgNameF'], true);
      expect(root.arguments['hasArgMissing'], false);
      expect(root.arguments['hasArgFake'], false);
      expect(root.arguments['hasFake'], false);
      expect(root.arguments['hasFn'], true);
      expect(root.arguments['runtimeVer'], 42);
      expect(root.arguments['metaVal'], true);
    });

    test('prunes dead switch branch for hasArg', () {
      final RemoteWidgetLibrary library = parseLibraryFile('''
        widget root = switch hasArg(widget: "Location", arg: "latLong") {
          true: Location(latLong: args.pos),
          default: FallbackWidget(),
        };
      ''');

      final RemoteWidgetLibrary specialized = specializeLibrary(
        library,
        widgetMetadata: <String, Map<String, Object?>>{
          'Location': <String, Object?>{
            'args': <String, Object?>{'latLong': true},
          },
        },
      );

      expect(specialized.widgets.single.root, isA<ConstructorCall>());
      final ConstructorCall call =
          specialized.widgets.single.root as ConstructorCall;
      expect(call.name, 'Location');
      expect(call.arguments.containsKey('latLong'), isTrue);
    });

    test('simplifies hybrid boolean expressions', () {
      final RemoteWidgetLibrary library = parseLibraryFile('''
        widget root = Box(
          falseAndDynamic: and(a: false, b: media.hasGps),
          trueAndDynamic: and(a: true, b: media.hasGps),
          trueOrDynamic: or(a: true, b: media.hasGps),
          falseOrDynamic: or(a: false, b: media.hasGps),
        );
      ''');

      final LocalFunctionLibrary coreFn = createCoreFunctions();
      final RemoteWidgetLibrary specialized = specializeLibrary(
        library,
        functions: coreFn.functions,
      );

      final ConstructorCall root =
          specialized.widgets.single.root as ConstructorCall;
      expect(root.arguments['falseAndDynamic'], false);
      expect(root.arguments['trueAndDynamic'], isA<MediaReference>());
      expect(root.arguments['trueOrDynamic'], true);
      expect(root.arguments['falseOrDynamic'], isA<MediaReference>());
    });

    test('preserves dynamic switches', () {
      final RemoteWidgetLibrary library = parseLibraryFile('''
        widget root = switch data.status {
          "active": Text(text: "Active"),
          default: Text(text: "Inactive"),
        };
      ''');

      final RemoteWidgetLibrary specialized = specializeLibrary(library);
      expect(specialized.widgets.single.root, isA<Switch>());
      final Switch sw = specialized.widgets.single.root as Switch;
      expect(sw.input, isA<DataReference>());
      expect(sw.outputs.length, 2);
    });

    test('preserves specialized BlobNode root when selected from Switch', () {
      final RemoteWidgetLibrary library = parseLibraryFile('''
        widget root = switch hasWidget(name: "Location") {
          true: Location(name: "active"),
          default: Text(text: "No location"),
        };
      ''');

      final RemoteWidgetLibrary specialized = specializeLibrary(
        library,
        knownWidgets: const <String>{'Location'},
      );
      expect(specialized.widgets.single.root, isA<ConstructorCall>());
      final ConstructorCall call =
          specialized.widgets.single.root as ConstructorCall;
      expect(call.name, 'Location');
      expect(call.arguments['name'], 'active');
    });
  });
}
