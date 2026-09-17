import 'package:flutter/material.dart';

import '../../core/errors/api_exception.dart';
import '../auth/services/auth_service.dart';
import 'email_verification_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

  @override
  State<RegisterScreen> createState() =>
      _RegisterScreenState();
}

class _RegisterScreenState
    extends State<RegisterScreen> {
  final _formKey =
      GlobalKey<FormState>();

  final _nameController =
      TextEditingController();

  final _emailController =
      TextEditingController();

  final _phoneController =
      TextEditingController();

  final AuthService _authService =
      AuthService();

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();

    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isLoading = true;
    });

    try {
      final email =
          await _authService.register(
        name: _nameController.text,
        email: _emailController.text,
        phoneNumber:
            _phoneController.text,
      );

      if (!mounted) {
        return;
      }

      await Navigator.of(context)
          .pushReplacement(
        MaterialPageRoute(
          builder: (_) =>
              EmailVerificationScreen(
            email: email,
          ),
        ),
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message =
          e is ApiException
              ? e.message
              : 'Registration failed. Please try again.';

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String? _validateName(
    String? value,
  ) {
    final name =
        value?.trim() ?? '';

    if (name.isEmpty) {
      return 'Enter your name.';
    }

    if (name.length < 2) {
      return 'Name is too short.';
    }

    return null;
  }

  String? _validateEmail(
    String? value,
  ) {
    final email =
        value?.trim() ?? '';

    if (email.isEmpty) {
      return 'Enter your email.';
    }

    final emailRegex = RegExp(
      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
    );

    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address.';
    }

    return null;
  }

  String? _validatePhone(
    String? value,
  ) {
    final phone =
        value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Enter your phone number.';
    }

    if (!phone.startsWith('+')) {
      return 'Use international format, for example +255...';
    }

    final digits =
        phone.substring(1);

    if (
        !RegExp(r'^\d{8,15}$')
            .hasMatch(digits)) {
      return 'Enter a valid international phone number.';
    }

    return null;
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Create your Webs account',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding:
              const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 20,
                ),

                const Icon(
                  Icons.hub,
                  size: 72,
                  color: Colors.green,
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Welcome to Webs People',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 10,
                ),

                const Text(
                  'Create your account once. '
                  'We will verify your email and keep you signed in.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 32,
                ),

                TextFormField(
                  controller:
                      _nameController,
                  textInputAction:
                      TextInputAction.next,
                  enabled: !_isLoading,
                  decoration:
                      const InputDecoration(
                    labelText: 'Name',
                    prefixIcon:
                        Icon(Icons.person),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator:
                      _validateName,
                ),

                const SizedBox(
                  height: 16,
                ),

                TextFormField(
                  controller:
                      _emailController,
                  keyboardType:
                      TextInputType.emailAddress,
                  textInputAction:
                      TextInputAction.next,
                  enabled: !_isLoading,
                  decoration:
                      const InputDecoration(
                    labelText: 'Email',
                    prefixIcon:
                        Icon(Icons.email),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator:
                      _validateEmail,
                ),

                const SizedBox(
                  height: 16,
                ),

                TextFormField(
                  controller:
                      _phoneController,
                  keyboardType:
                      TextInputType.phone,
                  textInputAction:
                      TextInputAction.done,
                  enabled: !_isLoading,
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Phone number',
                    hintText:
                        '+255712345678',
                    prefixIcon:
                        Icon(Icons.phone),
                    border:
                        OutlineInputBorder(),
                  ),
                  validator:
                      _validatePhone,
                  onFieldSubmitted: (_) {
                    _register();
                  },
                ),

                const SizedBox(
                  height: 24,
                ),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : _register,
                    child: _isLoading
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Continue',
                          ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                const Text(
                  'Your email is used for verification. '
                  'Your phone number is used to help Webs People find connections from your contacts.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}