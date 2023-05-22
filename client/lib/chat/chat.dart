import 'package:flutter/material.dart';
import 'package:minichat_client/chat/chat_input.dart';
import 'package:minichat_client/chat/chat_msg_list.dart';
import 'package:minichat_client/chat_repo/chat_repo.dart';

class Chat extends StatefulWidget {
  const Chat(this._repo, {super.key});

  final ChatRepo _repo;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final controller = MessageListController();
  late String handle;

  void _onSubmit(String msg) async {
    controller.addMessage(Message(DateTime.now(), User(handle), msg),
        completionFuture: widget._repo.sendMessage(msg));
  }

  @override
  Widget build(BuildContext context) {
    widget._repo.watchMessages().forEach((msg) {
      controller.addMessage(msg);
    });

    if (widget._repo.handle == null) {
      Navigator.pop(context);
    }
    handle = widget._repo.handle!;

    return WillPopScope(
      onWillPop: () async {
        await widget._repo.logout();
        return true;
      },
      child: Scaffold(
          appBar: AppBar(
            title: const Text('mini-chat'),
          ),
          body: Column(
            children: [
              Expanded(
                child: TextFieldTapRegion(
                    child: MessageList(controller: controller)),
              ),
              ChatInput(
                onSubmit: _onSubmit,
              ),
            ],
          )),
    );
  }
}
