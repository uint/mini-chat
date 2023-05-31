import 'package:flutter/material.dart';
import 'package:minichat_client/chat/async_message.dart';
import 'package:minichat_client/chat_repo/chat_repo.dart';

class AsyncMessageView extends StatelessWidget {
  const AsyncMessageView(this.asyncMsg, this._wide, {super.key});

  final AsyncMessage asyncMsg;
  final bool _wide;

  @override
  Widget build(BuildContext context) {
    switch (asyncMsg.state) {
      case AsyncMessageState.waiting:
        return FutureBuilder(
            future: asyncMsg.completionFuture,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return MessageView(
                    AsyncMessageState.waiting, asyncMsg.msg, _wide);
              } else if (snapshot.hasError &&
                  snapshot.connectionState == ConnectionState.done) {
                return MessageView(
                    AsyncMessageState.error, asyncMsg.msg, _wide);
              } else {
                return MessageView(AsyncMessageState.done, asyncMsg.msg, _wide);
              }
            });
      default:
        return MessageView(asyncMsg.state, asyncMsg.msg, _wide);
    }
  }
}

class MessageView extends StatelessWidget {
  final AsyncMessageState msgState;
  final Message msg;
  final bool _wide;

  const MessageView(this.msgState, this.msg, this._wide, {super.key});

  @override
  Widget build(BuildContext context) {
    Widget successText() => Text(msg.msg);
    Widget errorText() => Text(
        style: const TextStyle(
            color: Colors.red, decoration: TextDecoration.lineThrough),
        msg.msg);
    Widget waitingText() =>
        Text(style: const TextStyle(color: Colors.grey), msg.msg);

    Widget msgText;
    switch (msgState) {
      case AsyncMessageState.waiting:
        msgText = waitingText();
        break;
      case AsyncMessageState.error:
        msgText = errorText();
        break;
      case AsyncMessageState.done:
        msgText = successText();
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(children: [
        if (_wide)
          SizedBox(
              width: 40,
              child: Text(
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                  textAlign: TextAlign.center,
                  displayTime(msg.dateTime))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(msg.user.handle,
              style: TextStyle(color: msg.user.color),
              textAlign: TextAlign.center),
        ),
        Flexible(child: msgText)
      ]),
    );
  }
}

String displayTime(DateTime dt) {
  var h = dt.hour.toString().padLeft(2, '0');
  var m = dt.minute.toString().padLeft(2, '0');
  return "$h:$m";
}
