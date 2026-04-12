import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'screens/auth/sign_in_screen.dart';
import 'theme/app_theme.dart';

class NuhrisAuthApp extends StatelessWidget {
  const NuhrisAuthApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      home: SignInScreen(onSignIn: () {}),
    );
  }
}