import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../../batches/domain/batch.dart';
import '../../projects/domain/project.dart';
import '../../users/domain/user_profile.dart';
import '../../users/presentation/profile_page.dart';
import '../domain/teammate_suggestion.dart';

class TeamSuggestionsSection extends ConsumerWidget {
  const TeamSuggestionsSection({
    super.key,
    required this.uid,
    required this.role,
    this.initialProjectId,
  });

  final String uid;
  final UserRole role;
  final String? initialProjectId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectFeedProvider);
    if (role == UserRole.student) {
      final batches = ref.watch(userBatchesProvider(uid));
      return projects.when(
        loading: () => const _SectionLoading(),
        error: (error, stackTrace) =>
            _SectionError(message: 'Unable to load projects: $error'),
        data: (allProjects) => batches.when(
          loading: () => const _SectionLoading(),
          error: (error, stackTrace) =>
              _SectionError(message: 'Unable to load your batch: $error'),
          data: (items) {
            final projectIds = items
                .where((batch) => batch.status == BatchStatus.active)
                .map((batch) => batch.projectId)
                .toSet();
            final eligible = allProjects
                .where((project) =>
                    projectIds.contains(project.id) ||
                    project.teamUids.contains(uid) ||
                    (project.status == 'open' && project.batchId == null))
                .toList(growable: false);
            return _ProjectSuggestions(
              uid: uid,
              projects: eligible,
              initialProjectId: initialProjectId,
            );
          },
        ),
      );
    }
    return projects.when(
      loading: () => const _SectionLoading(),
      error: (error, stackTrace) =>
          _SectionError(message: 'Unable to load projects: $error'),
      data: (items) => _ProjectSuggestions(
        uid: uid,
        initialProjectId: initialProjectId,
        projects: items
            .where((project) =>
                project.ownerUid == uid &&
                (project.status == 'open' || project.status == 'active'))
            .toList(growable: false),
      ),
    );
  }
}

class _ProjectSuggestions extends ConsumerStatefulWidget {
  const _ProjectSuggestions({
    required this.uid,
    required this.projects,
    this.initialProjectId,
  });

  final String uid;
  final List<Project> projects;
  final String? initialProjectId;

  @override
  ConsumerState<_ProjectSuggestions> createState() =>
      _ProjectSuggestionsState();
}

class _ProjectSuggestionsState extends ConsumerState<_ProjectSuggestions> {
  String? _selectedProjectId;
  String? _invitingUid;
  final Map<String, Set<String>> _requestedByProject = {};
  final _skillFilter = TextEditingController();
  final _collegeFilter = TextEditingController();
  String _experienceFilter = 'Any';
  bool _availableOnly = false;

  @override
  void initState() {
    super.initState();
    _selectedProjectId = widget.initialProjectId;
  }

