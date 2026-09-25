import 'package:flutter/material.dart';
import '../../screens/splash_screen.dart';
// import '../screens/login_screen.dart';
// import '../screens/welcome_screen.dart';
// import '../screens/select_room_screen.dart';
// import '../screens/tavern_room_screen.dart';
// import '../screens/register_screen.dart';
// import '../screens/friends_screen.dart';
// import '../screens/add_friends_screen.dart';
// import '../screens/profile_screen.dart';

/// Every route name lives here as a constant, so a typo in a route string
/// becomes a compile error instead of a silent navigation bug.
class AppRoutes {
  static const splash = '/';
  static const login = '/login';
  static const welcome = '/welcome';
  static const selectRoom = '/rooms';
  static const tavernRoom = '/rooms/tavern';
  static const register = '/register';
  static const friends = '/friends';
  static const addFriends = '/friends/add';
  static const profile = '/profile';

  /// The route table the MaterialApp consumes.
  /// Uncomment each screen's import above as you build it,
  /// then add its entry here.
  static Map<String, WidgetBuilder> get routes => {
        splash: (context) => const SplashScreen(),
        // login: (context) => const LoginScreen(),
        // welcome: (context) => const WelcomeScreen(),
        // selectRoom: (context) => const SelectRoomScreen(),
        // tavernRoom: (context) => const TavernRoomScreen(),
        // register: (context) => const RegisterScreen(),
        // friends: (context) => const FriendsScreen(),
        // addFriends: (context) => const AddFriendsScreen(),
        // profile: (context) => const ProfileScreen(),
      };
}
