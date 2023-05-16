import 'dart:typed_data';
import 'dart:convert';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:minichat_client/chat_repo/chat_repo.dart';

class WsChatRepo implements ChatRepo {
  WsChatRepo(this._uri);

  final Uri _uri;
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

abstract class ServerFrame {
  factory ServerFrame.decode(Uint8List bytes) {
    var msgId = bytes[0];
    var remaining = bytes.sublist(1);

    switch (msgId) {
      case 0:
        return ServerFrameOkay.decode(remaining);
      case 1:
        return ServerFrameErr.decode(remaining);
      default:
        throw "unknown message";
    }
  }
}

class ServerFrameOkay implements ServerFrame {
  late int id;

  ServerFrameOkay(this.id);

  ServerFrameOkay.decode(Uint8List bytes) {
    if (bytes.length != 1) {
      throw "invalid okay message";
    }
    id = bytes[0];
  }
}

class ServerFrameErr implements ServerFrame {
  late int id;
  late String msg;

  ServerFrameErr(this.id, this.msg);

  ServerFrameErr.decode(Uint8List bytes) {
    if (bytes.length > 1 || bytes.length != bytes[1] + 2) {
      throw "invalid okay message";
    }

    id = bytes[0];
    msg = utf8.decode(bytes.sublist(2));
  }
}

class MinichatWsChannel {
  MinichatWsChannel(this._channel);

  final WebSocketChannel _channel;

  Stream<ServerFrame> get stream {
    return _channel.stream.map((msg) => ServerFrame.decode(msg));
  }
}
