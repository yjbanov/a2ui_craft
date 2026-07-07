// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// A runtime parser + resolver for the W3C DTCG design-tokens format.
///
/// A theme loads ephemerally as one or more DTCG `.tokens.json` documents
/// (DESIGN.md §13.5): a base layer plus optional per-mode overlays. Each
/// document is parsed with [parseDesignTokens] into a [DesignTokenSet]; the
/// active layers are then merged and alias-dereferenced by
/// [resolveDesignTokens] into a [ResolvedTokens], whose typed getters are what
/// primitives and `theme.` references read.
///
/// Everything here is **total**: malformed input — a bad document, an invalid
/// name, an unresolvable or cyclic alias, a wrong-shaped value — drops the
/// affected token (so the consumer falls back to the layer below, ultimately
/// the host default) and never throws. A theme is untrusted-shaped ephemeral
/// data; the same discipline as the function library.
library;

import 'value_types.dart';

// Design notes (not part of the public contract):
// - This is the "adopt the format, not the tooling" decision
//   (research/theming/DESIGN_TOKENS.md): the DTCG ecosystem is build-time
//   compilers, but our themes load at runtime, so we interpret the standard
//   shape ourselves. Parsing lives in the core — like the value-type decoders
//   and the function library — so both adapters resolve identical values by
//   construction (§13.6).
// - Aliases are dereferenced AFTER the layers are merged. That ordering is the
//   whole dark-mode mechanism: an overlay that overrides a primitive token
//   re-points every semantic alias into it without restating the semantics.
// - Typed getters are strict about value shape (a number token never reads as
//   a color) but liberal about which DTCG revision wrote the value: both the
//   2025.10 object forms and the older string forms are accepted, because the
//   format only recently stabilized and files in the wild predate it.

/// One parsed design token: a dot-joined [path], the effective [type]
/// (declared on the token or inherited from the nearest ancestor group; null
/// if neither), and the raw, unresolved [value] (which may be an alias string
/// such as `"{color.base.blue}"`).
final class DesignToken {
  const DesignToken({
    required this.path,
    required this.type,
    required this.value,
  });

  /// The dot-joined group path of the token, e.g. `color.base.blue`.
  final String path;

  /// The DTCG `$type`, e.g. `"color"`, or null if the document declared none.
  final String? type;

  /// The raw `$value`, not yet alias-resolved.
  final Object? value;

  @override
  String toString() => 'DesignToken($path: $type = $value)';
}

/// The tokens of one parsed DTCG document, keyed by dot path.
///
/// A token set is one *layer* of a theme (the base document, or a mode
/// overlay). Aliases are still unresolved at this stage; combine layers with
/// [resolveDesignTokens] to get readable values.
final class DesignTokenSet {
  const DesignTokenSet(this.tokens);

  /// An empty set (what malformed input parses to).
  static const DesignTokenSet empty = DesignTokenSet(<String, DesignToken>{});

  /// The parsed tokens, keyed by dot path.
  final Map<String, DesignToken> tokens;

  @override
  String toString() => 'DesignTokenSet(${tokens.length} tokens)';
}

/// Parses one decoded DTCG `.tokens.json` document into a [DesignTokenSet].
///
/// Walks the group tree: an object with a `$value` member is a token; any
/// other object is a group. `$type` set on a group is inherited by every
/// descendant that does not declare its own. `$`-prefixed members are DTCG
/// properties, not names.
///
/// Total: a non-map document parses to [DesignTokenSet.empty]; a name that is
/// invalid per the DTCG naming rules (contains `{`, `}`, or `.`, or begins
/// with `$`) drops that subtree; everything else parses independently.
DesignTokenSet parseDesignTokens(Object? document) {
  if (document is! Map<String, Object?>) return DesignTokenSet.empty;
  final Map<String, DesignToken> tokens = <String, DesignToken>{};
  _parseGroup(document, '', null, tokens);
  return DesignTokenSet(tokens);
}

