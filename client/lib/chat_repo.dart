import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeChatRepo {
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

  StreamController<Message> stream = StreamController();

  List<Message> getMessages() {
    return _hardcodedMessages;
  }

  void pushMessage(Message msg) {
    stream.add(msg);
  }

  Stream<Message> watchMessages() async* {
    for (var msg in _hardcodedMessages) {
      await Future.delayed(const Duration(milliseconds: 600));
      yield msg;
    }

    await for (var msg in stream.stream) {
      yield msg;
    }
  }
}

final chatRepositoryProvider = Provider<FakeChatRepo>((ref) {
  return FakeChatRepo();
});

final chatMsgsStreamProvider = StreamProvider.autoDispose<Message>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.watchMessages();
});

final chatMsgsFutureProvider = FutureProvider.autoDispose<List<Message>>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.getMessages();
});

class Message {
  final DateTime dateTime;
  final User user;
  final String msg;

  Message(this.dateTime, this.user, this.msg);
}

class User {
  final String handle;
  final Color color;

  User(this.handle) : color = handleColor(handle);
}

Color handleColor(String handle) {
  var bytes = utf8.encode(handle);
  var dg = md5.convert(bytes).bytes;

  return Color.fromARGB(255, dg[0], dg[1], dg[2]);
}
