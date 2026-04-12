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

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: Icon(icon, color: const Color(0xFFB0B0B0), size: 20),
      filled: true,
      fillColor: const Color(0xFFF3F4F6),
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFFD5D7DA)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Color(0xFF0B67B2), width: 1.2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFDEDEE8),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(14),
            child: Container(
              width: 360,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, 2),
                    color: Color(0x22000000),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Container(
                    height: 66,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Color(0xFF073D75), Color(0xFF0A63B4)],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 26),
                    child: Column(
                      children: [
                        const Text(
                          'Welcome to NUHRIS!',
                          style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Color(0xFF121212)),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to continue',
                          style: TextStyle(color: Color(0xFF9A9A9A), fontWeight: FontWeight.w700, fontSize: 13),
                        ),
                        const SizedBox(height: 18),
                        OutlinedButton.icon(
                          onPressed: () {},
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(44),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            foregroundColor: const Color(0xFF4B5563),
                          ),
                          icon: const Text('G', style: TextStyle(color: Color(0xFFEA4335), fontWeight: FontWeight.w900, fontSize: 22)),
                          label: const Text('Continue with Google', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: const [
                            Expanded(child: Divider(color: Color(0xFFBFBFBF))),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: 10),
                              child: Text('OR', style: TextStyle(color: Color(0xFF7A7A7A), fontWeight: FontWeight.w700)),
                            ),
                            Expanded(child: Divider(color: Color(0xFFBFBFBF))),
                          ],
                        ),
                        const SizedBox(height: 20),
                        const Text('Email', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: emailCtrl,
                          decoration: _inputDeco(hint: 'you@example.com', icon: Icons.mail_outline),
                        ),
                        const SizedBox(height: 12),
                        const Text('Password', style: TextStyle(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 6),
                        TextField(
                          controller: passCtrl,
                          obscureText: true,
                          decoration: _inputDeco(hint: '.............', icon: Icons.lock_outline),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            onPressed: widget.onSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF070C4A),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            child: const Text('Sign In', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ),
                        const SizedBox(height: 16),
                        InkWell(
                          onTap: () {
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()));
                          },
                          child: const Text('Forgot password?', style: TextStyle(fontWeight: FontWeight.w700, color: Color(0xFF555555))),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text('Need an account? ', style: TextStyle(color: Color(0xFF666666))),
                            InkWell(
                              onTap: () {
                                Navigator.push(context, MaterialPageRoute(builder: (_) => const SignUpScreen()));
                              },
                              child: const Text('Sign up', style: TextStyle(fontWeight: FontWeight.w800, color: Color(0xFF2F2F2F))),
                            ),
                          ],
                        ),
                      ],
                    ),
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
