import 'package:flutter/material.dart';
import '../../authentication/presentation/auth_page.dart';
import '../domain/user_profile.dart';

class RoleSelectionPage extends StatelessWidget {
  const RoleSelectionPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Choose your role')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          for (final role in UserRole.values)
            Card(
              child: ListTile(
                title: Text(_roleTitle(role)),
                trailing: const Icon(Icons.arrow_forward),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => AuthPage(
                      role: role,
                      initiallyCreatingAccount: true,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _roleTitle(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.innovator:
        return 'Innovator';
    }
  }
}
