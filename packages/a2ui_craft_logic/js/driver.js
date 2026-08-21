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
    var inTurn = false;

    function post(type, body) {
      if (state === 'faulted' || state === 'terminated') return;
      // Serialize BEFORE claiming a sequence number: a value JSON cannot
      // carry must not burn a seq, or the host sees a gap in the stream and
      // faults with a misleading "out of order" instead of the real cause.
      var text;
      try {
        text = JSON.stringify({ seq: outSeq + 1, type: type, body: body });
      } catch (error) {
        if (type === 'error') {
          // The unencodable thing IS the error report; latching quietly is
          // all that is left.
          state = 'faulted';
          pending = [];
          return;
        }
        fault('driverCrash', 'A frame was not JSON-encodable: ' + error);
        return;
      }
      outSeq += 1;
      global.postMessage(text);
    }

    // Says why before latching. A driver that latches silently is
    // indistinguishable from a hung one: a host with a heartbeat misreports
    // it seconds later as a lost heartbeat, and a host without one waits
    // forever. The Dart runtime reports its failures; so must this side.
    function fault(code, reason) {
      post('error', { code: code, message: reason });
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
        guardEscape();
      },
      send: function (messages) {
        for (var i = 0; i < messages.length; i++) pending.push(messages[i]);
        guardEscape();
      },
      fail: function (code, message, details) {
        pending = [];
        post('error', {
          code: code,
          message: message,
          details: details === undefined ? null : details,
        });
        state = 'faulted';
      },
      diagnostic: function (message) {
        // Loud by default; a production build passes `diagnostics: false`.
        if (spec.diagnostics === false) return;
        if (global.console && global.console.warn) {
          global.console.warn('[a2ui.driver] ' + message);
        }
      },
    };

    // Catches a write that arrived after its handler already returned — a
    // promise the handler forgot to return or await:
    //
    //     handlers: {
    //       save: function (ctx) {
    //         fetch(url).then(function (r) { ctx.write('/x', r); });  // lost
    //       },
    //     }
    //
    // Left alone that write would sit in the batch until some later, unrelated
    // handler flushed it — out of order, attributed to the wrong event, or
    // never at all. So it is reported and sent on its own.
    //
    // This matters more here than in Dart: there is no `unawaited_futures`
    // lint on this side, so the runtime check is the only thing standing
    // between an author and a silent divergence.
    function guardEscape() {
      if (inTurn) return;
      context.diagnostic(
          'A write arrived outside any handler turn — a promise was probably ' +
          'not returned or awaited. It is being sent on its own rather than ' +
          "folded into the next handler's batch, but the ordering the driver " +
          'intended is lost. Return the promise from your handler.');
      flush();
    }

    // Handlers are chained, so the next event waits for this one — a driver
    // never observes two of its own handlers interleaving its state.
    function run(fn) {
      chain = chain.then(function () {
        inTurn = true;
        return fn();
      }).then(function () {
        inTurn = false;
        flush();
      }, function (error) {
        inTurn = false;
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
      if (!frame || frame.seq !== inSeq + 1) {
        return fault('outOfOrder',
            'Expected frame #' + (inSeq + 1) + ', got #' +
            (frame && frame.seq) + '. A message was lost, duplicated, or ' +
            'reordered.');
      }
      inSeq = frame.seq;
      var body = frame.body || {};
      switch (frame.type) {
        case 'init':
          if (state !== 'handshaking') {
            return fault('illegalMessage',
                "An 'init' is not legal while the session is " + state + '.');
          }
          if (body.protocolVersion !== PROTOCOL_VERSION) {
            return fault('versionSkew',
                'This driver speaks protocol ' + PROTOCOL_VERSION +
                '; the host speaks ' + body.protocolVersion + '.');
          }
          state = 'ready';
          surfaceId = body.surfaceId;
          hostContext = body.context || {};
          if (spec.onInit) run(function () { return spec.onInit(context); });
          return;
        case 'event':
          if (state !== 'ready') {
            return fault('illegalMessage',
                "An 'event' is not legal while the session is " + state + '.');
          }
          run(function () { return dispatch(body); });
          return;
        case 'ping':
          if (state !== 'ready') {
            return fault('illegalMessage',
                "A 'ping' is not legal while the session is " + state + '.');
          }
          post('pong', { nonce: body.nonce });
          return;
        case 'terminate':
          state = 'terminated';
          // The author's chance to cancel what they opened. A worker is
          // usually killed outright and never sees this; a driver that does
          // must not be able to take the runtime down with it.
          //
          // On the handler chain, like every other author callback: a driver
          // suspended on a promise must not have its teardown run underneath
          // it. The Dart runtime states that as a contract, and a driver
          // ported between the two languages does not get to relearn it. The
          // chain is appended to directly rather than through `run`, whose
          // failure path would report a fault on a session that has already
          // ended.
          if (spec.onTerminate) {
            chain = chain.then(function () {
              return spec.onTerminate(body.reason);
            }).then(null, function (ignored) {});
          }
          return;
        case 'error':
          state = 'faulted';
          return;
        default:
          return fault('malformed', "Unknown frame type '" + frame.type + "'.");
      }
    }

    global.onmessage = function (event) {
      var frame;
      try {
        frame = JSON.parse(event.data);
      } catch (error) {
        return fault('malformed',
            'The channel carried something that is not JSON: ' + error);
      }
      receive(frame);
    };

    // The driver speaks first: a worker's readiness is not observable to the
    // host, so announcing it is the only way the host learns of it.
    post('hello', { protocolVersion: PROTOCOL_VERSION, capabilities: [] });
    state = 'handshaking';
  }

  global.a2uiDriver = a2uiDriver;
})(self);
