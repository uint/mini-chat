import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat/chat_input.dart';
import 'package:minichat_client/chat/chat_msg_list.dart';
import 'package:minichat_client/chat_repo/chat_repo.dart';

class Chat extends ConsumerStatefulWidget {
  Chat({super.key});

  @override
  ConsumerState<Chat> createState() => _ChatState();
}

class _ChatState extends ConsumerState<Chat> {
  final controller = MessageListController();
  late String handle;

  void _onSubmit(String msg, WidgetRef ref) async {
    var repo = ref.read(chatRepositoryProvider);
    controller.addMessage(Message(DateTime.now(), User(handle), msg),
        completionFuture: repo.sendMessage(msg));
  }

  @override
  Widget build(BuildContext context) {
    var repo = ref.read(chatRepositoryProvider);
    if (repo.handle == null) {
      Navigator.pop(context);
    }
    handle = repo.handle!;

    return Scaffold(
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
        ));
  }
}
