import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../ads/ad_service.dart';
import '../core/app_info.dart';
import '../core/theme.dart';
import '../state/app_state.dart';

/// Wraps the whole Navigator. When App lock is on, a full-screen lock covers every
/// route on cold start and after the app has been in the background for 20 seconds.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});
  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  bool _locked = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _locked = AppScope.read(context).lockEnabled;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt ??= DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final at = _pausedAt;
      _pausedAt = null;
      if (at == null) return;
      final s = AppScope.read(context);
      if (s.lockEnabled &&
          !AdService.instance.isBusy &&
          DateTime.now().difference(at) > const Duration(seconds: 20)) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppScope.of(context);
    final showLock = _locked && s.lockEnabled;
    return Stack(
      children: [
        widget.child,
        if (showLock)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () => setState(() => _locked = false),
            ),
          ),
      ],
    );
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});
  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _auth = LocalAuthentication();
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
  }

  Future<void> _authenticate() async {
    if (_busy) return;
    _busy = true;
    var ok = false;
    String? message;
    try {
      ok = await AdService.instance.quiet(
        () => _auth.authenticate(
          localizedReason: 'Unlock ${AppInfo.name}',
          persistAcrossBackgrounding: true,
        ),
      );
    } on LocalAuthException catch (e) {
      // The phone no longer has a screen lock: do not trap the user out of their own data.
      if (e.code == LocalAuthExceptionCode.noCredentialsSet) {
        if (mounted) AppScope.read(context).setLock(false);
        ok = true;
      } else {
        message = 'Could not authenticate. Please try again.';
      }
    } catch (_) {
      message = 'Could not authenticate. Please try again.';
    }
    _busy = false;
    if (!mounted) return;
    if (ok) {
      widget.onUnlocked();
    } else {
      setState(() => _message = message ?? 'Locked. Tap Unlock to continue.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: accentGradient(context.cs.primary)),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 92,
                    height: 92,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0x33FFFFFF),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.lock_rounded,
                        size: 46,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text(
                    '${AppInfo.name} is locked',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _message ?? 'Your entries are hidden until you unlock.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  const SizedBox(height: 28),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 28,
                        vertical: 16,
                      ),
                    ),
                    onPressed: _authenticate,
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text(
                      'Unlock',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
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
