import 'dart:io';
import 'dart:typed_data';

import 'package:final_project/constants/characters.dart';
import 'package:flutter_test/flutter_test.dart';

/// Width and height from a PNG file's header.
(int, int) pngSize(String asset) {
  final bytes = File(asset).readAsBytesSync();
  final data = ByteData.sublistView(bytes);
  return (data.getUint32(16), data.getUint32(20));
}

void main() {
  // A character's walk, idle and run sheets are drawn into the same box, so
  // their frames must be the same size or the sprite stretches when it
  // starts or stops moving.
  for (final character in gameCharacters) {
    test('${character.name}: idle and run frames match the walk frames', () {
      final (walkW, walkH) = pngSize(character.sheet);
      final frames = character.frames;
      final walkCell = (walkW / frames, walkH / 4);

      final idle = character.idleSheet;
      if (idle != null) {
        final (w, h) = pngSize(idle);
        expect((w / frames, h / 4), walkCell, reason: '$idle ($frames x 4)');
      }

      final sit = character.sitBackSheet;
      if (sit != null) {
        final (w, h) = pngSize(sit);
        expect((w / frames, h / 1), walkCell, reason: '$sit ($frames x 1)');
      }

      final run = character.horizontalRunSheet;
      if (run != null) {
        final (w, h) = pngSize(run);
        expect((w / 8, h / 2), walkCell, reason: '$run (8 x 2)');
      }
    });
  }
}
