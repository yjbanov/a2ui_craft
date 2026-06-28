// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The canonical set of **core primitive** names that every framework adapter
/// must implement — no more, no less.
///
/// These are the *standard* primitives A2UI Craft ships (apps may register
/// additional custom primitives, which are not part of this contract). Each
/// adapter's `createCoreComponents()` is checked against this set by a contract
/// test, and the behavior of each is verified by the conformance suite (see
/// `runCoreComponentConformance`). Keeping the set here, framework-neutral, is
/// what makes the adapters provably interchangeable.
///
/// (Primitives are the template-private building blocks; the agent-facing
/// **catalog** is a separate, higher-level set of templates over them — see
/// DESIGN.md's Glossary.)
const Set<String> corePrimitives = <String>{
  'Text',
  'Heading',
  'Markdown',
  'Flex',
  'Row',
  'Column',
  'Expanded',
  'List',
  'Button',
  'Center',
  'Align',
  'AspectRatio',
  'Wrap',
  'Opacity',
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
  'Radio',
  'Slider',
};
