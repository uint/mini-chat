import 'package:flutter/material.dart';
import 'package:minichat_client/chat_repo/chat_repo.dart';

class UserList extends StatelessWidget {
  const UserList(this._initial, this._stream, {super.key});

  final Set<User> _initial;
  final Stream<Set<User>> _stream;

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 240, 245, 240),
          //border: Border(left: BorderSide())
        ),
        padding: const EdgeInsets.symmetric(horizontal: 6),
        width: 200,
        child: Column(children: [
          const Text(style: TextStyle(color: Colors.grey), "users"),
          Expanded(
              child: StreamBuilder(
            stream: _stream,
            builder: (_, AsyncSnapshot<Set<User>> snapshot) {
              var users = snapshot.data ?? _initial;

              return ListView(
                  children: users
                      .map((user) => Text(
                          style: TextStyle(color: user.color), user.handle))
                      .toList());
            },
          )),
        ]));
  }
}
