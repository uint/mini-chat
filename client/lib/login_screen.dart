import 'package:flutter/material.dart';
import 'package:minichat_client/chat/chat.dart';
import 'package:minichat_client/chat_repo/fake_chat_repo.dart';
import 'package:minichat_client/chat_repo/ws_chat_repo.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
      ),
      body: const LoginForm(),
    );
  }
}

class LoginForm extends StatefulWidget {
  const LoginForm({super.key});

  @override
  LoginFormState createState() {
    return LoginFormState();
  }
}

class LoginFormState extends State<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _handleController = TextEditingController();
  bool _processing = false;
  bool _valid = false;

  void _setProcessing(bool state) {
    setState(() {
      _processing = state;
    });
  }

  void _validate() {
    setState(() {
      _valid = _formKey.currentState?.validate() ?? false;
    });
  }

  void _submit() {
    _setProcessing(true);

    //var repo = FakeChatRepo();
    var repo = WsChatRepo(Uri.parse("ws://127.0.0.1:8080"));

    repo
        .logIn(_handleController.text)
        .timeout(const Duration(seconds: 10))
        .then((_) => Navigator.push(context,
                MaterialPageRoute<void>(builder: (BuildContext context) {
              return Chat(repo);
            })))
        .catchError((e) {
      repo.close();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("error: $e")),
      );
    }).whenComplete(() => _setProcessing(false));
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 220,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              HandleField(
                handleController: _handleController,
                processing: _processing,
                onChanged: (_) => _validate(),
                onSubmit: (_processing || !_valid) ? null : _submit,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: SubmitButton(_processing,
                      onPressed: (_processing || !_valid) ? null : _submit),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class HandleField extends StatelessWidget {
  const HandleField({
    super.key,
    onChanged,
    onSubmit,
    required TextEditingController handleController,
    required bool processing,
  })  : _handleController = handleController,
        _processing = processing,
        _onChanged = onChanged,
        _onSubmit = onSubmit;

  static final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');

  final TextEditingController _handleController;
  final bool _processing;
  final void Function(String)? _onChanged;
  final void Function()? _onSubmit;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      onChanged: _onChanged,
      onFieldSubmitted: (_) => _onSubmit?.call(),
      textAlign: TextAlign.center,
      //autovalidateMode: AutovalidateMode.onUserInteraction,
      controller: _handleController,
      enabled: !_processing,
      decoration: const InputDecoration(
        border: UnderlineInputBorder(),
        label: Center(child: Text("Handle")),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your preferred handle';
        }

        if (value.length > 16) {
          return 'Please use at most 16 characters';
        }

        if (!validCharacters.hasMatch(value)) {
          return 'Allowed characters: a-Z, 0-9, _';
        }
        return null;
      },
    );
  }
}

class SubmitButton extends StatelessWidget {
  const SubmitButton(
    this._processing, {
    super.key,
    void Function()? onPressed,
  }) : _onPressed = onPressed;

  final void Function()? _onPressed;
  final bool _processing;

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: _onPressed,
      style: ElevatedButton.styleFrom(fixedSize: const Size(150, 50)),
      child: _processing
          ? const SizedBox(
              height: 22,
              width: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 3, color: Colors.grey))
          : const Text("Log in"),
    );
  }
}
