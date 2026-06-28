// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `18_track-list` — a `Card` with a
/// playlist `Heading` header and a `...for` list of tracks, each a number, art,
/// an `Expanded` title/artist column, and a duration. Art is an `example.com`
/// placeholder.
SampleSpec trackListSpec(String framework) => SampleSpec(
      label: 'Track List',
      catalogSource: '''
import core;

widget TrackList = Card(child: Column(crossAxisAlignment: "stretch", gap: 8.0,
  children: [
    Row(gap: 6.0, crossAxisAlignment: "center", children: [
      Icon(icon: "play"),
      Heading(text: args.playlistName, level: 3),
    ]),
    Divider(),
    Column(gap: 8.0, children: [
      ...for track in args.tracks: Row(gap: 8.0, crossAxisAlignment: "center",
        children: [
          Text(text: track.number, variant: "caption"),
          Image(url: track.art, variant: "avatar", fit: "cover"),
          Expanded(child: Column(gap: 2.0, children: [
            Text(text: track.title),
            Text(text: track.artist, variant: "caption"),
          ])),
          Text(text: track.duration, variant: "caption"),
        ]),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'TrackList': <String, Object?>{
            'properties': <String, Object?>{
              'playlistName': <String, Object?>{r'$ref': 'DynamicString'},
              'tracks': <String, Object?>{
                'type': 'array',
                'items': <String, Object?>{'type': 'object'},
              },
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
              'component': 'TrackList',
              'playlistName': 'Focus Flow',
              'tracks': <Object?>[
                <String, Object?>{
                  'number': '1',
                  'art': 'https://example.com/track1.jpg',
                  'title': 'Weightless',
                  'artist': 'Marconi Union',
                  'duration': '8:09',
                },
                <String, Object?>{
                  'number': '2',
                  'art': 'https://example.com/track2.jpg',
                  'title': 'Clair de Lune',
                  'artist': 'Debussy',
                  'duration': '5:12',
                },
                <String, Object?>{
                  'number': '3',
                  'art': 'https://example.com/track3.jpg',
                  'title': 'Ambient Light',
                  'artist': 'Brian Eno',
                  'duration': '6:45',
                },
              ],
            },
          ],
        ),
      ],
    );
