import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/async.dart';
import 'package:minichat_client/chat_repo.dart';

class MessageList extends ConsumerStatefulWidget {
  MessageList({Key? key}) : super(key: key);

  @override
  MessageListState createState() => MessageListState();
}

class MessageListState extends ConsumerState<MessageList> {
  List<Message> stateList = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  // Used to build list items that haven't been removed.
  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    return SizeTransition(
        sizeFactor: animation, child: MessageView(stateList[index]));
  }

  @override
  Widget build(BuildContext ctx) {
    ref.listen(chatMsgsStreamProvider, (_, msg) {
      if (msg.value != null) {
        var list = _listKey.currentState;
        stateList.insert(0, msg.value!);
        list!.insertItem(0);
      }
    });

    return AnimatedList(
      reverse: true,
      key: _listKey,
      initialItemCount: 0,
      itemBuilder: _buildItem,
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
