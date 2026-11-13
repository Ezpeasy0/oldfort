import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/auth/presentation/pdpa_page.dart';
import '../../features/auth/presentation/register_info_page.dart';
import '../../features/auth/presentation/splash_page.dart';
import '../../features/chat/presentation/chat_hub_page.dart';
import '../../features/chat/presentation/chat_room_page.dart';
import '../../features/chat/presentation/group_settings_page.dart';
import '../../features/chat/presentation/private_chats_page.dart';
import '../../features/friends/presentation/friends_page.dart';
import '../../features/friends/presentation/user_profile_page.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/settings/presentation/change_phone_page.dart';
import '../../features/settings/presentation/display_settings_page.dart';
import '../../features/settings/presentation/profile_page.dart';
import '../../features/settings/presentation/settings_page.dart';
import '../session/session_controller.dart';

class AppRoutes {
  AppRoutes._();

  static const splash = '/splash';
  static const login = '/login';
  static const otp = '/otp';
  static const registerInfo = '/register-info';
  static const pdpa = '/pdpa';
  static const home = '/home';
  static const settings = '/settings';
  static const profile = '/settings/profile';
  static const changePhone = '/settings/profile/phone';
  static const display = '/settings/display';
  static const friends = '/friends';
  static const userProfile = '/user/:uid';
  static const chat = '/chat';
  static const communityRooms = '/chat/community';
  static const privateChats = '/chat/private';
  static const createGroup = '/chat/private/new-group';
  static const chatRoom = '/chat/room/:chatId';
  static const groupSettings = '/chat/room/:chatId/settings';

  static String userProfilePath(String uid) => '/user/$uid';
  static String chatRoomPath(String chatId) => '/chat/room/$chatId';
  static String groupSettingsPath(String chatId) => '/chat/room/$chatId/settings';
}

class OtpArgs {
  const OtpArgs({
    required this.phoneNumber,
    required this.verificationId,
    this.resendToken,
  });

  final String phoneNumber; // 0812345678
  final String verificationId;
  final int? resendToken;
}

class RegisterDraft {
  const RegisterDraft({
    required this.firstName,
    required this.lastName,
    required this.nickname,
  });

  final String firstName;
  final String lastName;
  final String nickname;
}

const _authFlow = {AppRoutes.login, AppRoutes.otp};
const _onboarding = {AppRoutes.registerInfo, AppRoutes.pdpa};

final routerProvider = Provider<GoRouter>((ref) {
  final session = ref.watch(sessionProvider);

  final router = GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: session,
    redirect: (context, state) {
      final location = state.matchedLocation;
      return switch (session.status) {
        SessionStatus.loading || SessionStatus.error =>
          location == AppRoutes.splash ? null : AppRoutes.splash,
        SessionStatus.signedOut =>
          _authFlow.contains(location) ? null : AppRoutes.login,
        SessionStatus.needsProfile =>
          _onboarding.contains(location) ? null : AppRoutes.registerInfo,
        SessionStatus.ready => (location == AppRoutes.splash ||
                _authFlow.contains(location) ||
                _onboarding.contains(location))
            ? AppRoutes.home
            : null,
      };
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: AppRoutes.otp,
        builder: (context, state) {
          final args = state.extra as OtpArgs?;
          if (args == null) return const LoginPage();
          return OtpPage(args: args);
        },
      ),
      GoRoute(
        path: AppRoutes.registerInfo,
        builder: (context, state) => const RegisterInfoPage(),
      ),
      GoRoute(
        path: AppRoutes.pdpa,
        builder: (context, state) {
          final draft = state.extra as RegisterDraft?;
          if (draft == null) return const RegisterInfoPage();
          return PdpaPage(draft: draft);
        },
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
      GoRoute(
        path: AppRoutes.settings,
        builder: (context, state) => const SettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: AppRoutes.changePhone,
        builder: (context, state) => const ChangePhonePage(),
      ),
      GoRoute(
        path: AppRoutes.display,
        builder: (context, state) => const DisplaySettingsPage(),
      ),
      GoRoute(
        path: AppRoutes.friends,
        builder: (context, state) => const FriendsPage(),
      ),
      GoRoute(
        path: AppRoutes.userProfile,
        builder: (context, state) =>
            UserProfilePage(uid: state.pathParameters['uid']!),
      ),
      GoRoute(
        path: AppRoutes.chat,
        builder: (context, state) => const ChatHubPage(),
      ),
      GoRoute(
        path: AppRoutes.communityRooms,
        builder: (context, state) => const CommunityRoomsPage(),
      ),
      GoRoute(
        path: AppRoutes.privateChats,
        builder: (context, state) => const PrivateChatsPage(),
      ),
      GoRoute(
        path: AppRoutes.createGroup,
        builder: (context, state) => const CreateGroupPage(),
      ),
      GoRoute(
        path: AppRoutes.chatRoom,
        builder: (context, state) =>
            ChatRoomPage(chatId: state.pathParameters['chatId']!),
      ),
      GoRoute(
        path: AppRoutes.groupSettings,
        builder: (context, state) =>
            GroupSettingsPage(chatId: state.pathParameters['chatId']!),
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});