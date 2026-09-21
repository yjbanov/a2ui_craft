// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:test/test.dart';

void main() {
  test('every code-free sample trio decodes into a usable SampleSpec', () {
    final List<SampleSpec> specs = sampleSpecs();
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

  test(
      'samples contain no {{framework}} tokens and use media.engine dynamically',
      () {
    for (final RawSample sample in rawSamples) {
      expect(sample.template.contains('{{framework}}'), isFalse,
          reason: '${sample.id} template has {{framework}}');
      expect(sample.messages.contains('{{framework}}'), isFalse,
          reason: '${sample.id} messages have {{framework}}');
    }
    final SampleSpec featureDetection = featureDetectionSpec();
    expect(featureDetection.catalogSource.contains('media.engine'), isTrue);
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
