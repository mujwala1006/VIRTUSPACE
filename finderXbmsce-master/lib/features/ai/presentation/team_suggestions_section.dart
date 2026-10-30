import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../../batches/domain/batch.dart';
import '../../projects/domain/project.dart';
import '../../users/domain/user_profile.dart';
import '../domain/teammate_suggestion.dart';

class TeamSuggestionsSection extends ConsumerWidget {
  const TeamSuggestionsSection({
    super.key,
    required this.uid,
    required this.role,
  });

  final String uid;
  final UserRole role;

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
                    (project.status == 'open' && project.batchId == null))
                .toList(growable: false);
            return _ProjectSuggestions(uid: uid, projects: eligible);
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
  const _ProjectSuggestions({required this.uid, required this.projects});

  final String uid;
  final List<Project> projects;

  @override
  ConsumerState<_ProjectSuggestions> createState() =>
      _ProjectSuggestionsState();
}

class _ProjectSuggestionsState extends ConsumerState<_ProjectSuggestions> {
  String? _selectedProjectId;
  String? _invitingUid;

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
            return SizedBox(
              height: 248,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                scrollDirection: Axis.horizontal,
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => _SuggestionCard(
                  suggestion: items[index],
                  inviting: _invitingUid == items[index].uid,
                  inviteLabel: project.batchId == null
                      ? 'Invite to project'
                      : 'Invite to batch',
                  onInvite: () => _invite(project, items[index]),
                ),
              ),
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
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(sent
              ? 'Invitation sent to ${teammate.name}.'
              : 'An invitation was already sent to ${teammate.name}.'),
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
        child: Text(
          'Suggested teammates',
          style: Theme.of(context).textTheme.titleLarge,
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
    required this.inviteLabel,
    required this.onInvite,
  });

  final TeammateSuggestion suggestion;
  final bool inviting;
  final String inviteLabel;
  final VoidCallback onInvite;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 250,
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
                            '${suggestion.role} • ${suggestion.score}% match',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  suggestion.skills.isEmpty
                      ? suggestion.department
                      : suggestion.skills.join(', '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Expanded(
                  child: Text(
                    suggestion.reason,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: inviting ? null : onInvite,
                    child: inviting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(inviteLabel),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}
