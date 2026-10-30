import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../../users/domain/user_profile.dart';
import '../../users/presentation/profile_page.dart';
import '../domain/app_notification.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({
    super.key,
    required this.uid,
    this.embedded = false,
  });

  final String uid;
  final bool embedded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider(uid));
    return Scaffold(
      appBar: embedded ? null : AppBar(title: const Text('Notifications')),
      body: notifications.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) =>
            Center(child: Text('Unable to load notifications: $error')),
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          final groups = <String, List<AppNotification>>{};
          for (final item in items) {
            groups.putIfAbsent(_dateGroup(item.createdAt), () => []).add(item);
          }
          return ListView(
            padding: const EdgeInsets.symmetric(vertical: 8),
            children: [
              for (final group in groups.entries) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                  child: Text(
                    group.key,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                for (final item in group.value)
                  _NotificationRow(
                    item: item,
                    onMarkRead: () => _markRead(context, ref, item),
                    onOpen: () => _openSender(context, ref, item),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }

  Future<void> _markRead(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    if (item.read) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(notificationRepositoryProvider).markRead(item.id);
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text('Unable to mark notification as read: $error')),
      );
    }
  }

  Future<void> _openSender(
    BuildContext context,
    WidgetRef ref,
    AppNotification item,
  ) async {
    final navigator = Navigator.of(context);
    await _markRead(context, ref, item);
    navigator.push(
      MaterialPageRoute<void>(
        builder: (_) => ProfilePage(uid: item.fromUid),
      ),
    );
  }

  String _dateGroup(DateTime dateTime) {
    final date = DateUtils.dateOnly(dateTime.toLocal());
    final today = DateUtils.dateOnly(DateTime.now());
    if (date == today) return 'Today';
    if (date == today.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}

class _NotificationRow extends ConsumerWidget {
  const _NotificationRow({
    required this.item,
    required this.onMarkRead,
    required this.onOpen,
  });

  final AppNotification item;
  final VoidCallback onMarkRead;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final senderState = ref.watch(userProfileProvider(item.fromUid));
    return senderState.when(
      loading: () => const ListTile(
        leading: SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        title: Text('Loading notification...'),
      ),
      error: (error, stackTrace) => ListTile(
        leading: const Icon(Icons.error_outline),
        title: const Text('Unable to load notification sender'),
        subtitle: Text('$error'),
      ),
      data: (profile) => _NotificationTile(
        item: item,
        profile: profile,
        onMarkRead: onMarkRead,
        onOpen: onOpen,
      ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({
    required this.item,
    required this.profile,
    required this.onMarkRead,
    required this.onOpen,
  });

  final AppNotification item;
  final UserProfile? profile;
  final VoidCallback onMarkRead;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final senderName = profile?.name ?? 'Former user';
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: profile == null || profile!.photoUrl.isEmpty
            ? null
            : NetworkImage(profile!.photoUrl),
        child: profile == null || profile!.photoUrl.isEmpty
            ? const Icon(Icons.person)
            : null,
      ),
      title: Text(_textForNotification(item.type, senderName)),
      subtitle: Text(
        TimeOfDay.fromDateTime(item.createdAt.toLocal()).format(context),
      ),
      trailing: item.read
          ? null
          : IconButton(
              tooltip: 'Mark as read',
              onPressed: onMarkRead,
              icon: const Icon(Icons.mark_email_read_outlined),
            ),
      tileColor: item.read
          ? null
          : Theme.of(context).colorScheme.secondaryContainer.withOpacity(0.35),
      onTap: onOpen,
    );
  }

  String _textForNotification(NotificationType type, String senderName) {
    switch (type) {
      case NotificationType.follow:
        return '$senderName followed you.';
      case NotificationType.interest:
        return '$senderName is interested in your profile.';
      case NotificationType.batchInvite:
        return '$senderName sent a batch invitation.';
      case NotificationType.teammateInvite:
        return '$senderName invited you to collaborate on a project.';
      case NotificationType.task:
        return '$senderName updated a task.';
      case NotificationType.batchCompleted:
        return '$senderName completed a project batch.';
    }
  }
}
