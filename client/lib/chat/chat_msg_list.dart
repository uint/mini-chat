import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat_repo.dart';

class MessageListController {
  void Function(Message, {Future<void>? completionFuture})? _addMessage;

  void register(
      void Function(Message, {Future<void>? completionFuture}) addMessageImpl) {
    _addMessage = addMessageImpl;
  }

  void addMessage(Message msg, {Future<void>? completionFuture}) {
    _addMessage?.call(msg, completionFuture: completionFuture);
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

  List<AsyncMessage> stateList = [];
  final GlobalKey<AnimatedListState> _listKey = GlobalKey<AnimatedListState>();

  void addMsg(Message msg, {Future<void>? completionFuture}) {
    var list = _listKey.currentState;
    stateList.insert(0, AsyncMessage(msg, completionFuture: completionFuture));
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

enum AsyncMessageState {
  waiting,
  error,
  done;
}

class AsyncMessage {
  AsyncMessage(this.msg, {this.completionFuture})
      : state = completionFuture == null
            ? AsyncMessageState.done
            : AsyncMessageState.waiting {
    completionFuture
        ?.then((_) => state = AsyncMessageState.done)
        .catchError((_) => state = AsyncMessageState.error);
  }

  final Message msg;
  final Future<void>? completionFuture;
  AsyncMessageState state;
}

class MessageView extends StatelessWidget {
  const MessageView(this.asyncMsg, {super.key});

  final AsyncMessage asyncMsg;

  @override
  Widget build(BuildContext context) {
    var successText = Text(asyncMsg.msg.msg);
    var errorText = Text(
        style: const TextStyle(
            color: Colors.red, decoration: TextDecoration.lineThrough),
        asyncMsg.msg.msg);
    var waitingText =
        Text(style: const TextStyle(color: Colors.grey), asyncMsg.msg.msg);

    Widget msgText;
    switch (asyncMsg.state) {
      case AsyncMessageState.waiting:
        msgText = FutureBuilder(
            future: asyncMsg.completionFuture,
            builder: (BuildContext context, AsyncSnapshot snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return waitingText;
              } else if (snapshot.hasError &&
                  snapshot.connectionState == ConnectionState.done) {
                return errorText;
              } else {
                return successText;
              }
            });
        break;
      case AsyncMessageState.error:
        msgText = errorText;
        break;
      case AsyncMessageState.done:
        msgText = successText;
        break;
    }

    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Row(children: [
        SizedBox(
            width: 45,
            child: Text(
                style: const TextStyle(fontSize: 12, color: Colors.grey),
                textAlign: TextAlign.center,
                displayTime(asyncMsg.msg.dateTime))),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          child: Text(asyncMsg.msg.user.handle,
              style: TextStyle(color: asyncMsg.msg.user.color),
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
