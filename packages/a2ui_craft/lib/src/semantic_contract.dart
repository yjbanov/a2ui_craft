// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The **semantic contract**: the design-token paths the core primitives read
/// for their *ambient role defaults* (DESIGN.md §9.4).
///
/// DTCG standardizes token *structure*, never *meaning* — nothing in the
/// format says a caption uses `color.onSurfaceVariant`. This contract is the
/// one piece of "standard" A2UI Craft authors itself: a small, versioned
/// vocabulary of intent-named roles, with surface/foreground pairing, using
/// Material 3's names wherever M3 has one (so an M3 or shadcn-shaped token
/// export maps on without translation — see
/// research/theming/SEMANTIC_CONTRACT.md).
///
/// Reading rules (§9.4): a primitive consults its role only when the
/// corresponding prop is unset; a theme that omits a role degrades to the
/// **host default** (an unthemed surface renders exactly as if this contract
/// did not exist). Lookups are typed and total — never throwing — like every
/// other theme read.
library;

import 'design_tokens.dart';
import 'value_types.dart';

// Design notes (not part of the public contract):
// - Consumers are listed per role below and pinned by the theming conformance
//   dimension; a primitive must not read a role this file does not name (add
//   it here first — the contract is the source of truth, additive-preferred).
// - `Button` deliberately consumes nothing: the primitive is a look-free
//   accessible pressable; branding a button is a catalog *template* over
//   Box/Text referencing these roles explicitly (the component tier of the
//   three-tier token taxonomy).
// - Radius/spacing scales, font *weights*, and `color.background` are
//   deliberately absent from v1 — see the proposal for the reasons each waits.
//   Font *families* arrived after v1 as a closed role vocabulary (`FontRole`),
//   not an open namespace: a family name is a request the host must be able to
//   answer, so the set is quantized the way the easing set is.

/// The token paths of the semantic contract, v1.
///
/// The `color.*` roles:
///
/// | Path | Read by (when unset) |
/// |---|---|
/// | [surface] | `Card` fill |
/// | [onSurface] | `Text` (body), `Heading`, `Markdown` body, `Icon` |
/// | [onSurfaceVariant] | `Text` (caption) |
/// | [primary] | `Checkbox` fill, `Radio` selected, `Slider` active, `Switch` active track |
/// | [onPrimary] | `Checkbox` mark, `Switch` on-thumb |
/// | [outline] | `Divider`, `TextField` border, `Card` border, `Box` border, `Checkbox` box, `Radio` ring, `Switch` inactive track |
/// | [link] | `Markdown` links |
///
/// The `type.*` roles (sizes and families; weights are a later phase):
///
/// | Path | Read by |
/// |---|---|
/// | [bodySize] | `Text` (body), `Markdown` body |
/// | [captionSize] | `Text` (caption) |
/// | [headingSize] (1–6) | `Heading`, `Markdown` headings |
/// | [bodyFamily] | `Text` (body), `Markdown` body |
/// | [captionFamily] | `Text` (caption) |
/// | [headingFamily] | `Heading`, `Markdown` headings |
/// | [codeFamily] | `Markdown` code spans |
///
/// Families are **named-string** tokens (an id read by `FontRole.decode`, never
/// a raw family name — see [FontRole] for why the vocabulary is closed), and
/// they are resolved through [resolveFontFamily]. Unlike sizes, a family is one
/// role per element kind rather than one per heading level: a type scale varies
/// size down the levels, not typeface.
///
/// The `motion.*` roles (the motion token system — durations + named easings):
///
/// | Path | Read by |
/// |---|---|
/// | [motionDurationShort] / [motionDurationMedium] / [motionDurationLong] | `Box` (via `animate`) |
/// | [motionEasingStandard] / [motionEasingEmphasized] / [motionEasingDecelerate] / [motionEasingAccelerate] | `Box` (via `animate`) |
///
/// Durations are `duration` tokens (ms); easings are **named-string** tokens
/// (an id read by `MotionEasing.decode`, not a raw `cubicBezier` — the quantized
/// vocabulary is the guard rail). `animate: true` resolves to
/// [motionDurationMedium] + [motionEasingStandard].
///
/// [error] and [onError] are **named now, consumed later**: no primitive reads
/// them yet, but themes and branded catalog templates can already target them
/// without fearing a rename.
abstract final class ThemeRoles {
  /// Fill of surface-like containers (`Card`).
  static const String surface = 'color.surface';

  /// Foreground (text, icons) on a surface — the default ink.
  static const String onSurface = 'color.onSurface';

  /// De-emphasized foreground (captions, secondary text).
  static const String onSurfaceVariant = 'color.onSurfaceVariant';

  /// The accent: selection and control-active color — the `Checkbox` fill,
  /// `Radio` selected glyph, `Slider` active track/thumb, `Switch` active track
  /// (and what branded action templates reference).
  static const String primary = 'color.primary';

  /// Foreground on [primary]: the `Checkbox` mark and the `Switch` on-thumb
  /// (also what branded templates ink over a [primary] surface).
  static const String onPrimary = 'color.onPrimary';

