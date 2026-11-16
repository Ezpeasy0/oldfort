import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../friends/data/friend_repository.dart';
import '../../friends/presentation/friend_widgets.dart';
import '../data/chat_repository.dart';
import 'chat_media.dart';

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

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isVisual = message.isImage || message.isVideo;
    final Widget content = message.isImage
        ? _ChatImage(message: message, width: screenWidth * 0.6)
        : message.isVideo
            ? VideoMessageContent(message: message, width: screenWidth * 0.6)
            : message.isAudio
                ? AudioMessageContent(key: ValueKey(message.id), message: message)
                : Align(
            alignment: Alignment.centerLeft,
            widthFactor: 1,
            child: Text(
              message.text,
              style: TextStyle(fontSize: 20, color: scheme.onSurface),
            ),
          );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: screenWidth * 0.7),
      padding: isVisual
          ? const EdgeInsets.fromLTRB(6, 6, 10, 6)
          : const EdgeInsets.fromLTRB(14, 10, 14, 6),
      decoration: BoxDecoration(
        color: bubbleColor,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          content,
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
              child: UserAvatar(uid: message.senderId, size: 44),
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

class _ChatImage extends StatelessWidget {
  const _ChatImage({required this.message, required this.width});

  final ChatMessage message;
  final double width;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final w = message.width ?? 4;
    final h = message.height ?? 3;
    final ratio = (w / h).clamp(0.6, 1.8);
    final url = message.mediaUrl!;

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => ImageViewerPage(url: url)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: ratio,
            child: Image.network(
              url,
              fit: BoxFit.cover,
              loadingBuilder: (context, child, progress) => progress == null
                  ? child
                  : ColoredBox(
                      color: scheme.surfaceContainerHigh,
                      child: const Center(child: CircularProgressIndicator()),
                    ),
              errorBuilder: (context, error, stackTrace) => ColoredBox(
                color: scheme.surfaceContainerHigh,
                child: Icon(Icons.broken_image_outlined,
                    size: 48, color: scheme.onSurfaceVariant),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ImageViewerPage extends StatelessWidget {
  const ImageViewerPage({super.key, required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              child: InteractiveViewer(
                maxScale: 5,
                child: Center(
                  child: Image.network(
                    url,
                    fit: BoxFit.contain,
                    loadingBuilder: (context, child, progress) => progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator()),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton.filled(
                style: IconButton.styleFrom(backgroundColor: Colors.black54),
                iconSize: 32,
                tooltip: 'ปิด',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
