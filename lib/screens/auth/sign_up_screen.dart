import 'package:flutter/material.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  final confirmCtrl = TextEditingController();

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    confirmCtrl.dispose();
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
                    const SizedBox(height: 18),

                    const Center(child: Text('Email', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: emailCtrl,
                      decoration: _inputDeco(hint: 'you@example.com', icon: Icons.mail_outline),
                    ),
                    const SizedBox(height: 12),

                    const Center(child: Text('Password', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: passCtrl,
                      obscureText: true,
                      decoration: _inputDeco(hint: '.............', icon: Icons.lock_outline),
                    ),
                    const SizedBox(height: 12),

                    const Center(child: Text('Confirm Password', style: TextStyle(fontWeight: FontWeight.w700))),
                    const SizedBox(height: 6),
                    TextField(
                      controller: confirmCtrl,
                      obscureText: true,
                      decoration: _inputDeco(hint: '.............', icon: Icons.lock_outline),
                    ),

                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF070C4A),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: const Text('Create Account', style: TextStyle(fontWeight: FontWeight.w700)),
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