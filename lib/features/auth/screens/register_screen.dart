import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../../auth/widgets/phone_number_field.dart';
import '../services/auth_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
  });

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
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final phoneNumber = PhoneNumberField.composeE164(
        phoneCode: _country.phoneCode,
        localNumber: _phoneController.text,
      );

      final email = await _authService.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phoneNumber: phoneNumber,
      );

      if (!mounted) return;

      Navigator.pushNamed(
        context,
        '/verify-email',
        arguments: email,
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
          content: Text('Registration failed. Please try again.'),
        ),
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
    final valid = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(email);
    if (!valid) return 'Enter a valid email address.';
    return null;
  }

  String? _validateNationalNumber(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Enter your phone number.';
    if (digits.length < 7) return 'Phone number is too short.';
    if (digits.length > 15) return 'Phone number is too long.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 20),
                const Icon(Icons.hub, size: 64),
                const SizedBox(height: 20),
                Text(
                  'Create your Webs account',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  'We will send a verification code to your email.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 32),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    prefixIcon: Icon(Icons.person_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
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
                ElevatedButton(
                  onPressed: _isLoading ? null : _register,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Continue'),
                ),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _isLoading
                      ? null
                      : () {
                          Navigator.pushReplacementNamed(
                            context,
                            '/login',
                          );
                        },
                  child: const Text('Already have an account? Login'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}