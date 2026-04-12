import 'package:flutter/material.dart';
import 'app.dart';
import 'screens/auth/sign_in_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool isLoggedIn = false;

  void _handleSignIn() {
    setState(() => isLoggedIn = true);
  }

  void _handleSignOut() {
    setState(() => isLoggedIn = false);
  }

  @override
  Widget build(BuildContext context) {
    if (!isLoggedIn) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SignInScreen(
          onSignIn: _handleSignIn,
        ),
      );
    }

    return NuhrisEmployeeApp(
      onSignOut: _handleSignOut,
    );
  }
}
