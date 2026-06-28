// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft_examples/a2ui_craft_examples.dart';
import 'package:flutter/material.dart';

import 'sample.dart';

void main() {
  runApp(const GalleryApp());
}

/// The shared sample specs, labelled for this adapter.
final List<SampleSpec> _specs = sampleSpecs('Flutter');

/// Nav icons, parallel to [_specs].
const List<IconData> _icons = <IconData>[
  Icons.message,
  Icons.add,
  Icons.crop_square,
  Icons.dashboard,
  Icons.contact_page,
  Icons.bar_chart,
  Icons.person,
  Icons.image,
  Icons.edit_note,
  // Templatized A2UI gallery examples.
  Icons.notes,
  Icons.touch_app,
  Icons.login,
  Icons.wb_sunny,
  Icons.shopping_bag,
  Icons.restaurant,
  Icons.account_balance_wallet,
  Icons.local_shipping,
  Icons.flight,
  Icons.check_circle,
  Icons.coffee,
  Icons.credit_card,
  Icons.list,
];

/// A simple gallery shell that shows one [Sample] at a time. Each sample is
/// fully self-contained, so switching tabs tears the old one down and builds the
/// next from scratch.
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
            // The rail scrolls: with many samples the destinations exceed the
            // viewport height, and NavigationRail does not scroll on its own.
            LayoutBuilder(
              builder: (BuildContext context, BoxConstraints constraints) =>
                  SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minHeight: constraints.maxHeight),
                  child: IntrinsicHeight(
                    child: NavigationRail(
                      selectedIndex: _index,
                      onDestinationSelected: (int index) =>
                          setState(() => _index = index),
                      labelType: NavigationRailLabelType.all,
                      destinations: <NavigationRailDestination>[
                        for (var i = 0; i < _specs.length; i++)
                          NavigationRailDestination(
                            icon: Icon(_icons[i]),
                            label: Text(_specs[i].label),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
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
                  child: Sample(_specs[_index], key: ValueKey<int>(_index)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
