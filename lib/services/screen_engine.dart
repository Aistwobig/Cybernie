/// The low-level part of screen sharing: capturing our screen, and one
/// direct (WebRTC) video link from the sharer to each viewer.
/// ScreenShareService decides who shares and who watches.
library;

import 'dart:ui' as ui;

import 'screen_engine_stub.dart'
    if (dart.library.js_interop) 'screen_engine_web.dart'
    as impl;

/// Sends a link setup message (offer / answer / candidate) to a player.
typedef ScreenSignalSender =
    void Function(String toId, Map<String, dynamic> signal);

abstract class ScreenEngine {
  /// The browser's engine on the web; elsewhere one that isn't supported.
  factory ScreenEngine(ScreenSignalSender send) =>
      impl.createScreenEngine(send);

  /// Whether this browser can share its screen (computer browsers can;
  /// phones generally can't, though they can watch).
  bool get canShare;

  /// Asks which screen / window / tab to share and starts capturing it.
  /// [onEnded] is called if the player stops it from the browser's own bar.
  Future<void> startCapture({required void Function() onEnded});

  /// Stops capturing and closes every link.
  Future<void> stop();

  /// Sharer: opens a link to viewer [peerId].
  Future<void> offerTo(String peerId);

  /// Closes the link with [peerId].
  void drop(String peerId);

  /// Players we have a link with.
  Set<String> get peers;

  /// A link setup message from [fromId].
  Future<void> handleSignal(String fromId, Map<String, dynamic> signal);

  /// The latest frame of the shared screen (ours while sharing, otherwise
  /// the one we receive), or null. The caller disposes it.
  Future<ui.Image?> grabFrame();
}
