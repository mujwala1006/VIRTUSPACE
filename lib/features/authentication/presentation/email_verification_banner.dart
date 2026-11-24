import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class EmailVerificationBanner extends StatefulWidget {
  const EmailVerificationBanner({super.key, required this.child});

  final Widget child;

  @override
  State<EmailVerificationBanner> createState() =>
      _EmailVerificationBannerState();
}

class _EmailVerificationBannerState extends State<EmailVerificationBanner> {
  StreamSubscription<User?>? _userSubscription;
  User? _user;
  String? _message;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final auth = FirebaseAuth.instance;
    _user = auth.currentUser;
    _userSubscription = auth.idTokenChanges().listen(
      (user) {
        if (!mounted) return;
        setState(() {
          _user = user;
          if (user?.emailVerified == true) _message = null;
        });
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!mounted) return;
        setState(() => _message = 'Unable to refresh your account status.');
      },
    );
  }

  @override
  void dispose() {
    unawaited(_userSubscription?.cancel());
    super.dispose();
  }

  Future<void> _resendVerification() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await user.sendEmailVerification();
      if (mounted) {
        setState(() => _message = 'Verification email sent.');
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Unable to send verification email: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _reloadUser() async {
    final auth = FirebaseAuth.instance;
    final user = auth.currentUser;
    if (user == null) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await user.reload();
      var refreshedUser = auth.currentUser;
      if (refreshedUser?.emailVerified == true) {
        await refreshedUser!.getIdToken(true);
        refreshedUser = auth.currentUser;
      }
      if (mounted) {
        setState(() {
          _user = refreshedUser;
          _message = refreshedUser?.emailVerified == true
              ? 'Your email is verified.'
              : 'Your email is not verified yet. Check your inbox and try again.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() => _message = 'Unable to refresh verification status: $error');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _user ?? FirebaseAuth.instance.currentUser;
    final showBanner = user != null && !user.emailVerified;
    return Column(
      children: [
        if (showBanner)
          MaterialBanner(
            content: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Verify your email address to create posts, projects, '
                  'batches, and requests.',
                ),
                if (_message != null) ...[
                  const SizedBox(height: 4),
                  Text(_message!),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: _busy ? null : _resendVerification,
                child: const Text('Resend'),
              ),
              TextButton(
                onPressed: _busy ? null : _reloadUser,
                child: const Text("I've verified"),
              ),
            ],
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
