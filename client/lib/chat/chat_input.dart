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
    return TextField(
      onSubmitted: _submit,
      controller: _controller,
      focusNode: focusNode,
      decoration: const InputDecoration(
        fillColor: Color.fromARGB(255, 225, 235, 225),
        filled: true,
        prefixIcon: Icon(Icons.message),
        border: InputBorder.none,
        hintText: 'enter your message',
      ),
    );
  }
}
