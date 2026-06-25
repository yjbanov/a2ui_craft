// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

import 'sample.dart';
import 'samples/counter.dart';
import 'samples/gallery.dart';
import 'samples/greeting.dart';
import 'samples/profile_card.dart';

/// One entry in the gallery's navigation.
typedef _Entry = ({String label, Sample sample});

const List<_Entry> _entries = <_Entry>[
  (label: 'Greeting', sample: GreetingSample()),
  (label: 'Counter', sample: CounterSample()),
  (label: 'Profile Card', sample: ProfileCardSample()),
  (label: 'Image Gallery', sample: GallerySample()),
];

/// A simple gallery shell that shows one [Sample] at a time. Each sample is
/// fully self-contained (its own catalog, runtime, and surface), so switching
/// tabs tears the old one down and builds the next from scratch.
class App extends StatefulComponent {
  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  int _index = 0;

  @override
  Component build(BuildContext context) {
    return div(
      styles: Styles(
        display: Display.flex,
        flexDirection: FlexDirection.row,
        height: Unit.vh(100),
      ),
      [
        div(
          styles: Styles(
            display: Display.flex,
            flexDirection: FlexDirection.column,
            width: Unit.pixels(200),
            padding: Padding.all(Unit.pixels(20)),
            border: Border.all(color: Colors.blue, width: Unit.pixels(1)),
          ),
          [
            for (var i = 0; i < _entries.length; i++) ...[
              button(
                onClick: () => setState(() => _index = i),
                [Component.text(_entries[i].label)],
              ),
              div(styles: Styles(height: Unit.pixels(10)), []),
            ],
          ],
        ),
        div(
          styles: Styles(
            flex: Flex(grow: 1),
            display: Display.flex,
            justifyContent: JustifyContent.center,
            alignItems: AlignItems.center,
          ),
          [
            div(
              styles: Styles(
                padding: Padding.all(Unit.pixels(20)),
                border: Border.all(color: Colors.blue, width: Unit.pixels(2)),
                radius: BorderRadius.circular(Unit.pixels(8)),
              ),
              // The differing runtimeType per sample guarantees a fresh,
              // isolated sample (and runtime/surface) on every switch.
              [_entries[_index].sample],
            ),
          ],
        ),
      ],
    );
  }
}
