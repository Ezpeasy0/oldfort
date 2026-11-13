import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/app_router.dart';
import '../../../core/widgets/app_widgets.dart';
import '../data/chat_repository.dart';
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

class CommunityRoomsPage extends StatelessWidget {
  const CommunityRoomsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          children: [
            const BackTextButton(),
            const PageTitle('แชทชุมชน'),
            const SizedBox(height: 20),
            for (final room in communityRooms)
              ImageCard(
                image: room.image,
                label: room.name,
                onTap: () => context.push(AppRoutes.chatRoomPath(room.id)),
              ),
          ],
        ),
      ),
    );
  }
}