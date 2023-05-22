import 'dart:async';
import 'dart:convert';

import 'package:flutter/painting.dart';
import 'package:crypto/crypto.dart';

abstract class ChatRepo {
  String? get handle;

  List<Message> getMessageHistory();

  Future<void> logIn(String handle);

  Future<void> sendMessage(String msg);

  Stream<Message> watchMessages();

  Future<void> logout();
}

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
