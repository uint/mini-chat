import 'package:minichat_client/chat_repo/chat_repo.dart';

class WsChatRepo implements ChatRepo {
  String? _handle;

  @override
  String? get handle {
    return _handle;
  }

  @override
  List<Message> getMessageHistory() {
    throw UnimplementedError();
  }

  @override
  Future<void> logIn(String handle) async {
    throw UnimplementedError();
  }

  @override
  Future<void> sendMessage(String msg) async {
    throw UnimplementedError();
  }

  @override
  Stream<Message> watchMessages() async* {
    throw UnimplementedError();
  }
}
