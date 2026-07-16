// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// This file is hand-formatted.

import 'dart:collection';

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/jaspr.dart' hide Import;

typedef VoidCallback = void Function();

/// Signature of builders for local widgets.
///
/// The [LocalWidgetLibrary] class wraps a map of widget names to
/// [LocalWidgetBuilder] callbacks.
typedef LocalWidgetBuilder = Component Function(
    BuildContext context, DataSource source);

// The template function types ([LocalFunction], [LocalFunctionLibrary],
// [FunctionArgType], [LocalFunctionImplementation]) and the standard library
// ([createCoreFunctions]) are framework-neutral and defined once in
// `package:a2ui_craft` (src/functions.dart); this adapter imports them so a
// template computes identical values on every adapter.

/// Signature of builders for remote widgets.
typedef _RemoteWidgetBuilder = _CurriedWidget Function(DynamicMap builderArg);

/// Signature of the callback passed to a [RemoteWidget].
///
/// This is used by [RemoteWidget] and [Runtime.build] as the callback for
/// events triggered by remote widgets.
typedef RemoteEventHandler = void Function(
    String eventName, DynamicMap eventArguments);

/// Signature of the callback passed to [DataSource.handler].
///
/// The callback should return a function of type `T`. That function should call
/// `trigger`.
///
/// See [DataSource.handler] for details.
typedef HandlerGenerator<T extends Function> = T Function(
    HandlerTrigger trigger);

/// Signature of the callback passed to a [HandlerGenerator].
///
/// See [DataSource.handler] for details.
typedef HandlerTrigger = void Function([DynamicMap? extraArguments]);

/// Used to indicate that there is an error with one of the libraries loaded
/// into the Remote Flutter Widgets [Runtime].
///
/// For example, a reference to a state variable did not match any actual state
/// values, or a library import loop.
class RemoteFlutterWidgetsException implements Exception {
  /// Creates a [RemoteFlutterWidgetsException].
  ///
  /// The message should be a complete sentence, starting with a capital letter
  /// and ending with a period.
  const RemoteFlutterWidgetsException(this.message);

  /// A description of the problem that was detected.
  ///
  /// This will end with a period.
  final String message;

  @override
  String toString() => message;
}

/// Interface for [LocalWidgetBuilder] to obtain data from arguments.
///
/// The interface exposes the [v] method, the argument to which is a list of
/// keys forming a path to a node in the arguments expected by the component. If
/// the method's type argument does not match the value obtained, null is
/// returned instead.
///
/// In addition, to fetch widgets specifically, the [child] and [childList]
/// methods must be used, and to fetch event handlers, the [handler] method must
/// be used.
///
/// The [isList] and [isMap] methods can be used to avoid inspecting keys that
/// may not be present (e.g. before reading 15 keys in a map that isn't even
/// present, consider checking if the map is present using [isMap] and
/// short-circuiting the key lookups if it is not).
///
/// To iterate over a list, the [length] method can be used to find the number
/// of items in the list.
abstract class DataSource {
  /// Return the int, double, bool, or String value at the given path of the
  /// arguments to the component.
  ///
  /// `T` must be one of [int], [double], [bool], or [String].
  ///
  /// If `T` does not match the type of the value obtained, then the method
  /// returns null.
  T? v<T extends Object>(List<Object> argsKey);

  /// Return true if the given key identifies a list, otherwise false.
  bool isList(List<Object> argsKey);

  /// Return the length of the list at the given path of the arguments to the
  /// component.
  ///
  /// If the given path does not identify a list, returns zero.
  int length(List<Object> argsKey);

  /// Return true if the given key identifies a map, otherwise false.
  bool isMap(List<Object> argsKey);

  /// Build the child at the given key.
  ///
  /// If the node specified is not a widget, returns an [ErrorWidget].
  ///
  /// See also:
  ///
  ///  * [optionalChild], which returns null if the widget is missing.
  Component child(List<Object> argsKey);

  /// Build the child at the given key.
  ///
  /// If the node specified is not a widget, returns null.
  ///
  /// See also:
  ///
  ///  * [child], which returns an [ErrorWidget] instead of null if the widget
  ///    is missing.
  Component? optionalChild(List<Object> argsKey);

  /// Builds the children at the given key.
  ///
  /// If the node is missing, returns an empty list.
  ///
  /// If the node specified is not a list of widgets, returns a list with the
  /// non-widget nodes replaced by [ErrorWidget].
  List<Component> childList(List<Object> argsKey);

  /// Builds the widget builder at the given key.
  ///
  /// If the node is not a widget builder, returns an [ErrorWidget].
  ///
  /// See also:
  ///
  ///  * [optionalBuilder], which returns null if the widget builder is missing.
  Component builder(List<Object> argsKey, DynamicMap builderArg);

  /// Builds the widget builder at the given key.
  ///
  /// If the node is not a widget builder, returns null.
  ///
  /// See also:
  ///
  ///  * [builder], which returns an [ErrorWidget] instead of null if the widget
  ///    builder is missing.
  Component? optionalBuilder(List<Object> argsKey, DynamicMap builderArg);

  /// Gets a [VoidCallback] event handler at the given key.
  ///
  /// If the node specified is an [AnyEventHandler] or a [DynamicList] of
  /// [AnyEventHandler]s, returns a callback that invokes the specified event
  /// handler(s), merging the given `extraArguments` into the arguments
  /// specified in each event handler. In the event of a key conflict (where
  /// both the arguments specified in the remote widget declaration and the
  /// argument provided to this method have the same name), the arguments
  /// specified here take precedence.
  VoidCallback? voidHandler(List<Object> argsKey, [DynamicMap? extraArguments]);

  /// Gets an event handler at the given key.
  ///
  /// The event handler can be of any Function type, as specified by the type
  /// argument `T`.
  ///
  /// When this method is called, the second argument, `generator`, is invoked.
  /// The `generator` callback must return a function, which we will call
  /// _entrypoint_, that matches the signature of `T`. The `generator` callback
  /// receives an argument, which we will call `trigger`. The _entrypoint_
  /// function must call `trigger`, optionally passing it any extra arguments
  /// that should be merged into the arguments specified in each event handler.
  ///
  /// This is admittedly a little confusing. At its core, the problem is that
  /// this method cannot itself automatically create a function (_entrypoint_)
  /// of the right type (`T`), and therefore a callback (`generator`) that knows
  /// how to wrap a function body (`trigger`) in the right signature (`T`) is
  /// needed to actually build that function (_entrypoint_).
  T? handler<T extends Function>(
      List<Object> argsKey, HandlerGenerator<T> generator);
}

/// Widgets defined by the client application. All remote widgets eventually
/// bottom out in these widgets.
class LocalWidgetLibrary extends WidgetLibrary {
  /// Create a [LocalWidgetLibrary].
  ///
  /// The given map must not change once the object is created.
  LocalWidgetLibrary(this._widgets);

  final Map<String, LocalWidgetBuilder> _widgets;

  /// Returns the builder for the widget of the given name, if any.
  @protected
  LocalWidgetBuilder? findConstructor(String name) {
    return _widgets[name];
  }

  /// The widgets defined by this [LocalWidgetLibrary].
  ///
  /// The returned map is an immutable view of the map provided to the constructor.
  /// They keys are the unqualified widget names, and the values are the corresponding
  /// [LocalWidgetBuilder]s.
  ///
  /// The map never changes during the lifetime of the [LocalWidgetLibrary], but a new
  /// instance of an [UnmodifiableMapView] is returned each time this getter is used.
  ///
  /// See also:
  ///
  ///  * [createCoreWidgets], a function that creates a [Map] of local widgets.
  UnmodifiableMapView<String, LocalWidgetBuilder> get widgets {
    return UnmodifiableMapView<String, LocalWidgetBuilder>(_widgets);
  }
}

class _ResolvedConstructor {
  const _ResolvedConstructor(this.fullName, this.constructor);
  final FullyQualifiedWidgetName fullName;
  final Object constructor;
}

/// The logic that builds and maintains Remote Flutter Widgets.
///
/// To declare the libraries of widgets, the [update] method is used.
///
/// At least one [LocalWidgetLibrary] instance must be declared
/// so that [RemoteWidgetLibrary] instances can resolve to real widgets.
///
/// The [build] method returns a [Component] generated from one of the libraries of
/// widgets added in this manner. Generally, it is simpler to use the
/// [RemoteWidget] widget (which calls [build]).
class Runtime extends ChangeNotifier {
  /// Create a [Runtime] object.
  ///
  /// This object should be [dispose]d when it is no longer needed.
  Runtime();

