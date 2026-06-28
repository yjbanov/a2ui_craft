// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `08_user-profile` — a centered `Card`
/// with an avatar, a `Heading` name + handle, a bio, a three-stat `Row`, and a
/// follow `Button`. Counts are supplied already formatted (`formatNumber`);
/// image is an `example.com` placeholder.
SampleSpec userProfileSpec(String framework) => SampleSpec(
      label: 'User Profile',
      catalogSource: '''
import core;

widget Stat = Column(crossAxisAlignment: "center", gap: 2.0, children: [
  Text(text: args.value),
  Text(text: args.label, variant: "caption"),
]);

widget UserProfile = Card(child: Column(crossAxisAlignment: "center", gap: 8.0,
  children: [
    Image(url: args.avatar, variant: "avatar", fit: "cover"),
    Column(crossAxisAlignment: "center", gap: 2.0, children: [
      Heading(text: args.name, level: 2),
      Text(text: args.username, variant: "caption"),
    ]),
    Text(text: args.bio),
    Row(mainAxisAlignment: "spaceAround", width: "fill", children: [
      Stat(value: args.followers, label: "Followers"),
      Stat(value: args.following, label: "Following"),
      Stat(value: args.posts, label: "Posts"),
    ]),
    Button(child: Text(text: args.followText)),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'UserProfile': <String, Object?>{
            'properties': <String, Object?>{
              'avatar': <String, Object?>{r'$ref': 'DynamicString'},
              'name': <String, Object?>{r'$ref': 'DynamicString'},
              'username': <String, Object?>{r'$ref': 'DynamicString'},
              'bio': <String, Object?>{r'$ref': 'DynamicString'},
              'followers': <String, Object?>{r'$ref': 'DynamicString'},
              'following': <String, Object?>{r'$ref': 'DynamicString'},
              'posts': <String, Object?>{r'$ref': 'DynamicString'},
              'followText': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'UserProfile',
              'avatar': 'https://example.com/sarah.jpg',
              'name': 'Sarah Chen',
              'username': '@sarahchen',
              'bio': 'Product Designer at Tech Co. Creating delightful '
                  'experiences.',
              'followers': '12.4K',
              'following': '892',
              'posts': '347',
              'followText': 'Follow',
            },
          ],
        ),
      ],
    );
