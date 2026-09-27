// Single entry point: DevicePreview setup, theme, and all named routes
// live here now instead of being split across app.dart / routes/app_routes.dart.

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';

import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/profile_screen.dart';

// import 'screens/select_room_screen.dart';
// import 'screens/tavern_room_screen.dart';
// import 'screens/register_screen.dart';
// import 'screens/add_friends_screen.dart';
// import 'screens/profile_screen.dart';

void main() {
  runApp(DevicePreview(enabled: true, builder: (context) => const App()));
}

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

      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        '/login': (context) => const LoginScreen(),
        '/welcome': (context) => const WelcomeScreen(),
        '/friends': (context) => const FriendsScreen(),
        '/profile': (context) => const ProfileScreen(),
        // '/rooms': (context) => const SelectRoomScreen(),
        // '/rooms/tavern': (context) => const TavernRoomScreen(),
        // '/register': (context) => const RegisterScreen(),
        // '/friends/add': (context) => const AddFriendsScreen(),
      },
    );
  }
}