  /// Borders and separators: `Divider`, `TextField` / `Card` / `Box` border,
  /// and the unchecked control chrome — the `Checkbox` box, `Radio` ring, and
  /// `Switch` inactive track.
  static const String outline = 'color.outline';

  /// Hyperlinks (`Markdown`). Typically aliased to `{color.primary}` by
  /// themes that don't need a distinct link color.
  static const String link = 'color.link';

  /// Error emphasis. Reserved; no primitive consumer yet.
  static const String error = 'color.error';

  /// Foreground on [error]. Reserved; no primitive consumer yet.
  static const String onError = 'color.onError';

  /// Body text size (logical pixels, a `dimension` token).
  static const String bodySize = 'type.body.size';

  /// Caption text size.
  static const String captionSize = 'type.caption.size';

  /// Heading text size for [level] 1–6, e.g. `type.heading.2.size`.
  static String headingSize(int level) => 'type.heading.$level.size';

  /// Body text family (a named-string token read by `FontRole.decode`).
  static const String bodyFamily = 'type.body.family';

  /// Caption text family.
  static const String captionFamily = 'type.caption.family';

  /// Heading family — one role for all six levels (a type scale varies size
  /// down the levels, not typeface).
  static const String headingFamily = 'type.heading.family';

  /// Code-span family (`Markdown`). The one role with a built-in default other
  /// than "unset": code is fixed-pitch even on an unthemed surface, which is
  /// what a monospace face *means*.
  static const String codeFamily = 'type.code.family';

  /// Short transition duration (`duration` token, ms) — small state changes.
  static const String motionDurationShort = 'motion.duration.short';

  /// Medium transition duration — the default; what `animate: true` uses.
  static const String motionDurationMedium = 'motion.duration.medium';

  /// Long transition duration — larger or more prominent changes.
  static const String motionDurationLong = 'motion.duration.long';

  /// Standard easing (a named-string token read by `MotionEasing.decode`) — the
  /// default curve; what `animate: true` uses.
  static const String motionEasingStandard = 'motion.easing.standard';

  /// Expressive easing for motion that should draw the eye.
  static const String motionEasingEmphasized = 'motion.easing.emphasized';

  /// Easing for elements entering the screen (ease-out).
  static const String motionEasingDecelerate = 'motion.easing.decelerate';

  /// Easing for elements leaving the screen (ease-in).
  static const String motionEasingAccelerate = 'motion.easing.accelerate';
}

/// The built-in default [Motion] used when a theme omits the motion roles (or
/// there is no theme at all): a medium duration and the standard easing.
const Motion _defaultMotion =
    Motion(durationMs: 250, easing: MotionEasing.standard);

/// Resolves a `Box(animate:)` argument [raw] into a [Motion], reading the
/// theme's motion roles for the `true` / default case.
///
/// - **absent** (`null`) / `false` → [Motion.none] (no animation): a box without
///   an `animate` prop never animates;
/// - `true` becomes [ThemeRoles.motionDurationMedium] +
///   [ThemeRoles.motionEasingStandard] from [tokens], each falling back to the
///   built-in default when the theme omits it (or when [tokens] is null);
/// - an explicit number (ms) or `{duration, easing}` map decodes directly.
///
/// Lives in the core so both adapters resolve the *identical* [Motion] for a
/// given prop + theme (Pillar A). The reduced-motion collapse is intentionally
/// left to the adapter, which reads the ambient [MediaContext].
Motion resolveMotion(Object? raw, ResolvedTokens? tokens) {
  // Absent means "no `animate` prop" → no animation. (Motion.decode would send a
  // null to its fallback, which here is the theme default — not what we want.)
  if (raw == null) return Motion.none;
  final Motion themeDefault = tokens == null
      ? _defaultMotion
      : Motion(
          durationMs:
              tokens.duration(ThemeRoles.motionDurationMedium)?.round() ??
                  _defaultMotion.durationMs,
          easing: MotionEasing.decode(
            tokens.raw(ThemeRoles.motionEasingStandard),
            fallback: _defaultMotion.easing,
          ),
        );
  return Motion.decode(raw, fallback: themeDefault);
}

/// Resolves a typography family role — [ThemeRoles.bodyFamily] and friends —
/// into the [FontRole] the primitive should render with, or **null** when
/// neither the theme nor [fallback] names one.
///
/// Null is the load-bearing case. §9.4's rule is that an unthemed surface
/// renders exactly as if this contract did not exist, and for typefaces that is
/// stronger than a stylistic nicety: the host's own font is what makes an
/// embedded surface look like part of the page around it. So a theme that omits
/// a family role leaves the font untouched — the adapters emit *nothing*, not a
/// default — and only an explicit token (or a primitive's own [fallback], as
/// `Markdown` code spans pass [FontRole.mono]) selects a face.
///
/// Lives in the core so both adapters resolve the identical role for a given
/// theme (Pillar A); mapping that role onto a concrete typeface is the host's
/// job, via `CraftFonts`.
FontRole? resolveFontFamily(
  String rolePath,
  ResolvedTokens? tokens, {
  FontRole? fallback,
}) =>
    FontRole.tryDecode(tokens?.raw(rolePath)) ?? fallback;
