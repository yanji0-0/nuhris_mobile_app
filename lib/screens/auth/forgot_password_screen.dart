import 'package:flutter/material.dart';
import 'check_email_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final emailCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco() {
    return InputDecoration(
      hintText: 'you@example.com',
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      prefixIcon: const Icon(Icons.mail_outline, color: Color(0xFFB0B0B0), size: 20),
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
                  BoxShadow(blurRadius: 8, offset: Offset(0, 2), color: Color(0x22000000)),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => Navigator.pop(context),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.chevron_left, color: Color(0xFFA8A8A8)),
                          SizedBox(width: 2),
                          Text(
                            'Back to sign in',
                            style: TextStyle(color: Color(0xFFA8A8A8), fontWeight: FontWeight.w700),
                          )
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Center(
                      child: Text(
                        'Create your account',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Center(
                      child: Text(
                        "Enter your email and we'll send you a link to\nreset your password",
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Color(0xFF5E5E5E), fontSize: 14, height: 1.35),
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Center(child: Text('Email', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailCtrl,
                      decoration: _inputDeco(),
                    ),

                    const SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {
                          final email = emailCtrl.text.trim().isEmpty
                              ? 'XXXX1234@gmail.com'
                              : emailCtrl.text.trim();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CheckEmailScreen(email: email),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF070C4A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Send Reset Link', style: TextStyle(fontWeight: FontWeight.w700)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}