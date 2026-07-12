// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'primitives/button.dart';
import 'primitives/checkbox.dart';
import 'primitives/layout.dart';
import 'primitives/media.dart';
import 'primitives/radio.dart';
import 'primitives/select.dart';
import 'primitives/slider.dart';
import 'primitives/switch.dart';
import 'primitives/text.dart';
import 'primitives/text_field.dart';
import 'runtime.dart';

// Design notes (not part of the public API):
// - Each component implements the framework-neutral spec (DESIGN.md §8,
//   Pillar A) using the shared value types (Dimension, FlexAxis, the
//   alignments), rather than mirroring the Jaspr adapter by hand; the contract
//   is verified by package:a2ui_craft_testing (behavioral, and geometric for the
//   Flex/Box slices).
// - Components outside the Flex/Box slices are still seed-grade fixtures.
// - The runtime lifts the reserved `key` onto its reconciliation unit
//   (`_Widget`, DESIGN.md §6), so these builders never read or apply it.
/// A library of standard core components (Text, Flex/Row/Column, Button, …)
/// implemented using Flutter widgets.
///
/// Register the result under the `core` library name; templates then compose
/// these primitives. The reserved `key` argument is handled by the runtime, so
/// the builders here do not read or apply it. This file only binds template
/// names to builders — one primitive per file under `primitives/`; keep it a
/// flat, diffable list (it must stay aligned with `corePrimitives` in
/// package:a2ui_craft_testing).
LocalWidgetLibrary createCoreComponents() {
  return LocalWidgetLibrary(<String, LocalWidgetBuilder>{
    'Text': buildText,
    'Heading': buildHeading,
    'Markdown': buildMarkdown,
    'Flex': buildFlex,
    'Row': buildRow,
    'Column': buildColumn,
    'Expanded': buildExpanded,
    'Button': buildButton,
    'Center': buildCenter,
    'Align': buildAlign,
    'AspectRatio': buildAspectRatio,
    'Wrap': buildWrap,
    'Opacity': buildOpacity,
    'SizedBox': buildSizedBox,
    'Box': buildBox,
    'Image': buildImage,
    'Icon': buildIcon,
    'Divider': buildDivider,
    'ScrollView': buildScrollView,
    'List': buildList,
    'Card': buildCard,
    'TextField': buildTextField,
    'Checkbox': buildCheckbox,
    'Radio': buildRadio,
    'Switch': buildSwitch,
    'Select': buildSelect,
    'Slider': buildSlider,
  });
}