  final Map<LibraryName, WidgetLibrary> _libraries =
      <LibraryName, WidgetLibrary>{};

  final Map<String, LocalFunction> _functions = <String, LocalFunction>{};

  /// Registers pure value-functions callable from templates (see
  /// [LocalFunction]), merging them into any already registered.
  ///
  /// This is additive: with no functions registered, template evaluation is
  /// byte-for-byte unchanged — a `name(arg: …)` call is only treated as a
  /// function when [name] is registered here *and* is not a widget in scope
  /// (widget names take precedence). Registering functions clears the widget
  /// cache, mirroring [update].
  void registerFunctions(LocalFunctionLibrary library) {
    _functions.addAll(library.functions);
    _clearCache();
  }

  /// Replace the definitions of the specified library (`name`).
  ///
  /// References to widgets that are not defined in the available libraries will
  /// default to using the [ErrorWidget] component.
  ///
  /// [LocalWidgetLibrary] and [RemoteWidgetLibrary] instances are added using
  /// this method.
  ///
  /// [RemoteWidgetLibrary] instances are typically first obtained using
  /// [decodeLibraryBlob].
  ///
  /// To remove a library, the libraries must be cleared using [clearLibraries]
  /// and then the libraries being retained must be readded.
  void update(LibraryName name, WidgetLibrary library) {
    _libraries[name] = library;
    _clearCache();
  }

  /// Remove all the libraries and start afresh.
  ///
  /// Calling this notifies the listeners, which typically causes them to
  /// rebuild their widgets in the next frame (for example, that is how
  /// [RemoteWidget] is implemented). If no libraries are readded after calling
  /// [clearLibraries], and there are any listeners, they will fail to rebuild
  /// any widgets that they were configured to create. For this reason, this
  /// call should usually be immediately followed by calls to [update].
  void clearLibraries() {
    _libraries.clear();
    _clearCache();
  }

  /// The widget libraries imported in this [Runtime].
  ///
  /// The returned map is an immutable view of the map updated by calls to
  /// [update] and [clearLibraries].
  ///
  /// The keys are instances [LibraryName] which encode fully qualified library
  /// names, and the values are the corresponding [WidgetLibrary]s.
  ///
  /// The returned map is an immutable copy of the registered libraries
  /// at the time of this call.
  ///
  /// See also:
  ///
  ///  * [update] and [clearLibraries], functions that populate this map.
  UnmodifiableMapView<LibraryName, WidgetLibrary> get libraries {
    return UnmodifiableMapView<LibraryName, WidgetLibrary>(
        Map<LibraryName, WidgetLibrary>.from(_libraries));
  }

  final Map<FullyQualifiedWidgetName, _ResolvedConstructor?>
      _cachedConstructors = <FullyQualifiedWidgetName, _ResolvedConstructor?>{};
  final Map<FullyQualifiedWidgetName, _CurriedWidget> _widgets =
      <FullyQualifiedWidgetName, _CurriedWidget>{};

  void _clearCache() {
    _cachedConstructors.clear();
    _widgets.clear();
    notifyListeners();
  }

  /// Build the root widget of a Remote Component subtree.
  ///
  /// The widget is identified by a [FullyQualifiedWidgetName], which identifies
  /// a library and a widget name. The widget does not strictly have to be in
  /// that library, so long as it is in that library's dependencies.
  ///
  /// The data for the widget is given by the `data` argument. That object can
  /// be updated independently, the widget will rebuild appropriately as it
  /// changes.
  ///
  /// The `remoteEventTarget` argument is the callback that the RFW runtime will
  /// invoke whenever a remote widget event handler is triggered.
  Component build(
    BuildContext context,
    FullyQualifiedWidgetName widget,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget, {
    CraftTheme? theme,
    MediaContext? media,
  }) {
    _CurriedWidget? boundWidget = _widgets[widget];
    if (boundWidget == null) {
      _checkForImportLoops(widget.library);
      boundWidget = _applyConstructorAndBindArguments(
        widget,
        const <String, Object?>{},
        const <String, Object?>{},
        -1,
        <FullyQualifiedWidgetName>{},
        null,
      );
      _widgets[widget] = boundWidget;
    }
    final Component built = boundWidget
        .build(context, data, remoteEventTarget, const <_WidgetState>[]);
    return _wrapAmbientScopes(built, theme, media);
  }

  /// Wraps [built] in the render-time ambient scopes — the [CraftTheme] and the
  /// [MediaContext] — that the host supplies. Each rides an inherited scope (the
  /// ambient cascade), not the curried-widget plumbing; a null one is omitted so
  /// any enclosing scope stays visible.
  Component _wrapAmbientScopes(
      Component built, CraftTheme? theme, MediaContext? media) {
    Component result = built;
    if (theme != null) result = _ThemeScope(theme: theme, child: result);
    if (media != null) result = _MediaScope(media: media, child: result);
    return result;
  }

  /// Builds an ad-hoc [composition] against the registered libraries, without it
  /// being a named [WidgetDeclaration].
  ///
  /// Like [build], but instead of looking up a declaration by name it curries the
  /// provided [composition] directly. Component names inside [composition] are
  /// resolved against [scope] (a registered library and its imports). Slot
  /// arguments may contain already-built host components, which are injected
  /// as-is.
  ///
  /// This is the entry point for runtime-composed UIs (e.g. an A2UI surface),
  /// where the structure is decided at runtime rather than declared ahead of
  /// time.
  Component buildNode(
    BuildContext context,
    ConstructorCall composition,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget, {
    required LibraryName scope,
    CraftTheme? theme,
    MediaContext? media,
  }) {
    // TODO(yjbanov): isn't it expensive to check for loops for every node build? Maybe we should cache the result of this check for each library.
    _checkForImportLoops(scope);
    final _CurriedWidget curried = _bindArguments(
      FullyQualifiedWidgetName(scope, '<buildNode>'),
      composition,
      const <String, Object?>{},
      const <String, Object?>{},
      -1,
      <FullyQualifiedWidgetName>{},
    ) as _CurriedWidget;
    final Component built =
        curried.build(context, data, remoteEventTarget, const <_WidgetState>[]);
    return _wrapAmbientScopes(built, theme, media);
  }

  /// Returns the [BlobNode] that most closely corresponds to a given [BuildContext].
  ///
  /// If the `context` is not a remote widget and has no ancestor remote widget,
  /// then this function returns null.
  ///
  /// The [BlobNode] is typically either a [WidgetDeclaration] (whose
  /// [WidgetDeclaration.root] argument is a [ConstructorCall] or a [Switch]
  /// that resolves to a [ConstructorCall]), indicating the [BuildContext] maps
  /// to a remote widget, or a [ConstructorCall] directly, in the case where it
  /// maps to a local component. Widgets that correspond to render objects (i.e.
  /// anything that might be found by hit testing on the screen) are always
  /// local widgets.
  static BlobNode? blobNodeFor(BuildContext context) {
    if (context.component is! _Widget) {
      context.visitAncestorElements((Element element) {
        if (element.component is _Widget) {
          context = element;
          return false;
        }
        return true;
      });
    }
    if (context.component is! _Widget) {
      return null;
    }
    return (context.component as _Widget).curriedWidget;
  }

  void _checkForImportLoops(LibraryName name, [Set<LibraryName>? visited]) {
    final WidgetLibrary? library = _libraries[name];
    if (library is RemoteWidgetLibrary) {
      visited ??= <LibraryName>{};
      visited.add(name);
      for (final Import import in library.imports) {
        final LibraryName dependency = import.name;
        if (visited.contains(dependency)) {
          final path = <LibraryName>[dependency];
          for (final LibraryName name in visited.toList().reversed) {
            if (name == dependency) {
              break;
            }
            path.add(name);
          }
          if (path.length == 1) {
            assert(path.single == dependency);
            throw RemoteFlutterWidgetsException(
                'Library $dependency depends on itself.');
          } else {
            throw RemoteFlutterWidgetsException(
                'Library $dependency indirectly depends on itself via ${path.reversed.join(" which depends on ")}.');
          }
        }
        _checkForImportLoops(dependency, visited.toSet());
      }
    }
  }

