import 'package:flutter/material.dart';
import 'screens/auth/sign_in_screen.dart';

class NuhrisAuthApp extends StatelessWidget {
  const NuhrisAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: SignInScreen(onSignIn: (email, password) async => null),
    );
  }
}
