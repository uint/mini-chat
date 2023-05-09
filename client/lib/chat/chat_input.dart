import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat_repo.dart';

class ChatInput extends ConsumerWidget {
  ChatInput({
    super.key,
  });

  String _text = "";

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
            child: TextField(
          onChanged: (t) {
            _text = t;
          },
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'enter your message',
          ),
        )),
        FloatingActionButton(onPressed: () {
          var repo = ref.read(chatRepositoryProvider);
          repo.pushMessage(Message(DateTime.now(), User("me"), _text));
        }),
      ],
    );
  }
}
