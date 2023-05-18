import 'package:minichat_client/chat_repo/client_frame.dart';
import 'package:test/test.dart';

void main() {
  group("Client frame encoding", () {
    test('login frame', () {
      expect(ClientLoginFrame("bob").encode(103),
          [103, 0, 3, 0, 0, 0, 98, 111, 98]);
    });

    test('msg frame', () {
      expect(ClientMsgFrame("hi").encode(22), [22, 1, 2, 0, 0, 0, 104, 105]);
    });
  });
}
