import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/app_shell.dart';
import '../../../core/errors/api_exception.dart';
import '../../../core/theme/webs_colors.dart';
import '../../../shared/widgets/webs_background.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePin = true;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await _authService.login(
        email: _emailController.text.trim(),
        password: _pinController.text,
      );

      if (!mounted) return;

      // Login is specifically for entering the Security system.
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const WebsAppShell(),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Login failed. Please try again.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Security Login',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: WebsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              kToolbarHeight + MediaQuery.of(context).padding.top + 16,
              24,
              24,
            ),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: WebsColors.softGreen(context),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: WebsColors.shadow(context),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.security,
                        size: 56,
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Security & Track',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Enter your email and 4-digit PIN to access '
                    'your device security and tracking tools.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: WebsColors.textLight(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ---------- EMAIL ----------
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      labelStyle:
                          TextStyle(color: WebsColors.textLight(context)),
                      prefixIcon: const Icon(
                        Icons.email_outlined,
                        color: WebsColors.primaryGreen,
                      ),
                      filled: true,
                      fillColor: WebsColors.softGreen(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: WebsColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                    ),
                    validator: (value) {
                      final email = value?.trim() ?? '';
                      if (email.isEmpty) return 'Enter your email.';
                      final regex =
                          RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
                      if (!regex.hasMatch(email)) {
                        return 'Enter a valid email.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 16),

                  // ---------- PIN ----------
                  TextFormField(
                    controller: _pinController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    enabled: !_isLoading,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    onFieldSubmitted: (_) {
                      if (!_isLoading) _login();
                    },
                    decoration: InputDecoration(
                      labelText: '4-digit PIN',
                      counterText: '',
                      prefixIcon: const Icon(
                        Icons.lock_outline,
                        color: WebsColors.primaryGreen,
                      ),
                      filled: true,
                      fillColor: WebsColors.softGreen(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: WebsColors.primaryGreen,
                          width: 2,
                        ),
                      ),
                      suffixIcon: IconButton(
                        onPressed: () {
                          setState(() => _obscurePin = !_obscurePin);
                        },
                        icon: Icon(
                          _obscurePin
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: WebsColors.textLight(context),
                        ),
                      ),
                    ),
                    validator: (value) {
                      final pin = value ?? '';
                      if (pin.isEmpty) return 'Enter your PIN.';
                      if (pin.length != 4) {
                        return 'PIN must be exactly 4 digits.';
                      }
                      return null;
                    },
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _login,
                      style: FilledButton.styleFrom(
                        backgroundColor: WebsColors.primaryGreen,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              height: 24,
                              width: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Enter Security',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.pushReplacementNamed(
                              context,
                              '/register',
                            );
                          },
                    child: const Text(
                      'Create a new account',
                      style: TextStyle(
                        color: WebsColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
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