  _ResolvedConstructor? _findConstructor(FullyQualifiedWidgetName fullName) {
    final _ResolvedConstructor? result = _cachedConstructors[fullName];
    if (result != null) {
      return result;
    }
    final WidgetLibrary? library = _libraries[fullName.library];
    if (library is RemoteWidgetLibrary) {
      for (final WidgetDeclaration constructor in library.widgets) {
        if (constructor.name == fullName.widget) {
          return _cachedConstructors[fullName] =
              _ResolvedConstructor(fullName, constructor);
        }
      }
      for (final Import import in library.imports) {
        final LibraryName dependency = import.name;
        final _ResolvedConstructor? result = _findConstructor(
            FullyQualifiedWidgetName(dependency, fullName.widget));
        if (result != null) {
          // We cache the constructor under each name that we tried to look it up with, so
          // that next time it takes less time to find it.
          return _cachedConstructors[fullName] = result;
        }
      }
    } else if (library is LocalWidgetLibrary) {
      final LocalWidgetBuilder? constructor =
          library.findConstructor(fullName.widget);
      if (constructor != null) {
        return _cachedConstructors[fullName] =
            _ResolvedConstructor(fullName, constructor);
      }
    } else {
      assert(library == null);
    }
    _cachedConstructors[fullName] = null;
    return null;
  }

  Iterable<LibraryName> _findMissingLibraries(LibraryName library) sync* {
    final WidgetLibrary? root = _libraries[library];
    if (root == null) {
      yield library;
      return;
    }
    if (root is LocalWidgetLibrary) {
      return;
    }
    root as RemoteWidgetLibrary;
    for (final Import import in root.imports) {
      yield* _findMissingLibraries(import.name);
    }
  }

  /// Resolves `fullName` to a [_ResolvedConstructor], then binds its arguments
  /// to `arguments` (binding any [ArgsReference]s to [BoundArgsReference]s) and
  /// expands any references to [ConstructorCall]s so that all remaining widgets
  /// are [_CurriedWidget]s.
  ///
  /// Widgets can't reference each other recursively; this is enforced using the
  /// `usedWidgets` argument.
  ///
  /// The `source` argument is the [BlobNode] that referenced the widget
  /// constructor, in the event that the widget comes from a
  /// [LocalWidgetBuilder] rather than a [WidgetDeclaration], and is used to
  /// provide source information for local widgets (which otherwise could not be
  /// associated with a part of the source). See also [Runtime.blobNodeFor].
  _CurriedWidget _applyConstructorAndBindArguments(
    FullyQualifiedWidgetName fullName,
    DynamicMap arguments,
    DynamicMap widgetBuilderScope,
    int stateDepth,
    Set<FullyQualifiedWidgetName> usedWidgets,
    BlobNode? source,
  ) {
    final _ResolvedConstructor? component = _findConstructor(fullName);
    if (component != null) {
      if (component.constructor is WidgetDeclaration) {
        if (usedWidgets.contains(component.fullName)) {
          return _CurriedLocalWidget.error(
            fullName,
            'Component loop: Tried to call ${component.fullName} constructor reentrantly.',
          )..propagateSource(source);
        }
        usedWidgets = usedWidgets.toSet()..add(component.fullName);
        final constructor = component.constructor as WidgetDeclaration;
        final int newDepth;
        if (constructor.initialState != null) {
          newDepth = stateDepth + 1;
        } else {
          newDepth = stateDepth;
        }
        Object result = _bindArguments(
          component.fullName,
          constructor.root,
          arguments,
          widgetBuilderScope,
          newDepth,
          usedWidgets,
        );
        if (result is Switch) {
          result = _CurriedSwitch(
            component.fullName,
            result,
            arguments,
            widgetBuilderScope,
            constructor.initialState,
          )..propagateSource(result);
        } else {
          result as _CurriedWidget;
          if (constructor.initialState != null) {
            result = _CurriedRemoteWidget(
              component.fullName,
              result,
              arguments,
              widgetBuilderScope,
              constructor.initialState,
            )..propagateSource(result);
          }
        }
        return result as _CurriedWidget;
      }
      assert(component.constructor is LocalWidgetBuilder);
      return _CurriedLocalWidget(
        component.fullName,
        component.constructor as LocalWidgetBuilder,
        arguments,
        widgetBuilderScope,
      )..propagateSource(source);
    }
    final Set<LibraryName> missingLibraries =
        _findMissingLibraries(fullName.library).toSet();
    if (missingLibraries.isNotEmpty) {
      return _CurriedLocalWidget.error(
        fullName,
        'Could not find remote widget named ${fullName.widget} in ${fullName.library}, '
        'possibly because some dependencies were missing: ${missingLibraries.join(", ")}',
      )..propagateSource(source);
    }
    return _CurriedLocalWidget.error(fullName,
        'Could not find remote widget named ${fullName.widget} in ${fullName.library}.')
      ..propagateSource(source);
  }

  Object _bindArguments(
    FullyQualifiedWidgetName context,
    Object node,
    Object arguments,
    DynamicMap widgetBuilderScope,
    int stateDepth,
    Set<FullyQualifiedWidgetName> usedWidgets,
  ) {
    if (node is Component) {
      // An already-built host component injected via [buildNode] (e.g. a child
      // adapter). Wrap it so child/childList accept it; it is rendered as-is.
      return _CurriedHostWidget(node);
    }
    if (node is ConstructorCall) {
      final subArguments = _bindArguments(
        context,
        node.arguments,
        arguments,
        widgetBuilderScope,
        stateDepth,
        usedWidgets,
      ) as DynamicMap;
      // A `name(arg: …)` call parses as a [ConstructorCall] whether it builds a
      // widget or calls a function. Widgets win: only treat it as a function
      // when the name is registered *and* is not a widget in scope. The bound
      // argument nodes are resolved to values (and the function invoked) lazily,
      // at fetch time, in [_CurriedWidget._resolveFrom].
      final LocalFunction? function = _functions[node.name];
      if (function != null &&
          _findConstructor(
                  FullyQualifiedWidgetName(context.library, node.name)) ==
              null) {
        assert(() {
          _debugValidateFunctionArguments(node.name, function, subArguments);
          return true;
        }());
        return _FunctionCall(node.name, function.implementation, subArguments)
          ..propagateSource(node);
      }
      return _applyConstructorAndBindArguments(
        FullyQualifiedWidgetName(context.library, node.name),
        subArguments,
        widgetBuilderScope,
        stateDepth,
        usedWidgets,
        node,
      );
    }
    if (node is WidgetBuilderDeclaration) {
      return (DynamicMap widgetBuilderArg) {
        final newWidgetBuilderScope = <String, Object?>{
          ...widgetBuilderScope,
          node.argumentName: widgetBuilderArg,
        };
        final Object result = _bindArguments(
          context,
          node.widget,
          arguments,
          newWidgetBuilderScope,
          stateDepth,
          usedWidgets,
        );
        if (result is Switch) {
          return _CurriedSwitch(
            FullyQualifiedWidgetName(context.library, ''),
            result,
            arguments as DynamicMap,
            newWidgetBuilderScope,
            const <String, Object?>{},
          )..propagateSource(result);
        }
        return result as _CurriedWidget;
      };
    }
    if (node is DynamicMap) {
      return node.map<String, Object?>(
        (String name, Object? value) => MapEntry<String, Object?>(
          name,
          _bindArguments(context, value!, arguments, widgetBuilderScope,
              stateDepth, usedWidgets),
        ),
      );
    }
    if (node is DynamicList) {
      return List<Object>.generate(
        node.length,
        (int index) => _bindArguments(
          context,
          node[index]!,
          arguments,
          widgetBuilderScope,
          stateDepth,
          usedWidgets,
        ),
        growable: false,
      );
    }
    if (node is Loop) {
      final Object input = _bindArguments(context, node.input, arguments,
          widgetBuilderScope, stateDepth, usedWidgets);
      final Object output = _bindArguments(context, node.output, arguments,
          widgetBuilderScope, stateDepth, usedWidgets);
      return Loop(input, output)..propagateSource(node);
    }
    if (node is Switch) {
      return Switch(
        _bindArguments(context, node.input, arguments, widgetBuilderScope,
            stateDepth, usedWidgets),
        node.outputs.map<Object?, Object>(
          (Object? key, Object value) {
            return MapEntry<Object?, Object>(
              key == null
                  ? key
                  : _bindArguments(context, key, arguments, widgetBuilderScope,
                      stateDepth, usedWidgets),
              _bindArguments(context, value, arguments, widgetBuilderScope,
                  stateDepth, usedWidgets),
            );
          },
        ),
      )..propagateSource(node);
    }
    if (node is ArgsReference) {
      return node.bind(arguments)..propagateSource(node);
    }
    if (node is StateReference) {
      return node.bind(stateDepth)..propagateSource(node);
    }
    if (node is EventHandler) {
      return EventHandler(
        node.eventName,
        _bindArguments(
          context,
          node.eventArguments,
          arguments,
          widgetBuilderScope,
          stateDepth,
          usedWidgets,
        ) as DynamicMap,
      )..propagateSource(node);
    }
    if (node is SetStateHandler) {
      assert(node.stateReference is StateReference);
      final BoundStateReference stateReference =
          (node.stateReference as StateReference).bind(stateDepth);
      return SetStateHandler(
        stateReference,
        _bindArguments(context, node.value, arguments, widgetBuilderScope,
            stateDepth, usedWidgets),
      )..propagateSource(node);
    }
    assert(node is! WidgetDeclaration);
    return node;
  }

