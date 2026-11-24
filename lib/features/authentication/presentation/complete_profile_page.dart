import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../../users/domain/user_profile.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key, required this.user});

  final User user;

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController =
      TextEditingController(text: widget.user.displayName ?? '');
  final _departmentController = TextEditingController();
  final _facultyCodeController = TextEditingController();
  UserRole _role = UserRole.student;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _departmentController.dispose();
    _facultyCodeController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      final repository = ref.read(userRepositoryProvider);
      if (_role == UserRole.teacher) {
        await repository.registerTeacher(
          name: _nameController.text.trim(),
          department: _departmentController.text.trim(),
          facultyCode: _facultyCodeController.text.trim(),
        );
      } else {
        await repository.create(
          UserProfile(
            uid: widget.user.uid,
            role: _role,
            name: _nameController.text.trim(),
            bio: '',
            photoUrl: '',
            department: _departmentController.text.trim(),
            skills: const [],
            interests: const [],
            followersCount: 0,
            followingCount: 0,
            resumeUrl: null,
            createdAt: DateTime.now(),
          ),
        );
      }
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to complete your profile: $error')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _roleLabel(UserRole role) {
    switch (role) {
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher';
      case UserRole.innovator:
        return 'Innovator';
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Complete your profile')),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<UserRole>(
                      value: _role,
                      decoration: const InputDecoration(labelText: 'Role'),
                      items: UserRole.values
                          .map(
                            (role) => DropdownMenuItem(
                              value: role,
                              child: Text(_roleLabel(role)),
                            ),
                          )
                          .toList(growable: false),
                      onChanged: _saving
                          ? null
                          : (role) {
                              if (role != null) setState(() => _role = role);
                            },
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _departmentController,
                      decoration:
                          const InputDecoration(labelText: 'Department'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter your department.'
                              : null,
                    ),
                    if (_role == UserRole.teacher) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _facultyCodeController,
                        obscureText: true,
                        decoration: const InputDecoration(
                          labelText: 'Faculty access code',
                        ),
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                                ? 'Enter the faculty access code.'
                                : null,
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saving ? null : _submit,
                        child: _saving
                            ? const CircularProgressIndicator()
                            : const Text('Complete profile'),
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
