import 'package:flutter/material.dart';

typedef OnSubmit = void Function(String);

class ChatInput extends StatelessWidget {
  ChatInput({
    super.key,
    this.onSubmit,
  });

  final OnSubmit? onSubmit;
  final FocusNode focusNode = FocusNode();
  final TextEditingController _controller = TextEditingController();

  void _submit(String msg) {
    if (msg.isNotEmpty) {
      onSubmit?.call(msg);
      _controller.text = "";
    }
    focusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: TextField(
          onSubmitted: _submit,
          controller: _controller,
          focusNode: focusNode,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: 'enter your message',
          ),
        )),
        TextFieldTapRegion(child: FloatingActionButton(onPressed: () {
          _submit(_controller.text);
        })),
      ],
    );
  }
}
