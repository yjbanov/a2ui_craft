// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'sample_spec.dart';
import 'samples/boxes.dart';
import 'samples/contact_card.dart';
import 'samples/counter.dart';
import 'samples/form.dart';
import 'samples/gallery.dart';
import 'samples/greeting.dart';
import 'samples/profile_card.dart';
import 'samples/stats_card.dart';

/// All sample specs, in gallery order, labelled for the given [framework] (used
/// where a sample shows which engine is rendering it, e.g. the greeting title).
List<SampleSpec> sampleSpecs(String framework) => <SampleSpec>[
      greetingSpec(framework),
      counterSpec(framework),
      boxesSpec(framework),
      contactCardSpec(framework),
      statsCardSpec(framework),
      profileCardSpec(framework),
      gallerySpec(framework),
      formSpec(framework),
    ];
