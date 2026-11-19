import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/community_room_repository.dart';
import 'chat_widgets.dart';

class ChatHubPage extends StatelessWidget {
  const ChatHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('แชท'),
            const SizedBox(height: 32),
            ImageCard(
              image: 'assets/images/chat/chat_community.png',
              label: 'แชทชุมชน',
              onTap: () => context.push(AppRoutes.communityRooms),
            ),
            const SizedBox(height: 12),
            ImageCard(
              image: 'assets/images/chat/chat_private.png',
              label: 'แชทส่วนตัว',
              onTap: () => context.push(AppRoutes.privateChats),
            ),
          ],
        ),
      ),
    );
  }
}

class CommunityRoomsPage extends ConsumerWidget {
  const CommunityRoomsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rooms = ref.watch(openCommunityRoomsProvider);

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('แชทชุมชน'),
            const SizedBox(height: 20),
            ...rooms.when(
              loading: () => const [
                Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator()),
                ),
              ],
              error: (e, _) => [Text('โหลดห้องไม่สำเร็จ\n$e')],
              data: (list) => list.isEmpty
                  ? [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 40),
                        child: Text(
                          'ยังไม่มีห้องแชทชุมชน',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 18, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ]
                  : [
                      for (final room in list)
                        RoomCard(
                          room: room,
                          onTap: () => context.push(AppRoutes.chatRoomPath(room.id)),
                        ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}

class RoomCard extends StatelessWidget {
  const RoomCard({super.key, required this.room, required this.onTap});

  final CommunityRoom room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final image = room.image;
    if (room.imageUrl == null && image != null) {
      return ImageCard(image: image, label: room.name, onTap: onTap);
    }
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        children: [
          Material(
            elevation: 4,
            shadowColor: Colors.black26,
            color: AppColors.brown,
            borderRadius: BorderRadius.circular(16),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: AspectRatio(
                aspectRatio: 2,
                child: RoomCover(room: room, iconSize: 80),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(room.name, style: TextStyle(fontSize: 22, color: scheme.onSurface)),
        ],
      ),
    );
  }
}

/// Cover of a community room: uploaded image, then built-in image, then icon.
class RoomCover extends StatelessWidget {
  const RoomCover({super.key, required this.room, this.iconSize = 30});

  final CommunityRoom room;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final icon = ColoredBox(
      color: room.open ? AppColors.brown : AppColors.grey,
      child: Center(child: Icon(roomIconOf(room.icon), size: iconSize, color: Colors.white)),
    );
    final url = room.imageUrl;
    if (url != null) {
      return Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => icon,
        loadingBuilder: (context, child, progress) => progress == null ? child : icon,
      );
    }
    final asset = room.image;
    if (asset != null) {
      return Image.asset(asset, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => icon);
    }
    return icon;
  }
}
