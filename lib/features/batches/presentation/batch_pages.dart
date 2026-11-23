import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../app_providers.dart';
import '../../batches/domain/batch.dart';
import '../../batches/domain/batch_message.dart';
import '../../batches/domain/batch_task.dart';
import '../../projects/domain/project.dart';
import '../../users/domain/user_profile.dart';

class CreateBatchPage extends ConsumerStatefulWidget {
  const CreateBatchPage({super.key, required this.teacherUid});

  final String teacherUid;

  @override
  ConsumerState<CreateBatchPage> createState() => _CreateBatchPageState();
}

class _CreateBatchPageState extends ConsumerState<CreateBatchPage> {
  final Set<String> _selectedStudents = {};
  String? _selectedProjectId;
  bool _saving = false;

  Future<void> _createBatch() async {
    if (_selectedStudents.length < 4) {
      _showMessage('Select at least four available students.');
      return;
    }
    final projectId = _selectedProjectId;
    if (projectId == null) {
      _showMessage('Choose one of your available projects.');
      return;
    }

    setState(() => _saving = true);
    try {
      final startDate = DateTime.now();
      await ref.read(batchRepositoryProvider).create(
            Batch(
              id: const Uuid().v4(),
              teacherUid: widget.teacherUid,
              studentUids: _selectedStudents.toList(growable: false),
              projectId: projectId,
              startDate: startDate,
              endDate: Batch.addThreeMonths(startDate),
              status: BatchStatus.active,
            ),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (error) {
      _showMessage('Unable to create batch: $error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final projects = ref.watch(projectFeedProvider);
    final profiles = ref.watch(userDirectoryProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Create a batch')),
      body: projects.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load projects: $error')),
        data: (allProjects) {
          final availableProjects = allProjects
              .where((project) =>
                  project.ownerUid == widget.teacherUid &&
                  project.batchId == null &&
                  project.status == 'open')
              .toList(growable: false);
          if (availableProjects.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Create an available project before forming a batch.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return profiles.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Unable to load students: $error')),
            data: (allProfiles) {
              final students = allProfiles
                  .where((profile) => profile.role == UserRole.student)
                  .toList(growable: false);
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedProjectId,
                      decoration: const InputDecoration(
                        labelText: 'Project',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        for (final project in availableProjects)
                          DropdownMenuItem(
                            value: project.id,
                            child: Text(project.title),
                          ),
                      ],
                      onChanged: _saving
                          ? null
                          : (value) =>
                              setState(() => _selectedProjectId = value),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Select students (${_selectedStudents.length}/4 minimum)',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _selectedStudents.length < 4 || _saving
                              ? null
                              : _createBatch,
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Text('Create batch'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: students.isEmpty
                        ? const _BatchEmpty('No student profiles found.')
                        : ListView.builder(
                            itemCount: students.length,
                            itemBuilder: (context, index) {
                              final student = students[index];
                              return _StudentPickerTile(
                                profile: student,
                                selected:
                                    _selectedStudents.contains(student.uid),
                                enabled: !_saving,
                                onChanged: (selected) => setState(() {
                                  if (selected) {
                                    _selectedStudents.add(student.uid);
                                  } else {
                                    _selectedStudents.remove(student.uid);
                                  }
                                }),
                              );
                            },
                          ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

class _StudentPickerTile extends ConsumerWidget {
  const _StudentPickerTile({
    required this.profile,
    required this.selected,
    required this.enabled,
    required this.onChanged,
  });

  final UserProfile profile;
  final bool selected;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeBatch = ref.watch(activeBatchIdProvider(profile.uid));
    return activeBatch.when(
      loading: () => ListTile(
        leading: const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text(profile.name),
        subtitle: const Text('Checking active batch...'),
      ),
      error: (error, stackTrace) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: Text(profile.name),
        subtitle: Text('Unable to check availability: $error'),
      ),
      data: (batchId) => CheckboxListTile(
        value: selected,
        onChanged: enabled && batchId == null
            ? (value) => onChanged(value ?? false)
            : null,
        title: Text(profile.name),
        subtitle: Text(batchId == null
            ? profile.department
            : 'Already in an active batch'),
        secondary: CircleAvatar(
          child: Text(
            profile.name.isEmpty ? '?' : profile.name[0].toUpperCase(),
          ),
        ),
      ),
    );
  }
}

class BatchSpacePage extends StatelessWidget {
  const BatchSpacePage({
    super.key,
    required this.batchId,
    required this.currentUid,
  });

  final String batchId;
  final String currentUid;

  @override
  Widget build(BuildContext context) => DefaultTabController(
        length: 4,
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Batch space'),
            bottom: const TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Overview'),
                Tab(text: 'Tasks'),
                Tab(text: 'Chat'),
                Tab(text: 'Members'),
              ],
            ),
          ),
          body: _BatchGate(
            batchId: batchId,
            builder: (batch) => TabBarView(
              children: [
                _BatchOverview(batch: batch),
                _BatchTasks(batch: batch, currentUid: currentUid),
                _BatchChat(batch: batch, currentUid: currentUid),
                _BatchMembers(batch: batch),
              ],
            ),
          ),
        ),
      );
}

class _BatchGate extends ConsumerWidget {
  const _BatchGate({required this.batchId, required this.builder});

  final String batchId;
  final Widget Function(Batch batch) builder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batch = ref.watch(batchProvider(batchId));
    return batch.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Unable to load batch: $error')),
      data: (value) => value == null
          ? const _BatchEmpty('This batch is no longer available.')
          : builder(value),
    );
  }
}

class _BatchOverview extends ConsumerWidget {
  const _BatchOverview({required this.batch});

  final Batch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final projects = ref.watch(projectFeedProvider);
    final profiles = ref.watch(userDirectoryProvider);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        projects.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              _BatchError(message: 'Unable to load project: $error'),
          data: (items) {
            Project? project;
            for (final item in items) {
              if (item.id == batch.projectId) {
                project = item;
                break;
              }
            }
            return Card(
              child: ListTile(
                leading: const Icon(Icons.lightbulb_outline),
                title: Text(project?.title ?? 'Project'),
                subtitle: Text(
                    project?.description ?? 'Project details unavailable.'),
              ),
            );
          },
        ),
        _BatchCountdown(batch: batch),
        const SizedBox(height: 8),
        BatchProjectProgress(batchId: batch.id),
        const SizedBox(height: 16),
        Text('Project dates', style: Theme.of(context).textTheme.titleMedium),
        Text('Started ${_formatDate(batch.startDate)}'),
        Text('Ends ${_formatDate(batch.endDate)}'),
        const SizedBox(height: 16),
        Text('Team', style: Theme.of(context).textTheme.titleMedium),
        profiles.when(
          loading: () => const LinearProgressIndicator(),
          error: (error, stackTrace) =>
              _BatchError(message: 'Unable to load members: $error'),
          data: (items) => Text(
            '${batch.studentUids.length} students • '
            'Teacher: ${_nameFor(items, batch.teacherUid)}',
          ),
        ),
      ],
    );
  }
}

