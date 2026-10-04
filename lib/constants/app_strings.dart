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
  static const String welcomeLabel = 'WELCOME,';
  static const String enteringTavern = 'Opening the tavern doors...';
  static const String enteringTavernSubtitle = "Bernie's Tavern awaits.";
  static const String menuButton = 'Menu';
  static const String nightMode = 'Night mode';
  static const String dayMode = 'Day mode';
  static const String characterPreviewTitle = 'Character Preview';
  static const String characterPreviewSubtitle =
      'Customize your look and join the adventure.';
  static const String turnLeft = 'Turn left';
  static const String turnRight = 'Turn right';
  static String tavernAdventurers(int players, int max) =>
      '$players / $max adventurers in the tavern';
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
  static const String chooseCharacterSubtitle =
      'Select and customize your adventure look.';
  static String levelLabel(int level) => 'Level $level';
  static String levelProgress(int level, double progress) =>
      'Level $level, ${(progress * 100).round()}% to next level';
  static const String characterLuna = 'Luna';
  static const String characterRogue = 'Rogue';
  static const String characterMage = 'Mage';
  static const String characterLily = 'Lily';
  static const String characterDancer = 'Dancer';
  static const String characterSlime = 'Slime';
  static const String moreCharacters = '+ MORE';
  static const String saveButton = 'SAVE';
  static const String editPlayerName = 'Edit player name';
  static const String playerNameLabel = 'Player name';
  static const String cancelButton = 'CANCEL';
  static const String profileSaved = 'Profile saved';
  static const String profilePhotoSaved = 'Profile photo saved';
  static const String profilePhotoSaveError =
      "Couldn't save your photo. Please try again.";
  static const String profileSaveError =
      'Could not save your profile. Check your connection and try again.';
  static const String moreCharactersComingSoon = 'More characters coming soon';
  static const String editProfilePicture = 'Choose a profile photo';
  static const String profilePhotoPickerError =
      'Unable to open photos. Please try again.';

  // Friends screens
  static const String friendsTitle = 'Friends';
  static String viewFriend(String name) => 'View $name';
  static const String searchFriendsHint = 'Search friends...';
  static const String noFriendsYet =
      'No friends yet. Find players and send them a friend request.';
  static String noFriendsMatch(String query) => 'No friends match "$query"';
  static const String findPlayersButton = 'FIND PLAYERS';
  static const String noFriendsYetShort = 'No friends yet. Add someone below!';
  static String yourFriendsHeader(int count) => 'YOUR FRIENDS ($count)';
  static const String suggestedHeader = 'SUGGESTED FOR YOU';
  static const String noSuggestions =
      "You're connected with everyone who's joined so far.";
  static const String friendsLoadError = "Couldn't load your friends.";
  static const String retryButton = 'TRY AGAIN';
  static const String removeFriendButton = 'REMOVE FRIEND';
  static const String confirmRemoveFriend = 'TAP AGAIN TO REMOVE';
  static const String friendActionError =
      'Something went wrong. Please try again.';
  static const String addFriendsTitle = 'Add Friends';
  static const String searchPlayersHint = 'Search by name or username...';
  static String friendRequestsHeader(int count) => 'FRIEND REQUESTS ($count)';
  static String sentRequestsHeader(int count) => 'SENT REQUESTS ($count)';
  static const String noFriendRequests = 'No friend requests right now.';
  static const String noSentRequests = "You haven't sent any requests.";
  static const String resultsHeader = 'RESULTS';
  static String noPlayersMatch(String query) => 'No players match "$query"';
  static const String acceptButton = 'ACCEPT';
  static const String declineButton = 'DECLINE';
  static const String addButton = 'ADD';
  static const String pendingLabel = 'Pending';
  static const String friendsLabel = 'Friends';
  static const String friendSafetyNote =
      'SAFETY NOTE: Please be aware of fake accounts and do not share '
      'personal information.';

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

  // Tavern panels: who's here, player card, report, notice board, emotes
  static const String backButton = 'Back';
  static const String closeButton = 'Close';
  static String playersHere(int count, int max) => "Who's here ($count / $max)";
  static const String showPlayers = "See who's here";
  static const String youLabel = 'You';
  static const String aloneInRoom =
      "It's just you for now. Invite a friend to join!";
  static const String inThisRoom = 'In this room';
  static const String playerCardError = "Couldn't load this player.";
  static const String reportPlayer = 'Report player';
  static const String addFriendButton = 'ADD FRIEND';
  static const String acceptFriendButton = 'ACCEPT FRIEND REQUEST';
  static const String requestSentLabel = 'FRIEND REQUEST SENT';
  static const String alreadyFriendsLabel = 'FRIENDS ✓';
  static String reportTitle(String name) => 'Report $name';
  static const String reportPrompt =
      "What happened? Reports are private: the player won't know it was you.";
  static const String reportDetailsHint = 'Add details (optional)';
  static const String sendReportButton = 'SEND REPORT';
  static const String reportError = "Report not sent. Please try again.";
  static const String reportThanks = 'Thanks for letting us know.';
  static const String reportThanksDetail =
      'Your report was sent and will be reviewed.';
  static const String doneButton = 'DONE';
  static const String noticeBoardTitle = 'Notice Board';
  static const String readNoticeBoard = 'Read notice board';
  static const String readNoticeBoardKey = 'Read notice board (E)';
  static const String noticeBoardHint = 'Pin a note for everyone...';
  static const String pinNoteButton = 'PIN';
  static const String noticeBoardEmpty = 'No notes yet. Pin the first one!';
  static const String noticeBoardError =
      'Something went wrong. Please try again.';
  static const String noticeBoardMissing =
      "The notice board isn't set up yet. Run the notice board SQL in Supabase.";
  static const String takeDownNote = 'Take down note';
  static const String emotesButton = 'Emotes';

  // Private messages between friends
  static const String messageButton = 'MESSAGE';
  static String messageFriend(String name) => 'Message $name';
  static String dmHint(String name) => 'Message $name…';
  static String dmEmpty(String name) =>
      'No messages yet. Say hi to $name or send an emote!';
  static const String dmLoadError = "Couldn't load your messages.";
  static const String dmNotSetUp =
      "Private messages aren't set up yet. Run the direct_messages "
      'migration in Supabase.';
  static const String dmSendError = "Couldn't send. Please try again.";
  static const String dmDeleteError = "Couldn't delete that message.";
  static const String dmEdited = 'edited';
  static const String dmEdit = 'Edit';
  static const String dmDelete = 'Delete';
  static const String dmEditing = 'Editing message';
  static const String dmSend = 'Send';
  static const String dmSaveEdit = 'Save edit';
  static const String dmMessageActionsHint = 'Edit or delete';
  static const String chatTitle = 'CHAT';
  static String chatNewMessages(int count) =>
      count == 1 ? '1 NEW MESSAGE' : '$count NEW MESSAGES';
  static const String hideChat = 'Hide chat';
  static const String showChat = 'Show chat';
  static const String moreRoomsComingSoon = 'MORE ROOMS — COMING SOON';
}
