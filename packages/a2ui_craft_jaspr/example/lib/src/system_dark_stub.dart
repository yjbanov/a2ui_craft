// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Non-browser stand-in (VM tests, server prerender): no dark preference and
/// no change notifications. The browser implementation is
/// `system_dark_web.dart`, selected by the conditional export in
/// `../system_dark.dart`.
bool systemPrefersDark() => false;

void watchSystemDark(void Function(bool dark) onChange) {}
