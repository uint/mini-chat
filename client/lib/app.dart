import 'package:flutter/material.dart';
import 'package:minichat_client/login_screen.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mini-chat',
      theme: ThemeData(
        primarySwatch: Colors.lightGreen,
      ),
      home: const LoginScreen(),
    );
  }
}
