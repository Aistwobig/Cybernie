// Entry point only. All configuration (theme, routes, screens) lives in
// their own files under lib/ — see app.dart, theme/, routes/, and screens/.
//
// DevicePreview is left ON in the deployed build on purpose: your live link
// is opened on a desktop browser, and a phone layout at full desktop width
// looks broken when it isn't wrapped in a frame.
//
// Want it off for a portfolio build instead? Import
//   'package:flutter/foundation.dart' show kReleaseMode;
// and set `enabled: !kReleaseMode`.

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'app.dart';

void main() {
  runApp(
    DevicePreview(
      enabled: true,
      builder: (context) => const App(),
    ),
  );
}