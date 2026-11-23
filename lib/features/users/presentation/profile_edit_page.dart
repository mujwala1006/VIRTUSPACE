import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app_providers.dart';
import '../domain/user_profile.dart';

class ProfileEditPage extends ConsumerStatefulWidget {
  const ProfileEditPage({
    super.key,
    required this.uid,
    this.embedded = false,
  });

  final String uid;
  final bool embedded;

  @override
  ConsumerState<ProfileEditPage> createState() => _ProfileEditPageState();
}

class _ProfileEditPageState extends ConsumerState<ProfileEditPage> {
  final _name = TextEditingController();
  final _bio = TextEditingController();
  final _photoUrl = TextEditingController();
  final _department = TextEditingController();
  final _collegeName = TextEditingController();
  final _skills = TextEditingController();
  final _domains = TextEditingController();
  final _interests = TextEditingController();
  final _preferredRole = TextEditingController();
  final _experienceLevel = TextEditingController();
  final _preferredWorkingHours = TextEditingController();
  String _availability = '';
  List<String> _certificationUrls = [];
  String? _resumeUrl;
  String? _loadedUid;
  UserRole? _loadedRole;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    _bio.dispose();
    _photoUrl.dispose();
    _department.dispose();
    _collegeName.dispose();
    _skills.dispose();
    _domains.dispose();
    _interests.dispose();
    _preferredRole.dispose();
    _experienceLevel.dispose();
    _preferredWorkingHours.dispose();
    super.dispose();
  }

  List<String> _parseList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  void _populate(UserProfile profile) {
    if (_loadedUid == profile.uid) return;
    _loadedUid = profile.uid;
    _loadedRole = profile.role;
    _name.text = profile.name;
    _bio.text = profile.bio;
    _photoUrl.text = profile.photoUrl;
    _department.text = profile.department;
    _collegeName.text = profile.collegeName;
    _skills.text = profile.skills.join(', ');
    _domains.text = profile.domains.join(', ');
    _interests.text = profile.interests.join(', ');
    _preferredRole.text = profile.preferredRole;
    _experienceLevel.text = profile.experienceLevel;
    _availability = profile.availability;
    _preferredWorkingHours.text = profile.preferredWorkingHours;
    _resumeUrl = profile.resumeUrl;
    _certificationUrls = List.of(profile.certificationUrls);
  }

  Future<void> _uploadDocument({required bool resume}) async {
    setState(() => _uploading = true);
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions:
            resume ? const ['pdf'] : const ['pdf', 'png', 'jpg', 'jpeg'],
        withData: true,
      );
      if (result == null) return;
      final file = result.files.single;
      final bytes = file.bytes;
      final extension = file.extension?.toLowerCase();
      const contentTypes = {
        'pdf': 'application/pdf',
        'png': 'image/png',
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
      };
      final contentType = contentTypes[extension];
      if (bytes == null ||
          contentType == null ||
          (resume && extension != 'pdf')) {
        throw StateError(
          resume
              ? 'Select a readable PDF file.'
              : 'Select a readable PDF, PNG, or JPEG file.',
        );
      }

      final id = const Uuid().v4();
      final destination = resume
          ? 'profiles/${widget.uid}/resume/$id.$extension'
          : 'profiles/${widget.uid}/certifications/$id.$extension';
      final reference =
          ref.read(firebaseStorageProvider).ref().child(destination);
      await reference.putData(
        bytes,
        SettableMetadata(contentType: contentType),
      );
      final url = await reference.getDownloadURL();
      if (!mounted) return;
      setState(() {
        if (resume) {
          _resumeUrl = url;
        } else {
          _certificationUrls = [..._certificationUrls, url];
        }
      });
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to upload file: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(userRepositoryProvider).updateFields(widget.uid, {
        'name': _name.text.trim(),
        'bio': _bio.text.trim(),
        'photoUrl': _photoUrl.text.trim(),
        'department': _department.text.trim(),
        'collegeName': _collegeName.text.trim(),
        'skills': _parseList(_skills.text),
        'domains': _parseList(_domains.text),
        'interests': _parseList(_interests.text),
        if (_loadedRole == UserRole.student) ...{
          'preferredRole': _preferredRole.text.trim(),
          'experienceLevel': _experienceLevel.text.trim(),
          'availability': _availability,
          'preferredWorkingHours': _preferredWorkingHours.text.trim(),
        },
        'resumeUrl': _resumeUrl,
        'certificationUrls': _certificationUrls,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile saved.')),
        );
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to save profile: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profileState = ref.watch(userProfileProvider(widget.uid));
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(
              title: const Text('My profile'),
              actions: [
                IconButton(
                  tooltip: 'Save profile',
                  onPressed: _saving || _uploading ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                ),
              ],
            ),
      body: profileState.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load profile: $error')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('Profile not found.'));
          }
          _populate(profile);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Center(
                child: CircleAvatar(
                  radius: 42,
                  backgroundImage: profile.photoUrl.isEmpty
                      ? null
                      : NetworkImage(profile.photoUrl),
                  child: profile.photoUrl.isEmpty
                      ? Text(profile.name.isEmpty
                          ? '?'
                          : profile.name[0].toUpperCase())
                      : null,
                ),
              ),
              const SizedBox(height: 16),
              _field('Name', _name),
              _field('About me', _bio, maxLines: 3),
              _field('Photo URL', _photoUrl),
              _field('Department', _department),
              if (profile.role == UserRole.student)
                _field('College name', _collegeName),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Role'),
                subtitle: Text(profile.role.value.toUpperCase()),
              ),
              _field(
                profile.role == UserRole.teacher
                    ? 'Expertise and skills (comma-separated)'
                    : 'Skills (comma-separated)',
                _skills,
              ),
              _field('Domains (comma-separated)', _domains),
              if (profile.role != UserRole.teacher)
                _field('Interests (comma-separated)', _interests),
              if (profile.role == UserRole.student) ...[
                _field('Preferred project role', _preferredRole),
                _field(
                  'Experience level (Beginner, Intermediate, Advanced, Expert)',
                  _experienceLevel,
                ),
                DropdownButtonFormField<String>(
                  value: const ['', 'Available', 'Limited', 'Unavailable']
                          .contains(_availability)
                      ? _availability
                      : '',
                  decoration: const InputDecoration(
                    labelText: 'Availability',
                    border: OutlineInputBorder(),
                  ),
                  items: const [
                    DropdownMenuItem(value: '', child: Text('Not specified')),
                    DropdownMenuItem(
                      value: 'Available',
                      child: Text('Available'),
                    ),
                    DropdownMenuItem(value: 'Limited', child: Text('Limited')),
                    DropdownMenuItem(
                      value: 'Unavailable',
                      child: Text('Unavailable'),
                    ),
                  ],
                  onChanged: (value) => setState(() {
                    _availability = value ?? '';
                  }),
                ),
                const SizedBox(height: 8),
                _field(
                  'Preferred working hours (e.g. evenings, 8 hrs/week)',
                  _preferredWorkingHours,
                ),
                const SizedBox(height: 8),
                _uploadTile(
                  title: 'Resume (PDF)',
                  hasFile: _resumeUrl != null,
                  onPressed: () => _uploadDocument(resume: true),
                ),
              ],
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Certifications (PDF or image)'),
                subtitle: Text(
                  _certificationUrls.isEmpty
                      ? 'No certifications uploaded'
                      : '${_certificationUrls.length} PDF file(s) uploaded',
                ),
                trailing: IconButton(
                  tooltip: 'Upload certification PDF',
                  onPressed:
                      _uploading ? null : () => _uploadDocument(resume: false),
                  icon: const Icon(Icons.upload_file),
                ),
              ),
              for (var index = 0; index < _certificationUrls.length; index++)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.picture_as_pdf_outlined),
                  title: Text('Certification ${index + 1}'),
                  subtitle: const Text('PDF stored in Firebase Storage'),
                  trailing: IconButton(
                    tooltip: 'Remove certification',
                    onPressed: () => setState(
                      () => _certificationUrls.removeAt(index),
                    ),
                    icon: const Icon(Icons.delete_outline),
                  ),
                ),
              if (_uploading) const LinearProgressIndicator(),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _saving || _uploading ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(_saving ? 'Saving...' : 'Save profile'),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                '${profile.followersCount} followers  •  '
                '${profile.followingCount} following',
                textAlign: TextAlign.center,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _field(String label, TextEditingController controller,
      {int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: TextField(
        controller: controller,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
      ),
    );
  }

  Widget _uploadTile({
    required String title,
    required bool hasFile,
    required VoidCallback onPressed,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(hasFile ? 'PDF uploaded' : 'No file uploaded'),
      trailing: IconButton(
        tooltip: 'Upload $title',
        onPressed: _uploading ? null : onPressed,
        icon: const Icon(Icons.upload_file),
      ),
    );
  }
}
