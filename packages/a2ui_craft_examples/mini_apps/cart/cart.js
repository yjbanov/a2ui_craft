// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.
//
// The cart mini-app's business logic, in JavaScript — the same state machine as
// `lib/src/mini_apps/cart_driver.dart`, written against the same protocol.
//
// This file is the whole point of the exercise. The template does not know it
// exists, the engine is written in a different language, and the conformance
// script that drives the Dart version drives this one unchanged. If the two
// ever diverge in behaviour, the suite says so.

var inventory = [
  {
    sku: 'kbd',
    name: 'Mechanical keyboard',
    detail: 'Tactile switches, no backlight, two-year warranty.',
    priceCents: 8900,
    stock: 3,
  },
  {
    sku: 'mug',
    name: 'Enamel mug',
    detail: 'Holds 350ml. Dishwasher safe, microwave regrettably not.',
    priceCents: 1500,
    stock: 12,
  },
  {
    sku: 'cbl',
    name: 'Braided USB-C cable',
    detail: 'Two metres, 100W, and it survives being wound round a laptop.',
    priceCents: 2200,
    stock: 2,
  },
];

var quantities = {};

function productFor(sku) {
  for (var i = 0; i < inventory.length; i++) {
    if (inventory[i].sku === sku) return inventory[i];
  }
  return null;
}

function held(sku) {
  return Object.prototype.hasOwnProperty.call(quantities, sku);
}

function totalCents() {
  var total = 0;
  for (var i = 0; i < inventory.length; i++) {
    var p = inventory[i];
    if (held(p.sku)) total += p.priceCents * quantities[p.sku];
  }
  return total;
}

function dollars(cents) {
  return '$' + Math.floor(cents / 100) + '.' +
      String(cents % 100).padStart(2, '0');
}

function asInt(value) {
  if (typeof value === 'number') return Math.round(value);
  if (typeof value === 'string') {
    var parsed = parseInt(value.trim(), 10);
    return isNaN(parsed) ? null : parsed;
  }
  return null;
}

// Writes the whole cart. Every write in one handler lands together, so the
// rows, the total, and the status line can never disagree on screen.
function publish(ctx, status) {
  var items = [];
  for (var i = 0; i < inventory.length; i++) {
    var p = inventory[i];
    if (!held(p.sku)) continue;
    items.push({
      sku: p.sku,
      name: p.name,
      detail: p.detail,
      // A string, because the quantity field is a text field and its optimistic
      // echo writes back a string.
      qty: String(quantities[p.sku]),
      lineCents: p.priceCents * quantities[p.sku],
    });
  }
  ctx.write('/cart/items', items);
  ctx.write('/cart/totalCents', totalCents());
  ctx.write('/cart/status', status);
}

a2uiDriver({
  onInit: function (ctx) {
    publish(ctx, 'Cart ready. Add something.');
  },
  handlers: {
    addItem: function (ctx, event) {
      var next = null;
      for (var i = 0; i < inventory.length && next === null; i++) {
        if (!held(inventory[i].sku)) next = inventory[i];
      }
      if (next === null) {
        publish(ctx, 'That is everything the shop has.');
        return;
      }
      quantities[next.sku] = 1;
      publish(ctx, 'Added ' + next.name + '.');
    },

    removeItem: function (ctx, event) {
      var sku = event.get('sku');
      if (!sku || !held(sku)) {
        publish(ctx, 'Nothing to remove.');
        return;
      }
      var product = productFor(sku);
      delete quantities[sku];
      publish(ctx, 'Removed ' + (product ? product.name : sku) + '.');
    },

    // The authoritative correction behind an optimistic echo: what arrives is
    // the value already on screen, and what leaves is the value the shop will
    // actually honour.
    setQuantity: function (ctx, event) {
      var sku = event.get('sku');
      var product = sku ? productFor(sku) : null;
      if (!product) {
        publish(ctx, 'Unknown item.');
        return;
      }
      var parsed = asInt(event.get('qty'));
      var requested = parsed === null
          ? (held(sku) ? quantities[sku] : 1)
          : parsed;
      var allowed = Math.min(Math.max(requested, 0), product.stock);
      if (allowed === 0) {
        delete quantities[sku];
        publish(ctx, 'Removed ' + product.name + '.');
        return;
      }
      quantities[sku] = allowed;
      publish(
          ctx,
          allowed === requested
              ? product.name + ': ' + allowed + '.'
              : 'Only ' + allowed + ' ' + product.name + ' in stock.');
    },

    checkout: function (ctx, event) {
      var skus = Object.keys(quantities);
      if (skus.length === 0) {
        publish(ctx, 'The cart is empty.');
        return;
      }
      var total = totalCents();
      var units = 0;
      for (var i = 0; i < skus.length; i++) units += quantities[skus[i]];
      quantities = {};
      publish(ctx, 'Ordered ' + units + ' item(s) for ' + dollars(total) + '.');
    },
  },
});
