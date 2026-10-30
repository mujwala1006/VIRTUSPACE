import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app_providers.dart';
import '../domain/teammate_suggestion.dart';

class AiChatPage extends ConsumerStatefulWidget {
  const AiChatPage({super.key, required this.uid});

  final String uid;

  @override
  ConsumerState<AiChatPage> createState() => _AiChatPageState();
}

class _AiChatPageState extends ConsumerState<AiChatPage> {
  final _messageController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final message = _messageController.text.trim();
    if (message.isEmpty || message.length > 2000 || _sending) return;
    setState(() => _sending = true);
    try {
      await ref.read(aiRepositoryProvider).sendChatMessage(message);
      _messageController.clear();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to get an answer: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final messages = ref.watch(aiChatMessagesProvider(widget.uid));
    return Scaffold(
      appBar: AppBar(title: const Text('FinderX AI assistant')),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Text(
              'Ask about profiles, skills, projects, and batches. '
              'Messages are processed by OpenAI. Do not share sensitive data.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Unable to load chat history: $error'),
                ),
              ),
              data: (items) => items.isEmpty
                  ? const Center(
                      child: Text('Ask FinderX AI a question to get started.'),
                    )
                  : ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(16),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        return _ChatBubble(
                          message: item,
                          isUser: item.role == 'user',
                        );
                      },
                    ),
            ),
          ),
          if (_sending)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LinearProgressIndicator(),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask about FinderX...',
                        border: OutlineInputBorder(),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sending ? null : _send,
                    tooltip: 'Send message',
                    icon: _sending
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message, required this.isUser});

  final AiChatMessage message;
  final bool isUser;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 320),
        margin: const EdgeInsets.symmetric(vertical: 5),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isUser ? colors.primaryContainer : colors.surfaceVariant,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.content),
      ),
    );
  }
}
