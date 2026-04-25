import 'package:flutter/material.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.onSignIn});

  final Future<String?> Function(String email, String password) onSignIn;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final emailCtrl = TextEditingController();
  final passCtrl = TextEditingController();
  static const String _defaultLoginFailedMessage =
      'These credentials do not match our records.';
  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;
  String? _loginError;

  @override
  void dispose() {
    emailCtrl.dispose();
    passCtrl.dispose();
    super.dispose();
  }

  InputDecoration _inputDeco({
    required String hint,
    Widget? suffix,
    bool isError = false,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      suffixIcon: suffix,
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isError ? const Color(0xFFF2A7AE) : const Color(0xFFD0D7E2),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(
          color: isError ? const Color(0xFFE85563) : const Color(0xFF0E3F76),
          width: 1.4,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final heroHeight = (size.height * 0.4).clamp(270.0, 380.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F4F8),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              SizedBox(
                height: heroHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/images/login_background.jpg',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [Color(0xFF204D85), Color(0xFF0A2D5C)],
                          ),
                        ),
                      ),
                    ),
                    Container(color: const Color(0x9E10396A)),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(22, 18, 22, 34),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: const [
                          Text(
                            'NU HRIS\nHUMAN RESOURCE INFORMATION SYSTEM',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              letterSpacing: 0.4,
                              height: 1.25,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Empowering your\nworkforce\nmanagement',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 35,
                                  height: 1.03,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Streamline employee records, attendance tracking, and credential monitoring in one place.',
                                style: TextStyle(
                                  color: Color(0xDDE8EEFA),
                                  fontSize: 13,
                                  height: 1.35,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(18, 20, 18, 18),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFDFDFE),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x290B2450),
                          blurRadius: 20,
                          offset: Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Welcome back',
                          style: TextStyle(
                            fontSize: 30,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF102D62),
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Sign in to your account to continue',
                          style: TextStyle(
                            color: Color(0xFF6A7A95),
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (_loginError != null) ...[
                          const SizedBox(height: 18),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDF0F1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFF3BCC2),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Padding(
                                  padding: EdgeInsets.only(top: 1),
                                  child: Icon(
                                    Icons.error_outline,
                                    color: Color(0xFFEB3C44),
                                    size: 22,
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      const Text(
                                        'Login failed',
                                        style: TextStyle(
                                          color: Color(0xFFC62429),
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _loginError!,
                                        style: TextStyle(
                                          color: Color(0xFFEB3C44),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 18),
                        const Text(
                          'Email Address',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334A70),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: emailCtrl,
                          keyboardType: TextInputType.emailAddress,
                          onChanged: (_) {
                            if (_loginError != null) {
                              setState(() => _loginError = null);
                            }
                          },
                          decoration: _inputDeco(
                            hint: 'name@nu.edu.ph',
                            isError: _loginError != null,
                          ),
                        ),
                        if (_loginError != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            _loginError!,
                            style: const TextStyle(
                              color: Color(0xFFEB3C44),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        const Text(
                          'Password',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF334A70),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: passCtrl,
                          obscureText: _obscurePassword,
                          onChanged: (_) {
                            if (_loginError != null) {
                              setState(() => _loginError = null);
                            }
                          },
                          decoration: _inputDeco(
                            hint: 'Enter your password',
                            suffix: IconButton(
                              onPressed: () {
                                setState(
                                  () => _obscurePassword = !_obscurePassword,
                                );
                              },
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                                color: const Color(0xFF71839D),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            SizedBox(
                              width: 22,
                              height: 22,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (value) {
                                  setState(() => _rememberMe = value ?? false);
                                },
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                activeColor: const Color(0xFF0D3C73),
                                side: const BorderSide(
                                  color: Color(0xFFB7C2D3),
                                  width: 1.1,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'Remember me',
                              style: TextStyle(
                                color: Color(0xFF4E6284),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: ElevatedButton(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    final email = emailCtrl.text.trim();
                                    final password = passCtrl.text;
                                    if (email.isEmpty || password.isEmpty) {
                                      setState(() {
                                        _loginError =
                                            'Please enter your email and password.';
                                      });
                                      return;
                                    }

                                    setState(() {
                                      _isSubmitting = true;
                                      _loginError = null;
                                    });
                                    final error = await widget.onSignIn(
                                      email,
                                      password,
                                    );
                                    if (!mounted) {
                                      return;
                                    }
                                    setState(() => _isSubmitting = false);

                                    if (error != null) {
                                      setState(
                                        () => _loginError = error.isEmpty
                                            ? _defaultLoginFailedMessage
                                            : error,
                                      );
                                    }
                                  },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF0C3F78),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Sign In',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
