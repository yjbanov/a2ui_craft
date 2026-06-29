// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'generated_samples.g.dart';
import 'sample_spec.dart';

// The samples themselves are **code-free data** under `samples/<id>/` (template,
// schema, messages); `tool/gen_samples.dart` bakes them into [rawSamples] and the
// named `<id>Spec(framework)` accessors. Re-export those so callers keep using
// `greetingSpec(...)` etc.
export 'generated_samples.g.dart';

/// All sample specs, in gallery order, labelled for the given [framework] (used
/// where a sample shows which engine is rendering it, e.g. the greeting title).
List<SampleSpec> sampleSpecs(String framework) =>
    <SampleSpec>[for (final RawSample r in rawSamples) r.toSpec(framework)];
