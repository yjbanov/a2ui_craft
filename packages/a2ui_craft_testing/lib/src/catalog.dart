// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The canonical set of core component names that every framework adapter must
/// implement — no more, no less.
///
/// This is the single source of truth for "what components exist" in the core
/// library. Each adapter's `createCoreComponents()` is checked against this set
/// by a contract test, and the behavior of each component is verified by the
/// conformance suite (see `runCoreComponentConformance`). Keeping the set here,
/// framework-neutral, is what makes the adapters provably interchangeable.
///
/// This is test-scoped for now; it will graduate to a production catalog when
/// A2UI integration lands and needs to bind catalog `component` references to
/// templates.
const Set<String> coreCatalog = <String>{
  'Text',
  'Flex',
  'Row',
  'Column',
  'Expanded',
  'Button',
  'Center',
  'SizedBox',
  'Box',
  'Image',
  'Icon',
  'Divider',
  'ScrollView',
  'Card',
  'Video',
  'TextField',
  'Checkbox',
};
