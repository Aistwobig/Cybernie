import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'routes/app_routes.dart';
import 'theme/app_theme.dart';

/// The root widget. main.dart only calls runApp(App()) — everything about
/// *how* the app is configured (theme, routes, DevicePreview wiring) lives
/// here instead, so main.dart stays a one-glance entry point.
class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CYBERNIE',
      debugShowCheckedModeBanner: false,

      // Required for DevicePreview to actually control the app.
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      theme: AppTheme.theme,

      initialRoute: AppRoutes.splash,
      routes: AppRoutes.routes,
    );
  }
}