void _parseGroup(
  Map<String, Object?> group,
  String pathPrefix,
  String? inheritedType,
  Map<String, DesignToken> out,
) {
  final Object? groupType = group[r'$type'];
  final String? effectiveType = groupType is String ? groupType : inheritedType;
  for (final MapEntry<String, Object?> entry in group.entries) {
    final String name = entry.key;
    if (name.startsWith(r'$')) continue; // A DTCG property, not a member name.
    if (name.contains('{') || name.contains('}') || name.contains('.')) {
      continue; // Reserved characters; the subtree is unaddressable.
    }
    final Object? child = entry.value;
    if (child is! Map<String, Object?>) continue;
    final String path = pathPrefix.isEmpty ? name : '$pathPrefix.$name';
    if (child.containsKey(r'$value')) {
      final Object? ownType = child[r'$type'];
      out[path] = DesignToken(
        path: path,
        type: ownType is String ? ownType : effectiveType,
        value: child[r'$value'],
      );
    } else {
      _parseGroup(child, path, effectiveType, out);
    }
  }
}

/// Merges token [layers] (later layers override earlier, token-by-token),
/// dereferences aliases, and returns the readable [ResolvedTokens].
///
/// Alias resolution happens *after* the merge, so an overlay that overrides a
/// primitive token (`color.base.bg`) re-points every semantic alias
/// (`color.surface → {color.base.bg}`) that survives from an earlier layer —
/// this is how a mode overlay re-themes without restating the semantic layer.
///
/// Total: an alias chain that is cyclic, dangling, or type-inconsistent drops
/// its token; every other token resolves independently.
ResolvedTokens resolveDesignTokens(List<DesignTokenSet> layers) {
  final Map<String, DesignToken> merged = <String, DesignToken>{};
  for (final DesignTokenSet layer in layers) {
    merged.addAll(layer.tokens);
  }
  final Map<String, DesignToken> resolved = <String, DesignToken>{};
  for (final DesignToken token in merged.values) {
    final DesignToken? result = _dereference(token, merged);
    if (result != null) resolved[token.path] = result;
  }
  return ResolvedTokens._(resolved);
}

/// The alias form: the whole `$value` is `{path.to.token}`.
String? _aliasTarget(Object? value) {
  if (value is! String) return null;
  final String s = value.trim();
  if (s.length < 3 || !s.startsWith('{') || !s.endsWith('}')) return null;
  final String path = s.substring(1, s.length - 1).trim();
  return path.isEmpty ? null : path;
}

DesignToken? _dereference(DesignToken token, Map<String, DesignToken> merged) {
  final Set<String> visited = <String>{token.path};
  String? declaredType = token.type;
  DesignToken current = token;
  String? target = _aliasTarget(current.value);
  while (target != null) {
    final DesignToken? next = merged[target];
    if (next == null || !visited.add(target)) return null; // Dangling or cycle.
    // A reference must not disagree with its target about the type.
    if (declaredType != null &&
        next.type != null &&
        next.type != declaredType) {
      return null;
    }
    declaredType ??= next.type;
    current = next;
    target = _aliasTarget(current.value);
  }
  return DesignToken(
    path: token.path,
    type: declaredType,
    value: current.value,
  );
}

/// A fully resolved token map: flat dot paths to concrete values, read through
/// typed, total getters.
///
/// The dot paths are exactly the template-facing `theme.<path>` references
/// (§13.4). Each getter returns null when the path is absent, the token's
/// `$type` does not match, or the value is malformed — the caller falls back
/// (ultimately to the host default); nothing throws.
///
/// Getters are strict about *types* (a `number` token never reads as a color)
/// but accept both the DTCG 2025.10 value shapes and the older string forms
/// (`{"value": 16, "unit": "px"}` and `"16px"`; the sRGB component object and
/// `"#RRGGBB"`).
final class ResolvedTokens {
  const ResolvedTokens._(this._tokens);

  /// No tokens; every read falls through.
  static const ResolvedTokens empty = ResolvedTokens._(<String, DesignToken>{});

  final Map<String, DesignToken> _tokens;

  /// The resolvable token paths, for tooling and tests.
  Iterable<String> get paths => _tokens.keys;

  /// Reads a `color` token as [Rgba].
  ///
  /// Accepts the 2025.10 object form — `colorSpace: "srgb"` with a 3-element
  /// `components` list in `[0, 1]` plus optional `alpha`, or any color space
  /// carrying the optional sRGB `hex` fallback — and the legacy hex string.
  Rgba? color(String path) {
    final DesignToken? token = _typed(path, 'color');
    if (token == null) return null;
    final Object? value = token.value;
    if (value is String) return Rgba.decode(value);
    if (value is Map<String, Object?>) {
      if (value['colorSpace'] == 'srgb') {
        final Object? components = value['components'];
        if (components is List && components.length == 3) {
          final double? r = _unitFraction(components[0]);
          final double? g = _unitFraction(components[1]);
          final double? b = _unitFraction(components[2]);
          final double a = _unitFraction(value['alpha']) ?? 1.0;
          if (r != null && g != null && b != null) {
            return Rgba(
              ((a * 255).round() << 24) |
                  ((r * 255).round() << 16) |
                  ((g * 255).round() << 8) |
                  (b * 255).round(),
            );
          }
        }
      }
      return Rgba.decode(value['hex']); // sRGB fallback for other spaces.
    }
    return null;
  }

