import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../core/errors/api_exception.dart';
import '../../core/theme/webs_colors.dart';
import '../../core/widgets/webs_background.dart';
import '../auth/services/auth_service.dart';
import 'screens/email_verification_screen.dart';
import 'widgets/phone_number_field.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final AuthService _authService = AuthService();

  // Not const — Country has no const constructor.
  Country _country = Country(
    phoneCode: '255',
    countryCode: 'TZ',
    e164Sc: 0,
    geographic: true,
    level: 1,
    name: 'Tanzania',
    example: '712345678',
    displayName: 'Tanzania',
    displayNameNoCountryCode: 'Tanzania',
    e164Key: '255-TZ-0',
  );

  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final phoneNumber = PhoneNumberField.composeE164(
        phoneCode: _country.phoneCode,
        localNumber: _phoneController.text,
      );

      final email = await _authService.register(
        name: _nameController.text,
        email: _emailController.text,
        phoneNumber: phoneNumber,
      );

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is ApiException
          ? e.message
          : 'Registration failed. Please try again.';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validateName(String? value) {
    final name = value?.trim() ?? '';
    if (name.isEmpty) return 'Enter your name.';
    if (name.length < 2) return 'Name is too short.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    if (email.isEmpty) return 'Enter your email.';
    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      return 'Enter a valid email address.';
    }
    return null;
  }

  String? _validateNationalNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter your phone number.';
    if (digits.length < 7) return 'Phone number is too short.';
    if (digits.length > 15) return 'Phone number is too long.';
    return null;
  }

  InputDecoration _fieldDecoration({
    required String label,
    String? hint,
    required IconData icon,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      labelStyle: TextStyle(color: WebsColors.textLight(context)),
      hintStyle: TextStyle(color: WebsColors.textLight(context)),
      prefixIcon: Icon(icon, color: WebsColors.primaryGreen),
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
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create your Webs account'),
      ),
      body: WebsBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 100, 24, 24),
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
                        Icons.hub,
                        size: 56,
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Welcome to Webs',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Create your account once. '
                    'We will verify your email and keep you signed in.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: WebsColors.textLight(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _nameController,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    style: TextStyle(color: WebsColors.textDark(context)),
                    decoration: _fieldDecoration(
                      label: 'Name',
                      icon: Icons.person,
                    ),
                    validator: _validateName,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                    style: TextStyle(color: WebsColors.textDark(context)),
                    decoration: _fieldDecoration(
                      label: 'Email',
                      icon: Icons.email,
                    ),
                    validator: _validateEmail,
                  ),
                  const SizedBox(height: 16),
                  PhoneNumberField(
                    controller: _phoneController,
                    initialCountry: _country,
                    enabled: !_isLoading,
                    textInputAction: TextInputAction.done,
                    onCountryChanged: (country) {
                      setState(() => _country = country);
                    },
                    validator: _validateNationalNumber,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _register,
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
                              'Continue',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            Navigator.of(context).pushReplacementNamed(
                              '/login',
                            );
                          },
                    child: Text(
                      'Already have an account? Login',
                      style: TextStyle(
                        color: WebsColors.primaryGreen,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Your email is used for verification. '
                    'Your phone number is used to help find connections '
                    'from your contacts.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: WebsColors.textLight(context),
                      fontSize: 13,
                      height: 1.4,
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