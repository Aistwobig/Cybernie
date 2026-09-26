/// Every user-facing string in the app, in one place.
/// Keeps widgets free of hardcoded text and makes copy changes (or future
/// translation) a one-file job instead of a hunt through every screen.
class AppStrings {
  // Splash screen
  static const String appName = 'CYBERNIE';
  static const String tagline = 'A SAFE SOCIAL SPACE';
  static const String tapToContinue = 'TAP TO CONTINUE';

  // Login screen
  static const String usernameLabel = 'USERNAME';
  static const String usernameHint = 'Enter your username';
  static const String passwordLabel = 'PASSWORD';
  static const String passwordHint = 'Enter your password';
  static const String logInButton = 'LOG IN';
  static const String safetyNote =
      'SAFETY NOTE: Your information is protected and will never be shared.';
  static const String noAccountPrompt = "Don't have an account?";
  static const String registerButton = 'REGISTER';
}