// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'model.dart' show DynamicMap;

/// Signature of a pure value-function's implementation (see [LocalFunction]).
///
/// Implementations MUST be **total**: given unexpected or missing argument
/// values they return `null` (which resolves to absent, e.g. an empty text)
/// rather than throwing. Totality is what lets wrong-typed *runtime* data (e.g.
/// an agent-supplied binding) degrade instead of crashing; author *literal*
/// type-mistakes are caught earlier, at bind time, against the
/// [LocalFunction.arguments] schema (in debug).
typedef LocalFunctionImplementation = Object? Function(DynamicMap arguments);

/// The value type a [LocalFunction] argument accepts.
///
/// Used to validate a call's *literal* arguments at bind time (in debug): a
/// literal of the wrong type is an author mistake and is reported early. A bound
/// argument (a data/state/args reference or a nested call) is resolved at
/// runtime — possibly from agent-controlled data — so its type is not (and must
/// not) be enforced statically; [LocalFunctionImplementation] totality handles a
/// bad runtime value.
enum FunctionArgType {
  /// An int or double.
  number,

  /// A string.
  string,

  /// A bool.
  boolean,

  /// Any value — no bind-time type check (e.g. an equality comparison that
  /// accepts operands of different types). Presence is still required.
  any;

  /// Whether [value] satisfies this type.
  bool accepts(Object? value) => switch (this) {
        FunctionArgType.number => value is num,
        FunctionArgType.string => value is String,
        FunctionArgType.boolean => value is bool,
        FunctionArgType.any => true,
      };

  /// A human-readable name for error messages.
  String get label => switch (this) {
        FunctionArgType.number => 'a number',
        FunctionArgType.string => 'a string',
        FunctionArgType.boolean => 'a boolean',
        FunctionArgType.any => 'any value',
      };
}

/// A pure value-function callable from a template, plus the schema of the
/// arguments it accepts.
///
/// Functions are the *computation* layer that complements the *rendering* layer
/// (the primitive widget library): a template writes `name(arg: value, …)` in
/// any value position — including the right-hand side of a `set state` — and the
/// runtime resolves the arguments to values, invokes [implementation], and
/// substitutes the returned value.
///
/// This is the trusted, template-author-facing shape — deliberately separate
/// from the agent-facing `a2ui_core` function catalog. Being pure and
/// framework-neutral, the standard library ([createCoreFunctions]) is defined
/// **once** here and shared by every adapter, so a template computes identical
/// values on all of them. See DESIGN.md (two-layer template-computation plan).
class LocalFunction {
  /// Creates a function with the given [arguments] schema and [implementation].
  const LocalFunction({required this.arguments, required this.implementation});

  /// The accepted arguments, keyed by name. Every listed argument is required;
  /// declaring an argument both names it (so an unknown name is rejected) and
  /// types it (so a wrong-typed literal is rejected) at bind time in debug.
  final Map<String, FunctionArgType> arguments;

  /// The (total) computation. See [LocalFunctionImplementation].
  final LocalFunctionImplementation implementation;
}

/// A named collection of pure [LocalFunction]s, registered on an adapter's
/// runtime.
///
/// The template-facing analogue of the primitive widget library: where that
/// supplies the widgets a template composes, this supplies the functions a
/// template calls in value positions. Provided by the host in Dart (compiled
/// AOT), so — like the primitive widgets — the set is fixed for a given host
/// build.
class LocalFunctionLibrary {
  /// Create a [LocalFunctionLibrary].
  ///
  /// The given map must not change once the object is created.
  const LocalFunctionLibrary(this._functions);

  final Map<String, LocalFunction> _functions;

  /// The functions defined by this library, keyed by the name templates call.
  Map<String, LocalFunction> get functions =>
      Map<String, LocalFunction>.unmodifiable(_functions);
}

/// Formats a number for display so the result is identical on every adapter.
///
/// The Dart VM and dart2js disagree on `(4.0).toString()` ("4.0" vs "4"), so an
/// integer-valued double is rendered without a trailing `.0`. Non-integer
/// doubles format consistently across the two, so they pass through. Used by
/// both a Text sink's numeric coercion and the string functions here, so a
/// computed number reads the same wherever it appears.
String numberToDisplayString(num value) {
  if (value is double && value.isFinite && value == value.roundToDouble()) {
    return value.toInt().toString();
  }
  return value.toString();
}

/// The standard **function library** — the pure, template-author-facing
/// computation layer that complements the primitive widget library (the
/// rendering layer). Register it on an adapter's runtime.
///
/// Every function is **total**: unexpected or missing arguments yield `null`
/// (rendered as absent) rather than an exception. Types are **strict**: a value
/// of the wrong type is not coerced (no JS-style `"5" + 3 == 8`). This is the
/// trusted library used by template authors, kept deliberately separate from the
/// agent-facing `a2ui_core` function catalog (see DESIGN.md, two-layer plan).
LocalFunctionLibrary createCoreFunctions() {
  return LocalFunctionLibrary(<String, LocalFunction>{
    // Basic arithmetic over int/double operands. Division by zero has no
    // numeric result → null (stays total).
    'add': _binaryNumber((num a, num b) => a + b),
    'subtract': _binaryNumber((num a, num b) => a - b),
    'multiply': _binaryNumber((num a, num b) => a * b),
    'divide': _binaryNumber((num a, num b) => b == 0 ? null : a / b),
  });
}

// --- Number helpers ---------------------------------------------------------

/// Reads a resolved argument as a [num], returning null for any non-numeric
/// value (no coercion; see [createCoreFunctions]).
num? _asNumber(Object? value) => value is num ? value : null;

/// Builds a binary numeric [LocalFunction] from [combine].
///
/// Total by construction: a non-numeric operand — or a [combine] that returns
/// null (e.g. divide-by-zero) — yields null (an absent result).
LocalFunction _binaryNumber(num? Function(num a, num b) combine) {
  return LocalFunction(
    arguments: const <String, FunctionArgType>{
      'a': FunctionArgType.number,
      'b': FunctionArgType.number,
    },
    implementation: (DynamicMap arguments) {
      final num? a = _asNumber(arguments['a']);
      final num? b = _asNumber(arguments['b']);
      if (a == null || b == null) {
        return null;
      }
      return combine(a, b);
    },
  );
}
