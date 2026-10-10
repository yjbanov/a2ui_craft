// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:flutter/material.dart';

import 'runtime.dart';

/// Creates a [LocalWidgetLibrary] containing the `Scanner` primitive customized
/// to the simulated [profile].
LocalWidgetLibrary createScannerLibrary(ClientProfile profile) {
  final Map<String, Object?> meta = profile.metadata['Scanner'] ??
      const <String, Object?>{
        'version': 2,
        'capabilities': <String, Object?>{'qr': true, 'barcode': true},
        'args': <String, Object?>{'mode': true, 'onDetected': true},
      };

  return LocalWidgetLibrary(<String, Object>{
    'Scanner': LocalWidget(
      (BuildContext context, DataSource source) {
        final String mode = source.v<String>(const <Object>['mode']) ?? 'qr';
        final bool isQr = mode == 'qr';
        final Color accentColor =
            isQr ? const Color(0xFF38BDF8) : const Color(0xFFF43F5E);

        return Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isQr ? const Color(0xFF1E293B) : const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: accentColor, width: 2),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    isQr ? Icons.qr_code_scanner : Icons.view_week,
                    color: accentColor,
                    size: 24,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isQr
                        ? 'Native 2D QR Scanner (Active)'
                        : 'Native 1D Barcode Scanner (Active)',
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                isQr
                    ? 'Live camera stream @ 60fps • Neural viewfinder target tracking'
                    : 'Hardware laser raster engine • Code 128 / EAN symbology',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                key: const Key('simulate_scan_button'),
                onPressed: () {
                  final String code =
                      isQr ? 'QR-PROD-2026-X99' : 'BARCODE-128-4455';
                  source.voidHandler(
                    const <Object>['onDetected'],
                    <String, Object?>{'code': code},
                  )?.call();
                },
                icon: const Icon(Icons.play_arrow, size: 16),
                label: Text(
                  isQr
                      ? 'Simulate Scan (QR: PROD-2026-X99)'
                      : 'Simulate Scan (Barcode: BARCODE-128-4455)',
                ),
              ),
            ],
          ),
        );
      },
      meta: meta,
    ),
  });
}