  @override
  void dispose() {
    _skillFilter.dispose();
    _collegeFilter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.projects.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _SectionTitle(),
          _SectionError(
            message:
                'Create a project or join an active batch to get teammate suggestions.',
          ),
        ],
      );
    }
    final project = widget.projects.firstWhere(
      (item) => item.id == _selectedProjectId,
      orElse: () => widget.projects.first,
    );
    final suggestions = ref.watch(
      teammateSuggestionsProvider(
        TeamSuggestionRequest(uid: widget.uid, projectId: project.id),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle(),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DropdownButtonFormField<String>(
            value: project.id,
            decoration: const InputDecoration(
              labelText: 'Match for project',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final item in widget.projects)
                DropdownMenuItem(
                  value: item.id,
                  child: Text(item.title, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() => _selectedProjectId = value),
          ),
        ),
        const SizedBox(height: 8),
        suggestions.when(
          loading: () => const _SectionLoading(),
          error: (error, stackTrace) =>
              _SectionError(message: 'Unable to find teammates: $error'),
          data: (items) {
            if (items.isEmpty) {
              return const _SectionError(
                message: 'No teammate suggestions yet. Add skills to profiles.',
              );
            }
            final skillQuery = _skillFilter.text.trim().toLowerCase();
            final collegeQuery = _collegeFilter.text.trim().toLowerCase();
            final filtered = items.where((item) {
              final matchesSkill = skillQuery.isEmpty ||
                  item.skills.any(
                    (skill) => skill.toLowerCase().contains(skillQuery),
                  );
              final matchesCollege = collegeQuery.isEmpty ||
                  item.collegeName.toLowerCase().contains(collegeQuery);
              final matchesExperience = _experienceFilter == 'Any' ||
                  item.experienceLevel.toLowerCase() ==
                      _experienceFilter.toLowerCase();
              final matchesAvailability = !_availableOnly ||
                  item.availability.toLowerCase() == 'available' ||
                  item.availability.toLowerCase() == 'actively looking';
              return matchesSkill &&
                  matchesCollege &&
                  matchesExperience &&
                  matchesAvailability;
            }).toList(growable: false);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      SizedBox(
                        width: 165,
                        child: TextField(
                          controller: _skillFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by skill',
                            prefixIcon: Icon(Icons.search),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: TextField(
                          controller: _collegeFilter,
                          decoration: const InputDecoration(
                            labelText: 'Filter by college',
                            prefixIcon: Icon(Icons.school_outlined),
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          onChanged: (_) => setState(() {}),
                        ),
                      ),
                      SizedBox(
                        width: 165,
                        child: DropdownButtonFormField<String>(
                          value: _experienceFilter,
                          decoration: const InputDecoration(
                            labelText: 'Experience',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Any',
                              child: Text('Any experience'),
                            ),
                            DropdownMenuItem(
                              value: 'Beginner',
                              child: Text('Beginner'),
                            ),
                            DropdownMenuItem(
                              value: 'Intermediate',
                              child: Text('Intermediate'),
                            ),
                            DropdownMenuItem(
                              value: 'Advanced',
                              child: Text('Advanced'),
                            ),
                            DropdownMenuItem(
                              value: 'Expert',
                              child: Text('Expert'),
                            ),
                          ],
                          onChanged: (value) => setState(
                            () => _experienceFilter = value ?? 'Any',
                          ),
                        ),
                      ),
                      FilterChip(
                        label: const Text('Available now'),
                        selected: _availableOnly,
                        onSelected: (value) =>
                            setState(() => _availableOnly = value),
                      ),
                    ],
                  ),
                ),
                if (filtered.isEmpty)
                  const _SectionError(
                    message:
                        'No recommendations match these filters. Try broadening your search.',
                  )
                else
                  SizedBox(
                    height: 430,
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      scrollDirection: Axis.horizontal,
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 10),
                      itemBuilder: (context, index) {
                        final suggestion = filtered[index];
                        return _SuggestionCard(
                          suggestion: suggestion,
                          inviting: _invitingUid == suggestion.uid,
                          requested: _requestedByProject[project.id]
                                  ?.contains(suggestion.uid) ??
                              false,
                          onInvite: () => _invite(project, suggestion),
                          onViewProfile: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => ProfilePage(uid: suggestion.uid),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  Future<void> _invite(Project project, TeammateSuggestion teammate) async {
    setState(() => _invitingUid = teammate.uid);
    try {
      final sent = await ref.read(aiRepositoryProvider).inviteTeammate(
            toUid: teammate.uid,
            projectId: project.id,
          );
      if (mounted) {
        setState(() {
          _requestedByProject
              .putIfAbsent(project.id, () => <String>{})
              .add(teammate.uid);
        });
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Collaboration request sent to ${teammate.name}.'
              : 'A collaboration request was already sent to ${teammate.name}.'),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to invite teammate: $error')),
      );
    } finally {
      if (mounted) setState(() => _invitingUid = null);
    }
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Smart Team Matching',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 4),
            Text(
              'Scoring-based recommendations prioritize project skill gaps, balanced roles, shared interests, experience, and availability.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      );
}

class _SectionLoading extends StatelessWidget {
  const _SectionLoading();

  @override
  Widget build(BuildContext context) => const Padding(
        padding: EdgeInsets.all(20),
        child: Center(child: CircularProgressIndicator()),
      );
}

class _SectionError extends StatelessWidget {
  const _SectionError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Text(message),
      );
}

class _SuggestionCard extends StatelessWidget {
  const _SuggestionCard({
    required this.suggestion,
    required this.inviting,
    required this.requested,
    required this.onInvite,
    required this.onViewProfile,
  });

  final TeammateSuggestion suggestion;
  final bool inviting;
  final bool requested;
  final VoidCallback onInvite;
  final VoidCallback onViewProfile;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 280,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: suggestion.photoUrl.isEmpty
                          ? null
                          : NetworkImage(suggestion.photoUrl),
                      child: suggestion.photoUrl.isEmpty
                          ? Text(suggestion.name.isEmpty
                              ? '?'
                              : suggestion.name[0].toUpperCase())
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            suggestion.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          Text(
                            suggestion.collegeName.isEmpty
                                ? 'College not provided'
                                : suggestion.collegeName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        suggestion.role.isEmpty
                            ? 'Role not specified'
                            : suggestion.role,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Chip(label: Text('${suggestion.score}%')),
                  ],
                ),
                LinearProgressIndicator(
                  value: suggestion.score / 100,
                  minHeight: 6,
                ),
                const SizedBox(height: 8),
                Text('Skills', style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 4,
                  runSpacing: 0,
                  children: [
                    for (final skill in suggestion.skills.take(5))
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(skill),
                      ),
                    if (suggestion.skills.isEmpty)
                      const Chip(label: Text('No skills listed')),
                  ],
                ),
                Text(
                  suggestion.interests.isEmpty
                      ? 'Interests not specified'
                      : 'Interests: ${suggestion.interests.take(3).join(', ')}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${suggestion.experienceLevel.isEmpty ? 'Experience not specified' : suggestion.experienceLevel}'
                  '${suggestion.availability.isEmpty ? '' : ' • ${suggestion.availability}'}'
                  '${suggestion.preferredWorkingHours.isEmpty ? '' : ' • ${suggestion.preferredWorkingHours}'}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 6),
                Expanded(
                  child: Text(
                    suggestion.reason,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: onViewProfile,
                        child: const Text('View profile'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: inviting || requested ? null : onInvite,
                        child: inviting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : Text(requested ? 'Request sent' : 'Request'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}
