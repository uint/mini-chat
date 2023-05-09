import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat_repo.dart';

class ChatInput extends ConsumerWidget {
  ChatInput({
    super.key,
  });

  FocusNode focusNode = FocusNode();
  String _text = "";

  void _submit(WidgetRef ref, String msg) {
    var repo = ref.read(chatRepositoryProvider);
    repo.pushMessage(Message(DateTime.now(), User("me"), msg));
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
            child: TextField(
          onChanged: (t) {
            _text = t;
          },
          onSubmitted: (String msg) {
            _submit(ref, msg);
          },
          focusNode: focusNode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'enter your message',
          ),
        )),
        TextFieldTapRegion(child: FloatingActionButton(onPressed: () {
          _submit(ref, _text);
        })),
      ],
    );
  }
}
