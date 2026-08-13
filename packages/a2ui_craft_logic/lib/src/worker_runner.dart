// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import 'driver_sdk.g.dart';
import 'transport.dart';

/// Runs a driver in a **web worker** — the sandboxed reference runner, and the
/// proof that the coupling surface between a template and its logic really is
/// the protocol.
///
/// The driver runs in another language, in another execution context, with no
/// DOM and no access to anything the host holds. It gets the channel and
/// nothing else.
///
/// Frames cross as **JSON text**, not structured-cloned objects: it is what a
/// socket or a platform channel would carry anyway, it makes a
/// non-serializable value fail at the author's desk instead of at a transport
/// boundary later, and it keeps the JavaScript SDK free of any assumption about
/// which host is on the other end.
class WorkerDriverRunner implements DriverTransport {
  /// Runs the driver whose source is [source], in a worker started from a blob.
  ///
  /// The [driverSdkJs] is prepended, so an ephemeral mini-app ships exactly one
  /// file of logic and does not have to host or resolve the SDK separately.
  WorkerDriverRunner.fromSource(String source)
      : _url = web.URL.createObjectURL(
          web.Blob(
            <JSAny>['$driverSdkJs\n$source'.toJS].toJS,
            web.BlobPropertyBag(type: 'text/javascript'),
          ),
        ),
        _ownsUrl = true;

  /// Runs the driver served at [url].
  ///
  /// The production shape: a project's `logic.entry`, resolved against the
  /// bundle's base URL. The script must load the SDK itself.
  WorkerDriverRunner.fromUrl(String url)
      : _url = url,
        _ownsUrl = false;

  final String _url;
  final bool _ownsUrl;

  web.Worker? _worker;
  void Function(Map<String, Object?> frame)? _onFrame;
  void Function(String reason)? _onCrash;
  bool _closed = false;

  @override
  set onFrame(void Function(Map<String, Object?> frame)? handler) =>
      _onFrame = handler;

  @override
  set onCrash(void Function(String reason)? handler) => _onCrash = handler;

  @override
  void start() {
    if (_closed || _worker != null) return;
    final web.Worker worker = web.Worker(_url.toJS);
    _worker = worker;
    worker.onmessage = (web.MessageEvent event) {
      if (_closed) return;
      final Object? decoded = jsonDecode((event.data as JSString).toDart);
      if (decoded is Map<String, Object?>) _onFrame?.call(decoded);
    }.toJS;
    worker.onerror = (web.Event event) {
      if (_closed) return;
      // A worker that threw on load or at top level is gone; there is no
      // half-alive state to recover to.
      _onCrash?.call(
        'The driver worker failed: ${(event as web.ErrorEvent).message}',
      );
    }.toJS;
  }

  @override
  void send(Map<String, Object?> frame) {
    if (_closed) return;
    final String encoded;
    try {
      encoded = jsonEncode(frame);
    } catch (error) {
      _onCrash
          ?.call('The host sent a frame that is not JSON-encodable: $error');
      return;
    }
    _worker?.postMessage(encoded.toJS);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    _onFrame = null;
    _onCrash = null;
    // Stop the driver, not merely listening to it: a worker left running would
    // keep burning CPU for a surface that is already out of service.
    _worker?.terminate();
    _worker = null;
    if (_ownsUrl) web.URL.revokeObjectURL(_url);
  }
}
