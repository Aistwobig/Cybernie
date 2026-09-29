/// Every user-facing string in the app, in one place.
/// Keeps widgets free of hardcoded text and makes copy changes (or future
/// translation) a one-file job instead of a hunt through every screen.
class AppStrings {
  // Splash screen
  static const String appName = 'CYBERNIE';
  static const String tagline = 'A SAFE SOCIAL SPACE';
  static const String tapToContinue = 'TAP TO CONTINUE';

  // Login screen
  static const String signInPrompt = 'Sign in with your Google account';
  static const String signInWithGoogle = 'SIGN IN WITH GOOGLE';
  static const String googleSignInError =
      'Google sign-in failed. Please try again.';
  static const String safetyNote =
      'SAFETY NOTE: Your information is protected and will never be shared.';
  static const String noAccountPrompt = "Don't have an account?";
  static const String registerWithGoogle = 'REGISTER WITH GOOGLE';
  static const String signOut = 'Sign out';

  // Welcome / character screen
  static String welcomeGreeting(String name) => 'Welcome, $name!';
  static const String characterPreviewLabel = 'CHARACTER PREVIEW';
  static const String joinRoomButton = 'JOIN ROOM';
  static const String navHome = 'HOME';
  static const String navFriends = 'FRIENDS';
  static const String navProfile = 'PROFILE';

  // Profile screen
  static const String profileTitle = 'Profile';
  static const String profilePlayerName = 'Player';
  static const String profileLevel = 'Level 12';
  static const String chooseCharacter = 'Choose a Character';
  static const String characterLuna = 'Luna';
  static const String characterRogue = 'Rogue';
  static const String characterMage = 'Mage';
  static const String characterLily = 'Lily';
  static const String characterDancer = 'Dancer';
  static const String moreCharacters = '+ MORE';
  static const String saveButton = 'SAVE';
  static const String editPlayerName = 'Edit player name';
  static const String playerNameLabel = 'Player name';
  static const String cancelButton = 'CANCEL';
  static const String profileSaved = 'Profile saved';
  static const String profileSaveError =
      'Could not save your profile. Check your connection and try again.';
  static const String moreCharactersComingSoon = 'More characters coming soon';
  static const String editProfilePicture = 'Choose a profile photo';
  static const String profilePhotoPickerError =
      'Unable to open photos. Please try again.';

  // Select room screen
  static const String selectRoomTitle = 'Select Room';
  static const String tavernRoomName = "Bernie's Tavern";
  static String tavernRoomDetails(int players, int max) =>
      '$players / $max Players • 1 voice channel';
  static String playerCount(int players, int max) => '$players / $max';
  static const String roomFullButton = 'ROOM FULL';
  static const String roomConnectionError =
      "Couldn't connect to the room. Other players may not be visible.";
  static const String joinButton = 'JOIN';
  static const String leaveRoomButton = 'LEAVE ROOM';
  static const String hitboxesButton = 'HITBOXES';
  static const String chatHint = 'Type a message...';
  static const String chatSendError = 'Message not sent. Please try again.';
  static const String chatSignInRequired = 'Sign in to chat.';
  static const String moreRoomsComingSoon = 'MORE ROOMS — COMING SOON';
}
