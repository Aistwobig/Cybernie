import 'package:final_project/services/voice_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voices fade with distance and go silent far away', () {
    expect(VoiceService.volumeAt(0), 1);
    expect(VoiceService.volumeAt(110), 1, reason: 'full volume up close');
    final mid = VoiceService.volumeAt(265);
    expect(mid, greaterThan(0.1));
    expect(mid, lessThan(0.5));
    expect(VoiceService.volumeAt(420), 0);
    expect(VoiceService.volumeAt(1000), 0);
    // We hang up a little further than we call, so it doesn't flicker.
    expect(VoiceService.hangUpRange, greaterThan(VoiceService.connectRange));
  });

  test('voice chat starts off', () {
    final voice = VoiceService();
    expect(voice.state.value, VoiceState.off);
    expect(voice.micOn.value, isFalse);
    expect(voice.speaking.value, isEmpty);
  });
}
