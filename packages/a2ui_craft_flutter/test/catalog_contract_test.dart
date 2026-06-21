// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_flutter/a2ui_craft_flutter.dart';
import 'package:a2ui_craft_testing/a2ui_craft_testing.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('implements exactly the core catalog (no more, no less)', () {
    final Set<String> implemented = createCoreComponents().widgets.keys.toSet();
    expect(implemented, coreCatalog);
  });
}
