// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:flutter/widgets.dart';

/// Renders a [SampleSpec] with the Flutter adapter — a thin wrapper over the
/// reusable [SampleView].
class Sample extends StatelessWidget {
  const Sample(this.spec, {super.key});

  final SampleSpec spec;

  @override
  Widget build(BuildContext context) => SampleView(
        template: spec.catalogSource,
        schema: spec.catalogSchema,
        messages: spec.messages,
      );
}
