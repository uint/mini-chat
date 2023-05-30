import 'package:flutter/material.dart';
import 'package:minichat_client/chat/async_message.dart';
import 'package:minichat_client/chat/chat_msg_view.dart';
import 'package:minichat_client/chat_repo/chat_repo.dart';

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

class MessageList extends StatefulWidget {
  const MessageList(this._wide, {Key? key, this.controller}) : super(key: key);

  final MessageListController? controller;
  final bool _wide;

  @override
  MessageListState createState() => MessageListState();
}

class MessageListState extends State<MessageList> {
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
            opacity: animation,
            child: AsyncMessageView(stateList[index], widget._wide)));
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedList(
      reverse: true,
      key: _listKey,
      initialItemCount: stateList.length,
      itemBuilder: _buildItem,
    );
  }
}
