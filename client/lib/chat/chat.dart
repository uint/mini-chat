import 'package:flutter/material.dart';
import 'package:minichat_client/chat/chat_input.dart';
import 'package:minichat_client/chat/chat_msg_list.dart';
import 'package:minichat_client/chat/user_list.dart';
import 'package:minichat_client/chat_repo/chat_repo.dart';

class Chat extends StatefulWidget {
  const Chat(this._repo, {super.key});

  final ChatRepo _repo;

  @override
  State<Chat> createState() => _ChatState();
}

class _ChatState extends State<Chat> {
  final controller = MessageListController();
  late String handle;

  void _onSubmit(String msg) async {
    controller.addMessage(Message(DateTime.now(), User(handle), msg),
        completionFuture: widget._repo.sendMessage(msg));
  }

  @override
  Widget build(BuildContext context) {
    widget._repo.watchMessages().forEach((msg) {
      controller.addMessage(msg);
    });

    if (widget._repo.handle == null) {
      Navigator.pop(context);
    }
    handle = widget._repo.handle!;

    return WillPopScope(
      onWillPop: () async {
        await widget._repo.logout();
        return true;
      },
      child: LayoutBuilder(builder: (_, constraints) {
        bool wide = constraints.maxWidth > 600;

        var actions = wide
            ? null
            : [
                Builder(
                  builder: (context) => IconButton(
                    icon: const Icon(Icons.people),
                    onPressed: () => Scaffold.of(context).openEndDrawer(),
                    tooltip: "users",
                  ),
                ),
              ];

        return Scaffold(
            endDrawer: wide
                ? null
                : UserList(widget._repo.users, widget._repo.watchUsers()),
            appBar: AppBar(
              title: const Text('mini-chat'),
              actions: actions,
            ),
            body: Column(
              children: [
                Expanded(
                    child: TextFieldTapRegion(
                  child: Row(
                    children: [
                      Expanded(
                        child: MessageList(wide, controller: controller),
                      ),
                      if (wide)
                        UserList(widget._repo.users, widget._repo.watchUsers()),
                    ],
                  ),
                )),
                ChatInput(
                  onSubmit: _onSubmit,
                ),
              ],
            ));
      }),
    );
  }
}
