import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat_repo/fake_chat_repo.dart';

abstract class ChatRepo {
  String? get handle;

  List<Message> getMessageHistory();

  Future<void> logIn(String handle);

  Future<void> sendMessage(String msg);

  Stream<Message> watchMessages();
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
