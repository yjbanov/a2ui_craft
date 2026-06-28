// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `06_music-player` — a `Card` with
/// album art, a `Heading` track title, a progress `Slider`, a time `Row`, and a
/// transport-control `Row` of icon `Button`s. Image is an `example.com`
/// placeholder; the progress value is a literal in the template.
SampleSpec musicPlayerSpec(String framework) => SampleSpec(
      label: 'Music Player',
      catalogSource: '''
import core;

widget MusicPlayer = Card(child: Column(crossAxisAlignment: "center", gap: 8.0,
  children: [
    Image(url: args.albumArt, variant: "mediumFeature", fit: "cover"),
    Column(crossAxisAlignment: "center", gap: 2.0, children: [
      Heading(text: args.title, level: 2),
      Text(text: args.artist, variant: "caption"),
    ]),
    Slider(value: 0.45, min: 0.0, max: 1.0),
    Row(mainAxisAlignment: "spaceBetween", width: "fill", children: [
      Text(text: args.currentTime, variant: "caption"),
      Text(text: args.totalTime, variant: "caption"),
    ]),
    Row(mainAxisAlignment: "center", gap: 16.0, children: [
      Button(child: Icon(icon: "skipPrevious")),
      Button(child: Icon(icon: args.playIcon)),
      Button(child: Icon(icon: "skipNext")),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'MusicPlayer': <String, Object?>{
            'properties': <String, Object?>{
              'albumArt': <String, Object?>{r'$ref': 'DynamicString'},
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'artist': <String, Object?>{r'$ref': 'DynamicString'},
              'currentTime': <String, Object?>{r'$ref': 'DynamicString'},
              'totalTime': <String, Object?>{r'$ref': 'DynamicString'},
              'playIcon': <String, Object?>{r'$ref': 'DynamicString'},
            },
          },
        },
      },
      messages: <A2uiMessage>[
        CreateSurfaceMessage(surfaceId: surfaceId, catalogId: catalogId),
        UpdateComponentsMessage(
          surfaceId: surfaceId,
          components: <Map<String, dynamic>>[
            <String, dynamic>{
              'id': 'root',
              'component': 'MusicPlayer',
              'albumArt': 'https://example.com/album.jpg',
              'title': 'Blinding Lights',
              'artist': 'The Weeknd',
              'currentTime': '1:48',
              'totalTime': '4:22',
              'playIcon': 'pause',
            },
          ],
        ),
      ],
    );
