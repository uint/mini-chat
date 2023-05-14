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
        title: const Text('Login'),
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

  void _setProcessing(bool state) {
    setState(() {
      _processing = state;
    });
  }

  void _submit() {
    if (_formKey.currentState!.validate()) {
      _setProcessing(true);

      var repo = ref.read(chatRepositoryProvider);

      repo
          .logIn(_handleController.text)
          .timeout(const Duration(seconds: 10))
          .then((_) => Navigator.push(context,
                  MaterialPageRoute<void>(builder: (BuildContext context) {
                return Chat();
              })))
          .catchError((e) => ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text("error: $e")),
              ))
          .whenComplete(() => _setProcessing(false));
    }
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
                  handleController: _handleController, processing: _processing),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: SubmitButton(onPressed: _processing ? null : _submit),
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
    required TextEditingController handleController,
    required bool processing,
  })  : _handleController = handleController,
        _processing = processing;

  static final validCharacters = RegExp(r'^[a-zA-Z0-9_]+$');

  final TextEditingController _handleController;
  final bool _processing;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      textAlign: TextAlign.center,
      autovalidateMode: AutovalidateMode.onUserInteraction,
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

class SubmitButton extends ConsumerWidget {
  const SubmitButton({
    super.key,
    void Function()? onPressed,
  }) : _onPressed = onPressed;

  final void Function()? _onPressed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton(
      onPressed: _onPressed,
      child: _onPressed == null
          ? const SizedBox(
              height: 22,
              width: 22,
              child:
                  CircularProgressIndicator(strokeWidth: 3, color: Colors.grey))
          : const Text("Log in"),
      style: ElevatedButton.styleFrom(fixedSize: const Size(150, 50)),
    );
  }
}
