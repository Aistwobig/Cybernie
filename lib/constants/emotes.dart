/// A reaction players can pop over their head in a room.
///
/// [id] is what's sent to the other players. It's an emoji, so it stays
/// short and older versions of the app that receive it still know it.
class Emote {
  const Emote(this.id, this.asset, this.label);

  final String id;

  /// The pixel-art picture (cut from assets/sheets/original_emotes.png).
  final String asset;

  /// Read out by screen readers.
  final String label;
}

/// The emotes, in the order the picker shows them.
const List<Emote> emotes = [
  Emote('👋', 'assets/images/emote_wave.png', 'Wave'),
  Emote('😂', 'assets/images/emote_cheers.png', 'Cheers'),
  Emote('❤️', 'assets/images/emote_love.png', 'Love'),
  Emote('👍', 'assets/images/emote_thumbs.png', 'Thumbs up'),
  Emote('😠', 'assets/images/emote_angry.png', 'Angry'),
  Emote('😮', 'assets/images/emote_surprised.png', 'Surprised'),
  Emote('😵', 'assets/images/emote_dizzy.png', 'Dizzy'),
  Emote('😭', 'assets/images/emote_crying.png', 'Crying'),
];

/// The emote sent as [id], or null if there isn't one.
Emote? emoteById(String id) {
  for (final emote in emotes) {
    if (emote.id == id) return emote;
  }
  return null;
}
