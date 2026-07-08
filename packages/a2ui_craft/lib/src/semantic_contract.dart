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

// Design notes (not part of the public contract):
// - Consumers are listed per role below and pinned by the theming conformance
//   dimension; a primitive must not read a role this file does not name (add
//   it here first — the contract is the source of truth, additive-preferred).
// - `Button` deliberately consumes nothing: the primitive is a look-free
//   accessible pressable; branding a button is a catalog *template* over
//   Box/Text referencing these roles explicitly (the component tier of the
//   three-tier token taxonomy).
// - Radius/spacing scales, font families/weights, and `color.background` are
//   deliberately absent from v1 — see the proposal for the reasons each waits.

/// The token paths of the semantic contract, v1.
///
/// The `color.*` roles:
///
/// | Path | Read by (when unset) |
/// |---|---|
/// | [surface] | `Card` background |
/// | [onSurface] | `Text` (body), `Heading`, `Markdown` body, `Icon` |
/// | [onSurfaceVariant] | `Text` (caption) |
/// | [primary] | `Checkbox`, `Slider`, `Radio` accents |
/// | [outline] | `Divider`, `TextField` border |
/// | [link] | `Markdown` links |
///
/// The `type.*` roles (sizes only in v1; families/weights are later phases):
///
/// | Path | Read by |
/// |---|---|
/// | [bodySize] | `Text` (body), `Markdown` body |
/// | [captionSize] | `Text` (caption) |
/// | [headingSize] (1–6) | `Heading`, `Markdown` headings |
///
/// [onPrimary], [error], and [onError] are **named now, consumed later**: no
/// primitive reads them yet, but themes and branded catalog templates can
/// already target them without fearing a rename.
abstract final class ThemeRoles {
  /// Background of surface-like containers (`Card`).
  static const String surface = 'color.surface';

  /// Foreground (text, icons) on a surface — the default ink.
  static const String onSurface = 'color.onSurface';

  /// De-emphasized foreground (captions, secondary text).
  static const String onSurfaceVariant = 'color.onSurfaceVariant';

  /// The accent: selection and control-active color (and what branded
  /// action templates reference).
  static const String primary = 'color.primary';

  /// Foreground on [primary]. Reserved for branded templates; no primitive
  /// consumer yet.
  static const String onPrimary = 'color.onPrimary';

  /// Borders and separators (`Divider`, `TextField`).
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
}
