import 'package:flutter/material.dart';
import 'app.dart';
import 'screens/auth/sign_in_screen.dart';
import 'services/api_client.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  bool isLoggedIn = ApiClient.instance.isAuthenticated;

  Future<String?> _handleSignIn(String email, String password) async {
    try {
      await ApiClient.instance.login(email: email, password: password);
      if (mounted) {
        setState(() => isLoggedIn = true);
      }
      return null;
    } on ApiException catch (error) {
      return error.message;
    } catch (_) {
      return 'Unable to sign in right now. Please try again.';
    }
  }

  void _handleSignOut() {
    ApiClient.instance.logout();
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