  /// Debug-only validation of a function call's *bound* arguments against its
  /// schema. Throws a [RemoteFlutterWidgetsException] describing the first
  /// problem: an unknown argument name, a missing required argument, or a
  /// **literal** argument of the wrong type.
  ///
  /// Only literal values are type-checked. A bound argument (any [BlobNode] —
  /// e.g. `data.x`, `state.y`, `args.z`, or a nested call) resolves at runtime,
  /// possibly from agent-controlled data, so enforcing its type here would both
  /// be impossible (the value isn't known yet) and wrong (untrusted data must
  /// degrade via totality, not crash). This catches the author's mistakes while
  /// leaving the trust boundary intact. Compiled out in release builds.
  void _debugValidateFunctionArguments(
    String name,
    LocalFunction function,
    DynamicMap boundArguments,
  ) {
    for (final String argName in boundArguments.keys) {
      if (!function.arguments.containsKey(argName)) {
        throw RemoteFlutterWidgetsException(
            'Function "$name" does not accept an argument named "$argName". '
            'Accepted: ${function.arguments.keys.join(", ")}.');
      }
    }
    for (final MapEntry<String, FunctionArgType> arg
        in function.arguments.entries) {
      if (!boundArguments.containsKey(arg.key)) {
        throw RemoteFlutterWidgetsException(
            'Function "$name" is missing required argument "${arg.key}".');
      }
      final Object? value = boundArguments[arg.key];
      if (value is! BlobNode && !arg.value.accepts(value)) {
        throw RemoteFlutterWidgetsException(
            'Function "$name" argument "${arg.key}" expects ${arg.value.label}, '
            'but got ${value.runtimeType} ($value).');
      }
    }
  }
}

// Internal structure to represent the result of indexing into a list.
//
// There are two ways this can go: either we index in and find a result, in
// which case [result] is that value and the other fields are null, or we fail
// to index into the list and we obtain the length as a side-effect, in which
// case [result] is null, [rawList] is the raw list (might contain [Loop] objects),
// and [length] is the effective length after expanding all the internal loops.
class _ResolvedDynamicList {
  const _ResolvedDynamicList(this.rawList, this.result, this.length);
  final DynamicList? rawList;
  final Object? result; // null means out of range
  final int? length; // might be null if result is not null
}

typedef _DataResolverCallback = Object Function(List<Object> dataKey);
typedef _StateResolverCallback = Object Function(
    List<Object> stateKey, int depth);
typedef _WidgetBuilderArgResolverCallback = Object Function(
    List<Object> argKey);

/// A bound call to a registered [LocalFunction] sitting in a value position.
///
/// Produced by [Runtime._bindArguments] when a `name(arg: …)` call resolves to a
/// registered function rather than a widget. [arguments] holds the still-bound
/// argument nodes (references to args/state/data, or nested [_FunctionCall]s);
/// [_CurriedWidget._resolveFrom] resolves them to concrete values via
/// [_CurriedWidget._fix] and then invokes [function], substituting its (total)
/// result. Resolving through the normal resolvers is what keeps a call reactive
/// — e.g. `add(a: state.count, b: 1)` re-runs when `state.count` changes.
class _FunctionCall extends BlobNode {
  _FunctionCall(this.name, this.function, this.arguments);

  final String name;
  final LocalFunctionImplementation function;
  final DynamicMap arguments;

  @override
  String toString() => '$name($arguments)';
}

abstract class _CurriedWidget extends BlobNode {
  const _CurriedWidget(
    this.fullName,
    this.arguments,
    this.widgetBuilderScope,
    this.initialState,
  );

  final FullyQualifiedWidgetName fullName;
  final DynamicMap arguments;
  final DynamicMap widgetBuilderScope;
  final DynamicMap? initialState;

  static Object _bindLoopVariable(Object node, Object argument, int depth) {
    if (node is DynamicMap) {
      return node.map<String, Object?>(
        (String name, Object? value) => MapEntry<String, Object?>(
            name, _bindLoopVariable(value!, argument, depth)),
      );
    }
    if (node is DynamicList) {
      return List<Object>.generate(
        node.length,
        (int index) => _bindLoopVariable(node[index]!, argument, depth),
        growable: false,
      );
    }
    if (node is Loop) {
      return Loop(_bindLoopVariable(node.input, argument, depth),
          _bindLoopVariable(node.output, argument, depth + 1))
        ..propagateSource(node);
    }
    if (node is Switch) {
      return Switch(
          _bindLoopVariable(node.input, argument, depth),
          node.outputs.map<Object?, Object>(
            (Object? key, Object value) => MapEntry<Object?, Object>(
              key == null ? null : _bindLoopVariable(key, argument, depth),
              _bindLoopVariable(value, argument, depth),
            ),
          ))
        ..propagateSource(node);
    }
    if (node is _CurriedLocalWidget) {
      return _CurriedLocalWidget(
        node.fullName,
        node.child,
        _bindLoopVariable(node.arguments, argument, depth) as DynamicMap,
        _bindLoopVariable(node.widgetBuilderScope, argument, depth)
            as DynamicMap,
      )..propagateSource(node);
    }
    if (node is _CurriedRemoteWidget) {
      return _CurriedRemoteWidget(
        node.fullName,
        _bindLoopVariable(node.child, argument, depth) as _CurriedWidget,
        _bindLoopVariable(node.arguments, argument, depth) as DynamicMap,
        _bindLoopVariable(node.widgetBuilderScope, argument, depth)
            as DynamicMap,
        node.initialState,
      )..propagateSource(node);
    }
    if (node is _CurriedSwitch) {
      return _CurriedSwitch(
        node.fullName,
        _bindLoopVariable(node.root, argument, depth) as Switch,
        _bindLoopVariable(node.arguments, argument, depth) as DynamicMap,
        _bindLoopVariable(node.widgetBuilderScope, argument, depth)
            as DynamicMap,
        node.initialState,
      )..propagateSource(node);
    }
    if (node is LoopReference) {
      if (node.loop == depth) {
        return node.bind(argument)..propagateSource(node);
      }
      return node;
    }
    if (node is BoundArgsReference) {
      return BoundArgsReference(
          _bindLoopVariable(node.arguments, argument, depth), node.parts)
        ..propagateSource(node);
    }
    if (node is EventHandler) {
      return EventHandler(node.eventName,
          _bindLoopVariable(node.eventArguments, argument, depth) as DynamicMap)
        ..propagateSource(node);
    }
    if (node is SetStateHandler) {
      return SetStateHandler(
          node.stateReference, _bindLoopVariable(node.value, argument, depth))
        ..propagateSource(node);
    }
    if (node is _FunctionCall) {
      return _FunctionCall(
        node.name,
        node.function,
        _bindLoopVariable(node.arguments, argument, depth) as DynamicMap,
      )..propagateSource(node);
    }
    return node;
  }

