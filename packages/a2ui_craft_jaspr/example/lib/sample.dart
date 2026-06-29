// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:jaspr/jaspr.dart';

/// Renders a [SampleSpec] with the Jaspr adapter — a thin wrapper over the
/// reusable [SampleView].
class Sample extends StatelessComponent {
  const Sample(this.spec, {super.key});

  final SampleSpec spec;

  @override
  Component build(BuildContext context) => SampleView(
        template: spec.catalogSource,
        schema: spec.catalogSchema,
        messages: spec.messages,
      );
}
