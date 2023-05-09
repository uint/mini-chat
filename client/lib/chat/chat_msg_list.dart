import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat_repo.dart';

class MessageListController {
  void Function(Message)? _addMessage;

  void register(void Function(Message) addMessageImpl) {
    _addMessage = addMessageImpl;
  }

  void addMessage(Message msg) {
    _addMessage?.call(msg);
  }
}

class MessageList extends ConsumerStatefulWidget {
  const MessageList({Key? key, this.controller}) : super(key: key);

  final MessageListController? controller;

  @override
  MessageListState createState() => MessageListState();
}

class MessageListState extends ConsumerState<MessageList> {
  @override
  void initState() {
    super.initState();
    widget.controller?.register(addMsg);
  }

  List<Message> stateList = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  void addMsg(Message msg) {
    var list = _listKey.currentState;
    stateList.insert(0, msg);
    list!.insertItem(0);
  }

  // Used to build list items that haven't been removed.
  Widget _buildItem(
      BuildContext context, int index, Animation<double> animation) {
    return SizeTransition(
        sizeFactor: animation,
        child: FadeTransition(
            opacity: animation, child: MessageView(stateList[index])));
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(chatMsgsStreamProvider, (_, msg) {
      if (msg.value != null) {
        addMsg(msg.value!);
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
