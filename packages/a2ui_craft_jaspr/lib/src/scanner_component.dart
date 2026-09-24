// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:a2ui_craft/a2ui_craft.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr/jaspr.dart';

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
        final String accentColor = isQr ? '#38BDF8' : '#F43F5E';
        final String bgColor = isQr ? '#1E293B' : '#0F172A';
        final String title = isQr
            ? 'Native 2D QR Scanner (Active)'
            : 'Native 1D Barcode Scanner (Active)';
        final String subtitle = isQr
            ? 'Live camera stream @ 60fps • Neural viewfinder target tracking'
            : 'Hardware laser raster engine • Code 128 / EAN symbology';
        final String buttonLabel = isQr
            ? 'Simulate Scan (QR: PROD-2026-X99)'
            : 'Simulate Scan (Barcode: BARCODE-128-4455)';
        final String code = isQr ? 'QR-PROD-2026-X99' : 'BARCODE-128-4455';

        return div(
          styles: Styles(
            raw: <String, String>{
              'background-color': bgColor,
              'border': '2px solid $accentColor',
              'border-radius': '8px',
              'padding': '16px',
              'margin': '8px 0',
              'color': '#FFFFFF',
              'display': 'flex',
              'flex-direction': 'column',
              'box-sizing': 'border-box',
            },
          ),
          <Component>[
            div(
              styles: Styles(
                raw: <String, String>{
                  'font-weight': 'bold',
                  'font-size': '16px',
                  'margin-bottom': '6px',
                  'color': accentColor,
                },
              ),
              <Component>[Component.text(title)],
            ),
            div(
              styles: Styles(
                raw: <String, String>{
                  'font-size': '12px',
                  'margin-bottom': '12px',
                  'color': 'rgba(255, 255, 255, 0.7)',
                },
              ),
              <Component>[Component.text(subtitle)],
            ),
            button(
              key: const Key('simulate_scan_button'),
              type: ButtonType.button,
              onClick: () {
                source.voidHandler(
                  const <Object>['onDetected'],
                  <String, Object?>{'code': code},
                )?.call();
              },
              styles: Styles(
                raw: <String, String>{
                  'padding': '8px 16px',
                  'border-radius': '6px',
                  'background-color': accentColor,
                  'color': '#000000',
                  'font-weight': 'bold',
                  'cursor': 'pointer',
                  'border': 'none',
                  'font-family': 'inherit',
                  'align-self': 'flex-start',
                },
              ),
              <Component>[Component.text(buttonLabel)],
            ),
          ],
        );
      },
      meta: meta,
    ),
  });
}
