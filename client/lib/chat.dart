import 'package:flutter/material.dart';
import 'package:minichat_client/chat_repo.dart';

class Chat extends StatelessWidget {
  const Chat({super.key});

  @override
  Widget build(BuildContext ctx) {
    return ListView.builder(
      //anchor: 1.0,
      reverse: true,
      itemCount: 10,
      itemBuilder: (BuildContext context, int index) {
        var time = DateTime.now().subtract(Duration(minutes: index));
        var msg = index == 5
            ? Message(time, User("jolene"),
                "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.")
            : Message(time, User("bob"), "hi");
        return MessageView(msg);
      },
    );
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
            width: 50,
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
