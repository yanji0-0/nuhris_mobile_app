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
  bool isLoggedIn = false;
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    _bootstrapSession();
  }

  Future<void> _bootstrapSession() async {
    final allowed = await ApiClient.instance.hasEmployeeAccess();
    if (!mounted) {
      return;
    }
    setState(() {
      isLoggedIn = allowed;
      _isInitializing = false;
    });
  }

  Future<String?> _handleSignIn(String email, String password) async {
    try {
      await ApiClient.instance.login(email: email, password: password);
      final allowed = await ApiClient.instance.hasEmployeeAccess();
      if (!allowed) {
        return 'These credentials do not match our records.';
      }
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
    if (_isInitializing) {
      return const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(body: Center(child: CircularProgressIndicator())),
      );
    }

    if (!isLoggedIn) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        home: SignInScreen(onSignIn: _handleSignIn),
      );
    }

    return NuhrisEmployeeApp(onSignOut: _handleSignOut);
  }
}
