// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Helpers shared by the core-primitive builders: argument decoding over the
/// framework-neutral value types, ambient theme-role lookups, and the
/// value-type → Flutter mappings.
library;

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import '../runtime.dart';

/// Reads a numeric argument, accepting an int or double literal.
double? numArg(DataSource source, String key) =>
    source.v<double>([key]) ?? source.v<int>([key])?.toDouble();

/// Gathers a raw inset value (a number or a list of numbers) from [source] so
/// the framework-neutral `Insets.decode` can interpret it. Only the extraction
/// is adapter-specific; the 2-vs-4-element interpretation lives in the core.
Object? insetsRaw(DataSource source, String key) {
  if (source.isList([key])) {
    final int n = source.length([key]);
    return <double>[
      for (int i = 0; i < n; i++)
        source.v<double>([key, i]) ??
            source.v<int>([key, i])?.toDouble() ??
            0.0,
    ];
  }
  return source.v<double>([key]) ?? source.v<int>([key])?.toDouble();
}

/// Reads a color argument as an [Rgba], or null when absent/invalid.
Rgba? rgbaArg(DataSource source, String key) =>
    Rgba.decode(source.v<String>([key]));

/// Gathers a raw `border` value (a width number, a `{width, color}` map, or a
/// bool) so the framework-neutral [BorderSpec.decode] can interpret it. Only the
/// extraction is adapter-specific; the interpretation lives in the core.
Object? borderRaw(DataSource source, String key) {
  if (source.isMap([key])) {
    return <String, Object?>{
      'width': source.v<double>([key, 'width']) ??
          source.v<int>([key, 'width'])?.toDouble(),
      'color': source.v<String>([key, 'color']),
    };
  }
  final bool? flag = source.v<bool>([key]);
  if (flag != null) return flag;
  return source.v<double>([key]) ?? source.v<int>([key])?.toDouble();
}

/// Reads a list-of-strings argument (e.g. a Select's `options`).
List<String> stringList(DataSource source, String key) {
  if (!source.isList([key])) return const <String>[];
  final int n = source.length([key]);
  return <String>[
    for (int i = 0; i < n; i++) source.v<String>([key, i]) ?? '',
  ];
}

/// Reads a role color from the ambient theme as a Flutter [Color], or null
/// when the surface is unthemed / the theme omits the role — the caller then
/// falls back to the host default (DESIGN.md §9.4).
Color? roleColor(BuildContext context, String role) {
  final Rgba? rgba = ambientCraftTheme(context)?.tokens.color(role);
  return rgba == null ? null : Color(rgba.value);
}

/// Reads a role size (a `dimension` token, logical pixels) from the ambient
/// theme, or null for the host default.
double? roleSize(BuildContext context, String role) =>
    ambientCraftTheme(context)?.tokens.dimension(role);

EdgeInsets toEdgeInsets(Insets i) =>
    EdgeInsets.fromLTRB(i.left, i.top, i.right, i.bottom);

MainAxisAlignment toMainAxisAlignment(MainAxisAlign a) => switch (a) {
      MainAxisAlign.start => MainAxisAlignment.start,
      MainAxisAlign.center => MainAxisAlignment.center,
      MainAxisAlign.end => MainAxisAlignment.end,
      MainAxisAlign.spaceBetween => MainAxisAlignment.spaceBetween,
      MainAxisAlign.spaceAround => MainAxisAlignment.spaceAround,
      MainAxisAlign.spaceEvenly => MainAxisAlignment.spaceEvenly,
    };

CrossAxisAlignment toCrossAxisAlignment(CrossAxisAlign a) => switch (a) {
      CrossAxisAlign.start => CrossAxisAlignment.start,
      CrossAxisAlign.center => CrossAxisAlignment.center,
      CrossAxisAlign.end => CrossAxisAlignment.end,
      CrossAxisAlign.stretch => CrossAxisAlignment.stretch,
    };

/// The shared field chrome (DESIGN.md §8), degrading role-by-role: `outline`
/// draws the box (1px border, the stock 6px control corner, 8/12 padding);
/// `primary` the focused border. Used by `TextField` and `Select`; the Jaspr
/// adapter paints the same spec (border/radius/padding inline; focus via the
/// control stylesheet). Unthemed keeps the host's default decoration.
InputDecoration fieldDecorationFor(Color? outline, Color? accent) {
  if (outline == null) return const InputDecoration();
  final BorderRadius radius = BorderRadius.circular(6);
  return InputDecoration(
    isDense: true,
    contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
    enabledBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: outline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: accent ?? outline, width: 2),
    ),
  );
}

/// [fieldDecorationFor], reading the roles from the ambient theme.
InputDecoration fieldDecoration(BuildContext context) => fieldDecorationFor(
      roleColor(context, ThemeRoles.outline),
      roleColor(context, ThemeRoles.primary),
    );
