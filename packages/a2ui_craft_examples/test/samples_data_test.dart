// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:test/test.dart';

void main() {
  test('every code-free sample trio decodes into a usable SampleSpec', () {
    final List<SampleSpec> specs = sampleSpecs('Jaspr');
    expect(specs, hasLength(rawSamples.length));
    expect(specs.length, greaterThanOrEqualTo(40));
    for (final SampleSpec spec in specs) {
      expect(spec.label, isNotEmpty);
      expect(spec.catalogSource, isNotEmpty);
      expect(spec.catalogSchema, isNotEmpty);
      expect(spec.messages, isNotEmpty,
          reason: '${spec.label} has no messages');
    }
  });

  test('the {{framework}} token is substituted everywhere', () {
    final SampleSpec greeting = greetingSpec('Jaspr');
    final String json = jsonEncode(<Object?>[
      for (final dynamic m in greeting.messages) m.toJson(),
    ]);
    expect(json.contains('{{framework}}'), isFalse);
    expect(json.contains('A2UI Craft × Jaspr'), isTrue);
  });

  test('SampleSpec.fromData parses a hand-written trio', () {
    final SampleSpec spec = SampleSpec.fromData(
      label: 'Demo',
      template: 'import core;\nwidget Demo = Text(text: args.t);',
      schemaJson: '{"catalogId":"demo","components":{"Demo":{"properties":'
          '{"t":{"\$ref":"DynamicString"}}}}}',
      messagesJson: '[{"version":"v0.9","createSurface":'
          '{"surfaceId":"demo","catalogId":"demo"}},'
          '{"version":"v0.9","updateComponents":{"surfaceId":"demo",'
          '"components":[{"id":"root","component":"Demo","t":"hi"}]}}]',
    );
    expect(spec.label, 'Demo');
    expect(spec.catalogSchema['catalogId'], 'demo');
    expect(spec.messages, hasLength(2));
  });
}