  /// Look up the _index_th entry in `list`, expanding any loops in `list`.
  ///
  /// If `targetEffectiveIndex` is -1, this evaluates the entire list to ensure
  /// the length is available.
  //
  // TODO(ianh): This really should have some sort of caching. Right now, evaluating a whole list
  // ends up being around O(N^2) since we have to walk the list from the start for every entry.
  static _ResolvedDynamicList _listLookup(
    DynamicList list,
    int targetEffectiveIndex,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  ) {
    var currentIndex =
        0; // where we are in `list` (some entries of which might represent multiple values, because they are themselves loops)
    var effectiveIndex =
        0; // where we are in the fully expanded list (the coordinate space in which we're aiming for `targetEffectiveIndex`)
    while (
        (effectiveIndex <= targetEffectiveIndex || targetEffectiveIndex < 0) &&
            currentIndex < list.length) {
      final Object node = list[currentIndex]!;
      if (node is Loop) {
        Object inputList = node.input;
        while (inputList is! DynamicList) {
          if (inputList is BoundArgsReference) {
            inputList = _resolveFrom(
              inputList.arguments,
              inputList.parts,
              stateResolver,
              dataResolver,
              widgetBuilderArgResolver,
            );
          } else if (inputList is DataReference) {
            inputList = dataResolver(inputList.parts);
          } else if (inputList is ThemeReference) {
            inputList =
                dataResolver(<Object>[_themeMarker, ...inputList.parts]);
          } else if (inputList is MediaReference) {
            inputList =
                dataResolver(<Object>[_mediaMarker, ...inputList.parts]);
          } else if (inputList is WidgetBuilderArgReference) {
            inputList = widgetBuilderArgResolver(
              <Object>[inputList.argumentName, ...inputList.parts],
            );
          } else if (inputList is BoundStateReference) {
            inputList = stateResolver(inputList.parts, inputList.depth);
          } else if (inputList is BoundLoopReference) {
            inputList = _resolveFrom(
              inputList.value,
              inputList.parts,
              stateResolver,
              dataResolver,
              widgetBuilderArgResolver,
            );
          } else if (inputList is Switch) {
            inputList = _resolveFrom(
              inputList,
              const <Object>[],
              stateResolver,
              dataResolver,
              widgetBuilderArgResolver,
            );
          } else {
            // e.g. it's a map or something else that isn't indexable
            inputList = DynamicList.empty();
          }
          assert(inputList is! _ResolvedDynamicList);
        }
        final _ResolvedDynamicList entry = _listLookup(
          inputList,
          targetEffectiveIndex >= 0
              ? targetEffectiveIndex - effectiveIndex
              : -1,
          stateResolver,
          dataResolver,
          widgetBuilderArgResolver,
        );
        if (entry.result != null) {
          final Object boundResult =
              _bindLoopVariable(node.output, entry.result!, 0);
          return _ResolvedDynamicList(null, boundResult, null);
        }
        effectiveIndex += entry.length!;
      } else {
        // list[currentIndex] is not a Loop
        if (effectiveIndex == targetEffectiveIndex) {
          return _ResolvedDynamicList(null, list[currentIndex], null);
        }
        effectiveIndex += 1;
      }
      currentIndex += 1;
    }
    return _ResolvedDynamicList(list, null, effectiveIndex);
  }

  static Object _resolveFrom(
    Object root,
    List<Object> parts,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  ) {
    var index = 0;
    var current = root;
    while (true) {
      if (current is DataReference) {
        if (index < parts.length) {
          current = current.constructReference(parts.sublist(index));
          index = parts.length;
        }
        current = dataResolver(current.parts);
        continue;
      } else if (current is ThemeReference) {
        if (index < parts.length) {
          current = current.constructReference(parts.sublist(index));
          index = parts.length;
        }
        // Theme lookups ride the data-resolver callback, marked with the
        // non-string _themeMarker so _dataResolver can route them to the theme
        // content. The marker type cannot appear in transport data (JSON keys
        // are strings), so the two trust domains cannot be confused.
        current = dataResolver(<Object>[_themeMarker, ...current.parts]);
        continue;
      } else if (current is MediaReference) {
        if (index < parts.length) {
          current = current.constructReference(parts.sublist(index));
          index = parts.length;
        }
        // Media lookups ride the data-resolver callback with the _mediaMarker,
        // exactly like the theme (see above).
        current = dataResolver(<Object>[_mediaMarker, ...current.parts]);
        continue;
      } else if (current is WidgetBuilderArgReference) {
        current = widgetBuilderArgResolver(
            <Object>[current.argumentName, ...current.parts]);
        continue;
      } else if (current is BoundArgsReference) {
        List<Object> nextParts = current.parts;
        if (index < parts.length) {
          nextParts += parts.sublist(index);
        }
        parts = nextParts;
        current = current.arguments;
        index = 0;
        continue;
      } else if (current is BoundStateReference) {
        if (index < parts.length) {
          current = current.constructReference(parts.sublist(index));
          index = parts.length;
        }
        current = stateResolver(current.parts, current.depth);
        continue;
      } else if (current is BoundLoopReference) {
        List<Object> nextParts = current.parts;
        if (index < parts.length) {
          nextParts += parts.sublist(index);
        }
        parts = nextParts;
        current = current.value;
        index = 0;
        continue;
      } else if (current is Switch) {
        final Object key = _resolveFrom(
          current.input,
          const <Object>[],
          stateResolver,
          dataResolver,
          widgetBuilderArgResolver,
        );
        Object? value = current.outputs[key];
        if (value == null) {
          value = current.outputs[null];
          if (value == null) {
            return missing;
          }
        }
        current = value;
        continue;
      } else if (current is _FunctionCall) {
        // Resolve the call's arguments to concrete values (recursing through
        // these same resolvers, so nested calls and any state/data references
        // are evaluated and subscribed to), then invoke the function. A total
        // function returns null for bad input, which resolves to `missing`.
        final DynamicMap resolvedArguments = _fix(
          current.arguments,
          stateResolver,
          dataResolver,
          widgetBuilderArgResolver,
        ) as DynamicMap;
        current = current.function(resolvedArguments) ?? missing;
        continue;
      } else if (index >= parts.length) {
        // We've reached the end of the line.
        // We handle some special leaf cases that still need processing before we return.
        if (current is EventHandler) {
          current = EventHandler(
            current.eventName,
            _fix(current.eventArguments, stateResolver, dataResolver,
                widgetBuilderArgResolver) as DynamicMap,
          );
        } else if (current is SetStateHandler) {
          current = SetStateHandler(
            current.stateReference,
            _fix(current.value, stateResolver, dataResolver,
                widgetBuilderArgResolver),
          );
        }
        // else `current` is nothing special, and we'll just return it below.
        break; // This is where the loop ends.
      } else if (current is DynamicMap) {
        if (parts[index] is! String) {
          return missing;
        }
        if (!current.containsKey(parts[index])) {
          return missing;
        }
        current = current[parts[index]]!;
      } else if (current is DynamicList) {
        if (parts[index] is! int) {
          return missing;
        }
        current = _listLookup(
              current,
              parts[index] as int,
              stateResolver,
              dataResolver,
              widgetBuilderArgResolver,
            ).result ??
            missing;
      } else {
        assert(current is! ArgsReference);
        assert(current is! StateReference);
        assert(current is! LoopReference);
        return missing;
      }
      index += 1;
    }
    assert(current is! Reference,
        'Unexpected unbound reference (of type ${current.runtimeType}): $current');
    assert(current is! Switch);
    assert(current is! Loop);
    return current;
  }

  static Object _fix(
    Object root,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  ) {
    if (root is DynamicMap) {
      return root.map(
        (String key, Object? value) => MapEntry<String, Object?>(
          key,
          _fix(root[key]!, stateResolver, dataResolver,
              widgetBuilderArgResolver),
        ),
      );
    } else if (root is DynamicList) {
      if (root.any((Object? entry) => entry is Loop)) {
        final int length = _listLookup(
          root,
          -1,
          stateResolver,
          dataResolver,
          widgetBuilderArgResolver,
        ).length!;
        return DynamicList.generate(
          length,
          (int index) => _fix(
            _listLookup(root, index, stateResolver, dataResolver,
                    widgetBuilderArgResolver)
                .result!,
            stateResolver,
            dataResolver,
            widgetBuilderArgResolver,
          ),
        );
      } else {
        return DynamicList.generate(
          root.length,
          (int index) => _fix(root[index]!, stateResolver, dataResolver,
              widgetBuilderArgResolver),
        );
      }
    } else if (root is BlobNode) {
      return _resolveFrom(root, const <Object>[], stateResolver, dataResolver,
          widgetBuilderArgResolver);
    } else {
      return root;
    }
  }

  Object resolve(
    List<Object> parts,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver, {
    required bool expandLists,
  }) {
    Object result = _resolveFrom(arguments, parts, stateResolver, dataResolver,
        widgetBuilderArgResolver);
    if (result is DynamicList && expandLists) {
      result = _listLookup(
          result, -1, stateResolver, dataResolver, widgetBuilderArgResolver);
    }
    assert(result is! Reference);
    assert(result is! Switch);
    assert(result is! Loop);
    return result;
  }

