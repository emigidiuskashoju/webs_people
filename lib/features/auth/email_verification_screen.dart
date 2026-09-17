import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors/api_exception.dart';
import '../main/main_navigation_screen.dart';
import 'services/auth_service.dart';

class EmailVerificationScreen
    extends StatefulWidget {
  final String email;

  const EmailVerificationScreen({
    super.key,
    required this.email,
  });

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends State<EmailVerificationScreen> {
  final TextEditingController _codeController =
      TextEditingController();

  final AuthService _authService =
      AuthService();

  Timer? _timer;

  bool _isVerifying = false;
  bool _isResending = false;

  int _resendSeconds = 60;

  @override
  void initState() {
    super.initState();

    _startResendTimer();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _codeController.dispose();

    super.dispose();
  }

  void _startResendTimer() {
    _timer?.cancel();

    setState(() {
      _resendSeconds = 60;
    });

    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_resendSeconds <= 1) {
          timer.cancel();

          setState(() {
            _resendSeconds = 0;
          });

          return;
        }

        setState(() {
          _resendSeconds--;
        });
      },
    );
  }

  Future<void> _verify() async {
    final code =
        _codeController.text.trim();

    if (code.length != 6 ||
        !RegExp(r'^\d{6}$').hasMatch(code)) {
      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Enter the 6-digit verification code.',
          ),
        ),
      );

      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _isVerifying = true;
    });

    try {
      await _authService.verifyEmail(
        email: widget.email,
        code: code,
      );

      if (!mounted) {
        return;
      }

      // Verification succeeded.
      // Open the main application directly.
      // Chats is the first tab in MainNavigationScreen.
      Navigator.of(context)
          .pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) =>
              const MainNavigationScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      if (!mounted) {
        return;
      }

      final message =
          e is ApiException
              ? e.message
              : 'Verification failed. Please try again.';

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isVerifying = false;
        });
      }
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0 ||
        _isResending ||
        _isVerifying) {
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

      _startResendTimer();

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'A new verification code has been sent.',
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
              : 'Could not resend the code.';

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(message),
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
  Widget build(
    BuildContext context,
  ) {
    return PopScope(
      canPop: false,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const Text(
            'Verify your email',
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding:
                const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.stretch,
              children: [
                const SizedBox(
                  height: 30,
                ),

                const Icon(
                  Icons.mark_email_read,
                  size: 80,
                  color: Colors.green,
                ),

                const SizedBox(
                  height: 24,
                ),

                const Text(
                  'Check your email',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                  ),
                ),

                const SizedBox(
                  height: 12,
                ),

                Text(
                  'We sent a 6-digit verification code to\n${widget.email}',
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    fontSize: 15,
                  ),
                ),

                const SizedBox(
                  height: 32,
                ),

                TextField(
                  controller:
                      _codeController,
                  enabled:
                      !_isVerifying,
                  keyboardType:
                      TextInputType.number,
                  maxLength: 6,
                  textAlign:
                      TextAlign.center,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight:
                        FontWeight.bold,
                    letterSpacing: 8,
                  ),
                  decoration:
                      const InputDecoration(
                    labelText:
                        'Verification code',
                    hintText:
                        '000000',
                    counterText: '',
                    border:
                        OutlineInputBorder(),
                  ),
                  onSubmitted: (_) {
                    _verify();
                  },
                ),

                const SizedBox(
                  height: 24,
                ),

                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    onPressed:
                        _isVerifying
                            ? null
                            : _verify,
                    child: _isVerifying
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          )
                        : const Text(
                            'Verify email',
                          ),
                  ),
                ),

                const SizedBox(
                  height: 20,
                ),

                TextButton(
                  onPressed:
                      (_resendSeconds == 0 &&
                              !_isResending &&
                              !_isVerifying)
                          ? _resend
                          : null,
                  child: _isResending
                      ? const Text(
                          'Sending...',
                        )
                      : _resendSeconds > 0
                          ? Text(
                              'Resend code in '
                              '$_resendSeconds s',
                            )
                          : const Text(
                              'Resend verification code',
                            ),
                ),

                const SizedBox(
                  height: 16,
                ),

                const Text(
                  'The verification code expires after 10 minutes.',
                  textAlign:
                      TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey,
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