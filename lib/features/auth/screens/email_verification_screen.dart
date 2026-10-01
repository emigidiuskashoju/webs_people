import 'package:flutter/material.dart';

import '../../../core/errors/api_exception.dart';
import '../services/auth_service.dart';

class EmailVerificationScreen extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _codeController = TextEditingController();
  final AuthService _authService = AuthService();

  bool _isLoading = false;
  bool _isResending = false;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final verified = await _authService.verifyEmail(
        email: widget.email,
        code: _codeController.text.trim(),
      );

      if (!mounted) {
        return;
      }

      if (!verified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'The server did not confirm email verification.',
            ),
          ),
        );
        return;
      }

      // ----------------------------------------------------------
      // Verification succeeded.
      //
      // NEXT STEP:
      //   Show the Terms & Conditions screen.
      //
      // The user must read and accept the terms before
      // continuing to Create Password.
      // ----------------------------------------------------------
      Navigator.pushReplacementNamed(
        context,
        '/terms',
        arguments: widget.email,
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Verification error: ${e.message}',
          ),
        ),
      );
    } catch (e, stackTrace) {
      debugPrint('EMAIL VERIFICATION ERROR: $e');
      debugPrint('EMAIL VERIFICATION STACK TRACE:\n$stackTrace');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Verification error: $e'),
          duration: const Duration(seconds: 8),
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

  Future<void> _resend() async {
    if (_isResending) {
      return;
    }

    setState(() {
      _isResending = true;
    });

    try {
      await _authService.resendVerificationCode(
        email: widget.email,
      );

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'A new verification code has been sent.',
          ),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
        ),
      );
    } catch (e) {
      debugPrint('RESEND VERIFICATION ERROR: $e');

      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Resend error: $e'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isResending = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Verify Email'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 32),

                const Icon(
                  Icons.mark_email_read_outlined,
                  size: 64,
                ),

                const SizedBox(height: 24),

                Text(
                  'Check your email',
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .headlineSmall
                      ?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),

                const SizedBox(height: 12),

                const Text(
                  'We sent a 6-digit verification code to:',
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 6),

                Text(
                  widget.email,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 32),

                TextFormField(
                  controller: _codeController,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    letterSpacing: 8,
                    fontWeight: FontWeight.bold,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Verification code',
                    border: OutlineInputBorder(),
                    counterText: '',
                  ),
                  validator: (value) {
                    final code = value?.trim() ?? '';
                    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
                      return 'Enter the 6-digit code.';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 20),

                ElevatedButton(
                  onPressed: _isLoading ? null : _verify,
                  child: _isLoading
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Text('Verify Email'),
                ),

                const SizedBox(height: 12),

                TextButton(
                  onPressed: _isLoading || _isResending ? null : _resend,
                  child: _isResending
                      ? const Text('Sending...')
                      : const Text('Resend verification code'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}