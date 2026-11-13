import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../data/chat_repository.dart';

class ImageCard extends StatelessWidget {
  const ImageCard({
    super.key,
    required this.image,
    required this.label,
    required this.onTap,
  });

  final String image;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Material(
            elevation: 4,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AspectRatio(
                aspectRatio: 2,
                child: Image.asset(
                  image,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => ColoredBox(
                    color: scheme.surfaceContainerHighest,
                    child: Icon(Icons.forum_outlined, size: 64, color: scheme.tertiary),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(label, style: TextStyle(fontSize: 22, color: scheme.onSurface)),
        ],
      ),
    );
  }
}

String _two(int n) => n.toString().padLeft(2, '0');

String formatChatTime(DateTime? time) {
  if (time == null) return '';
  final now = DateTime.now();
  final hm = '${_two(time.hour)}:${_two(time.minute)}';
  final sameDay =
      time.year == now.year && time.month == now.month && time.day == now.day;
  return sameDay ? hm : '${time.day}/${time.month} $hm';
}

class MessageBubble extends ConsumerWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.chatType,
    required this.readers,
    this.onSenderTap,
  });

  final ChatMessage message;
  final bool isMine;
  final ChatType chatType;

  final int readers;
  final VoidCallback? onSenderTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final showSender = !isMine && chatType != ChatType.private;

    final bubbleColor = isMine
        ? (isDark ? const Color(0xFF2F5D45) : const Color(0xFFDDF6CC))
        : scheme.surfaceContainerHighest;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.7),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(
              message.text,
              style: TextStyle(fontSize: 20, color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                formatChatTime(message.createdAt ?? DateTime.now()),
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              if (isMine) ...[
                const SizedBox(width: 4),
                _ReadStatus(
                  pending: message.pending,
                  readers: readers,
                  showCount: chatType != ChatType.private,
                ),
              ],
            ],
          ),
        ],
      ),
    );

    if (isMine) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Align(alignment: Alignment.centerRight, child: bubble),
      );
    }

    final senderName = showSender
        ? ref.watch(publicProfileProvider(message.senderId)).value?.nickname ?? '...'
        : null;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSender) ...[
            GestureDetector(
              onTap: onSenderTap,
              child: const ProfileAvatar(size: 44),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (senderName != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      senderName,
                      style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadStatus extends StatelessWidget {
  const _ReadStatus({
    required this.pending,
    required this.readers,
    required this.showCount,
  });

  final bool pending;
  final int readers;
  final bool showCount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (pending) {
      return Icon(Icons.schedule, size: 15, color: scheme.onSurfaceVariant);
    }
    if (readers == 0) {
      return Icon(Icons.done, size: 17, color: scheme.onSurfaceVariant);
    }
    const blue = Color(0xFF2E86DE);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.done_all, size: 17, color: blue),
        if (showCount) ...[
          const SizedBox(width: 2),
          Text('อ่านแล้ว $readers', style: const TextStyle(fontSize: 13, color: blue)),
        ],
      ],
    );
  }
}
