import 'dart:typed_data';

import 'package:minichat_client/chat_repo/server_frame.dart';
import 'package:test/test.dart';

void main() {
  group("Server frame decoding", () {
    test('okay frame', () {
      var frame = ServerFrame.decode(Uint8List.fromList([0, 2]));
      expect(frame, ServerFrameOkay(2));
    });

    test('error frame', () {
      var frame =
          ServerFrame.decode(Uint8List.fromList([1, 2, 1, 0, 0, 0, 97]));
      expect(frame, ServerFrameErr(2, "a"));
    });

    test('broadcast frame', () {
      var frame = ServerFrame.decode(Uint8List.fromList(
          [2, 3, 0, 0, 0, 98, 111, 98, 2, 0, 0, 0, 104, 105]));
      expect(frame, ServerFrameBroadcast("bob", "hi"));
    });
  });
}
