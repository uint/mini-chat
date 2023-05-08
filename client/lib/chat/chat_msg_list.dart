import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/async.dart';
import 'package:minichat_client/chat_repo.dart';

class MessageList extends ConsumerWidget {
  const MessageList({super.key});

  @override
  Widget build(BuildContext ctx, WidgetRef ref) {
    final msgList = ref.watch(chatMsgsStreamProvider);

    return AsyncValueWidget(
        value: msgList,
        data: (msgs) => ListView.builder(
              reverse: true,
              itemCount: msgs.length,
              itemBuilder: (BuildContext context, int index) {
                return MessageView(msgs[msgs.length - index - 1]);
              },
            ));
  }
}

class MessageView extends StatelessWidget {
  final Message msg;

  const MessageView(this.msg, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(children: [
        SizedBox(
            width: 45,
            child: Text(
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
                displayTime(msg.dateTime))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(msg.user.handle,
              style: TextStyle(color: msg.user.color),
              textAlign: TextAlign.center),
        ),
        Flexible(child: Text(msg.msg))
      ]),
    );
  }
}

String displayTime(DateTime dt) {
  var h = dt.hour.toString().padLeft(2, '0');
  var m = dt.minute.toString().padLeft(2, '0');
  return "$h:$m";
}
