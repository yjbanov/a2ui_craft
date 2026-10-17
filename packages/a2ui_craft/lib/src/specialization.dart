// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'functions.dart' show LocalFunction, currentRuntimeVersion;
import 'model.dart';

/// Navigates a sequence of [parts] (either String or int keys) through [target].
///
/// Returns `null` if any key in the path does not exist or cannot be indexed.
Object? lookupMetadataPath(Object? target, Iterable<Object> parts) {
  Object? current = target;
  for (final Object part in parts) {
    if (current == null) {
      return null;
    }
    if (current is Map) {
      current = current[part];
    } else if (current is List) {
      final int? index = part is int ? part : int.tryParse(part.toString());
      if (index != null && index >= 0 && index < current.length) {
        current = current[index];
      } else {
        return null;
      }
    } else {
      return null;
    }
  }
  return current;
}

/// Optimizes and specializes an AST node at template load time.
///
/// Folds static [SymbolReference] queries, evaluates pure compile-time functions,
/// simplifies boolean expressions, and eliminates dead [Switch] branches ahead of render.
///
/// [remoteWidgets] names remote widgets in scope: like [knownWidgets], a call
/// with one of these names is never folded as a function, but they do not count
/// as host-provided for `hasWidget`.
Object? specializeNode(
  Object? node, {
  required Map<String, Map<String, Object?>> widgetMetadata,
  required Map<String, LocalFunction> functions,
  required Set<String> knownWidgets,
  required int runtimeVersion,
  required String? appVersion,
  Set<String> remoteWidgets = const <String>{},
}) {
  if (node == null || node is num || node is String || node is bool) {
    return node;
  }

  if (node is Map) {
    final result = <String, Object?>{};
    node.forEach((key, value) {
      result[key.toString()] = specializeNode(
        value,
        widgetMetadata: widgetMetadata,
        functions: functions,
        knownWidgets: knownWidgets,
        remoteWidgets: remoteWidgets,
        runtimeVersion: runtimeVersion,
        appVersion: appVersion,
      );
    });
    return result;
  }

  if (node is List) {
    return node
        .map((e) => specializeNode(
              e,
              widgetMetadata: widgetMetadata,
              functions: functions,
              knownWidgets: knownWidgets,
              remoteWidgets: remoteWidgets,
              runtimeVersion: runtimeVersion,
              appVersion: appVersion,
            ))
        .toList();
  }

  if (node is SymbolReference) {
    // 1. Check widget metadata
    if (widgetMetadata.containsKey(node.symbol)) {
      return lookupMetadataPath(widgetMetadata[node.symbol], node.parts);
    }
    // 2. Check function metadata
    final LocalFunction? fn = functions[node.symbol];
    if (fn != null) {
      if (node.parts.isNotEmpty && node.parts.first == 'args') {
        if (node.parts.length == 2) {
          final Object argName = node.parts[1];
          if (fn.arguments.containsKey(argName.toString())) {
            return true;
          }
        }
      }
      return lookupMetadataPath(fn.meta, node.parts);
    }
    // 3. Known widget without metadata -> null
    if (knownWidgets.contains(node.symbol)) {
      return null;
    }
    // 4. Unknown symbol -> null
    return null;
  }

  if (node is Switch) {
    final Object? specializedInput = specializeNode(
      node.input,
      widgetMetadata: widgetMetadata,
      functions: functions,
      knownWidgets: knownWidgets,
      remoteWidgets: remoteWidgets,
      runtimeVersion: runtimeVersion,
      appVersion: appVersion,
    );

    final specializedOutputs = <Object?, Object>{};
    node.outputs.forEach((key, value) {
      final Object? specializedKey = key == null
          ? null
          : specializeNode(
              key,
              widgetMetadata: widgetMetadata,
              functions: functions,
              knownWidgets: knownWidgets,
              remoteWidgets: remoteWidgets,
              runtimeVersion: runtimeVersion,
              appVersion: appVersion,
            );
      final Object? specializedVal = specializeNode(
        value,
        widgetMetadata: widgetMetadata,
        functions: functions,
        knownWidgets: knownWidgets,
        remoteWidgets: remoteWidgets,
        runtimeVersion: runtimeVersion,
        appVersion: appVersion,
      );
      if (specializedVal is Object) {
        specializedOutputs[specializedKey] = specializedVal;
      }
    });

    // If input was constant-folded (not a BlobNode, like a Reference or un-folded Switch),
    // prune dead branches.
    if (specializedInput is! BlobNode) {
      if (specializedOutputs.containsKey(specializedInput)) {
        final Object selected = specializedOutputs[specializedInput]!;
        if (selected is BlobNode) {
          selected.propagateSource(node);
        }
        return selected;
      }
      if (specializedOutputs.containsKey(null)) {
        final Object defaultBranch = specializedOutputs[null]!;
        if (defaultBranch is BlobNode) {
          defaultBranch.propagateSource(node);
        }
        return defaultBranch;
      }
      return missing;
    }

    return Switch(specializedInput as Object, specializedOutputs)
      ..propagateSource(node);
  }

  if (node is ConstructorCall) {
    final specializedArgs = <String, Object?>{};
    node.arguments.forEach((key, val) {
      specializedArgs[key] = specializeNode(
        val,
        widgetMetadata: widgetMetadata,
        functions: functions,
        knownWidgets: knownWidgets,
        remoteWidgets: remoteWidgets,
        runtimeVersion: runtimeVersion,
        appVersion: appVersion,
      );
    });

    const introspectionNames = <String>{
      'hasWidget',
      'hasWidgetArg',
      'hasFunction',
      'hasFunctionArg',
      'hasArg',
      'meta',
      'runtimeVersion',
      'appVersion',
    };

    if (!knownWidgets.contains(node.name) &&
        !remoteWidgets.contains(node.name) &&
        (functions.containsKey(node.name) ||
            introspectionNames.contains(node.name))) {
      // Algebraic boolean simplifications
      if (node.name == 'and') {
        final a = specializedArgs['a'];
        final b = specializedArgs['b'];
        // Mirror the runtime: a constant non-boolean operand yields null.
        if (!_isBoolOrDynamic(a) || !_isBoolOrDynamic(b)) {
          return null;
        }
        if (a == false || b == false) {
          return false;
        }
        if (a == true) {
          return b;
        }
        if (b == true) {
          return a;
        }
        if (a is bool && b is bool) {
          return a && b;
        }
      } else if (node.name == 'or') {
        final a = specializedArgs['a'];
        final b = specializedArgs['b'];
        if (!_isBoolOrDynamic(a) || !_isBoolOrDynamic(b)) {
          return null;
        }
        if (a == true || b == true) {
          return true;
        }
        if (a == false) {
          return b;
        }
        if (b == false) {
          return a;
        }
        if (a is bool && b is bool) {
          return a || b;
        }
      } else if (node.name == 'equals') {
        final a = specializedArgs['a'];
        final b = specializedArgs['b'];
        if (a is! BlobNode && b is! BlobNode) {
          return a == b;
        }
      } else if (node.name == 'notEquals') {
        final a = specializedArgs['a'];
        final b = specializedArgs['b'];
        if (a is! BlobNode && b is! BlobNode) {
          return a != b;
        }
      } else if (node.name == 'hasWidget') {
        final name = specializedArgs['name'];
        if (name is String) {
          return knownWidgets.contains(name) ||
              widgetMetadata.containsKey(name);
        }
      } else if (node.name == 'hasWidgetArg') {
        final widget = specializedArgs['widget'];
        final arg = specializedArgs['arg'];
        if (widget is String && arg is String) {
          final meta = widgetMetadata[widget];
          if (meta != null && meta['args'] is Map) {
            final Map<Object?, Object?> args =
                meta['args'] as Map<Object?, Object?>;
            return args.containsKey(arg) && args[arg] != false;
          }
          return false;
        }
      } else if (node.name == 'hasFunction') {
        final name = specializedArgs['name'];
        if (name is String) {
          return functions.containsKey(name);
        }
      } else if (node.name == 'hasFunctionArg') {
        final function = specializedArgs['function'];
        final arg = specializedArgs['arg'];
        if (function is String && arg is String) {
          final fn = functions[function];
          if (fn != null) {
            if (fn.arguments.containsKey(arg)) {
              return true;
            }
            if (fn.meta['args'] is Map &&
                (fn.meta['args'] as Map).containsKey(arg)) {
              return true;
            }
          }
          return false;
        }
      } else if (node.name == 'hasArg') {
        final widget = specializedArgs['widget'];
        final function = specializedArgs['function'];
        final name = specializedArgs['name'];
        final arg = specializedArgs['arg'];
        final bool allConstants =
            specializedArgs.values.every((v) => v is! BlobNode);

        bool checkWidget(String w, String a) {
          final meta = widgetMetadata[w];
          if (meta != null && meta['args'] is Map) {
            final Map<Object?, Object?> args =
                meta['args'] as Map<Object?, Object?>;
            return args.containsKey(a) && args[a] != false;
          }
          return false;
        }

        bool checkFunction(String f, String a) {
          final fn = functions[f];
          if (fn != null) {
            if (fn.arguments.containsKey(a)) {
              return true;
            }
            if (fn.meta['args'] is Map &&
                (fn.meta['args'] as Map).containsKey(a)) {
              return true;
            }
          }
          return false;
        }

        if (arg is String) {
          if (widget is String) {
            return checkWidget(widget, arg);
          }
          if (function is String) {
            return checkFunction(function, arg);
          }
          if (name is String) {
            if (checkWidget(name, arg)) {
              return true;
            }
            if (checkFunction(name, arg)) {
              return true;
            }
            return false;
          }
        }
        if (allConstants) {
          return false;
        }
      } else if (node.name == 'runtimeVersion') {
        return runtimeVersion;
      } else if (node.name == 'appVersion') {
        return appVersion ?? '';
      } else if (node.name == 'meta') {
        final w = specializedArgs['w'];
        final f = specializedArgs['f'];
        final path = specializedArgs['path'];
        final pathList = (path is String && path.isNotEmpty)
            ? path.split('.')
            : const <Object>[];
        if (w is String) {
          return lookupMetadataPath(widgetMetadata[w], pathList);
        } else if (f is String) {
          final fn = functions[f];
          if (fn != null) {
            if (pathList.isNotEmpty &&
                pathList.first == 'args' &&
                pathList.length == 2) {
              if (fn.arguments.containsKey(pathList[1].toString())) {
                return true;
              }
            }
            return lookupMetadataPath(fn.meta, pathList);
          }
          return null;
        }
      } else {
        final fn = functions[node.name]!;
        final bool allConstants =
            specializedArgs.values.every((v) => v is! BlobNode);
        if (allConstants) {
          try {
            return fn.implementation(specializedArgs);
          } catch (_) {
            // Keep call if error
          }
        }
      }
    }

    return ConstructorCall(node.name, specializedArgs)..propagateSource(node);
  }

  if (node is Loop) {
    // A child that folds to null keeps its original node.
    return Loop(
      specializeNode(
            node.input,
            widgetMetadata: widgetMetadata,
            functions: functions,
            knownWidgets: knownWidgets,
            remoteWidgets: remoteWidgets,
            runtimeVersion: runtimeVersion,
            appVersion: appVersion,
          ) ??
          node.input,
      specializeNode(
            node.output,
            widgetMetadata: widgetMetadata,
            functions: functions,
            knownWidgets: knownWidgets,
            remoteWidgets: remoteWidgets,
            runtimeVersion: runtimeVersion,
            appVersion: appVersion,
          ) ??
          node.output,
    )..propagateSource(node);
  }

  if (node is WidgetBuilderDeclaration) {
    final Object? specializedWidget = specializeNode(
      node.widget,
      widgetMetadata: widgetMetadata,
      functions: functions,
      knownWidgets: knownWidgets,
      remoteWidgets: remoteWidgets,
      runtimeVersion: runtimeVersion,
      appVersion: appVersion,
    );
    // As for a widget declaration's root, keep the original body unless the
    // specialized one is still a widget or a switch.
    return WidgetBuilderDeclaration(
      node.argumentName,
      specializedWidget is ConstructorCall || specializedWidget is Switch
          ? specializedWidget as BlobNode
          : node.widget,
    )..propagateSource(node);
  }

  if (node is EventHandler) {
    return EventHandler(
      node.eventName,
      specializeNode(
        node.eventArguments,
        widgetMetadata: widgetMetadata,
        functions: functions,
        knownWidgets: knownWidgets,
        remoteWidgets: remoteWidgets,
        runtimeVersion: runtimeVersion,
        appVersion: appVersion,
      ) as DynamicMap,
    )..propagateSource(node);
  }

  if (node is SetStateHandler) {
    return SetStateHandler(
      node.stateReference,
      specializeNode(
            node.value,
            widgetMetadata: widgetMetadata,
            functions: functions,
            knownWidgets: knownWidgets,
            remoteWidgets: remoteWidgets,
            runtimeVersion: runtimeVersion,
            appVersion: appVersion,
          ) ??
          node.value,
    )..propagateSource(node);
  }

  return node;
}

