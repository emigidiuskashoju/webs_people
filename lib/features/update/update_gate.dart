import 'package:flutter/material.dart';

import '/core/theme/webs_colors.dart';
import 'models/app_release_info.dart';
import 'services/app_update_service.dart';
import 'widgets/update_required_screen.dart';

/// Wraps the app. On launch, checks the server for a newer
/// release and shows [UpdateRequiredScreen] if one exists.
/// Once the check passes, shows [child].
///
/// Re-checks whenever the app returns to the foreground.
class UpdateGate extends StatefulWidget {
  final Widget child;

  const UpdateGate({super.key, required this.child});

  @override
  State<UpdateGate> createState() => _UpdateGateState();
}

class _UpdateGateState extends State<UpdateGate>
    with WidgetsBindingObserver {
  final AppUpdateService _service = AppUpdateService();

  bool _checking = true;
  AppReleaseInfo? _requiredRelease;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _requiredRelease == null) {
      _check();
    }
  }

  Future<void> _check() async {
    final release = await _service.fetchLatestRelease();
    final required = await _service.isUpdateRequired(release);

    if (!mounted) return;

    setState(() {
      _checking = false;
      _requiredRelease = required ? release : null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: const Center(
          child: CircularProgressIndicator(
            color: WebsColors.primaryGreen,
          ),
        ),
      );
    }

    final release = _requiredRelease;
    if (release != null) {
      return UpdateRequiredScreen(release: release);
    }

    return widget.child;
  }
}