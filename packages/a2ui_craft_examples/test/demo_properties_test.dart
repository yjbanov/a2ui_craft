// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:test/test.dart';

// The demonstrated-property labels: each sample manifest tags the properties
// it meaningfully demonstrates; the gallery's filter bar is built from the
// vocabulary in demo_properties.dart. These tests keep the two honest.

void main() {
  test('the vocabulary ids are unique and lookup works', () {
    final Set<String> ids =
        demoProperties.map((DemoProperty p) => p.id).toSet();
    expect(ids.length, demoProperties.length);
    for (final DemoProperty p in demoProperties) {
      expect(demoPropertyById(p.id), same(p));
    }
    expect(demoPropertyById('nope'), isNull);
  });

  test('every sample label is a known property id (no typos)', () {
    final Set<String> known =
        demoProperties.map((DemoProperty p) => p.id).toSet();
    for (final RawSample sample in rawSamples) {
      for (final String label in sample.demonstrates) {
        expect(known, contains(label),
            reason: '${sample.id} declares unknown property "$label"');
      }
      expect(sample.demonstrates.toSet().length, sample.demonstrates.length,
          reason: '${sample.id} has duplicate labels');
    }
  });

  test('every property is demonstrated by at least one sample', () {
    for (final DemoProperty property in demoProperties) {
      final Iterable<String> carriers = rawSamples
          .where((RawSample s) => s.demonstrates.contains(property.id))
          .map((RawSample s) => s.id);
      expect(carriers, isNotEmpty,
          reason: 'no sample demonstrates "${property.id}"');
    }
  });

  test('the flagship demos carry their expected labels', () {
    RawSample byId(String id) =>
        rawSamples.firstWhere((RawSample s) => s.id == id);
    // The themed projects are the theming demos.
    for (final String id in <String>[
      'profile_card',
      'product_card',
      'chat_message',
      'weather',
      'calculator',
      'settings',
    ]) {
      expect(byId(id).demonstrates, contains('theming'), reason: id);
    }
    // The function-driven interactive samples.
    expect(byId('calculator').demonstrates,
        containsAll(<String>['functions', 'controls']));
    // The layout showcase.
    expect(byId('layout').demonstrates, contains('layout'));
    // The A2UI-composition demos (multiple components wired by id refs /
    // data-model updates).
    for (final String id in <String>['profile_card', 'form', 'greeting']) {
      expect(byId(id).demonstrates, contains('a2ui'), reason: id);
    }
  });
}
