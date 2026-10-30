import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../app_providers.dart';
import '../../batches/domain/batch.dart';
import '../../batches/domain/batch_task.dart';
import '../../batches/presentation/batch_pages.dart';
import '../../ai/presentation/ai_chat_page.dart';
import '../../ai/presentation/team_suggestions_section.dart';
import '../../notifications/presentation/notifications_page.dart';
import '../../posts/domain/post.dart';
import '../../posts/data/post_repository.dart';
import '../../projects/domain/project.dart';
import '../../projects/presentation/projects_page.dart';
import '../domain/user_profile.dart';
import 'profile_page.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key, required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  int _selectedIndex = 0;

  Future<void> _openCreate() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => _CreateChooserPage(
        uid: widget.profile.uid,
        role: widget.profile.role,
      ),
    ));
    if (mounted) setState(() => _selectedIndex = 0);
  }

  void _selectDestination(int index) {
    if (index == 2) {
      _openCreate();
    } else {
      setState(() => _selectedIndex = index);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = widget.profile.uid;
    final unreadCount =
        ref.watch(unreadNotificationsProvider(uid)).valueOrNull ?? 0;
    final destinations = <Widget>[
      _HomePage(profile: widget.profile),
      _ExplorePage(profile: widget.profile),
      const SizedBox.shrink(),
      NotificationsPage(uid: uid, embedded: true),
      ProfilePage(uid: uid, embedded: true),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(_selectedIndex == 0 ? 'FinderX' : _destinationName),
        actions: [
          IconButton(
            tooltip: 'Ask FinderX AI',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => AiChatPage(uid: uid),
              ),
            ),
            icon: const Icon(Icons.auto_awesome_outlined),
          ),
          IconButton(
            tooltip: 'Explore projects',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const ProjectExplorePage(),
              ),
            ),
            icon: const Icon(Icons.lightbulb_outline),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: () => ref.read(firebaseAuthProvider).signOut(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: destinations,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: _selectDestination,
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Home',
          ),
          const NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore),
            label: 'Explore',
          ),
          const NavigationDestination(
            icon: Icon(Icons.add_circle_outline, size: 30),
            selectedIcon: Icon(Icons.add_circle, size: 30),
            label: 'Create',
          ),
          NavigationDestination(
            icon: _UnreadBadge(
              count: unreadCount,
              child: const Icon(Icons.notifications_outlined),
            ),
            selectedIcon: _UnreadBadge(
              count: unreadCount,
              child: const Icon(Icons.notifications),
            ),
            label: 'Notifications',
          ),
          const NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  String get _destinationName {
    switch (_selectedIndex) {
      case 1:
        return 'Explore';
      case 3:
        return 'Notifications';
      case 4:
        return 'Profile';
      default:
        return 'FinderX';
    }
  }
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({required this.count, required this.child});

  final int count;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
        clipBehavior: Clip.none,
        children: [
          child,
          if (count > 0)
            Positioned(
              top: -7,
              right: -10,
              child: Container(
                constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.error,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onError,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
        ],
      );
}