class _BatchCountdown extends StatefulWidget {
  const _BatchCountdown({required this.batch});

  final Batch batch;

  @override
  State<_BatchCountdown> createState() => _BatchCountdownState();
}

class _BatchCountdownState extends State<_BatchCountdown> {
  Timer? _timer;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _updateCountdown();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateCountdown();
    });
  }

  @override
  void didUpdateWidget(covariant _BatchCountdown oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.batch.endDate != widget.batch.endDate ||
        oldWidget.batch.status != widget.batch.status) {
      _updateCountdown();
    }
  }

  void _updateCountdown() {
    setState(() {
      _remaining = widget.batch.endDate.difference(DateTime.now());
      if (_remaining.isNegative) _remaining = Duration.zero;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final completed = widget.batch.status == BatchStatus.completed;
    final days = _remaining.inDays;
    final hours = _remaining.inHours % 24;
    final minutes = _remaining.inMinutes % 60;
    final seconds = _remaining.inSeconds % 60;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                completed
                    ? 'Batch completed'
                    : _remaining == Duration.zero
                        ? 'Batch expired — awaiting completion'
                        : '$days days  $hours:${minutes.toString().padLeft(2, '0')}:'
                            '${seconds.toString().padLeft(2, '0')} remaining',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class BatchProjectProgress extends ConsumerWidget {
  const BatchProjectProgress({super.key, required this.batchId});

  final String batchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(batchTasksProvider(batchId));
    return tasks.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, stackTrace) =>
          _BatchError(message: 'Unable to load task progress: $error'),
      data: (items) {
        final done =
            items.where((task) => task.status == TaskStatus.done).length;
        final progress = items.isEmpty ? 0.0 : done / items.length;
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Project progress: $done/${items.length} tasks complete'),
                const SizedBox(height: 8),
                LinearProgressIndicator(value: progress),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _BatchTasks extends ConsumerWidget {
  const _BatchTasks({required this.batch, required this.currentUid});

  final Batch batch;
  final String currentUid;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasks = ref.watch(batchTasksProvider(batch.id));
    final members = [batch.teacherUid, ...batch.studentUids];
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add task',
        onPressed: () => _editTask(context, ref, members, null),
        child: const Icon(Icons.add),
      ),
      body: tasks.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load tasks: $error')),
        data: (items) => items.isEmpty
            ? const _BatchEmpty('No tasks yet. Add the first task.')
            : ListView(
                padding: const EdgeInsets.only(bottom: 88, top: 8),
                children: [
                  BatchProjectProgress(batchId: batch.id),
                  SizedBox(
                    height: 465,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        for (final status in TaskStatus.values)
                          _KanbanColumn(
                            status: status,
                            tasks: items
                                .where((task) => task.status == status)
                                .toList(growable: false),
                            onEdit: (task) =>
                                _editTask(context, ref, members, task),
                            onStatusChanged: (task, nextStatus) =>
                                _changeStatus(context, ref, task, nextStatus),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Future<void> _editTask(
    BuildContext context,
    WidgetRef ref,
    List<String> members,
    BatchTask? existing,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final task = await showDialog<BatchTask>(
      context: context,
      builder: (_) => _TaskEditor(
        existing: existing,
        members: members,
        currentUid: currentUid,
      ),
    );
    if (task == null) return;
    try {
      final repository = ref.read(batchRepositoryProvider);
      if (existing == null) {
        await repository.createTask(batch.id, task);
      } else {
        await repository.updateTask(batch.id, task);
      }
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Unable to save task: $error')),
        );
      }
    }
  }

  Future<void> _changeStatus(
    BuildContext context,
    WidgetRef ref,
    BatchTask task,
    TaskStatus status,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(batchRepositoryProvider).updateTask(
            batch.id,
            BatchTask(
              id: task.id,
              title: task.title,
              description: task.description,
              assigneeUid: task.assigneeUid,
              status: status,
              updatedBy: currentUid,
              updatedAt: DateTime.now(),
            ),
          );
    } catch (error) {
      if (messenger.mounted) {
        messenger.showSnackBar(
          SnackBar(content: Text('Unable to move task: $error')),
        );
      }
    }
  }
}

class _KanbanColumn extends StatelessWidget {
  const _KanbanColumn({
    required this.status,
    required this.tasks,
    required this.onEdit,
    required this.onStatusChanged,
  });

  final TaskStatus status;
  final List<BatchTask> tasks;
  final ValueChanged<BatchTask> onEdit;
  final void Function(BatchTask, TaskStatus) onStatusChanged;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 300,
        child: Card(
          margin: const EdgeInsets.all(8),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        _statusName(status),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    Chip(label: Text('${tasks.length}')),
                  ],
                ),
              ),
              Expanded(
                child: tasks.isEmpty
                    ? const Center(child: Text('No tasks'))
                    : ListView.builder(
                        itemCount: tasks.length,
                        itemBuilder: (context, index) {
                          final task = tasks[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(10),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          task.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleSmall,
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Edit task',
                                        onPressed: () => onEdit(task),
                                        icon: const Icon(Icons.edit_outlined),
                                      ),
                                    ],
                                  ),
                                  if (task.description.isNotEmpty)
                                    Text(task.description),
                                  const SizedBox(height: 6),
                                  Text(
                                    'Assigned to ${_shortUid(task.assigneeUid)}',
                                    style:
                                        Theme.of(context).textTheme.bodySmall,
                                  ),
                                  DropdownButton<TaskStatus>(
                                    value: task.status,
                                    isExpanded: true,
                                    onChanged: (next) {
                                      if (next != null && next != task.status) {
                                        onStatusChanged(task, next);
                                      }
                                    },
                                    items: [
                                      for (final next in TaskStatus.values)
                                        DropdownMenuItem(
                                          value: next,
                                          child: Text(_statusName(next)),
                                        ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      );
}

class _TaskEditor extends StatefulWidget {
  const _TaskEditor({
    required this.existing,
    required this.members,
    required this.currentUid,
  });

  final BatchTask? existing;
  final List<String> members;
  final String currentUid;

  @override
  State<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends State<_TaskEditor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late String _assigneeUid;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _description =
        TextEditingController(text: widget.existing?.description ?? '');
    _assigneeUid = widget.existing?.assigneeUid ?? widget.currentUid;
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        title: Text(widget.existing == null ? 'New task' : 'Edit task'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _title,
                  decoration: const InputDecoration(labelText: 'Title'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Enter a task title.'
                      : null,
                ),
                TextFormField(
                  controller: _description,
                  decoration: const InputDecoration(labelText: 'Description'),
                  maxLines: 3,
                ),
                DropdownButtonFormField<String>(
                  value: _assigneeUid,
                  decoration: const InputDecoration(labelText: 'Assignee'),
                  items: [
                    for (final uid in widget.members)
                      DropdownMenuItem(value: uid, child: Text(_shortUid(uid))),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _assigneeUid = value);
                  },
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              if (!_formKey.currentState!.validate()) return;
              final old = widget.existing;
              Navigator.of(context).pop(
                BatchTask(
                  id: old?.id ?? const Uuid().v4(),
                  title: _title.text.trim(),
                  description: _description.text.trim(),
                  assigneeUid: _assigneeUid,
                  status: old?.status ?? TaskStatus.todo,
                  updatedBy: widget.currentUid,
                  updatedAt: DateTime.now(),
                ),
              );
            },
            child: const Text('Save'),
          ),
        ],
      );
}

class _BatchChat extends ConsumerStatefulWidget {
  const _BatchChat({required this.batch, required this.currentUid});

  final Batch batch;
  final String currentUid;

  @override
  ConsumerState<_BatchChat> createState() => _BatchChatState();
}

class _BatchChatState extends ConsumerState<_BatchChat> {
  final _controller = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    if (_controller.text.trim().isEmpty || _sending) return;
    final text = _controller.text.trim();
    setState(() => _sending = true);
    try {
      await ref.read(batchRepositoryProvider).sendMessage(
            batchId: widget.batch.id,
            senderUid: widget.currentUid,
            text: text,
          );
      _controller.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to send message: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(batchMessagesProvider(widget.batch.id));
    return Column(
      children: [
        Expanded(
          child: messages.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) =>
                Center(child: Text('Unable to load chat: $error')),
            data: (items) => items.isEmpty
                ? const _BatchEmpty('No messages yet. Start the conversation.')
                : ListView.builder(
                    controller: _scrollController,
                    reverse: true,
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    itemBuilder: (context, index) => _ChatMessageTile(
                      message: items[index],
                      isMine: items[index].senderUid == widget.currentUid,
                    ),
                  ),
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                      hintText: 'Message your batch',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _send(),
                  ),
                ),
                IconButton(
                  tooltip: 'Send message',
                  onPressed: _sending ? null : _send,
                  icon: _sending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ChatMessageTile extends ConsumerWidget {
  const _ChatMessageTile({required this.message, required this.isMine});

  final BatchMessage message;
  final bool isMine;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileProvider(message.senderUid));
    final name = profile.when(
      loading: () => 'Loading...',
      error: (error, stackTrace) => 'Member',
      data: (value) => value?.name ?? 'Former member',
    );
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Card(
        color: isMine ? Theme.of(context).colorScheme.primaryContainer : null,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: Theme.of(context).textTheme.labelSmall),
              const SizedBox(height: 3),
              Text(message.text),
              const SizedBox(height: 3),
              Text(
                TimeOfDay.fromDateTime(message.createdAt.toLocal())
                    .format(context),
                style: Theme.of(context).textTheme.labelSmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BatchMembers extends ConsumerWidget {
  const _BatchMembers({required this.batch});

  final Batch batch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profiles = ref.watch(userDirectoryProvider);
    return profiles.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) =>
          Center(child: Text('Unable to load members: $error')),
      data: (items) {
        final members = [
          batch.teacherUid,
          ...batch.studentUids,
        ];
        return ListView(
          children: [
            for (final uid in members)
              ListTile(
                leading: CircleAvatar(
                  child: Text(
                    _nameFor(items, uid).isEmpty
                        ? '?'
                        : _nameFor(items, uid)[0].toUpperCase(),
                  ),
                ),
                title: Text(_nameFor(items, uid)),
                subtitle: Text(uid == batch.teacherUid ? 'Teacher' : 'Student'),
              ),
          ],
        );
      },
    );
  }
}

class _BatchEmpty extends StatelessWidget {
  const _BatchEmpty(this.message);

  final String message;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(message, textAlign: TextAlign.center),
        ),
      );
}

class _BatchError extends StatelessWidget {
  const _BatchError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(12),
        child: Text(message),
      );
}

String _nameFor(List<UserProfile> profiles, String uid) {
  for (final profile in profiles) {
    if (profile.uid == uid) return profile.name;
  }
  return 'Member';
}

String _shortUid(String uid) => uid.length > 10 ? uid.substring(0, 10) : uid;

String _formatDate(DateTime date) {
  final local = date.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/'
      '${local.month.toString().padLeft(2, '0')}/${local.year}';
}

String _statusName(TaskStatus status) {
  switch (status) {
    case TaskStatus.todo:
      return 'To do';
    case TaskStatus.doing:
      return 'Doing';
    case TaskStatus.done:
      return 'Done';
  }
}
