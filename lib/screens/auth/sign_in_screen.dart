import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'forgot_password_screen.dart';
import 'sign_up_screen.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({
    super.key,
    required this.onSignIn,
  });

  final VoidCallback onSignIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        middle: Text('NUHRIS'),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 18),
                  const Text(
                    'Welcome back',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Sign in with your account',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF6B7280),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      children: [
                        CupertinoTextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          placeholder: 'Email address',
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(CupertinoIcons.mail, color: Color(0xFF9CA3AF), size: 20),
                          ),
                          decoration: const BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.8),
                            ),
                          ),
                        ),
                        CupertinoTextField(
                          controller: passCtrl,
                          obscureText: true,
                          placeholder: 'Password',
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                          prefix: const Padding(
                            padding: EdgeInsets.only(left: 10),
                            child: Icon(CupertinoIcons.lock, color: Color(0xFF9CA3AF), size: 20),
                          ),
                          decoration: const BoxDecoration(),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  CupertinoButton.filled(
                    onPressed: widget.onSignIn,
                    borderRadius: BorderRadius.circular(12),
                    child: const Text('Sign In'),
                  ),
                  const SizedBox(height: 10),
                  CupertinoButton(
                    onPressed: () {},
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    child: const Text(
                      'Continue with Google',
                      style: TextStyle(color: Color(0xFF374151), fontWeight: FontWeight.w600),
                    ),
                  ),
                  const SizedBox(height: 10),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      Navigator.of(context).push(
                        CupertinoPageRoute(builder: (_) => const ForgotPasswordScreen()),
                      );
                    },
                    child: const Text('Forgot password?'),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text(
                        'Need an account? ',
                        style: TextStyle(color: Color(0xFF6B7280)),
                      ),
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          Navigator.of(context).push(
                            CupertinoPageRoute(builder: (_) => const SignUpScreen()),
                          );
                        },
                        child: const Text('Sign up'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}