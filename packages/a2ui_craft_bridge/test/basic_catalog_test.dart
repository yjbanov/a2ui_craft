// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:a2ui_craft_bridge/a2ui_craft_bridge.dart';
import 'package:test/test.dart';

void main() {
  group('a2uiBasicCatalogCall', () {
    test('Row/Column rename justify/align onto the primitive props', () {
      final ConstructorCall c = a2uiBasicCatalogCall('Row', <String, Object?>{
        'justify': 'spaceBetween',
        'align': 'center',
        'children': <Object?>[],
      });
      expect(c.name, 'Row');
      expect(c.arguments['mainAxisAlignment'], 'spaceBetween');
      expect(c.arguments['crossAxisAlignment'], 'center');
      expect(c.arguments.containsKey('justify'), isFalse);
      expect(c.arguments.containsKey('align'), isFalse);
      expect(c.arguments['children'], isEmpty); // child slot passes through
    });

    test('align defaults to stretch (A2UI default) when absent', () {
      final ConstructorCall c = a2uiBasicCatalogCall(
          'Column', <String, Object?>{'children': <Object?>[]});
      expect(c.arguments['crossAxisAlignment'], 'stretch');
    });

    test('Icon maps name->icon, Button maps action->onPressed', () {
      expect(
        a2uiBasicCatalogCall('Icon', <String, Object?>{'name': 'phone'})
            .arguments['icon'],
        'phone',
      );
      final ConstructorCall b = a2uiBasicCatalogCall(
          'Button', <String, Object?>{'action': 'cb', 'child': 'x'});
      expect(b.arguments['onPressed'], 'cb');
      expect(b.arguments.containsKey('action'), isFalse);
    });

    test('Text/Card/Image/Divider pass through unchanged', () {
      final ConstructorCall t = a2uiBasicCatalogCall(
          'Text', <String, Object?>{'text': 'hi', 'variant': 'caption'});
      expect(t.name, 'Text');
      expect(t.arguments['text'], 'hi');
      expect(t.arguments['variant'], 'caption');
    });
  });
}