  Component build(
    BuildContext context,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget,
    List<_WidgetState> states,
  ) {
    return _Widget(
      // Lift a reserved literal `key` argument onto the reconciliation unit so
      // host reconciliation matches this subtree by identity (e.g. an A2UI id),
      // not by position. See DESIGN.md §6.
      key: _liftKey(arguments['key']),
      curriedWidget: this,
      data: data,
      widgetBuilderScope: DynamicContent(widgetBuilderScope),
      remoteEventTarget: remoteEventTarget,
      states: states,
    );
  }

  Component buildChild(
    BuildContext context,
    DataSource source,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget,
    List<_WidgetState> states,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  );

  @override
  String toString() => '$fullName ${initialState ?? "{}"} $arguments';
}

/// The attribute stamped on every core-primitive DOM element, naming the widget
/// that produced it (e.g. `data-craft="Column"`), so the rendered HTML is
/// legible when debugging — a `<div>` reads as a `Box`, `Row`, or `Column` at a
/// glance. A `data-*` attribute is used rather than `is` (which is reserved for
/// customized built-in elements) so it is a pure, side-effect-free marker.
const String kCraftWidgetAttribute = 'data-craft';

/// Returns [built] wrapped so [kCraftWidgetAttribute] naming [widget] is merged
/// onto its root element.
///
/// Applied centrally by the runtime at the one point a primitive's builder is
/// invoked, so no primitive annotates itself and only its root element is
/// stamped (composite template widgets expand to primitives and own no element).
/// [Component.wrapElement] merges the attribute onto the child's element without
/// adding a DOM node of its own — so it works for whatever element a primitive
/// returns (`<div>`, `<input>`, `<button>`, …) and never perturbs layout.
Component _annotateCraftWidget(String widget, Component built) {
  return Component.wrapElement(
    attributes: <String, String>{kCraftWidgetAttribute: widget},
    child: built,
  );
}

class _CurriedLocalWidget extends _CurriedWidget {
  const _CurriedLocalWidget(
    FullyQualifiedWidgetName fullName,
    this.child,
    DynamicMap arguments,
    DynamicMap widgetBuilderScope,
  ) : super(fullName, arguments, widgetBuilderScope, null);

  factory _CurriedLocalWidget.error(
      FullyQualifiedWidgetName fullName, String message) {
    return _CurriedLocalWidget(
      fullName,
      (BuildContext context, DataSource data) => _buildErrorWidget(message),
      const <String, Object?>{},
      const <String, Object?>{},
    );
  }

  final LocalWidgetBuilder child;

  @override
  Component buildChild(
    BuildContext context,
    DataSource source,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget,
    List<_WidgetState> states,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  ) {
    return _annotateCraftWidget(fullName.widget, child(context, source));
  }
}

/// Synthetic name used for host components injected via [Runtime.buildNode].
const FullyQualifiedWidgetName _hostWidgetName = FullyQualifiedWidgetName(
  LibraryName(<String>['<host>']),
  '<host>',
);

/// Wraps an already-built host [Component] injected via [Runtime.buildNode] (e.g.
/// a child adapter) so that `child`/`childList` accept it.
///
/// Its [build] returns the host component **directly** — with no [_Widget]
/// wrapper — so the host component sits at the reconciliation position and keeps
/// its own key. This is the transparent-injection half of the keyed-reconciliation
/// story (the other half is the lifted `_Widget.key` for RFW-curried widgets).
/// See DESIGN.md §6.
class _CurriedHostWidget extends _CurriedWidget {
  _CurriedHostWidget(this.hostWidget)
      : super(
          _hostWidgetName,
          const <String, Object?>{},
          const <String, Object?>{},
          null,
        );

  final Component hostWidget;

  @override
  Component build(
    BuildContext context,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget,
    List<_WidgetState> states,
  ) {
    return hostWidget;
  }

  @override
  Component buildChild(
    BuildContext context,
    DataSource source,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget,
    List<_WidgetState> states,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  ) {
    return hostWidget;
  }
}

class _CurriedRemoteWidget extends _CurriedWidget {
  const _CurriedRemoteWidget(
    FullyQualifiedWidgetName fullName,
    this.child,
    DynamicMap arguments,
    DynamicMap widgetBuilderScope,
    DynamicMap? initialState,
  ) : super(fullName, arguments, widgetBuilderScope, initialState);

  final _CurriedWidget child;

  @override
  Component buildChild(
    BuildContext context,
    DataSource source,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget,
    List<_WidgetState> states,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  ) {
    return child.build(context, data, remoteEventTarget, states);
  }

  @override
  String toString() => '${super.toString()} = $child';
}

class _CurriedSwitch extends _CurriedWidget {
  const _CurriedSwitch(
    FullyQualifiedWidgetName fullName,
    this.root,
    DynamicMap arguments,
    DynamicMap widgetBuilderScope,
    DynamicMap? initialState,
  ) : super(fullName, arguments, widgetBuilderScope, initialState);

  final Switch root;

  @override
  Component buildChild(
    BuildContext context,
    DataSource source,
    DynamicContent data,
    RemoteEventHandler remoteEventTarget,
    List<_WidgetState> states,
    _StateResolverCallback stateResolver,
    _DataResolverCallback dataResolver,
    _WidgetBuilderArgResolverCallback widgetBuilderArgResolver,
  ) {
    final Object resolvedWidget = _CurriedWidget._resolveFrom(
      root,
      const <Object>[],
      stateResolver,
      dataResolver,
      widgetBuilderArgResolver,
    );
    if (resolvedWidget is _CurriedWidget) {
      return resolvedWidget.build(context, data, remoteEventTarget, states);
    }
    return _buildErrorWidget(
        'Switch in $fullName did not resolve to a widget (got $resolvedWidget).');
  }

  @override
  String toString() => '${super.toString()} = $root';
}

/// Lifts a reserved, literal `key` argument to a host [Key] so a remote widget
/// subtree reconciles by identity rather than position. Non-literal values (such
/// as references, which only occur inside loops) yield null. See DESIGN.md §6.
Key? _liftKey(Object? value) {
  return switch (value) {
    final String v => ValueKey<String>(v),
    final int v => ValueKey<int>(v),
    final double v => ValueKey<double>(v),
    final bool v => ValueKey<bool>(v),
    _ => null,
  };
}

class _Widget extends StatefulComponent {
  const _Widget({
    super.key,
    required this.curriedWidget,
    required this.data,
    required this.widgetBuilderScope,
    required this.remoteEventTarget,
    required this.states,
  });

  final _CurriedWidget curriedWidget;

  final DynamicContent data;

  final DynamicContent widgetBuilderScope;

  final RemoteEventHandler remoteEventTarget;

  final List<_WidgetState> states;

  @override
  State<_Widget> createState() => _WidgetState();
}

class _WidgetState extends State<_Widget> implements DataSource {
  DynamicContent? _state;
  DynamicMap? _stateStore;
  late List<_WidgetState> _states;

  @override
  void initState() {
    super.initState();
    _updateState();
  }

