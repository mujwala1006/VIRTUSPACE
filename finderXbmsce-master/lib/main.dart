import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_options.dart';
import 'features/app_providers.dart';
import 'features/authentication/presentation/auth_page.dart';
import 'features/notifications/presentation/push_notification_setup.dart';
import 'features/users/presentation/dashboard_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  runApp(const ProviderScope(child: FinderApp()));
}

class FinderApp extends StatelessWidget {
  const FinderApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        navigatorKey: appNavigatorKey,
        scaffoldMessengerKey: appScaffoldMessengerKey,
        home: const PushNotificationSetup(child: AuthGate()),
      );
}

class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    return authState.when(
      loading: () => const _LoadingPage(),
      error: (error, stackTrace) => _ErrorPage(
        message: 'Unable to check your sign-in status: $error',
      ),
      data: (user) {
        if (user == null) return const AuthPage();
        final profileState = ref.watch(userProfileProvider(user.uid));
        return profileState.when(
          loading: () => const _LoadingPage(),
          error: (error, stackTrace) => _ErrorPage(
            message: 'Unable to load your profile: $error',
          ),
          data: (profile) {
            if (profile == null) {
              return const _ErrorPage(
                message:
                    'Your account profile is missing. Please contact support.',
              );
            }
            return DashboardPage(profile: profile);
          },
        );
      },
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}

class _ErrorPage extends ConsumerWidget {
  const _ErrorPage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.read(firebaseAuthProvider).signOut(),
                  child: const Text('Sign out'),
                ),
              ],
            ),
          ),
        ),
      );
}