/// Runs an AST specialization and constant-folding pass over [library].
///
/// Replaces static symbol references ([SymbolReference]), constant pure function
/// calls, and simplified boolean expressions with their resolved values.
/// Prunes dead branches from [Switch] constructs when the switch input evaluates
/// to a known compile-time constant.
///
/// A call whose name is in [knownWidgets], [remoteWidgets], or is declared by
/// [library] itself is treated as a widget, never folded as a function.
RemoteWidgetLibrary specializeLibrary(
  RemoteWidgetLibrary library, {
  Map<String, Map<String, Object?>> widgetMetadata =
      const <String, Map<String, Object?>>{},
  Map<String, LocalFunction> functions = const <String, LocalFunction>{},
  Set<String> knownWidgets = const <String>{},
  Set<String> remoteWidgets = const <String>{},
  int runtimeVersion = currentRuntimeVersion,
  String? appVersion,
}) {
  final allKnownWidgets = <String>{...knownWidgets, ...widgetMetadata.keys};
  final allRemoteWidgets = <String>{
    ...remoteWidgets,
    for (final WidgetDeclaration decl in library.widgets) decl.name,
  };
  final specializedWidgets = <WidgetDeclaration>[];
  for (final WidgetDeclaration decl in library.widgets) {
    final Object? specializedRoot = specializeNode(
      decl.root,
      widgetMetadata: widgetMetadata,
      functions: functions,
      knownWidgets: allKnownWidgets,
      remoteWidgets: allRemoteWidgets,
      runtimeVersion: runtimeVersion,
      appVersion: appVersion,
    );
    final BlobNode finalRoot;
    if (specializedRoot is ConstructorCall || specializedRoot is Switch) {
      finalRoot = specializedRoot as BlobNode;
    } else {
      finalRoot = decl.root;
    }
    final specializedDecl =
        WidgetDeclaration(decl.name, decl.initialState, finalRoot);
    specializedDecl.propagateSource(decl);
    specializedWidgets.add(specializedDecl);
  }
  return RemoteWidgetLibrary(library.imports, specializedWidgets);
}

/// Whether [value] is a boolean or a node still resolved at runtime.
bool _isBoolOrDynamic(Object? value) => value is bool || value is BlobNode;
