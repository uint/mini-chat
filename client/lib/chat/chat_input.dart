import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat_repo.dart';

class ChatInput extends ConsumerWidget {
  ChatInput({
    super.key,
    this.onSubmit,
  });

  final void Function(AsyncValue<void>, String)? onSubmit;
  FocusNode focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  void _submit(WidgetRef ref, String msg) {
    if (msg.isNotEmpty) {
      var fut = ref.read(chatSendMsgProvider(msg));
      onSubmit?.call(fut, msg);
      _controller.text = "";
    }
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Expanded(
            child: TextField(
          onSubmitted: (String msg) {
            _submit(ref, msg);
          },
          controller: _controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'enter your message',
          ),
        )),
        TextFieldTapRegion(child: FloatingActionButton(onPressed: () {
          _submit(ref, _controller.text);
        })),
      ],
    );
  }
}
