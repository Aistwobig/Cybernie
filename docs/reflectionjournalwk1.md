# Reflection Journal — Week 1

**Week of:** September 21–27, 2026

## My Goal This Week
To finalize the CYBERNIE design system based on project screens and visual direction, define the color palette, create a typography scale, establish a 4px spacing unit, plan reusable Flutter components (`PrimaryButton`, `AppTextField`, `AppBottomNavBar`, `CharacterCard`, `RoomCard`, `FriendListTile`, `ProfileHeader`), and assemble `lib/theme.dart` using `ThemeData` and `ColorScheme.fromSeed`.

## What I Did
* Finalized the visual direction and design system components for CYBERNIE, mapping out cohesive styles across screens.
* Defined the primary, secondary, surface, text, and error color palette.
* Established a consistent typography scale utilizing Flutter's `TextTheme`.
* Set up a consistent 4px base unit for reusable spacing values across the application.
* Outlined modular Flutter components (`PrimaryButton`, `AppTextField`, `AppBottomNavBar`, `CharacterCard`, `RoomCard`, `FriendListTile`, and `ProfileHeader`) to reduce code duplication.
* Assembled the proposed `lib/theme.dart` file using `ThemeData` and `ColorScheme.fromSeed`.
* Documented all design decisions and recorded changes made from preliminary design iterations.

## What Blocked Me
* Determining how best to organize reusable components without overcomplicating the project folder structure or adding unnecessary abstraction layers.
* Translating high-level visual design concepts into actual Flutter theme property values while preserving a consistent interface.
* Figuring out how components should accept data and callbacks rather than embedding screen-specific logic directly inside them.

## What I Learned
* Why reusable widgets should strictly focus on displaying information and triggering actions rather than managing the entire application's state.
* How structuring a centralized theme file (`lib/theme.dart`) using `ColorScheme.fromSeed` streamlines maintaining visual consistency across multiple screens.
* The importance of decoupling business/screen logic from UI components to make future refactoring and code maintenance significantly easier.
