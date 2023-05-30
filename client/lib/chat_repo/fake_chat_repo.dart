import 'dart:async';
import 'dart:math';

import 'package:minichat_client/chat_repo/chat_repo.dart';

class FakeChatRepo implements ChatRepo {
  FakeChatRepo();

  final _hardcodedMessages = [
    Message(
        DateTime.now().subtract(const Duration(minutes: 3)), User("rob"), "hi"),
    Message(DateTime.now(), User("jolene"), "yo"),
    Message(DateTime.now(), User("rob"), "wyd"),
    Message(DateTime.now(), User("scholar"),
        "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum."),
    Message(DateTime.now(), User("rob"), "wow, spammy"),
  ];

  String? _handle;
  int _count = 0;
  final Random _rng = Random();

  @override
  List<Message> getMessageHistory() {
    return _hardcodedMessages;
  }

  @override
  Future<void> logIn(String handle) async {
    await Future.delayed(Duration(milliseconds: 600 + _rng.nextInt(1200)));
    if (handle == "system") {
      // this exists just to test error handling
      throw "system is a reserved handle";
    }
    _handle = handle;
  }

  @override
  Future<void> sendMessage(String msg) async {
    await Future.delayed(Duration(milliseconds: 600 + _rng.nextInt(1200)));

    // external dependencies fail sometimes!
    if (_count++ % 5 == 3) {
      throw "noes!";
    }
  }

  @override
  Stream<Message> watchMessages() async* {
    for (var msg in _hardcodedMessages) {
      await Future.delayed(const Duration(milliseconds: 600));
      yield msg;
    }
  }

  @override
  String? get handle => _handle;

  @override
  Future<void> logout() async {}

  @override
  Set<User> get users => {};

  @override
  Stream<Set<User>> watchUsers() async* {
    while (true) {
      await Future.delayed(const Duration(milliseconds: 1000));
      yield {User("bob"), User("agnes")};
      await Future.delayed(const Duration(milliseconds: 4500));
      yield {User("bob"), User("agnes"), User("roxanne")};
    }
  }
}
