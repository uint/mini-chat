import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:minichat_client/chat/chat.dart';
import 'package:minichat_client/chat_repo.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('login'),
      ),
      body: const LoginForm(),
    );
  }
}

class LoginForm extends ConsumerStatefulWidget {
  const LoginForm({super.key});

  @override
  LoginFormState createState() {
    return LoginFormState();
  }
}

class LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _handleController = TextEditingController();
  bool _processing = false;

  static final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              autovalidateMode: AutovalidateMode.onUserInteraction,
              controller: _handleController,
              decoration: const InputDecoration(
                border: UnderlineInputBorder(),
                labelText: 'Enter your handle',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your preferred handle';
                }

                if (value.length > 16) {
                  return 'The handle can be at most 16 characters long';
                }

                if (!validCharacters.hasMatch(value)) {
                  return 'Allowed characters: a-Z, 0-9, _';
                }
                return null;
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Center(
                child: ElevatedButton(
                  onPressed: _processing
                      ? null
                      : () {
                          if (_formKey.currentState!.validate()) {
                            setState(() {
                              _processing = true;
                            });
                            var repo = ref.read(chatRepositoryProvider);
                            repo
                                .logIn(_handleController.text)
                                .timeout(const Duration(seconds: 10))
                                .then((_) => Navigator.push(context,
                                        MaterialPageRoute<void>(
                                            builder: (BuildContext context) {
                                      return Chat();
                                    })))
                                .catchError((e) =>
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text("error: $e")),
                                    ))
                                .whenComplete(() => setState(() {
                                      _processing = false;
                                    }));
                          }
                        },
                  child: const Text('Submit'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
