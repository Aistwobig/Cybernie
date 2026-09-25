CYBERNIE

1. Overview

CYBERNIE is an interactive Flutter-based application designed for social tavern networking and community engagement. It provides users with virtual rooms, friend management, and customizable profile spaces to connect with others in a themed environment. The app is built for gamers and online communities looking for an immersive and organized hangout experience.

2. Setup and Installation

Follow these steps to get the app running from a clean environment:

Flutter & Dart Versions: Built with Flutter 3.x and Dart 3.x.

Clone the Repository:

git clone https://github.com/your-username/cybernie.git
cd cybernie


Install Dependencies:

flutter pub get


Configuration:
The app currently runs locally. If backend integration or API keys are required in future iterations, configure them in a .env file (never commit real keys):

API_BASE_URL=https://api.placeholder.com/v1
API_KEY=your_api_key_here


3. How to Run It

Run the application using the following command targeting Chrome or your preferred device:

flutter run -d chrome


Expected Output: When working correctly, the app should launch with the finalized CYBERNIE design system theme applied, displaying the initial navigation screens.

4. Features and Usage

CYBERNIE guides users through a structured flow across several core screens:

Select Room Screen: Browse available virtual rooms and tavern spaces.

Tavern Room Screen: Join a selected room to interact with other users and participate in group activities.

Friends Screen: Manage your connections, view friend lists, and send or accept requests.

Profile Screen: View and edit personal user details, avatar settings, and preferences.

5. Project Structure

A map of the lib/ directory and its important files:

lib/
├── theme.dart             # Centralized ThemeData and ColorScheme.fromSeed
├── main.dart              # Application entry point
├── models/                # Data models (User, Room, Friend)
├── screens/               # Main application screens
│   ├── select_room_screen.dart
│   ├── tavern_room_screen.dart
│   ├── friends_screen.dart
│   └── profile_screen.dart
└── widgets/               # Reusable components
    ├── PrimaryButton.dart
    ├── AppTextField.dart
    ├── AppBottomNavBar.dart
    ├── CharacterCard.dart
    ├── RoomCard.dart
    ├── FriendListTile.dart
    └── ProfileHeader.dart


6. Screenshots

to be followed

7. Known Issues and Next Steps

What is not finished: Screen interactions, application state connection, and persistent data/storage solution.

What is known to be broken: Navigation between main screens is currently stubbed and pending state implementation.

Next steps: Implement planned reusable components in Flutter, hook up application state management, finalize screen navigation, and integrate local/persistent storage.

AI Usage

AI tools were utilized to assist with structuring code, drafting documentation, and designing the theme architecture. See AI-USAGE.md for full credit details.
