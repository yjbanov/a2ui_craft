// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_jaspr/a2ui_craft_jaspr.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:jaspr_test/jaspr_test.dart';

void main() {
  test('implements exactly the primitives set (no more, no less)', () {
    final Set<String> implemented = createCoreComponents().widgets.keys.toSet();
    expect(implemented, corePrimitives);
  });
}
