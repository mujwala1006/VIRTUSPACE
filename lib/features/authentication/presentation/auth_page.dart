import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../../users/domain/user_profile.dart';
import '../../users/presentation/role_selection_page.dart';

class AuthPage extends ConsumerStatefulWidget {
  const AuthPage({
    super.key,
    this.role,
    this.initiallyCreatingAccount = false,
  });

  final UserRole? role;
  final bool initiallyCreatingAccount;

  @override
  ConsumerState<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends ConsumerState<AuthPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();
  late bool _isCreatingAccount;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _isCreatingAccount = widget.initiallyCreatingAccount;
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_isCreatingAccount && widget.role == null) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const RoleSelectionPage()),
      );
      return;
    }

    setState(() => _isLoading = true);
    String? errorMessage;
    try {
      final auth = ref.read(firebaseAuthProvider);
      if (_isCreatingAccount) {
        final credential = await auth.createUserWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
        final uid = credential.user!.uid;
        final now = DateTime.now();
        await ref.read(userRepositoryProvider).create(
              UserProfile(
                uid: uid,
                role: widget.role!,
                name: _nameController.text.trim(),
                bio: '',
                photoUrl: '',
                department: '',
                skills: const [],
                interests: const [],
                followersCount: 0,
                followingCount: 0,
                resumeUrl: null,
                createdAt: now,
              ),
            );
      } else {
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }
    } on FirebaseAuthException catch (error) {
      errorMessage = error.message ?? 'Authentication failed.';
    } on FirebaseException catch (error) {
      errorMessage = error.message ?? 'Unable to save the profile.';
    } catch (error) {
      errorMessage = error.toString();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }

    if (errorMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final title = _isCreatingAccount ? 'Create account' : 'Sign in';
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        leading: widget.role == null
            ? null
            : IconButton(
                onPressed: () => Navigator.of(context).maybePop(),
                icon: const Icon(Icons.arrow_back),
              ),
      ),
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
                  if (_isCreatingAccount) ...[
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(labelText: 'Name'),
                      validator: (value) =>
                          value == null || value.trim().isEmpty
                              ? 'Enter your name.'
                              : null,
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Enter your email.'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                    validator: (value) => value == null || value.isEmpty
                        ? 'Enter your password.'
                        : null,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      child: _isLoading
                          ? const CircularProgressIndicator()
                          : Text(title),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () {
                            if (!_isCreatingAccount && widget.role == null) {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const RoleSelectionPage(),
                                ),
                              );
                            } else {
                              setState(
                                () => _isCreatingAccount = !_isCreatingAccount,
                              );
                            }
                          },
                    child: Text(
                      _isCreatingAccount
                          ? 'Already have an account? Sign in'
                          : 'Create a new account',
                    ),
                  ),
                  if (_isCreatingAccount && widget.role == null)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const RoleSelectionPage(),
                        ),
                      ),
                      child: const Text('Choose account role'),
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

UserRole roleFromLegacyValue(String role) {
  switch (role) {
    case 'student':
    case 'students':
      return UserRole.student;
    case 'teacher':
    case 'teachers':
      return UserRole.teacher;
    case 'innovator':
    case 'innovators':
      return UserRole.innovator;
    default:
      throw ArgumentError.value(role, 'role', 'Unsupported account role.');
  }
}
