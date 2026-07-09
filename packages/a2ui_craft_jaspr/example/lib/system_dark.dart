// Copyright 2013 The Flutter Authors
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

// The system dark-light preference — the host's render-time mode input
// (DESIGN.md §9.5). Conditionally implemented: the browser reads (and
// watches) `prefers-color-scheme`; on the VM (tests) it is a no-preference
// stub, so the gallery renders Light there by default.
export 'src/system_dark_stub.dart'
    if (dart.library.js_interop) 'src/system_dark_web.dart';
