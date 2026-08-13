// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// The sustained frame rate a driver channel allows, per second, per direction.
///
/// Calibrated to clear any humanly-produceable rate by a wide margin, because
/// the cost of guessing low is a legitimate user hitting a wall and the cost of
/// guessing high is a runaway loop taking a few hundred milliseconds longer to
/// stop. A fast tapper manages perhaps ten actions a second; a tremor or a stuck
/// key might treble that. Thirty a second, *sustained*, is not a person.
///
/// It is also not where continuous interaction is supposed to live: a dragged
/// slider or a per-keystroke edit echoes locally through two-way binding, and
/// the driver hears about the outcome, not the trajectory. A template wired to
/// fire a business event per intermediate value is mis-tiered, and this ceiling
/// is where that shows up.
const double defaultChannelRatePerSecond = 30;

/// How far a driver channel may run ahead of [defaultChannelRatePerSecond]
/// before it halts, in frames.
///
/// Four seconds of headroom: enough that a burst of genuine activity — a page
/// of controls initialising, a user hammering a button in frustration — never
/// trips it, and small enough that a loop emitting as fast as it can is stopped
/// in well under a second.
const int defaultChannelBurst = 120;

/// A leaky-bucket rate limiter.
///
/// Holds up to [capacity] tokens and refills at [refillPerSecond]. Draining it
/// is not a signal to slow down — the channel does not throttle or coalesce —
/// it is the definition of overload, and overload halts the session.
class TokenBucket {
  /// Creates a bucket that starts full.
  ///
  /// [clock] reports elapsed time since some fixed origin; the default is a
  /// stopwatch started here. Tests supply their own so a flood can be produced
  /// without waiting for one.
  TokenBucket({
    this.capacity = defaultChannelBurst,
    this.refillPerSecond = defaultChannelRatePerSecond,
    Duration Function()? clock,
  })  : _tokens = capacity.toDouble(),
        _clock = clock ?? _stopwatchClock() {
    _last = _clock();
  }

  /// The most tokens the bucket holds — the burst allowance.
  final int capacity;

  /// How fast tokens return, per second.
  final double refillPerSecond;

  final Duration Function() _clock;
  double _tokens;
  late Duration _last;

  /// Tokens currently available, after refilling for elapsed time.
  double get available {
    _refill();
    return _tokens;
  }

  /// Takes [count] tokens, or returns `false` if there are not that many.
  ///
  /// A refusal takes nothing: a caller that halts on `false` and one that
  /// retries later see the same bucket.
  bool tryConsume([int count = 1]) {
    _refill();
    if (_tokens < count) return false;
    _tokens -= count;
    return true;
  }

  void _refill() {
    final Duration now = _clock();
    final double seconds = (now - _last).inMicroseconds / 1000000;
    if (seconds <= 0) return;
    _last = now;
    _tokens = (_tokens + seconds * refillPerSecond).clamp(
      0,
      capacity.toDouble(),
    );
  }

  static Duration Function() _stopwatchClock() {
    final Stopwatch stopwatch = Stopwatch()..start();
    return () => stopwatch.elapsed;
  }
}

/// The pair of budgets guarding a driver channel — one per direction.
///
/// Both directions are guarded because both can flood. A driver spamming
/// updates is the async-amplification attack arriving over a wire; a template
/// mis-wired to fire a business event per intermediate value is the same
/// problem pointed the other way. Neither is a rate to accommodate.
class ChannelBudgets {
  /// Creates a pair of buckets with the default calibration.
  ///
  /// Pass [clock] to drive both from a test's own notion of time.
  ChannelBudgets({
    int capacity = defaultChannelBurst,
    double refillPerSecond = defaultChannelRatePerSecond,
    Duration Function()? clock,
  })  : outbound = TokenBucket(
          capacity: capacity,
          refillPerSecond: refillPerSecond,
          clock: clock,
        ),
        inbound = TokenBucket(
          capacity: capacity,
          refillPerSecond: refillPerSecond,
          clock: clock,
        );

  /// Guards user events travelling to the driver.
  final TokenBucket outbound;

  /// Guards frames arriving from the driver.
  ///
  /// An update frame costs one token per A2UI message it carries, not one per
  /// frame: a batch of ten thousand writes is exactly the flood this exists to
  /// stop, and it would otherwise cost the same as a single one.
  final TokenBucket inbound;
}
