// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'sample_spec.dart';
import 'samples/account_balance.dart';
import 'samples/boxes.dart';
import 'samples/chat_message.dart';
import 'samples/child_list_template.dart';
import 'samples/coffee_order.dart';
import 'samples/contact_card.dart';
import 'samples/countdown_timer.dart';
import 'samples/counter.dart';
import 'samples/credit_card.dart';
import 'samples/event_detail.dart';
import 'samples/financial_data_grid.dart';
import 'samples/flight_status.dart';
import 'samples/form.dart';
import 'samples/gallery.dart';
import 'samples/greeting.dart';
import 'samples/interactive_button.dart';
import 'samples/layout.dart';
import 'samples/login_form.dart';
import 'samples/markdown_text.dart';
import 'samples/music_player.dart';
import 'samples/notification_permission.dart';
import 'samples/product_card.dart';
import 'samples/profile_card.dart';
import 'samples/purchase_complete.dart';
import 'samples/restaurant_card.dart';
import 'samples/row_layout.dart';
import 'samples/shipping_status.dart';
import 'samples/simple_text.dart';
import 'samples/sports_player.dart';
import 'samples/stats_card.dart';
import 'samples/step_counter.dart';
import 'samples/track_list.dart';
import 'samples/user_profile.dart';
import 'samples/weather.dart';
import 'samples/workout_summary.dart';

/// All sample specs, in gallery order, labelled for the given [framework] (used
/// where a sample shows which engine is rendering it, e.g. the greeting title).
List<SampleSpec> sampleSpecs(String framework) => <SampleSpec>[
      greetingSpec(framework),
      counterSpec(framework),
      boxesSpec(framework),
      layoutSpec(framework),
      contactCardSpec(framework),
      statsCardSpec(framework),
      profileCardSpec(framework),
      gallerySpec(framework),
      formSpec(framework),
      // Templatized A2UI Basic Catalog gallery examples.
      simpleTextSpec(framework),
      interactiveButtonSpec(framework),
      loginFormSpec(framework),
      weatherSpec(framework),
      productCardSpec(framework),
      restaurantCardSpec(framework),
      accountBalanceSpec(framework),
      shippingStatusSpec(framework),
      flightStatusSpec(framework),
      purchaseCompleteSpec(framework),
      coffeeOrderSpec(framework),
      creditCardSpec(framework),
      childListTemplateSpec(framework),
      markdownTextSpec(framework),
      musicPlayerSpec(framework),
      notificationPermissionSpec(framework),
      sportsPlayerSpec(framework),
      eventDetailSpec(framework),
      stepCounterSpec(framework),
      countdownTimerSpec(framework),
      rowLayoutSpec(framework),
      userProfileSpec(framework),
      chatMessageSpec(framework),
      workoutSummarySpec(framework),
      trackListSpec(framework),
      financialDataGridSpec(framework),
    ];
