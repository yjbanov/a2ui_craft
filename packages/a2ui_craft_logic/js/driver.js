// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// The A2UI Craft driver SDK for JavaScript — one file, no dependencies, no
// build step. It is the JavaScript half of the language-neutrality claim: a
// driver written against this speaks the same session protocol as one written
// in Dart, and the host cannot tell which it is talking to.
//
// Load it in a worker and describe your logic:
//
//     a2uiDriver({
//       onInit(ctx) { ctx.write('/status', 'ready'); },
//       handlers: {
//         addItem(ctx, event) { ctx.write('/count', 1); },
//       },
//     });
//
// Everything crossing the boundary is JSON. The SDK batches each handler's
// writes into one update, so a handler's effects land all at once or not at
// all, and it serializes handlers so two never interleave.

(function (global) {
  'use strict';

  var PROTOCOL_VERSION = '0.1';

  function a2uiDriver(spec) {
    var outSeq = 0;
    var inSeq = 0;
    var state = 'connecting';
    var surfaceId = null;
    var hostContext = {};
    var pending = [];
    var chain = Promise.resolve();
    var handlers = spec.handlers || {};
    var fired = {};

    function post(type, body) {
      if (state === 'faulted' || state === 'terminated') return;
      outSeq += 1;
      global.postMessage(JSON.stringify({
        seq: outSeq,
        type: type,
        body: body,
      }));
    }

    function fault(reason) {
      state = 'faulted';
      pending = [];
    }

    function flush() {
      if (pending.length === 0) return;
      var batch = pending;
      pending = [];
      post('update', { messages: batch });
    }

    var context = {
      get surfaceId() {
        return surfaceId;
      },
      get hostContext() {
        return hostContext;
      },
      write: function (path, value) {
        pending.push({
          version: 'v0.9',
          updateDataModel: {
            surfaceId: surfaceId,
            path: path,
            value: value,
          },
        });
      },
      send: function (messages) {
        for (var i = 0; i < messages.length; i++) pending.push(messages[i]);
      },
      fail: function (code, message, details) {
        pending = [];
        post('error', {
          code: code,
          message: message,
          details: details === undefined ? null : details,
        });
        fault(message);
      },
      diagnostic: function (message) {
        // Loud by default; a production build passes `diagnostics: false`.
        if (spec.diagnostics === false) return;
        if (global.console && global.console.warn) {
          global.console.warn('[a2ui.driver] ' + message);
        }
      },
    };

    // Handlers are chained, so the next event waits for this one — a driver
    // never observes two of its own handlers interleaving its state.
    function run(fn) {
      chain = chain.then(function () {
        return fn();
      }).then(flush, function (error) {
        pending = [];
        context.fail('handlerThrew', String(error));
      });
    }

    function dispatch(body) {
      var handler = handlers[body.name];
      if (!handler) {
        var known = Object.keys(handlers).sort().join(', ');
        context.diagnostic(
          "No handler for event '" + body.name + "', dispatched by '" +
          body.sourceComponentId + "'. This driver handles: " + known + '.');
        return;
      }
      fired[body.name] = true;
      return handler(context, {
        name: body.name,
        sourceComponentId: body.sourceComponentId,
        context: body.context || {},
        values: body.values || {},
        get: function (key) {
          var c = body.context || {};
          if (Object.prototype.hasOwnProperty.call(c, key)) return c[key];
          var v = body.values || {};
          return Object.prototype.hasOwnProperty.call(v, key) ? v[key] : null;
        },
      });
    }

    function receive(frame) {
      if (state === 'faulted' || state === 'terminated') return;
      if (!frame || frame.seq !== inSeq + 1) return fault('out of order');
      inSeq = frame.seq;
      var body = frame.body || {};
      switch (frame.type) {
        case 'init':
          if (state !== 'handshaking') return fault('illegal init');
          if (body.protocolVersion !== PROTOCOL_VERSION) {
            return fault('version skew');
          }
          state = 'ready';
          surfaceId = body.surfaceId;
          hostContext = body.context || {};
          if (spec.onInit) run(function () { return spec.onInit(context); });
          return;
        case 'event':
          if (state !== 'ready') return fault('illegal event');
          run(function () { return dispatch(body); });
          return;
        case 'ping':
          if (state !== 'ready') return fault('illegal ping');
          post('pong', { nonce: body.nonce });
          return;
        case 'terminate':
          state = 'terminated';
          return;
        case 'error':
          state = 'faulted';
          return;
        default:
          return fault('unknown frame type ' + frame.type);
      }
    }

    global.onmessage = function (event) {
      receive(JSON.parse(event.data));
    };

    // The driver speaks first: a worker's readiness is not observable to the
    // host, so announcing it is the only way the host learns of it.
    post('hello', { protocolVersion: PROTOCOL_VERSION, capabilities: [] });
    state = 'handshaking';
  }

  global.a2uiDriver = a2uiDriver;
})(self);