class _HomePage extends StatelessWidget {
  const _HomePage({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context) {
    switch (profile.role) {
      case UserRole.student:
        return _StudentHome(profile: profile);
      case UserRole.teacher:
        return _TeacherHome(profile: profile);
      case UserRole.innovator:
        return _InnovatorHome(profile: profile);
    }
  }
}

class _StudentHome extends ConsumerWidget {
  const _StudentHome({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final follows = ref.watch(followingUidsProvider(profile.uid));
    final directory = ref.watch(userDirectoryProvider);
    final batches = ref.watch(userBatchesProvider(profile.uid));
    final projects = ref.watch(projectFeedProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WelcomeCard(
          title: 'Welcome, ${profile.name}',
          subtitle: 'Updates from faculty you follow and your project team.',
        ),
        TeamSuggestionsSection(uid: profile.uid, role: profile.role),
        const _SectionTitle('Faculty updates'),
        follows.when(
          loading: () => const _LoadingIndicator(),
          error: (error, stackTrace) =>
              _InlineError(message: 'Unable to load followed faculty: $error'),
          data: (followingUids) => directory.when(
            loading: () => const _LoadingIndicator(),
            error: (error, stackTrace) =>
                _InlineError(message: 'Unable to load faculty: $error'),
            data: (profiles) {
              final facultyIds = profiles
                  .where((item) =>
                      followingUids.contains(item.uid) &&
                      item.role == UserRole.teacher)
                  .map((item) => item.uid)
                  .toSet();
              if (facultyIds.isEmpty) {
                return const _EmptyMessage(
                  'Follow faculty to see their updates here.',
                );
              }
              return _FollowedPostFeed(
                uid: profile.uid,
                authorUids: facultyIds,
                authorNames: {
                  for (final item in profiles) item.uid: item.name,
                },
              );
            },
          ),
        ),
        const _SectionTitle('My batch and project'),
        batches.when(
          loading: () => const _LoadingIndicator(),
          error: (error, stackTrace) =>
              _InlineError(message: 'Unable to load your batch: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyMessage(
                'You are not assigned to a batch yet.',
              );
            }
            return projects.when(
              loading: () => const _LoadingIndicator(),
              error: (error, stackTrace) =>
                  _InlineError(message: 'Unable to load projects: $error'),
              data: (projectList) => Column(
                children: [
                  for (final batch in items)
                    _StudentBatchCard(
                      batch: batch,
                      project: _findProject(projectList, batch.projectId),
                      currentUid: profile.uid,
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _TeacherHome extends ConsumerWidget {
  const _TeacherHome({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batches = ref.watch(teacherBatchesProvider(profile.uid));
    final directory = ref.watch(userDirectoryProvider);
    final projects = ref.watch(projectFeedProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WelcomeCard(
          title: 'Welcome, ${profile.name}',
          subtitle: 'Manage your batches and track student progress.',
        ),
        TeamSuggestionsSection(uid: profile.uid, role: profile.role),
        const _SectionTitle('Updates from people you follow'),
        _FollowedPostFeed(uid: profile.uid),
        const _SectionTitle('My batches'),
        batches.when(
          loading: () => const _LoadingIndicator(),
          error: (error, stackTrace) =>
              _InlineError(message: 'Unable to load batches: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const _EmptyMessage(
                'No batch yet. Create a project to get started.',
              );
            }
            return projects.when(
              loading: () => const _LoadingIndicator(),
              error: (error, stackTrace) =>
                  _InlineError(message: 'Unable to load projects: $error'),
              data: (projectList) => directory.when(
                loading: () => const _LoadingIndicator(),
                error: (error, stackTrace) =>
                    _InlineError(message: 'Unable to load students: $error'),
                data: (profiles) => Column(
                  children: [
                    for (final batch in items)
                      _TeacherBatchCard(
                        batch: batch,
                        project: _findProject(projectList, batch.projectId),
                        profiles: profiles,
                        currentUid: profile.uid,
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => CreateBatchPage(teacherUid: profile.uid),
              ),
            ),
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Create batch'),
          ),
        ),
        const _SectionTitle('Faculty directory'),
        projects.when(
          loading: () => const _LoadingIndicator(),
          error: (error, stackTrace) =>
              _InlineError(message: 'Unable to load projects: $error'),
          data: (projectList) => directory.when(
            loading: () => const _LoadingIndicator(),
            error: (error, stackTrace) =>
                _InlineError(message: 'Unable to load faculty: $error'),
            data: (profiles) {
              final faculty = profiles
                  .where((item) => item.role == UserRole.teacher)
                  .toList(growable: false);
              if (faculty.isEmpty) {
                return const _EmptyMessage('No faculty profiles found.');
              }
              return Column(
                children: [
                  for (final teacher in faculty)
                    _FacultySummaryCard(
                      teacher: teacher,
                      projects: projectList
                          .where((project) => project.ownerUid == teacher.uid)
                          .toList(growable: false),
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _InnovatorHome extends ConsumerWidget {
  const _InnovatorHome({required this.profile});

  final UserProfile profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectFeedProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _WelcomeCard(
          title: 'Welcome, ${profile.name}',
          subtitle: 'Build your ideas and connect with collaborators.',
        ),
        TeamSuggestionsSection(uid: profile.uid, role: profile.role),
        const _SectionTitle('Updates from people you follow'),
        _FollowedPostFeed(uid: profile.uid),
        const _SectionTitle('My projects'),
        projects.when(
          loading: () => const _LoadingIndicator(),
          error: (error, stackTrace) =>
              _InlineError(message: 'Unable to load projects: $error'),
          data: (items) {
            final mine =
                items.where((project) => project.ownerUid == profile.uid);
            if (mine.isEmpty) {
              return const _EmptyMessage(
                'You have not created a project yet. Tap Create to begin.',
              );
            }
            return Column(children: mine.map(_ProjectCard.new).toList());
          },
        ),
      ],
    );
  }
}

class _FollowedPostFeed extends ConsumerWidget {
  const _FollowedPostFeed({
    required this.uid,
    this.authorUids,
    this.authorNames = const {},
  });

  final String uid;
  final Set<String>? authorUids;
  final Map<String, String> authorNames;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(followingUidsProvider(uid));
    final directory = ref.watch(userDirectoryProvider);
    return following.when(
      loading: () => const _LoadingIndicator(),
      error: (error, stackTrace) =>
          _InlineError(message: 'Unable to load followed profiles: $error'),
      data: (uids) => directory.when(
        loading: () => const _LoadingIndicator(),
        error: (error, stackTrace) =>
            _InlineError(message: 'Unable to load profiles: $error'),
        data: (profiles) {
          final followedIds = authorUids ?? uids.toSet();
          if (followedIds.isEmpty) {
            return const _EmptyMessage(
              'Follow people to see their posts in your feed.',
            );
          }
          final names = <String, String>{
            for (final profile in profiles) profile.uid: profile.name,
            ...authorNames,
          };
          final authorKey = followedIds.toList()..sort();
          return _PagedFollowedPosts(
            key: ValueKey(authorKey.join('|')),
            authorUids: followedIds,
            authorNames: names,
          );
        },
      ),
    );
  }
}

class _PagedFollowedPosts extends ConsumerStatefulWidget {
  const _PagedFollowedPosts({
    super.key,
    required this.authorUids,
    required this.authorNames,
  });

  final Set<String> authorUids;
  final Map<String, String> authorNames;

  @override
  ConsumerState<_PagedFollowedPosts> createState() =>
      _PagedFollowedPostsState();
}

class _PagedFollowedPostsState extends ConsumerState<_PagedFollowedPosts> {
  final List<Post> _posts = [];
  PostCursor? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      var attempts = 0;
      final additions = <Post>[];
      while (additions.isEmpty && _hasMore && attempts < 3) {
        final page = await ref.read(postRepositoryProvider).fetchFollowedPage(
              authorUids: widget.authorUids,
              cursor: _cursor,
            );
        additions.addAll(page.posts);
        _cursor = page.cursor;
        _hasMore = page.hasMore;
        attempts++;
      }
      if (!mounted) return;
      setState(() => _posts.addAll(additions));
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading && _posts.isEmpty) return const _LoadingIndicator();
    if (_error != null && _posts.isEmpty) {
      return Column(
        children: [
          _InlineError(message: 'Unable to load your feed: $_error'),
          TextButton(onPressed: _loadMore, child: const Text('Retry')),
        ],
      );
    }
    if (_posts.isEmpty && !_hasMore) {
      return const _EmptyMessage('No posts from people you follow yet.');
    }
    return Column(
      children: [
        if (_error != null)
          _InlineError(message: 'Unable to load more posts: $_error'),
        for (final post in _posts)
          _PostCard(
            post: post,
            authorName: widget.authorNames[post.authorUid] ?? 'Member',
          ),
        if (_loading)
          const _LoadingIndicator()
        else if (_hasMore)
          TextButton(
            onPressed: _loadMore,
            child: Text(
              _posts.isEmpty ? 'Load older posts' : 'Load more posts',
            ),
          ),
      ],
    );
  }
}

class _ExplorePage extends ConsumerStatefulWidget {
  const _ExplorePage({required this.profile});

  final UserProfile profile;

  @override
  ConsumerState<_ExplorePage> createState() => _ExplorePageState();
}

class _ExplorePageState extends ConsumerState<_ExplorePage> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _isDiscoverable(UserProfile candidate) {
    final current = widget.profile;
    switch (current.role) {
      case UserRole.student:
        return candidate.role == UserRole.teacher;
      case UserRole.teacher:
        return candidate.role == UserRole.teacher;
      case UserRole.innovator:
        return candidate.role == UserRole.student ||
            candidate.role == UserRole.teacher;
    }
  }

  @override
  Widget build(BuildContext context) {
    final directory = ref.watch(userDirectoryProvider);
    final allProjects = ref.watch(projectFeedProvider);
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: TextField(
            controller: _searchController,
            decoration: const InputDecoration(
              prefixIcon: Icon(Icons.search),
              hintText: 'Filter by skill or domain',
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => setState(() => _search = value.trim()),
          ),
        ),
        Expanded(
          child: directory.when(
            loading: () => const _LoadingIndicator(),
            error: (error, stackTrace) =>
                _InlineError(message: 'Unable to load directory: $error'),
            data: (profiles) {
              final query = _search.toLowerCase();
              final visible = profiles.where((candidate) {
                if (!_isDiscoverable(candidate) ||
                    candidate.uid == widget.profile.uid) {
                  return false;
                }
                return query.isEmpty ||
                    candidate.name.toLowerCase().contains(query) ||
                    candidate.department.toLowerCase().contains(query) ||
                    candidate.skills.any(
                      (skill) => skill.toLowerCase().contains(query),
                    ) ||
                    candidate.domains.any(
                      (domain) => domain.toLowerCase().contains(query),
                    );
              }).toList(growable: false);
              if (visible.isEmpty) {
                return const _EmptyMessage('No matching profiles found.');
              }
              return allProjects.when(
                loading: () => const _LoadingIndicator(),
                error: (error, stackTrace) => _InlineError(
                  message: 'Unable to load projects: $error',
                ),
                data: (projectList) => ListView.builder(
                  itemCount: visible.length,
                  itemBuilder: (context, index) {
                    final person = visible[index];
                    final activeProjects = projectList
                        .where((p) => p.ownerUid == person.uid)
                        .toList(growable: false);
                    return _DirectoryCard(
                      person: person,
                      currentUid: widget.profile.uid,
                      currentRole: widget.profile.role,
                      projects: activeProjects,
                    );
                  },
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _DirectoryCard extends ConsumerWidget {
  const _DirectoryCard({
    required this.person,
    required this.currentUid,
    required this.currentRole,
    required this.projects,
  });

  final UserProfile person;
  final String currentUid;
  final UserRole currentRole;
  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final following = ref.watch(isFollowingProvider(
      FollowPair(currentUid, person.uid),
    ));
    final guidedCount = person.role == UserRole.teacher
        ? ref.watch(facultyGuidedStudentCountProvider(person.uid))
        : const AsyncValue<int>.data(0);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundImage: person.photoUrl.isEmpty
                    ? null
                    : NetworkImage(person.photoUrl),
                child: person.photoUrl.isEmpty
                    ? Text(person.name.isEmpty
                        ? '?'
                        : person.name[0].toUpperCase())
                    : null,
              ),
              title: Text(person.name),
              subtitle: Text(
                [
                  person.role.value,
                  person.department,
                  if (person.skills.isNotEmpty)
                    'Skills: ${person.skills.join(', ')}',
                  if (person.domains.isNotEmpty)
                    'Domains: ${person.domains.join(', ')}',
                  if (person.role == UserRole.teacher)
                    guidedCount.when(
                      loading: () => 'Loading guidance count...',
                      error: (error, stackTrace) =>
                          'Unable to load guidance count',
                      data: (count) => 'Guides $count student(s)',
                    ),
                  if (projects.isNotEmpty)
                    'Projects: ${projects.map((p) => p.title).join(', ')}',
                ].where((part) => part.isNotEmpty).join('\n'),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: following.when(
                loading: () => const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, stackTrace) => const Icon(Icons.error_outline),
                data: (isFollowing) => Wrap(
                  spacing: 4,
                  children: [
                    if (currentRole == UserRole.student &&
                        person.role == UserRole.teacher)
                      TextButton.icon(
                        icon: const Icon(Icons.volunteer_activism_outlined),
                        label: const Text('Interest'),
                        onPressed: () async {
                          final messenger = ScaffoldMessenger.of(context);
                          try {
                            final created = await ref
                                .read(notificationRepositoryProvider)
                                .createInterestOnce(
                                  fromUid: currentUid,
                                  toUid: person.uid,
                                );
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  created
                                      ? 'Interest sent to ${person.name}.'
                                      : 'You have already expressed interest.',
                                ),
                              ),
                            );
                          } catch (error) {
                            messenger.showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Unable to send interest: $error',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    TextButton(
                      onPressed: () async {
                        final messenger = ScaffoldMessenger.of(context);
                        try {
                          final repository = ref.read(userRepositoryProvider);
                          if (isFollowing) {
                            await repository.unfollow(currentUid, person.uid);
                          } else {
                            await repository.follow(currentUid, person.uid);
                          }
                        } catch (error) {
                          messenger.showSnackBar(
                            SnackBar(
                              content: Text('Unable to update follow: $error'),
                            ),
                          );
                        }
                      },
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StudentBatchCard extends StatelessWidget {
  const _StudentBatchCard({
    required this.batch,
    required this.project,
    required this.currentUid,
  });

  final Batch batch;
  final Project? project;
  final String currentUid;

  @override
  Widget build(BuildContext context) => Card(
        child: InkWell(
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => BatchSpacePage(
                batchId: batch.id,
                currentUid: currentUid,
              ),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.groups_outlined),
                  title: Text(project?.title ?? 'Project batch'),
                  subtitle: Text(
                    '${batch.studentUids.length} students • '
                    '${batch.status.name} • '
                    '${batch.startDate.toLocal().toString().split(' ').first} – '
                    '${batch.endDate.toLocal().toString().split(' ').first}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                ),
                BatchProjectProgress(batchId: batch.id),
              ],
            ),
          ),
        ),
      );
}

class _TeacherBatchCard extends ConsumerWidget {
  const _TeacherBatchCard({
    required this.batch,
    required this.project,
    required this.profiles,
    required this.currentUid,
  });

  final Batch batch;
  final Project? project;
  final List<UserProfile> profiles;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(batchTasksProvider(batch.id));
    final students = profiles
        .where((profile) => batch.studentUids.contains(profile.uid))
        .map((profile) => profile.name)
        .toList(growable: false);
    return Card(
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => BatchSpacePage(
              batchId: batch.id,
              currentUid: currentUid,
            ),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                project?.title ?? 'Project batch',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 6),
              Text(students.isEmpty
                  ? '${batch.studentUids.length} students'
                  : students.join(', ')),
              const SizedBox(height: 8),
              tasks.when(
                loading: () => const LinearProgressIndicator(),
                error: (error, stackTrace) =>
                    Text('Unable to load progress: $error'),
                data: (items) {
                  final completed = items
                      .where((task) => task.status == TaskStatus.done)
                      .length;
                  final progress =
                      items.isEmpty ? 0.0 : completed / items.length;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LinearProgressIndicator(value: progress),
                      const SizedBox(height: 4),
                      Text(
                        items.isEmpty
                            ? 'Progress: no tasks yet'
                            : 'Progress: ${(progress * 100).round()}% '
                                '($completed/${items.length} tasks complete)',
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FacultySummaryCard extends ConsumerWidget {
  const _FacultySummaryCard({
    required this.teacher,
    required this.projects,
  });

  final UserProfile teacher;
  final List<Project> projects;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guidedCount =
        ref.watch(facultyGuidedStudentCountProvider(teacher.uid));
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          child: Text(
            teacher.name.isEmpty ? '?' : teacher.name[0].toUpperCase(),
          ),
        ),
        title: Text(teacher.name),
        subtitle: Text(
          '${guidedCount.when(
            loading: () => 'Loading guidance count...',
            error: (error, stackTrace) => 'Guidance count unavailable',
            data: (count) => '$count student(s) guided',
          )} • '
          '${projects.isEmpty ? 'No current projects' : projects.map((p) => p.title).join(', ')}',
        ),
      ),
    );
  }
}

class _ProjectCard extends StatelessWidget {
  const _ProjectCard(this.project);

  final Project project;

  @override
  Widget build(BuildContext context) => Card(
        child: ListTile(
          leading: const Icon(Icons.lightbulb_outline),
          title: Text(project.title),
          subtitle: Text(
            '${project.description}\n'
            '${project.domains.join(', ')}'
            '${project.requiredSkills.isEmpty ? '' : ' • ${project.requiredSkills.join(', ')}'}',
          ),
          isThreeLine: true,
          trailing: Text(project.status),
        ),
      );
}

class _PostCard extends StatelessWidget {
  const _PostCard({required this.post, required this.authorName});

  final Post post;
  final String authorName;

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.symmetric(vertical: 5),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(post.type == PostType.certification
                      ? Icons.workspace_premium_outlined
                      : Icons.campaign_outlined),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      authorName,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  Text(post.createdAt.toLocal().toString().split(' ').first),
                ],
              ),
              if (post.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(post.text),
              ],
              for (final imageUrl in post.imageUrls)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      imageUrl,
                      width: double.infinity,
                      height: 220,
                      fit: BoxFit.cover,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;
                        return const SizedBox(
                          height: 220,
                          child: Center(child: CircularProgressIndicator()),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) =>
                          const SizedBox(
                        height: 120,
                        child: Center(child: Text('Unable to load image.')),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
}

class _WelcomeCard extends StatelessWidget {
  const _WelcomeCard({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) => Card(
        color: Theme.of(context).colorScheme.primaryContainer,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 4),
              Text(subtitle),
            ],
          ),
        ),
      );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 20, 2, 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
}

class _EmptyMessage extends StatelessWidget {
  const _EmptyMessage(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Text(message, textAlign: TextAlign.center),
      );
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message, textAlign: TextAlign.center),
      );
}

class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
}

Project? _findProject(List<Project> projects, String projectId) {
  for (final project in projects) {
    if (project.id == projectId) return project;
  }
  return null;
}

class _CreateChooserPage extends StatelessWidget {
  const _CreateChooserPage({required this.uid, required this.role});

  final String uid;
  final UserRole role;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create')),
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.post_add_outlined),
                title: const Text('Share a post'),
                subtitle: const Text('Add a caption, images, and post type.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => Navigator.of(context).pushReplacement(
                  MaterialPageRoute<void>(
                    builder: (_) => CreatePostPage(authorUid: uid),
                  ),
                ),
              ),
            ),
            if (role != UserRole.student)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.lightbulb_outline),
                  title: const Text('Create a project'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).pushReplacement(
                    MaterialPageRoute<void>(
                      builder: (_) => CreateProjectPage(ownerUid: uid),
                    ),
                  ),
                ),
              ),
          ],
        ),
      );
}

class CreatePostPage extends ConsumerStatefulWidget {
  const CreatePostPage({super.key, required this.authorUid});

