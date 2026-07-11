// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

/// Non-web stub of the control-stylesheet installer: there is no live
/// document to install into (VM component tests, server-side pre-rendering).
/// On the client the web implementation installs the sheet on first control
/// build; hover/pressed feedback is a browser-only concern, so tests that
/// never layout lose nothing.
void ensureCoreControlStyleSheet(String css) {}
