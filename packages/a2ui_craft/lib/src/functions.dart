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
    // Arithmetic (number, number → number). Division/modulo by zero has no
    // numeric result → null (stays total).
    'add': _binaryNumber((num a, num b) => a + b),
    'subtract': _binaryNumber((num a, num b) => a - b),
    'multiply': _binaryNumber((num a, num b) => a * b),
    'divide': _binaryNumber((num a, num b) => b == 0 ? null : a / b),
    'mod': _binaryNumber((num a, num b) => b == 0 ? null : a % b),
    'min': _binaryNumber((num a, num b) => a <= b ? a : b),
    'max': _binaryNumber((num a, num b) => a >= b ? a : b),

    // Unary number (number → number). round/floor/ceil return an int.
    'abs': _unaryNumber((num a) => a.abs()),
    'round': _unaryNumber((num a) => a.round()),
    'floor': _unaryNumber((num a) => a.floor()),
    'ceil': _unaryNumber((num a) => a.ceil()),

    // Numeric comparison (number, number → boolean).
    'greaterThan': _numberComparison((num a, num b) => a > b),
    'lessThan': _numberComparison((num a, num b) => a < b),
    'greaterThanOrEqual': _numberComparison((num a, num b) => a >= b),
    'lessThanOrEqual': _numberComparison((num a, num b) => a <= b),

    // Equality (any, any → boolean). Cross-type compares are false (5 ≠ "5");
    // no coercion. Total — always a boolean.
    'equals': _equality(wantEqual: true),
    'notEquals': _equality(wantEqual: false),

    // Boolean logic (boolean … → boolean). Operands are pre-resolved, so there
    // is nothing to short-circuit.
    'and': _binaryBoolean((bool a, bool b) => a && b),
    'or': _binaryBoolean((bool a, bool b) => a || b),
    'not': _unaryBoolean((bool value) => !value),

    // Strings. `concat` stringifies each operand (numbers via
    // [numberToDisplayString], booleans as "true"/"false", anything absent as
    // ""), so it accepts any value; the rest require a string.
    'concat': _concat(),
    'uppercase': _unaryString((String s) => s.toUpperCase()),
    'lowercase': _unaryString((String s) => s.toLowerCase()),
    'trim': _unaryString((String s) => s.trim()),
    'length': _stringLength(),
  });
}

// --- Argument schemas -------------------------------------------------------

const Map<String, FunctionArgType> _twoNumbers = <String, FunctionArgType>{
  'a': FunctionArgType.number,
  'b': FunctionArgType.number,
};
const Map<String, FunctionArgType> _oneNumber = <String, FunctionArgType>{
  'value': FunctionArgType.number,
};
const Map<String, FunctionArgType> _twoAny = <String, FunctionArgType>{
  'a': FunctionArgType.any,
  'b': FunctionArgType.any,
};
const Map<String, FunctionArgType> _twoBooleans = <String, FunctionArgType>{
  'a': FunctionArgType.boolean,
  'b': FunctionArgType.boolean,
};
const Map<String, FunctionArgType> _oneBoolean = <String, FunctionArgType>{
  'value': FunctionArgType.boolean,
};
const Map<String, FunctionArgType> _oneString = <String, FunctionArgType>{
  'value': FunctionArgType.string,
};

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
    arguments: _twoNumbers,
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

/// Builds a unary numeric [LocalFunction] from [compute]. Total: a non-numeric
/// operand yields null.
LocalFunction _unaryNumber(num? Function(num value) compute) {
  return LocalFunction(
    arguments: _oneNumber,
    implementation: (DynamicMap arguments) {
      final num? value = _asNumber(arguments['value']);
      return value == null ? null : compute(value);
    },
  );
}

/// Builds a numeric comparison ((number, number) → boolean). Total: a
/// non-numeric operand yields null.
LocalFunction _numberComparison(bool Function(num a, num b) compare) {
  return LocalFunction(
    arguments: _twoNumbers,
    implementation: (DynamicMap arguments) {
      final num? a = _asNumber(arguments['a']);
      final num? b = _asNumber(arguments['b']);
      if (a == null || b == null) {
        return null;
      }
      return compare(a, b);
    },
  );
}

// --- Equality & boolean logic ----------------------------------------------

/// Builds `equals`/`notEquals`. Uses Dart `==`, so operands of different types
/// are unequal and numbers are not coerced. Total — always returns a boolean.
LocalFunction _equality({required bool wantEqual}) {
  return LocalFunction(
    arguments: _twoAny,
    implementation: (DynamicMap arguments) =>
        (arguments['a'] == arguments['b']) == wantEqual,
  );
}

/// Builds a binary boolean [LocalFunction]. Total: a non-boolean operand yields
/// null.
LocalFunction _binaryBoolean(bool Function(bool a, bool b) combine) {
  return LocalFunction(
    arguments: _twoBooleans,
    implementation: (DynamicMap arguments) {
      final Object? a = arguments['a'];
      final Object? b = arguments['b'];
      return (a is bool && b is bool) ? combine(a, b) : null;
    },
  );
}

/// Builds a unary boolean [LocalFunction]. Total: a non-boolean operand yields
/// null.
LocalFunction _unaryBoolean(bool Function(bool value) compute) {
  return LocalFunction(
    arguments: _oneBoolean,
    implementation: (DynamicMap arguments) {
      final Object? value = arguments['value'];
      return value is bool ? compute(value) : null;
    },
  );
}

// --- String helpers ---------------------------------------------------------

/// Builds a unary string transform. Total: a non-string operand yields null.
LocalFunction _unaryString(String Function(String value) transform) {
  return LocalFunction(
    arguments: _oneString,
    implementation: (DynamicMap arguments) {
      final Object? value = arguments['value'];
      return value is String ? transform(value) : null;
    },
  );
}

/// `length`: the number of UTF-16 code units in a string. Total: a non-string
/// operand yields null.
LocalFunction _stringLength() {
  return LocalFunction(
    arguments: _oneString,
    implementation: (DynamicMap arguments) {
      final Object? value = arguments['value'];
      return value is String ? value.length : null;
    },
  );
}

/// `concat`: joins two operands as display strings (see [_stringifyOperand]).
/// Accepts any values and always returns a string, so it is convenient for
/// building labels from a mix of text and computed numbers.
LocalFunction _concat() {
  return LocalFunction(
    arguments: _twoAny,
    implementation: (DynamicMap arguments) =>
        '${_stringifyOperand(arguments['a'])}${_stringifyOperand(arguments['b'])}',
  );
}

/// Renders a value the way `concat` (and a Text sink) would: a string as-is, a
/// number via [numberToDisplayString], a boolean as "true"/"false", and anything
/// absent or non-scalar (null, an unresolved binding, a list/map) as an empty
/// string.
String _stringifyOperand(Object? value) {
  if (value is String) {
    return value;
  }
  if (value is num) {
    return numberToDisplayString(value);
  }
  if (value is bool) {
    return value ? 'true' : 'false';
  }
  return '';
}
