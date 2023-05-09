import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat/chat_input.dart';
import 'package:minichat_client/chat/chat_msg_list.dart';
import 'package:minichat_client/chat_repo.dart';

class Chat extends StatefulWidget {
  Chat({super.key});

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final controller = MessageListController();

  void _onSubmit(AsyncValue<void> asyncValue, String msg) async {
    controller.addMessage(Message(DateTime.now(), User("me"), msg));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: TextFieldTapRegion(child: MessageList(controller: controller)),
        ),
        ChatInput(
          onSubmit: _onSubmit,
        ),
      ],
    );
  }
}
