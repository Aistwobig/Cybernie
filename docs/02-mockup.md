# Mockup and wireframes

The visual plan for Cybernie, updated to the finished app (v1.1, 2026-10-09).

## Mockup

Screenshots of the finished app (more to come).

### Splash and Login

<p align="center">
  <img src="assets/screenshots/splash.png" alt="Splash screen" width="250">
  <img src="assets/screenshots/login-day.png" alt="Login screen, day mode" width="250">
  <img src="assets/screenshots/login-night.png" alt="Login screen, night mode" width="250">
</p>

### Home, messages, friends and profile

**Home** greets you with your hero and the Join Room button, **Messages**
is a private chat with a friend (with emotes), **Friends** shows who is
online with a chat button for each, and **Profile** is where you rename
yourself, get your QR code and pick one of the six heroes.

<p align="center">
  <img src="assets/screenshots/home.png" alt="Home screen" width="200">
  <img src="assets/screenshots/messages.png" alt="Private messages with a friend" width="200">
  <img src="assets/screenshots/friends.png" alt="Friends screen" width="200">
  <img src="assets/screenshots/profile.png" alt="Profile screen" width="200">
</p>

### Chat and notifications

**A message notification:** a new private message slides in at the top,
even in the middle of a blackjack hand.

![A message notification over the blackjack table](assets/screenshots/message-notification.png)

**Private chat in the tavern:** the conversation opens beside the room, so
you can keep chatting without leaving it.

![Private chat open in the tavern](assets/screenshots/tavern-private-chat.png)

**Tavern chat:** everyone in the room can read the open chat log above the
message box.

![The tavern chat log](assets/screenshots/tavern-chat.png)

### Upstairs meeting room

Six players watching a shared game, one seated at the table:

![Six players in the meeting room watching a shared screen](assets/screenshots/meeting-room-six-players.png)

Five players seated at the table, cameras on, watching the projector:

![Five players seated at the meeting table with cameras on](assets/screenshots/meeting-table-seated-cameras.png)

Tapping the projector shows **Share screen** and **Full screen**:

![Projector with Share screen and Full screen buttons](assets/screenshots/meeting-room-projector-buttons.png)

Screen sharing on the projector, with players' cameras above their heads:

![Meeting room with screen sharing and cameras](assets/screenshots/meeting-room-screen-share-camera.png)

Chatting while a screen is shared:

![Meeting room with screen sharing and chat](assets/screenshots/meeting-room-screen-share.png)

Cameras on, someone typing, and the "Click to sit" prompt near the table:

![Meeting room with cameras and a typing indicator](assets/screenshots/meeting-room-typing.png)

A longer chat bubble over a player:

![Meeting room with a long chat bubble](assets/screenshots/meeting-room-chat-bubble.png)

## Screen flow

Which screen opens first, and how a player moves between them. Friends, Home and
Profile are the three tabs of the bottom navigation bar.

```mermaid
flowchart TD
    Splash[Splash] -->|signed out| Login[Login: Sign in with Google]
    Splash -->|signed in| Home
    Login --> Home

    subgraph Tabs[Bottom navigation]
        Friends[Friends]
        Home[Home: character and Join Room]
        Profile[Profile]
    end

    Home --> Rooms[Select Room]
    Rooms --> Tavern[Bernie's Tavern]
    Tavern -->|stairs| Meeting[Upstairs meeting room]
    Meeting -->|stairs| Tavern

    Friends --> AddFriends[Add Friends]
    Friends --> Chat[Private chat]
    Friends --> PlayerProfile[Player profile]
    Profile --> QR[My QR code]
    QR -.->|scanned by someone else| PlayerProfile
    PlayerProfile --> Chat

    Tavern --> Bar[Bernie: drinks and blackjack]
    Tavern --> Panels[Who's here, tasks, inventory,<br>leaderboard, notice board, settings]
```

## Wireframes

_(To add: photos of the original paper or digital wireframes, saved in
`assets/`.)_

## Screens

### Splash
The Cybernie logo and title over the tavern art. Signed-in players go straight
to Home; everyone else goes to Login. A scanned profile link is remembered here
until the player has signed in.

### Login
One button: **Sign in with Google** (and **Register with Google**, which is the
same flow: the first sign-in creates the account). A short safety note explains
what is stored.

### Home (Welcome)
A greeting with the player's name and a large animated preview of their
character, with arrows to turn it. Below: choose a character, then **Join
Room**. The menu holds music and sound effect volumes, night mode and sign out.
Goes to: Select Room, Friends, Profile.

### Select Room
The room list. Bernie's Tavern shows how many adventurers are inside (up to
20); **Join** enters it, or shows **Room full**. More rooms are marked as coming
soon.

### Bernie's Tavern
The game. The player walks with WASD / arrow keys, or the joystick on phones.
On screen:
- **Top left:** back (leave room), the room name, and the player count, which
  opens **Who's here** (players in the room and in voice chat).
- **Top right:** coins, tasks, inventory, leaderboard and settings (microphone,
  camera, speaker, volumes).
- **Bottom:** room chat with emotes, and the voice chat bar (join, mute,
  camera, hang up).
- **In the room:** walk up to a stool or chair to sit, to Bernie to order
  drinks or play blackjack, to the notice board to read it, and to the stairs
  to go upstairs. Tapping another player opens their **player card** (profile,
  add friend, message, report).

### Upstairs meeting room
A long meeting table where every chair can be sat on, and a projector. Tap or
hover the projector to **Share screen** or open it **full screen**. Only one
person shares at a time; everyone sees "*name* is sharing".

### Friends
Friend requests, the friends list with online dots, last-seen times and unread
message badges, and friend suggestions with **Add friend** pills. Goes to: Add
Friends, Private chat, Player profile.

### Add Friends
Search players by name. Each result shows **Add friend**, **Requested** or
**Friends**. Sent and received requests can be cancelled or accepted.

### Private chat
A purple and gold chat with one friend: text and emotes, editing and deleting
your own messages. New messages from anyone pop up as a banner on every screen.

### Profile
Your photo (tap to change), player name, bio and character, all editable, and
**Generate QR code**.

### Player profile
Another player's photo, name, character, bio and last online, with **Add
friend** (if not friends yet) and **Message**. Opened from the friends list, a
player card, or by scanning their QR code.
