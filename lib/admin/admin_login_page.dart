import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const Color _background = Color(0xFF171717);
const Color _surface = Color(0xFF222222);
const Color _ivory = Color(0xFFF4EFE6);
const Color _bronze = Color(0xFFB6A080);
const Color _muted = Color(0xFFAAA69F);

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await Supabase.instance.client.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('تم تسجيل الدخول بنجاح'),
          backgroundColor: Color(0xFF526B50),
        ),
      );

      // هنربط الانتقال إلى لوحة التحكم بعد إنشاء صفحة Dashboard.
    } on AuthException catch (error) {
      if (!mounted) return;

      setState(() {
        _errorMessage = error.message;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _errorMessage = 'حدث خطأ غير متوقع. حاول مرة أخرى.';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Container(
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                color: _surface,
                border: Border.all(color: const Color(0xFF3B3935)),
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.architecture, color: _bronze, size: 42),

                    const SizedBox(height: 20),

                    const Text(
                      'INNOVISTA',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _ivory,
                        fontSize: 27,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 4,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'ADMINISTRATION PANEL',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _bronze,
                        fontSize: 10,
                        letterSpacing: 2.5,
                      ),
                    ),

                    const SizedBox(height: 42),

                    const Text(
                      'Welcome Back',
                      style: TextStyle(
                        color: _ivory,
                        fontSize: 25,
                        fontWeight: FontWeight.w300,
                      ),
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Sign in to manage your studio.',
                      style: TextStyle(color: _muted, fontSize: 13),
                    ),

                    const SizedBox(height: 30),

                    const Text(
                      'EMAIL ADDRESS',
                      style: TextStyle(
                        color: _bronze,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      style: const TextStyle(color: _ivory),
                      decoration: _inputDecoration(
                        hint: 'admin@example.com',
                        icon: Icons.email_outlined,
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'أدخل البريد الإلكتروني';
                        }

                        if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                            .hasMatch(value.trim())) {
                          return 'البريد الإلكتروني غير صحيح';
                        }

                        return null;
                      },
                    ),

                    const SizedBox(height: 24),

                    const Text(
                      'PASSWORD',
                      style: TextStyle(
                        color: _bronze,
                        fontSize: 10,
                        letterSpacing: 1.5,
                      ),
                    ),

                    const SizedBox(height: 10),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: !_isPasswordVisible,
                      style: const TextStyle(color: _ivory),
                      decoration:
                          _inputDecoration(
                            hint: 'Enter your password',
                            icon: Icons.lock_outline,
                          ).copyWith(
                            suffixIcon: IconButton(
                              onPressed: () {
                                setState(() {
                                  _isPasswordVisible = !_isPasswordVisible;
                                });
                              },
                              icon: Icon(
                                _isPasswordVisible
                                    ? Icons.visibility_off_outlined
                                    : Icons.visibility_outlined,
                                color: _muted,
                                size: 19,
                              ),
                            ),
                          ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'أدخل كلمة المرور';
                        }

                        return null;
                      },
                    ),

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 20),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFE58C83),
                          fontSize: 12,
                        ),
                      ),
                    ],

                    const SizedBox(height: 30),

                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _signIn,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bronze,
                          foregroundColor: _background,
                          disabledBackgroundColor: _bronze.withValues(
                            alpha: 0.5,
                          ),
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.zero,
                          ),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                height: 21,
                                width: 21,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: _background,
                                ),
                              )
                            : const Text(
                                'SIGN IN',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 2,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 28),

                    const Text(
                      'AUTHORIZED ACCESS ONLY',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: _muted,
                        fontSize: 9,
                        letterSpacing: 1.5,
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

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(color: Color(0xFF77736D), fontSize: 13),
      prefixIcon: Icon(icon, color: _bronze, size: 19),
      filled: true,
      fillColor: _background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      enabledBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFF3B3935)),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: _bronze),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFFE58C83)),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: BorderRadius.zero,
        borderSide: BorderSide(color: Color(0xFFE58C83)),
      ),
    );
  }
}
