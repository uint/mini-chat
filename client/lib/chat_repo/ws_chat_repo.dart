// TODO: split serialization/deserialization into separate modules and test that!
// TODO: test this using dummy ws streams

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import 'package:minichat_client/chat_repo/server_frame.dart';
import 'package:minichat_client/chat_repo/client_frame.dart';
import 'package:minichat_client/chat_repo/chat_repo.dart';

class WsChatRepo implements ChatRepo {
  WsChatRepo(this.uri) {
    _connect();
  }

  final Uri uri;
  late WebSocketChannel _channel;
  String? _handle;
  StreamController<ServerFrameErr> errors = StreamController.broadcast();
  StreamController<Message> messages = StreamController.broadcast();
  StreamController<int> receipts = StreamController.broadcast();
  int msgCount = 0;
  bool _connected = false;

  Future<void> _connect() async {
    _channel = WebSocketChannel.connect(uri);
    _channel.stream.map((bytes) => ServerFrame.decode(bytes)).handleError((e) {
      if (e is ServerFrameErr) {
        errors.add(e);
      } else {
        //throw e;
      }
    }).forEach(_handleFrame);
    await _channel.ready;
    _connected = true;
  }

  void _handleFrame(ServerFrame frame) {
    switch (frame.runtimeType) {
      case ServerFrameBroadcast:
        var frame_ = frame as ServerFrameBroadcast;
        messages.add(Message(DateTime.now(), User(frame_.user), frame_.msg));
        break;
      case ServerFrameOkay:
        var frame_ = frame as ServerFrameOkay;
        receipts.add(frame_.id);
        break;
      case ServerFrameErr:
        errors.add(frame as ServerFrameErr);
        break;
      default:
        throw "unknown frame";
    }
  }

  @override
  String? get handle {
    return _handle;
  }

  @override
  List<Message> getMessageHistory() {
    return [];
  }

  @override
  Future<void> logIn(String handle) async {
    if (!_connected) {
      await _connect();
    }

    var id = issueId();
    _channel.sink.add(ClientLoginFrame(handle).encode(id));
    await waitForCompletion(id);
    _handle = handle;
  }

  int issueId() {
    msgCount++;
    msgCount %= 256;
    return msgCount;
  }

  Future<void> waitForCompletion(int id) async {
    errors.stream
        .firstWhere((err) => err.id == id)
        .then((err) => throw err.msg);
    await receipts.stream
        .firstWhere((receiptId) => receiptId == id)
        .timeout(const Duration(minutes: 1));
  }

  @override
  Future<void> sendMessage(String msg) async {
    var id = issueId();
    _channel.sink.add(ClientMsgFrame(msg).encode(id));
    await waitForCompletion(id);
  }

  @override
  Stream<Message> watchMessages() {
    return messages.stream;
  }

  @override
  Future<void> logout() async {
    _handle = null;

    if (_connected) {
      var id = issueId();
      _channel.sink.add(ClientLogoutFrame().encode(id));
      await waitForCompletion(id);
    }
  }

  //@override
  void onDisconnect(void Function() handler) {
    _channel.sink.done.then((_) {
      if (_connected) {
        _connected = false;
        handler();
      }
    });
    _channel.stream.last.then((_) {
      if (_connected) {
        _connected = false;
        handler();
      }
    });
  }
}
