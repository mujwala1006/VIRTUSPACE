import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'notifications_page.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appScaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
}

class PushNotificationSetup extends StatefulWidget {
  const PushNotificationSetup({super.key, required this.child});

  final Widget child;

  @override
  State<PushNotificationSetup> createState() => _PushNotificationSetupState();
}

class _PushNotificationSetupState extends State<PushNotificationSetup> {
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<String>? _tokenSubscription;
  StreamSubscription<RemoteMessage>? _messageSubscription;
  StreamSubscription<RemoteMessage>? _openedSubscription;
  String? _uid;
  String? _token;
  RemoteMessage? _pendingMessage;

  @override
  void initState() {
    super.initState();
    _messageSubscription =
        FirebaseMessaging.onMessage.listen(_showForegroundNotification);
    _openedSubscription =
        FirebaseMessaging.onMessageOpenedApp.listen(_openNotifications);
    _tokenSubscription = FirebaseMessaging.instance.onTokenRefresh.listen(
      (token) => unawaited(_refreshToken(token)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('FCM token refresh failed: $error');
      },
    );
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen(
      (user) => unawaited(_changeUser(user?.uid)),
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Unable to watch auth state for push notifications: $error');
      },
    );
    unawaited(_handleInitialMessage());
  }

  Future<void> _refreshToken(String token) async {
    final oldToken = _token;
    final uid = _uid;
    _token = token;
    if (uid == null) return;
    if (oldToken != null && oldToken != token) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('fcmTokens')
            .doc(oldToken)
            .delete();
      } catch (error) {
        debugPrint('Unable to remove the expired FCM token: $error');
      }
    }
    await _saveToken(uid, token);
  }

  Future<void> _changeUser(String? newUid) async {
    final oldUid = _uid;
    final oldToken = _token;
    _uid = newUid;
    if (oldUid != null && oldUid != newUid && oldToken != null) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(oldUid)
            .collection('fcmTokens')
            .doc(oldToken)
            .delete();
      } catch (error) {
        debugPrint('Unable to remove the previous FCM token: $error');
      }
    }
    if (newUid == null) return;
    final pendingMessage = _pendingMessage;
    if (pendingMessage != null) {
      _pendingMessage = null;
      _openNotifications(pendingMessage);
    }

    try {
      await FirebaseMessaging.instance.requestPermission();
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) {
        debugPrint('FCM did not return a registration token.');
        return;
      }
      _token = token;
      await _saveToken(newUid, token);
    } catch (error) {
      debugPrint(
          'Unable to register this device for push notifications: $error');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('fcmTokens')
          .doc(token)
          .set({
        'token': token,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      debugPrint('Unable to save the FCM registration token: $error');
    }
  }

  Future<void> _handleInitialMessage() async {
    try {
      final message = await FirebaseMessaging.instance.getInitialMessage();
      if (message != null) _openNotifications(message);
    } catch (error) {
      debugPrint('Unable to handle the initial push notification: $error');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    final title = message.notification?.title ?? 'New notification';
    final body = message.notification?.body ?? 'You have an update.';
    appScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('$title: $body'),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _openNotifications(message),
        ),
      ),
    );
  }

  void _openNotifications(RemoteMessage message) {
    final uid = _uid;
    if (uid == null) {
      _pendingMessage = message;
      return;
    }
    appNavigatorKey.currentState?.push(
      MaterialPageRoute<void>(
        builder: (_) => NotificationsPage(uid: uid),
      ),
    );
  }

  @override
  void dispose() {
    unawaited(_authSubscription?.cancel());
    unawaited(_tokenSubscription?.cancel());
    unawaited(_messageSubscription?.cancel());
    unawaited(_openedSubscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
