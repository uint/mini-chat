import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat_repo.dart';

class ChatInput extends ConsumerWidget {
  const ChatInput({
    super.key,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FloatingActionButton(onPressed: () {
      var repo = ref.read(chatRepositoryProvider);
      repo.pushMessage(Message(DateTime.now(), User("me"), "hi"));
    });
  }
}
