// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';

import 'sample.dart';
import 'samples/counter.dart';
import 'samples/gallery.dart';
import 'samples/greeting.dart';
import 'samples/profile_card.dart';

void main() {
  runApp(const GalleryApp());
}

/// One entry in the gallery's navigation.
typedef _Entry = ({String label, IconData icon, Sample sample});

const List<_Entry> _entries = <_Entry>[
  (label: 'Greeting', icon: Icons.message, sample: GreetingSample()),
  (label: 'Counter', icon: Icons.add, sample: CounterSample()),
  (label: 'Profile Card', icon: Icons.person, sample: ProfileCardSample()),
  (label: 'Image Gallery', icon: Icons.image, sample: GallerySample()),
];

/// A simple gallery shell that shows one [Sample] at a time. Each sample is
/// fully self-contained (its own catalog, runtime, and surface), so switching
/// tabs tears the old one down and builds the next from scratch.
class GalleryApp extends StatefulWidget {
  const GalleryApp({super.key});

  @override
  State<GalleryApp> createState() => _GalleryAppState();
}

class _GalleryAppState extends State<GalleryApp> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: _index,
              onDestinationSelected: (int index) =>
                  setState(() => _index = index),
              labelType: NavigationRailLabelType.all,
              destinations: <NavigationRailDestination>[
                for (final _Entry entry in _entries)
                  NavigationRailDestination(
                    icon: Icon(entry.icon),
                    label: Text(entry.label),
                  ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.blue, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  // The key ensures a fresh, isolated sample on every switch.
                  child: KeyedSubtree(
                    key: ValueKey<int>(_index),
                    child: _entries[_index].sample,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
