// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_core/a2ui_core.dart';

import '../sample_spec.dart';

/// Templatized A2UI Basic Catalog example `10_notification-permission` — a
/// centered `Card` permission prompt: an `Icon`, a `Heading` title, a
/// description, and a Yes/No action `Row`.
SampleSpec notificationPermissionSpec(String framework) => SampleSpec(
      label: 'Permission',
      catalogSource: '''
import core;

widget NotificationPermission = Card(child: Column(crossAxisAlignment: "center",
  gap: 8.0, children: [
    Icon(icon: args.icon),
    Heading(text: args.title, level: 2),
    Text(text: args.description),
    Row(mainAxisAlignment: "center", gap: 12.0, children: [
      Button(child: Text(text: args.acceptLabel)),
      Button(child: Text(text: args.declineLabel)),
    ]),
  ]));
''',
      catalogSchema: <String, Object?>{
        'catalogId': catalogId,
        'components': <String, Object?>{
          'NotificationPermission': <String, Object?>{
            'properties': <String, Object?>{
              'icon': <String, Object?>{r'$ref': 'DynamicString'},
              'title': <String, Object?>{r'$ref': 'DynamicString'},
              'description': <String, Object?>{r'$ref': 'DynamicString'},
              'acceptLabel': <String, Object?>{r'$ref': 'DynamicString'},
              'declineLabel': <String, Object?>{r'$ref': 'DynamicString'},
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
              'component': 'NotificationPermission',
              'icon': 'notifications',
              'title': 'Enable notifications',
              'description': 'Get alerts for order status changes',
              'acceptLabel': 'Yes',
              'declineLabel': 'No',
            },
          ],
        ),
      ],
    );
