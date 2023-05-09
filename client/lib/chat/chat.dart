import 'package:flutter/material.dart';
import 'package:minichat_client/chat/chat_input.dart';
import 'package:minichat_client/chat/chat_msg_list.dart';

class Chat extends StatelessWidget {
  const Chat({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: TextFieldTapRegion(child: MessageList()),
        ),
        ChatInput(),
      ],
    );
  }
}
