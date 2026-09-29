import 'package:final_project/services/room_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const move = PlayerMove(
    playerId: 'abc',
    x: 100.4,
    y: 200.6,
    facing: 2,
    moving: true,
  );

  test('a move survives being sent and received', () {
    final received = PlayerMove.fromPayload(move.toPayload())!;
    expect(received.playerId, 'abc');
    expect(received.x, 100);
    expect(received.y, 201);
    expect(received.facing, 2);
    expect(received.moving, isTrue);
  });

  test('a move nested under "payload" is read too', () {
    final received = PlayerMove.fromPayload({
      'type': 'broadcast',
      'event': 'move',
      'payload': move.toPayload(),
    })!;
    expect(received.playerId, 'abc');
  });

  test('malformed messages are ignored', () {
    expect(PlayerMove.fromPayload({'x': 1}), isNull);
    expect(PlayerMove.fromPayload({'id': 'a', 'x': 'far', 'y': 2}), isNull);
  });
}