  /// Reads a `dimension` token as logical pixels.
  ///
  /// Accepts `{"value": n, "unit": "px" | "rem"}` and the legacy `"16px"` /
  /// `"1rem"` strings. `rem` converts at the conventional 16 px root (the
  /// v1 convention; a host-supplied root is future work).
  double? dimension(String path) {
    final DesignToken? token = _typed(path, 'dimension');
    if (token == null) return null;
    final Object? value = token.value;
    if (value is Map<String, Object?>) {
      final Object? magnitude = value['value'];
      if (magnitude is num) {
        return _toPixels(magnitude.toDouble(), value['unit']);
      }
      return null;
    }
    if (value is String) {
      final String s = value.trim();
      for (final String unit in const <String>['rem', 'px']) {
        if (s.endsWith(unit)) {
          final double? magnitude = double.tryParse(
            s.substring(0, s.length - unit.length).trim(),
          );
          if (magnitude == null) return null;
          return _toPixels(magnitude, unit);
        }
      }
    }
    return null;
  }

  /// Reads a `number` token.
  double? number(String path) {
    final DesignToken? token = _typed(path, 'number');
    final Object? value = token?.value;
    return value is num ? value.toDouble() : null;
  }

  /// The resolved raw `$value` at [path], whatever its type — the escape hatch
  /// for types without a typed getter yet.
  Object? raw(String path) => _tokens[path]?.value;

  /// Converts the resolved tokens into the nested map the `theme.` reference
  /// scope reads (via a `DynamicContent`), with each value re-encoded in the
  /// **canonical template form** for its type — exactly what a literal in the
  /// same value position would be:
  ///
  /// * `color` → an `#AARRGGBB` hex string ([Rgba.toHexString]),
  /// * `dimension` → logical pixels as a double,
  /// * `number` → a double,
  /// * anything else → the resolved raw `$value` unchanged.
  ///
  /// This is what makes `theme.color.action` interchangeable with a literal
  /// `"#0066CC"`: primitives keep their one decoding path, and the theme scope
  /// speaks the template's value vocabulary. Tokens whose value fails its
  /// type's canonicalization are omitted (total — the reference then resolves
  /// as missing and the consumer falls back).
  Map<String, Object?> toTemplateValues() {
    final Map<String, Object?> root = <String, Object?>{};
    for (final DesignToken token in _tokens.values) {
      final Object? canonical = switch (token.type) {
        'color' => color(token.path)?.toHexString(),
        'dimension' => dimension(token.path),
        'number' => number(token.path),
        _ => token.value,
      };
      if (canonical == null) continue;
      final List<String> parts = token.path.split('.');
      Map<String, Object?> group = root;
      for (final String part in parts.sublist(0, parts.length - 1)) {
        final Object? existing = group[part];
        if (existing is Map<String, Object?>) {
          group = existing;
        } else {
          // A token where a group is needed (possible when merged layers
          // disagree about the shape) — the group wins; the shadowed token
          // is dropped rather than corrupting the tree.
          final Map<String, Object?> fresh = <String, Object?>{};
          group[part] = fresh;
          group = fresh;
        }
      }
      if (group[parts.last] is! Map<String, Object?>) {
        group[parts.last] = canonical;
      }
    }
    return root;
  }

  DesignToken? _typed(String path, String type) {
    final DesignToken? token = _tokens[path];
    return (token == null || token.type != type) ? null : token;
  }

  static double? _toPixels(double magnitude, Object? unit) => switch (unit) {
        'px' => magnitude,
        'rem' => magnitude * 16.0,
        _ => null,
      };

  static double? _unitFraction(Object? raw) {
    if (raw is! num) return null;
    final double value = raw.toDouble();
    return value < 0.0 ? 0.0 : (value > 1.0 ? 1.0 : value);
  }
}