  @override
  void didUpdateComponent(_Widget oldWidget) {
    super.didUpdateComponent(oldWidget);
    if (oldWidget.curriedWidget != component.curriedWidget) {
      _updateState();
    }
    if (oldWidget.data != component.data ||
        oldWidget.curriedWidget != component.curriedWidget ||
        oldWidget.states != component.states) {
      _unsubscribe();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The ambient theme instance changed (_ThemeScope, subscribed to via
    // _theme); drop subscriptions so lookups re-subscribe into the new one.
    _unsubscribe();
  }

  @override
  void dispose() {
    _unsubscribe();
    super.dispose();
  }

  void _updateState() {
    _stateStore =
        deepClone(component.curriedWidget.initialState) as DynamicMap?;
    if (_stateStore != null) {
      _state ??= DynamicContent();
      _state!.updateAll(_stateStore!);
    } else {
      _state = null;
    }
    _states = component.states;
    if (_state != null) {
      _states = _states.toList()..add(this);
    }
  }

  void _handleSetState(int depth, List<Object> parts, Object value) {
    _states[depth].applySetState(parts, value);
  }

  void applySetState(List<Object> parts, Object value) {
    assert(parts.isNotEmpty);
    assert(_stateStore != null);
    var index = 0;
    Object current = _stateStore!;
    while (index < parts.length) {
      final Object subindex = parts[index];
      if (current is DynamicMap) {
        if (subindex is! String) {
          throw RemoteFlutterWidgetsException(
              '${parts.join(".")} does not identify existing state.');
        }
        if (!current.containsKey(subindex)) {
          throw RemoteFlutterWidgetsException(
              '${parts.join(".")} does not identify existing state.');
        }
        if (index == parts.length - 1) {
          current[subindex] = value;
        } else {
          current = current[parts[index]]!;
        }
      } else if (current is DynamicList) {
        if (subindex is! int) {
          throw RemoteFlutterWidgetsException(
              '${parts.join(".")} does not identify existing state.');
        }
        if (subindex < 0 || subindex >= current.length) {
          throw RemoteFlutterWidgetsException(
              '${parts.join(".")} does not identify existing state.');
        }
        if (index == parts.length - 1) {
          current[subindex] = value;
        } else {
          current = current[subindex]!;
        }
      } else {
        throw RemoteFlutterWidgetsException(
            '${parts.join(".")} does not identify existing state.');
      }
      index += 1;
    }
    _state!.updateAll(_stateStore!);
  }

  // List of subscriptions into [component.data].
  //
  // Keys are into the [DynamicContent] object.
  final Map<_Key, _Subscription> _subscriptions = <_Key, _Subscription>{};

  void _unsubscribe() {
    for (final _Subscription value in _subscriptions.values) {
      value.dispose();
    }
    _subscriptions.clear();
    _argsCache.clear();
  }

  @override
  T? v<T extends Object>(List<Object> argsKey) {
    assert(T == int || T == double || T == bool || T == String);
    final Object value = _fetch(argsKey, expandLists: false);
    return value is T ? value : null;
  }

  @override
  bool isList(List<Object> argsKey) {
    final Object value = _fetch(argsKey, expandLists: false);
    return value is _ResolvedDynamicList || value is DynamicList;
  }

  @override
  int length(List<Object> argsKey) {
    final Object value = _fetch(argsKey, expandLists: true);
    if (value is _ResolvedDynamicList) {
      if (value.rawList != null) {
        assert(value.length != null);
        return value.length!;
      }
    }
    assert(value is! DynamicList);
    return 0;
  }

  @override
  bool isMap(List<Object> argsKey) {
    final Object value = _fetch(argsKey, expandLists: false);
    return value is DynamicMap;
  }

  @override
  Component child(List<Object> argsKey) {
    final Object value = _fetch(argsKey, expandLists: false);
    if (value is _CurriedWidget) {
      return value.build(context, component.data, component.remoteEventTarget,
          component.states);
    }
    return _buildErrorWidget(
        'Not a widget at $argsKey (got $value) for ${component.curriedWidget.fullName}.');
  }

  @override
  Component? optionalChild(List<Object> argsKey) {
    final Object value = _fetch(argsKey, expandLists: false);
    if (value is _CurriedWidget) {
      return value.build(context, component.data, component.remoteEventTarget,
          component.states);
    }
    return null;
  }

  @override
  List<Component> childList(List<Object> argsKey) {
    final Object value = _fetch(argsKey, expandLists: true);
    if (value is _ResolvedDynamicList) {
      assert(value.length != null);
      final DynamicList fullList = _fetchList(argsKey, value.length!);
      return List<Component>.generate(
        fullList.length,
        (int index) {
          final Object? node = fullList[index];
          if (node is _CurriedWidget) {
            return node.build(
                context, component.data, component.remoteEventTarget, _states);
          }
          return _buildErrorWidget(
              'Not a widget at $argsKey (got $node) for ${component.curriedWidget.fullName}.');
        },
      );
    }
    if (value == missing) {
      return const <Component>[];
    }
    return <Component>[
      _buildErrorWidget(
          'Not a widget list at $argsKey (got $value) for ${component.curriedWidget.fullName}.'),
    ];
  }

  @override
  Component builder(List<Object> argsKey, DynamicMap builderArg) {
    return _fetchBuilder(argsKey, builderArg, optional: false)!;
  }

  @override
  Component? optionalBuilder(List<Object> argsKey, DynamicMap builderArg) {
    return _fetchBuilder(argsKey, builderArg);
  }

  Component? _fetchBuilder(
    List<Object> argsKey,
    DynamicMap builderArg, {
    bool optional = true,
  }) {
    final Object value = _fetch(argsKey, expandLists: false);
    if (value is _RemoteWidgetBuilder) {
      final _CurriedWidget curriedWidget = value(builderArg);
      return curriedWidget.build(
        context,
        component.data,
        component.remoteEventTarget,
        component.states,
      );
    }
    return optional
        ? null
        : _buildErrorWidget(
            'Not a builder at $argsKey (got $value) for ${component.curriedWidget.fullName}.');
  }

  @override
  VoidCallback? voidHandler(List<Object> argsKey,
      [DynamicMap? extraArguments]) {
    return handler<VoidCallback>(
        argsKey, (HandlerTrigger callback) => () => callback(extraArguments));
  }

  @override
  T? handler<T extends Function>(
      List<Object> argsKey, HandlerGenerator<T> generator) {
    Object value = _fetch(argsKey, expandLists: true);
    // a2ui_core seam: an already-resolved Dart callback supplied directly as an
    // argument value (e.g. an action callback produced by a2ui_core's
    // GenericBinder). RFW's own parsed args never carry bare Dart functions, so
    // this is additive — it only matches host-supplied callbacks, returned as-is.
    if (value is T) {
      return value;
    }
    if (value is AnyEventHandler) {
      value = <Object>[value];
    } else if (value is _ResolvedDynamicList) {
      value = _fetchList(argsKey, value.length!);
    }
    if (value is DynamicList) {
      final List<AnyEventHandler> handlers =
          value.whereType<AnyEventHandler>().toList();
      if (handlers.isNotEmpty) {
        return generator(([DynamicMap? extraArguments]) {
          for (final entry in handlers) {
            if (entry is EventHandler) {
              DynamicMap arguments = entry.eventArguments;
              if (extraArguments != null) {
                arguments = DynamicMap.fromEntries(
                    arguments.entries.followedBy(extraArguments.entries));
              }
              component.remoteEventTarget(entry.eventName, arguments);
            } else if (entry is SetStateHandler) {
              assert(entry.stateReference is BoundStateReference);
              _handleSetState(
                  (entry.stateReference as BoundStateReference).depth,
                  entry.stateReference.parts,
                  entry.value);
            }
          }
        });
      }
    }
    return null;
  }

  // null values means the data is not in the cache
  final Map<_Key, Object?> _argsCache = <_Key, Object?>{};

  bool _debugFetching = false;
  final List<_Subscription> _dependencies = <_Subscription>[];

  Object _fetch(List<Object> argsKey, {required bool expandLists}) {
    final key = _Key(_kArgsSection, argsKey);
    final Object? value = _argsCache[key];
    if (value != null && (value is! DynamicList || !expandLists)) {
      return value;
    }
    assert(!_debugFetching);
    try {
      _debugFetching = true;
      final Object result = component.curriedWidget.resolve(
        argsKey,
        _stateResolver,
        _dataResolver,
        _widgetBuilderArgResolver,
        expandLists: expandLists,
      );
      for (final _Subscription subscription in _dependencies) {
        subscription.addClient(key);
      }
      _argsCache[key] = result;
      return result;
    } finally {
      _dependencies.clear();
      _debugFetching = false;
    }
  }

  DynamicList _fetchList(List<Object> argsKey, int length) {
    return DynamicList.generate(length, (int index) {
      return _fetch(<Object>[...argsKey, index], expandLists: false);
    });
  }

  Object _dataResolver(List<Object> rawDataKey) {
    // A theme lookup routed through this callback (see _themeMarker): the same
    // subscription machinery, but into the ambient theme content — a different
    // object in a different trust domain (author/host, never the transport).
    if (rawDataKey.isNotEmpty && identical(rawDataKey.first, _themeMarker)) {
      final List<Object> themeKey = rawDataKey.sublist(1);
      final themeSubscriptionKey = _Key(_kThemeSection, themeKey);
      final _Subscription subscription =
          _subscriptions[themeSubscriptionKey] ??=
              _Subscription(_theme, this, themeKey);
      _dependencies.add(subscription);
      return subscription.value;
    }
    // A media lookup, marked with _mediaMarker (see [MediaReference]): the same
    // subscription machinery into the ambient [MediaContext]'s content — a third
    // trust domain (host render-time config), like the theme.
    if (rawDataKey.isNotEmpty && identical(rawDataKey.first, _mediaMarker)) {
      final List<Object> mediaKey = rawDataKey.sublist(1);
      final mediaSubscriptionKey = _Key(_kMediaSection, mediaKey);
      final _Subscription subscription =
          _subscriptions[mediaSubscriptionKey] ??=
              _Subscription(_media, this, mediaKey);
      _dependencies.add(subscription);
      return subscription.value;
    }
    final dataKey = _Key(_kDataSection, rawDataKey);
    final _Subscription subscription;
    if (!_subscriptions.containsKey(dataKey)) {
      subscription = _Subscription(component.data, this, rawDataKey);
      _subscriptions[dataKey] = subscription;
    } else {
      subscription = _subscriptions[dataKey]!;
    }
    _dependencies.add(subscription);
    return subscription.value;
  }

  /// The ambient theme's template-facing content, from the nearest
  /// [_ThemeScope]; a shared empty content when the surface has no theme
  /// (every lookup resolves as missing, so consumers fall back to host
  /// defaults).
  DynamicContent get _theme =>
      ambientCraftTheme(context)?.content ?? _emptyTheme;
  static final DynamicContent _emptyTheme = DynamicContent();

  /// The ambient [MediaContext]'s template-facing content, from the nearest
  /// [_MediaScope]; a shared empty content when the surface has no media (every
  /// `media.` lookup then resolves as missing, so a `switch` falls to its
  /// default). Read once per subscription; a new snapshot triggers
  /// [didChangeDependencies] → [_unsubscribe], re-subscribing into the new one.
  DynamicContent get _media =>
      ambientMediaContext(context)?.toContent() ?? _emptyMedia;
  static final DynamicContent _emptyMedia = DynamicContent();

  Object _widgetBuilderArgResolver(List<Object> rawDataKey) {
    final widgetBuilderArgKey = _Key(_kWidgetBuilderArgSection, rawDataKey);
    final _Subscription subscription =
        _subscriptions[widgetBuilderArgKey] ??= _Subscription(
      component.widgetBuilderScope,
      this,
      rawDataKey,
    );
    _dependencies.add(subscription);
    return subscription.value;
  }

  Object _stateResolver(List<Object> rawStateKey, int depth) {
    final stateKey = _Key(depth, rawStateKey);
    final _Subscription subscription;
    if (!_subscriptions.containsKey(stateKey)) {
      if (depth >= _states.length) {
        throw const RemoteFlutterWidgetsException(
            'Reference to state value did not correspond to any stateful remote component.');
      }
      final DynamicContent? state = _states[depth]._state;
      if (state == null) {
        return missing;
      }
      subscription = _Subscription(state, this, rawStateKey);
      _subscriptions[stateKey] = subscription;
    } else {
      subscription = _subscriptions[stateKey]!;
    }
    _dependencies.add(subscription);
    return subscription.value;
  }

  void updateData(Set<_Key> affectedArgs) {
    setState(() {
      for (final key in affectedArgs) {
        _argsCache[key] = null;
      }
    });
  }

  @override
  Component build(BuildContext context) {
    // TODO(ianh): what if this creates some _dependencies?
    return component.curriedWidget.buildChild(
      context,
      this,
      component.data,
      component.remoteEventTarget,
      _states,
      _stateResolver,
      _dataResolver,
      _widgetBuilderArgResolver,
    );
  }
}

const int _kDataSection = -1;
const int _kArgsSection = -2;
const int _kWidgetBuilderArgSection = -3;
const int _kThemeSection = -4;
const int _kMediaSection = -5;

/// The marker prepended to a key routed through the data-resolver callback to
/// address the ambient theme rather than [DynamicContent] data (see
/// [_WidgetState._dataResolver]). A private non-string type: transport data is
/// JSON (string keys only), so no message can ever produce this marker.
class _ThemeMarker {
  const _ThemeMarker();
}

const Object _themeMarker = _ThemeMarker();

/// The marker prepended to a key routed through the data-resolver callback to
/// address the ambient [MediaContext] rather than [DynamicContent] data, mirroring
/// [_themeMarker]. A private non-string type, so no JSON transport key can forge it.
class _MediaMarker {
  const _MediaMarker();
}

const Object _mediaMarker = _MediaMarker();

/// Supplies the ambient [CraftTheme] to every remote component below it — both
/// the `theme.` reference scope (via [CraftTheme.content]) and the primitives'
/// role defaults (via [ambientCraftTheme]). Installed by [Runtime.build] /
/// [Runtime.buildNode] when a theme is provided.
///
/// The theme is an immutable snapshot; a host re-themes by providing a new
/// one, which notifies dependents here.
class _ThemeScope extends InheritedComponent {
  const _ThemeScope({required this.theme, required super.child});

  final CraftTheme theme;

  @override
  bool updateShouldNotify(_ThemeScope oldComponent) =>
      theme != oldComponent.theme;
}

/// The ambient [CraftTheme] installed by [Runtime.build] / [Runtime.buildNode],
/// or null when the surface is unthemed.
///
/// This is how the core primitives read their role defaults (the semantic
/// contract, DESIGN.md §9.4): a typed, total lookup with the host default as
/// the fallback. Registers a dependency, so a theme swap rebuilds the caller.
CraftTheme? ambientCraftTheme(BuildContext context) =>
    context.dependOnInheritedComponentOfExactType<_ThemeScope>()?.theme;

/// Supplies the ambient [MediaContext] — the render-time responsive environment
/// (research/responsive/RESPONSIVE_DESIGN.md) — to every remote component below
/// it. Installed by [Runtime.build] / [Runtime.buildNode] when a media context
/// is provided. Like the theme, it is an immutable snapshot; a host supplies a
/// new one when the size class changes, which notifies dependents (a re-render
/// in place, no remount — the same reactivity contract as [_ThemeScope]).
class _MediaScope extends InheritedComponent {
  const _MediaScope({required this.media, required super.child});

  final MediaContext media;

  @override
  bool updateShouldNotify(_MediaScope oldComponent) =>
      media != oldComponent.media;
}

/// The ambient [MediaContext] installed by [Runtime.build] / [Runtime.buildNode],
/// or null when the host supplies none (the surface is size-agnostic — the
/// `Responsive` primitive then falls back to its smallest / mobile-first child).
/// Registers a dependency, so a size-class change rebuilds the caller.
MediaContext? ambientMediaContext(BuildContext context) =>
    context.dependOnInheritedComponentOfExactType<_MediaScope>()?.media;

@immutable
class _Key {
  _Key(this.section, this.parts)
      : assert(_isValidKey(parts), '$parts is not a valid key');

  static bool _isValidKey(List<Object> parts) {
    return parts.every((Object segment) => segment is int || segment is String);
  }

  final int section;
  final List<Object> parts;

  @override
  bool operator ==(Object other) {
    return other
            is _Key // _Key has no subclasses, don't need to check runtimeType
        &&
        section == other.section &&
        listEquals(parts, other.parts);
  }

  @override
  int get hashCode => Object.hash(section, Object.hashAll(parts));
}

class _Subscription {
  _Subscription(this._data, this._state, this._dataKey) {
    _update(_data.subscribe(_dataKey, _update));
  }

  final DynamicContent _data;
  final _WidgetState _state;
  final List<Object> _dataKey;
  final Set<_Key> _clients = <_Key>{};

  Object get value => _value;
  late Object _value;

  void _update(Object value) {
    _state.updateData(_clients);
    _value = value;
  }

  void addClient(_Key key) {
    _clients.add(key);
  }

  void dispose() {
    _data.unsubscribe(_dataKey, _update);
  }
}

Component _buildErrorWidget(String message) {
  final detail = FlutterErrorDetails(
    exception: message,
    stack: StackTrace.current,
    library: 'Remote Flutter Widgets',
  );
  FlutterError.reportError(detail);
  return ErrorWidget.builder(detail);
}

class FlutterErrorDetails {
  final Object exception;
  final StackTrace stack;
  final String library;
  FlutterErrorDetails(
      {required this.exception, required this.stack, required this.library});
}

class FlutterError {
  static void reportError(FlutterErrorDetails details) {
    print('Error: ${details.exception}\n${details.stack}');
  }
}

class ErrorWidget extends StatelessComponent {
  final Object exception;
  const ErrorWidget(this.exception);

  static Component builder(FlutterErrorDetails detail) =>
      ErrorWidget(detail.exception);

  @override
  Component build(BuildContext context) {
    return Component.text(exception.toString());
  }
}

class DiagnosticPropertiesBuilder {
  void add(Object property) {}
}

class StringProperty {
  StringProperty(String name, String value);
}

bool listEquals<T>(List<T>? a, List<T>? b) {
  if (a == null) return b == null;
  if (b == null || a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