  final String authorUid;

  @override
  ConsumerState<CreatePostPage> createState() => _CreatePostPageState();
}

class _PickedPostImage {
  const _PickedPostImage(this.file, this.bytes);

  final XFile file;
  final List<int> bytes;
}

class _CreatePostPageState extends ConsumerState<CreatePostPage> {
  final _formKey = GlobalKey<FormState>();
  final _caption = TextEditingController();
  final _imagePicker = ImagePicker();
  final List<_PickedPostImage> _images = [];
  PostType _type = PostType.update;
  bool _saving = false;
  int _uploadedImages = 0;

  @override
  void dispose() {
    _caption.dispose();
    super.dispose();
  }

  Future<void> _pickImages() async {
    try {
      final selected = await _imagePicker.pickMultiImage(imageQuality: 85);
      if (selected.isEmpty) return;
      final remaining = 6 - _images.length;
      if (remaining <= 0) {
        _showMessage('A post can include up to six images.');
        return;
      }
      final chosen = selected.take(remaining);
      final loaded = <_PickedPostImage>[];
      for (final file in chosen) {
        loaded.add(_PickedPostImage(file, await file.readAsBytes()));
      }
      if (mounted) setState(() => _images.addAll(loaded));
      if (selected.length > remaining) {
        _showMessage('Only the first six selected images were added.');
      }
    } catch (error) {
      _showMessage('Unable to select images: $error');
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final postId = const Uuid().v4();
    final uploadedFiles = <Reference>[];
    try {
      final imageUrls = <String>[];
      final storage = ref.read(firebaseStorageProvider);
      for (var index = 0; index < _images.length; index++) {
        final image = _images[index];
        final extension = image.file.name.split('.').last.toLowerCase();
        const contentTypes = {
          'jpg': 'image/jpeg',
          'jpeg': 'image/jpeg',
          'png': 'image/png',
          'webp': 'image/webp',
        };
        final contentType = contentTypes[extension];
        if (contentType == null) {
          throw StateError(
            'Unsupported image format: $extension. Use JPG, PNG, or WebP.',
          );
        }
        final reference = storage
            .ref()
            .child('posts/${widget.authorUid}/$postId/$index.$extension');
        await reference.putData(
          Uint8List.fromList(image.bytes),
          SettableMetadata(contentType: contentType),
        );
        uploadedFiles.add(reference);
        imageUrls.add(await reference.getDownloadURL());
        if (mounted) setState(() => _uploadedImages = index + 1);
      }
      await ref.read(postRepositoryProvider).create(
            Post(
              id: postId,
              authorUid: widget.authorUid,
              type: _type,
              text: _caption.text.trim(),
              imageUrls: imageUrls,
              createdAt: DateTime.now(),
              likesCount: 0,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      final cleanupErrors = <String>[];
      for (final reference in uploadedFiles) {
        try {
          await reference.delete();
        } catch (cleanupError) {
          cleanupErrors.add('$cleanupError');
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              cleanupErrors.isEmpty
                  ? 'Unable to publish post: $error'
                  : 'Unable to publish post: $error. '
                      'Some uploaded files could not be cleaned up.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
          _uploadedImages = 0;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Create post')),
        body: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              DropdownButtonFormField<PostType>(
                value: _type,
                decoration: const InputDecoration(
                  labelText: 'Post type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: PostType.update,
                    child: Text('Update'),
                  ),
                  DropdownMenuItem(
                    value: PostType.certification,
                    child: Text('Certification'),
                  ),
                ],
                onChanged: _saving
                    ? null
                    : (value) {
                        if (value != null) setState(() => _type = value);
                      },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _caption,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'Caption',
                  border: OutlineInputBorder(),
                ),
                validator: (value) =>
                    (value == null || value.trim().isEmpty) && _images.isEmpty
                        ? 'Add a caption or at least one image.'
                        : null,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _saving ? null : _pickImages,
                icon: const Icon(Icons.add_photo_alternate_outlined),
                label: Text('Add images (${_images.length}/6)'),
              ),
              if (_images.isNotEmpty) ...[
                const SizedBox(height: 8),
                SizedBox(
                  height: 116,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _images.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) => Stack(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.memory(
                            Uint8List.fromList(_images[index].bytes),
                            width: 116,
                            height: 116,
                            fit: BoxFit.cover,
                          ),
                        ),
                        Positioned(
                          top: 2,
                          right: 2,
                          child: IconButton(
                            tooltip: 'Remove image',
                            onPressed: _saving
                                ? null
                                : () => setState(
                                      () => _images.removeAt(index),
                                    ),
                            icon: const Icon(Icons.cancel),
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              if (_saving && _images.isNotEmpty) ...[
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value:
                      _images.isEmpty ? null : _uploadedImages / _images.length,
                ),
                const SizedBox(height: 4),
                Text('Uploading $_uploadedImages of ${_images.length} images'),
              ],
              const SizedBox(height: 18),
              ElevatedButton(
                onPressed: _saving ? null : _submit,
                child: _saving
                    ? const CircularProgressIndicator()
                    : const Text('Publish post'),
              ),
            ],
          ),
        ),
      );

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}
