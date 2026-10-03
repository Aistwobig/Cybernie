// Single entry point: DevicePreview setup, theme, and all named routes
// live here now instead of being split across app.dart / routes/app_routes.dart.

import 'package:device_preview/device_preview.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'config/supabase_config.dart';
import 'services/auth_service.dart';
import 'services/presence_service.dart';
import 'utils/app_nav.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/profile_screen.dart';

import 'screens/select_room_screen.dart';
import 'screens/tavern_room_screen.dart';
import 'screens/add_friends_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Also finishes a Google sign-in: when Google redirects back to the app,
  // this reads the session out of the URL before the first screen shows.
  if (SupabaseConfig.isConfigured) {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    // Marks the signed-in player as online while the app is open.
    PresenceService.start();
  } else {
    debugPrint(
      'Supabase is not configured: copy .env.example to .env and run with '
      '--dart-define-from-file=.env',
    );
  }

  await ThemeModeController.load();

  runApp(DevicePreview(enabled: true, builder: (context) => const App()));
}

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();

  static final Map<String, WidgetBuilder> _routes = {
    '/': (context) => const SplashScreen(),
    '/login': (context) => const LoginScreen(),
    '/welcome': (context) => const WelcomeScreen(),
    '/friends': (context) => const FriendsScreen(),
    '/profile': (context) => const ProfileScreen(),
    '/rooms': (context) => const SelectRoomScreen(),
    '/rooms/tavern': (context) => const TavernRoomScreen(),
    '/friends/add': (context) => const AddFriendsScreen(),
  };

  /// Bottom-nav tabs slide between each other (see AppNav.tabRoute); other
  /// screens use the normal page transition.
  static Route<dynamic>? _page(RouteSettings settings) {
    final builder = _routes[settings.name];
    if (builder == null) return null;
    return AppNav.tabs.contains(settings.name)
        ? AppNav.tabRoute(settings, builder)
        : MaterialPageRoute<void>(settings: settings, builder: builder);
  }

  /// The screens the app opens with (also used when a web page is reloaded
  /// on, say, #/friends). Flutter's default would put the splash screen
  /// underneath, so "back" or Home could land on it. Instead:
  /// signed out -> just the splash; signed in -> Welcome, plus the requested
  /// screen on top of it.
  static List<Route<dynamic>> _initialRoutes(String name) {
    Route<dynamic> page(String route) => _page(RouteSettings(name: route))!;

    if (!AuthService.isSignedIn) return [page('/')];
    const entryScreens = {'/', '/login', '/welcome'};
    if (entryScreens.contains(name) || !_routes.containsKey(name)) {
      return [page('/welcome')];
    }
    return [page('/welcome'), page(name)];
  }
}

class _AppState extends State<App> {
  @override
  void initState() {
    super.initState();
    ThemeModeController.night.addListener(_onModeChanged);
  }

  @override
  void dispose() {
    ThemeModeController.night.removeListener(_onModeChanged);
    super.dispose();
  }

  /// Screens read their colors from AppColors while building, so every
  /// widget (including const ones and screens further back in the stack)
  /// is rebuilt to pick up the new mode. Navigation and screen state stay.
  void _onModeChanged() {
    setState(() {});
    void rebuild(Element element) {
      element.markNeedsBuild();
      element.visitChildren(rebuild);
    }

    (context as Element).visitChildren(rebuild);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CYBERNIE',
      debugShowCheckedModeBanner: false,

      // Required for DevicePreview to actually control the app.
      locale: DevicePreview.locale(context),
      builder: DevicePreview.appBuilder,

      theme: AppTheme.theme,

      // Signed-in players skip the splash and login screens.
      initialRoute: AuthService.isSignedIn ? '/welcome' : '/',
      onGenerateInitialRoutes: App._initialRoutes,
      navigatorObservers: [AppNav.routeObserver],
      onGenerateRoute: App._page,
    );
  }
}
