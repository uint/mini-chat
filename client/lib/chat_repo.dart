import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class FakeChatRepo {
  FakeChatRepo();

  final List<Message> _messages = [
    Message(DateTime.now(), User("bob"), "hi"),
    Message(DateTime.now(), User("jolene"), "yo"),
    Message(DateTime.now(), User("bob"), "wyd")
  ];

  List<Message> getMessages() {
    return _messages;
  }

  void pushMessage(Message msg) {
    _messages.add(msg);
  }

  Future<List<Message>> fetchMessages() async {
    return Future.value(_messages);
  }

  Stream<List<Message>> watchMessages() async* {
    yield _messages;
  }
}

final chatRepositoryProvider = Provider<FakeChatRepo>((ref) {
  return FakeChatRepo();
});

final chatMsgsStreamProvider = StreamProvider.autoDispose<List<Message>>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.watchMessages();
});

final chatMsgsFutureProvider = FutureProvider.autoDispose<List<Message>>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.fetchMessages();
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
