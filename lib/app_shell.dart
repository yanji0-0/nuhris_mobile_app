import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'app.dart';
import 'screens/auth/sign_in_screen.dart';
import 'theme/app_theme.dart';

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
      return CupertinoApp(
        debugShowCheckedModeBanner: false,
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: const [Locale('en', 'US')],
        theme: const CupertinoThemeData(
          brightness: Brightness.light,
          primaryColor: AppColors.primaryBlue,
        ),
        builder: (context, child) {
          return Theme(
            data: buildAppTheme(),
            child: child ?? const SizedBox.shrink(),
          );
        },
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