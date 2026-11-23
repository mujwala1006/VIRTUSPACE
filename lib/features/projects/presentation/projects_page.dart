import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../batches/presentation/batch_pages.dart';
import '../../batches/domain/batch.dart';
import '../../app_providers.dart';
import '../../ai/presentation/team_suggestions_section.dart';
import '../domain/project.dart';
import '../../users/domain/user_profile.dart';

class ProjectExplorePage extends ConsumerWidget {
  const ProjectExplorePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectFeedProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Explore projects')),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load projects: $error')),
        data: (items) {
          final active = items
              .where((project) =>
                  project.status == 'open' || project.status == 'active')
              .toList(growable: false);
          if (active.isEmpty) {
            return const Center(child: Text('No active projects yet.'));
          }
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: active.length,
            itemBuilder: (context, index) {
              final project = active[index];
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(project.title),
                        subtitle: Text(
                          '${project.description}\n'
                          '${project.domains.join(', ')}'
                          '${project.requiredSkills.isEmpty ? '' : ' • ${project.requiredSkills.join(', ')}'}',
                        ),
                        isThreeLine: true,
                        trailing: Chip(label: Text(project.status)),
                      ),
                      if (project.teamUids.isNotEmpty)
                        _ProjectCollaborators(teamUids: project.teamUids),
                      if (user != null)
                        _ProjectMatchingButton(
                          uid: user.uid,
                          project: project,
                        ),
                      if (project.batchId != null ||
                          project.totalTaskCount > 0) ...[
                        _PublicProjectProgress(project: project),
                        if (project.batchId != null &&
                            user != null &&
                            user.uid == project.ownerUid)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => BatchSpacePage(
                                    batchId: project.batchId!,
                                    currentUid: user.uid,
                                  ),
                                ),
                              ),
                              icon: const Icon(Icons.groups_outlined),
                              label: const Text('Open batch'),
                            ),
                          ),
                        if (project.batchId != null &&
                            user != null &&
                            user.uid != project.ownerUid)
                          _StudentBatchOpenButton(
                            batchId: project.batchId!,
                            uid: user.uid,
                          ),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(top: 8),
                          child: Text('Not assigned to a batch yet.'),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class _ProjectMatchingButton extends ConsumerWidget {
  const _ProjectMatchingButton({
    required this.uid,
    required this.project,
  });

  final String uid;
  final Project project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    return profile.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Unable to load your profile: $error'),
      ),
      data: (userProfile) {
        if (userProfile?.role != UserRole.student) {
          return const SizedBox.shrink();
        }
        final batches = ref.watch(userBatchesProvider(uid));
        return batches.when(
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text('Unable to verify your project access: $error'),
          ),
          data: (items) {
            final belongsToBatch = items.any(
              (batch) =>
                  batch.status == BatchStatus.active &&
                  batch.projectId == project.id,
            );
            final canMatch = project.teamUids.contains(uid) ||
                belongsToBatch ||
                (project.status == 'open' && project.batchId == null);
            if (!canMatch) return const SizedBox.shrink();
            return Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => Scaffold(
                      appBar: AppBar(title: const Text('Smart Team Matching')),
                      body: ListView(
                        children: [
                          TeamSuggestionsSection(
                            uid: uid,
                            role: UserRole.student,
                            initialProjectId: project.id,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                icon: const Icon(Icons.groups_outlined),
                label: const Text('Find teammates'),
              ),
            );
          },
        );
      },
    );
  }
}

class _ProjectCollaborators extends ConsumerWidget {
  const _ProjectCollaborators({required this.teamUids});

  final List<String> teamUids;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Wrap(
          spacing: 6,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Chip(
              avatar: Icon(Icons.groups_outlined, size: 18),
              label: Text('Accepted collaborators'),
            ),
            for (final uid in teamUids) _CollaboratorChip(uid: uid),
          ],
        ),
      );
}

