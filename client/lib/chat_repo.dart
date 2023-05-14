import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/painting.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract class ChatRepo {
  String? get handle;

  List<Message> getMessageHistory();

  Future<void> logIn(String handle);

  Future<void> sendMessage(String msg);

  Stream<Message> watchMessages();
}

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
}

final chatRepositoryProvider = Provider<ChatRepo>((ref) {
  return FakeChatRepo();
});

final chatMsgsStreamProvider = StreamProvider.autoDispose<Message>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.watchMessages();
});

final chatMsgsFutureProvider = FutureProvider.autoDispose<List<Message>>((ref) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.getMessageHistory();
});

final chatSendMsgProvider =
    FutureProvider.autoDispose.family<void, String>((ref, msg) {
  final chatRepo = ref.watch(chatRepositoryProvider);
  return chatRepo.sendMessage(msg);
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
