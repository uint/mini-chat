import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

typedef OnSubmit = void Function(String, WidgetRef ref);

class ChatInput extends ConsumerWidget {
  ChatInput({
    super.key,
    this.onSubmit,
  });

  final OnSubmit? onSubmit;
  FocusNode focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  void _submit(WidgetRef ref, String msg) {
    if (msg.isNotEmpty) {
      onSubmit?.call(msg, ref);
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