class _CollaboratorChip extends ConsumerWidget {
  const _CollaboratorChip({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    return profile.when(
      loading: () => const Chip(label: Text('Loading teammate...')),
      error: (error, stackTrace) =>
          Chip(label: Text('Unable to load teammate: $error')),
      data: (value) => Chip(
        avatar: CircleAvatar(
          backgroundImage: value == null || value.photoUrl.isEmpty
              ? null
              : NetworkImage(value.photoUrl),
          child: value == null || value.photoUrl.isEmpty
              ? const Icon(Icons.person, size: 16)
              : null,
        ),
        label: Text(value?.name ?? 'Former member'),
      ),
    );
  }
}

class _PublicProjectProgress extends StatelessWidget {
  const _PublicProjectProgress({required this.project});

  final Project project;

  @override
  Widget build(BuildContext context) {
    final total = project.totalTaskCount;
    final done = project.doneTaskCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Project progress: $done/$total tasks complete'),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: total == 0 ? 0 : done / total),
          ],
        ),
      ),
    );
  }
}

class _StudentBatchOpenButton extends ConsumerWidget {
  const _StudentBatchOpenButton({
    required this.batchId,
    required this.uid,
  });

  final String batchId;
  final String uid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(uid));
    return profile.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(12),
        child: LinearProgressIndicator(),
      ),
      error: (error, stackTrace) => Padding(
        padding: const EdgeInsets.all(8),
        child: Text('Unable to verify account role: $error'),
      ),
      data: (userProfile) {
        if (userProfile?.role != UserRole.student) {
          return const SizedBox.shrink();
        }
        final activeBatch = ref.watch(activeBatchIdProvider(uid));
        return activeBatch.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: LinearProgressIndicator(),
          ),
          error: (error, stackTrace) => Padding(
            padding: const EdgeInsets.all(8),
            child: Text('Unable to verify batch membership: $error'),
          ),
          data: (activeBatchId) => activeBatchId == batchId
              ? Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => BatchSpacePage(
                          batchId: batchId,
                          currentUid: uid,
                        ),
                      ),
                    ),
                    icon: const Icon(Icons.groups_outlined),
                    label: const Text('Open batch'),
                  ),
                )
              : const SizedBox.shrink(),
        );
      },
    );
  }
}

class ProjectsPage extends ConsumerWidget {
  const ProjectsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectFeedProvider);
    final user = ref.watch(authStateProvider).valueOrNull;
    return Scaffold(
      appBar: AppBar(title: const Text('Projects')),
      floatingActionButton: user == null
          ? null
          : FloatingActionButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => CreateProjectPage(ownerUid: user.uid),
                ),
              ),
              child: const Icon(Icons.add),
            ),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load projects: $error')),
        data: (items) => items.isEmpty
            ? const Center(child: Text('No projects yet.'))
            : ListView.builder(
                itemCount: items.length,
                itemBuilder: (context, index) {
                  final project = items[index];
                  return ListTile(
                    title: Text(project.title),
                    subtitle: Text(project.description),
                    trailing: Text(project.status),
                  );
                },
              ),
      ),
    );
  }
}

class CreateProjectPage extends ConsumerStatefulWidget {
  const CreateProjectPage({super.key, required this.ownerUid});

  final String ownerUid;

  @override
  ConsumerState<CreateProjectPage> createState() => _CreateProjectPageState();
}

class _CreateProjectPageState extends ConsumerState<CreateProjectPage> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _domains = TextEditingController();
  final _skills = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _domains.dispose();
    _skills.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final now = DateTime.now();
      final project = Project(
        id: const Uuid().v4(),
        ownerUid: widget.ownerUid,
        title: _title.text.trim(),
        description: _description.text.trim(),
        domains: _parseList(_domains.text),
        requiredSkills: _parseList(_skills.text),
        status: 'open',
        batchId: null,
        createdAt: now,
      );
      await ref.read(projectRepositoryProvider).create(project);
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to create project: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  List<String> _parseList(String value) => value
      .split(',')
      .map((item) => item.trim())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create project')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a project title.'
                  : null,
            ),
            TextFormField(
              controller: _description,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Description'),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter a description.'
                  : null,
            ),
            TextFormField(
              controller: _domains,
              decoration: const InputDecoration(
                labelText: 'Domains (comma-separated)',
              ),
            ),
            TextFormField(
              controller: _skills,
              decoration: const InputDecoration(
                labelText: 'Required skills (comma-separated)',
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Create project'),
            ),
          ],
        ),
      ),
    );
  }
}
