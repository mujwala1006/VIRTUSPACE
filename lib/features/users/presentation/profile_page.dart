import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../../posts/domain/post.dart';
import 'profile_edit_page.dart';

class ProfilePage extends ConsumerWidget {
  const ProfilePage({
    super.key,
    required this.uid,
    this.embedded = false,
  });

  final String uid;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(userProfileProvider(uid));
    final canEdit = ref.watch(firebaseAuthProvider).currentUser?.uid == uid;
    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: const Text('Profile'),
              actions: [
                if (canEdit)
                  IconButton(
                    tooltip: 'Edit profile',
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => ProfileEditPage(uid: uid),
                      ),
                    ),
                    icon: const Icon(Icons.edit_outlined),
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
              const SizedBox(height: 12),
              Center(
                child: Text(
                  profile.name,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Center(child: Text(profile.role.value.toUpperCase())),
              const SizedBox(height: 16),
              _ProfileDetail(label: 'About', value: profile.bio),
              _ProfileDetail(label: 'Department', value: profile.department),
              _ProfileDetail(label: 'College', value: profile.collegeName),
              _ProfileDetail(
                label: 'Preferred project role',
                value: profile.preferredRole,
              ),
              _ProfileDetail(
                label: 'Experience',
                value: profile.experienceLevel,
              ),
              _ProfileDetail(
                label: 'Availability',
                value: profile.availability,
              ),
              _ProfileDetail(
                label: 'Preferred working hours',
                value: profile.preferredWorkingHours,
              ),
              _ProfileDetail(
                label: 'Skills',
                value: profile.skills.join(', '),
              ),
              _ProfileDetail(
                label: 'Domains',
                value: profile.domains.join(', '),
              ),
              _ProfileDetail(
                label: 'Interests',
                value: profile.interests.join(', '),
              ),
              _ProfileDetail(
                label: 'Resume',
                value:
                    profile.resumeUrl == null ? 'Not uploaded' : 'PDF uploaded',
              ),
              _ProfileDetail(
                label: 'Certifications',
                value: '${profile.certificationUrls.length} uploaded',
              ),
              _ProfileDetail(
                label: 'Community',
                value:
                    '${profile.followersCount} followers • ${profile.followingCount} following',
              ),
              if (canEdit && embedded) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ProfileEditPage(uid: uid),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit profile'),
                ),
              ],
              const SizedBox(height: 18),
              Text(
                'Posts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              _ProfilePostGrid(uid: uid),
            ],
          );
        },
      ),
    );
  }
}

class _ProfilePostGrid extends ConsumerWidget {
  const _ProfilePostGrid({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final posts = ref.watch(authorPostsProvider(uid));
    return posts.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text('Unable to load posts: $error'),
      ),
      data: (items) {
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Text('No posts yet.'),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: items.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 4,
            mainAxisSpacing: 4,
          ),
          itemBuilder: (context, index) => _PostGridTile(post: items[index]),
        );
      },
    );
  }
}

class _PostGridTile extends StatelessWidget {
  const _PostGridTile({required this.post});

  final Post post;

  @override
  Widget build(BuildContext context) {
    if (post.imageUrls.isEmpty) {
      return Container(
        color: Theme.of(context).colorScheme.surfaceVariant,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(8),
        child: Text(
          post.text,
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
        ),
      );
    }
    return Image.network(
      post.imageUrls.first,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => const Center(
        child: Icon(Icons.broken_image_outlined),
      ),
    );
  }
}

class _ProfileDetail extends StatelessWidget {
  const _ProfileDetail({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label),
        subtitle: Text(value.isEmpty ? 'Not provided' : value),
      );
}
