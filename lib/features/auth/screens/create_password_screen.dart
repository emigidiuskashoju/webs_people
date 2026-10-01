import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/errors/api_exception.dart';
import '../../../core/theme/webs_colors.dart';
import '../../../shared/widgets/webs_background.dart';
import '../../main/main_navigation_screen.dart';
import '../services/auth_service.dart';

class CreatePasswordScreen extends StatefulWidget {
  final String email;

  const CreatePasswordScreen({
    super.key,
    required this.email,
  });

  @override
  State<CreatePasswordScreen> createState() =>
      _CreatePasswordScreenState();
}

class _CreatePasswordScreenState extends State<CreatePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmationController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _obscurePin = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }

  Future<void> _createPassword() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      await _authService.setPassword(
        email: widget.email,
        password: _passwordController.text,
        passwordConfirmation: _confirmationController.text,
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (e) {
      debugPrint('CREATE PIN ERROR: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create your PIN: $e'),
          duration: const Duration(seconds: 6),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String? _validatePin(String? value) {
    final pin = value ?? '';
    if (pin.isEmpty) return 'Enter a 4-digit PIN.';
    if (pin.length != 4) return 'PIN must be exactly 4 digits.';
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      return 'PIN must contain only numbers.';
    }
    return null;
  }

  String? _validateConfirmation(String? value) {
    if (value != _passwordController.text) {
      return 'PINs do not match.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text(
          'Create PIN',
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
                        Icons.pin_outlined,
                        size: 56,
                        color: WebsColors.primaryGreen,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Create your 4-digit PIN',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: WebsColors.textDark(context),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your email has been verified. '
                    'Choose a 4-digit PIN to finish your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: WebsColors.textLight(context),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ---------- PIN ----------
                  TextFormField(
                    controller: _passwordController,
                    obscureText: _obscurePin,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    maxLength: 4,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    style: const TextStyle(
                      fontSize: 32,
                      letterSpacing: 16,
                      fontWeight: FontWeight.bold,
                    ),
                    decoration: InputDecoration(
                      labelText: '4-digit PIN',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
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
                        ),
                      ),
                    ),
                    validator: _validatePin,
                  ),

                  const SizedBox(height: 16),

                  // ---------- CONFIRM PIN ----------
                  TextFormField(
                    controller: _confirmationController,
                    obscureText: _obscureConfirm,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.done,
                    maxLength: 4,
                    textAlign: TextAlign.center,
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
                      if (!_isLoading) _createPassword();
                    },
                    decoration: InputDecoration(
                      labelText: 'Confirm 4-digit PIN',
                      counterText: '',
                      prefixIcon: const Icon(Icons.lock_outline),
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
                          setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          );
                        },
                        icon: Icon(
                          _obscureConfirm
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                        ),
                      ),
                    ),
                    validator: _validateConfirmation,
                  ),

                  const SizedBox(height: 24),

                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _isLoading ? null : _createPassword,
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
                              'Finish Registration',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  Text(
                    'Keep this PIN private. You will need it to '
                    'enter the Security & Track system.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: WebsColors.textLight(context),
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