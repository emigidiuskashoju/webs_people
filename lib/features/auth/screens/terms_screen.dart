import 'package:flutter/material.dart';

import '../../../core/theme/webs_colors.dart';
import '../../../shared/widgets/webs_background.dart';

class TermsScreen extends StatefulWidget {
  /// The email the user just verified.
  ///
  /// Passed through to the Create Password screen after the
  /// user accepts the terms.
  final String email;

  const TermsScreen({
    super.key,
    required this.email,
  });

  @override
  State<TermsScreen> createState() => _TermsScreenState();
}

class _TermsScreenState extends State<TermsScreen> {
  final ScrollController _scrollController = ScrollController();

  bool _hasReachedEnd = false;
  bool _agreed = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_hasReachedEnd) return;

    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 20) {
      setState(() => _hasReachedEnd = true);
    }
  }

  void _onAgreePressed() {
    Navigator.of(context).pushReplacementNamed(
      '/create-password',
      arguments: widget.email,
    );
  }

  void _onDeclinePressed() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Decline Terms?'),
          content: const Text(
            'You must agree to the Terms and Conditions '
            'to use Webs.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: Colors.redAccent,
              ),
              child: const Text('Decline'),
            ),
          ],
        );
      },
    );

    if (confirm != true) return;
    if (!mounted) return;

    Navigator.of(context).pushNamedAndRemoveUntil(
      '/register',
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: const Color(0xFF1B5E20),
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        title: const Text(
          'Terms & Conditions',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: WebsBackground(
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: ListView(
                  controller: _scrollController,
                  padding: EdgeInsets.fromLTRB(
                    20,
                    kToolbarHeight +
                        MediaQuery.of(context).padding.top +
                        16,
                    20,
                    20,
                  ),
                  children: [
                    // Hero
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
                          Icons.gavel_outlined,
                          size: 52,
                          color: WebsColors.primaryGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'Welcome to Webs',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: WebsColors.textDark(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please read these Terms and Conditions '
                      'carefully before continuing.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        color: WebsColors.textLight(context),
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    _Section(
                      number: '1',
                      title: 'About Webs',
                      body:
                          'Webs is a communication and device '
                          'security platform that lets you chat, call, '
                          'share your location with people you trust, '
                          'and protect your phone against loss or theft.',
                    ),

                    _Section(
                      number: '2',
                      title: 'Safe and Secure Connections',
                      body:
                          'Webs provides a 98% safe and secure '
                          'connection between people using the app. '
                          'Messages, calls, and location sharing are '
                          'protected by modern encryption, authenticated '
                          'accounts, and verified identities.\n\n'
                          'While we work hard to keep every interaction '
                          'secure, no system can guarantee 100% safety. '
                          'You are responsible for protecting your '
                          'password, your device, and your account '
                          'credentials.',
                      highlight:
                          '98% safe and secure connection between people.',
                    ),

                    _Section(
                      number: '3',
                      title: 'Device Recovery',
                      body:
                          'If your phone is lost or stolen, Webs '
                          'gives you tools to help recover it. You can '
                          'remotely view its location, enable Lost Mode, '
                          'and receive updates even if the phone is offline.\n\n'
                          'Because a lost phone may not always be online, '
                          'connected to GPS, or powered on, Webs '
                          'can give you an 80% chance of accessing its '
                          'last known location and status.',
                      highlight:
                          '80% access to your lost or stolen phone.',
                    ),

                    _Section(
                      number: '4',
                      title: 'Your Privacy',
                      body:
                          'Your messages, contacts, and locations stay '
                          'on your phone whenever possible. Information '
                          'is only sent to the server when it is needed '
                          'to deliver a message, share your location '
                          'with a person you have approved, or recover '
                          'a lost device.',
                    ),

                    _Section(
                      number: '5',
                      title: 'Your Responsibilities',
                      body:
                          'By using Webs you agree to:\n\n'
                          '• Use the app only for lawful purposes.\n'
                          '• Not send threats, abuse, or spam.\n'
                          '• Not attempt to hack, reverse-engineer, or '
                          'misuse the service.\n'
                          '• Only share your location with people you '
                          'trust.\n'
                          '• Keep your account password private.',
                    ),

                    _Section(
                      number: '6',
                      title: 'Location Sharing',
                      body:
                          'Webs lets you share your location with '
                          'another user only after both of you accept a '
                          'sharing request. You can stop sharing at any '
                          'time. Sharing does not happen in the '
                          'background unless you have enabled it.',
                    ),

                    _Section(
                      number: '7',
                      title: 'Limitations',
                      body:
                          'Webs is provided "as is". We do our '
                          'best to keep the service reliable, but we '
                          'cannot promise it will always be available or '
                          'free of errors. We are not responsible for '
                          'losses caused by network problems, device '
                          'failures, or events outside our control.',
                    ),

                    _Section(
                      number: '8',
                      title: 'Changes to These Terms',
                      body:
                          'We may update these Terms and Conditions from '
                          'time to time. When we do, the app will show '
                          'you the new version and ask you to agree again '
                          'before you continue.',
                    ),

                    _Section(
                      number: '9',
                      title: 'Contact',
                      body:
                          'If you have questions about these Terms, '
                          'please contact us through the app or by email '
                          'at support@webspeople.app.',
                    ),

                    const SizedBox(height: 24),

                    // End-of-document marker
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: WebsColors.softGreen(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: WebsColors.border(context),
                          width: 2,
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            _hasReachedEnd
                                ? Icons.check_circle
                                : Icons.info_outline,
                            color: WebsColors.primaryGreen,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _hasReachedEnd
                                  ? 'You have reached the end. '
                                      'Please confirm your agreement below.'
                                  : 'Please scroll to the bottom '
                                      'to continue.',
                              style: TextStyle(
                                color: WebsColors.textDark(context),
                                fontSize: 13,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
              _buildAgreementBar(context),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAgreementBar(BuildContext context) {
    final canAgree = _hasReachedEnd && _agreed;

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        boxShadow: [
          BoxShadow(
            color: WebsColors.shadow(context),
            blurRadius: 12,
            offset: const Offset(0, -3),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: _hasReachedEnd
                  ? () => setState(() => _agreed = !_agreed)
                  : null,
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 4,
                  horizontal: 4,
                ),
                child: Row(
                  children: [
                    Checkbox(
                      value: _agreed,
                      onChanged: _hasReachedEnd
                          ? (v) => setState(() => _agreed = v ?? false)
                          : null,
                      activeColor: WebsColors.primaryGreen,
                    ),
                    Expanded(
                      child: Text(
                        'I have read and agree to the Terms and Conditions.',
                        style: TextStyle(
                          fontSize: 13,
                          color: _hasReachedEnd
                              ? WebsColors.textDark(context)
                              : WebsColors.textLight(context),
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _onDeclinePressed,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      side: const BorderSide(color: Colors.redAccent),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Decline',
                      style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: canAgree ? _onAgreePressed : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: WebsColors.primaryGreen,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text(
                      'Agree and Continue',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ====================================================================
// SECTION WIDGET
// ====================================================================

class _Section extends StatelessWidget {
  final String number;
  final String title;
  final String body;
  final String? highlight;

  const _Section({
    required this.number,
    required this.title,
    required this.body,
    this.highlight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: WebsColors.surface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: WebsColors.border(context),
          width: 2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: const BoxDecoration(
                  color: WebsColors.primaryGreen,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Text(
                  number,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: WebsColors.textDark(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: WebsColors.textLight(context),
              height: 1.5,
            ),
          ),
          if (highlight != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: WebsColors.softGreen(context),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.verified_user_outlined,
                    size: 18,
                    color: WebsColors.primaryGreen,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      highlight!,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: WebsColors.primaryGreen,
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}