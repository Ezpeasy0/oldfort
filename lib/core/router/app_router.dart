// lib/core/router/app_router.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/auth/presentation/pdpa_page.dart';
import '../../features/auth/presentation/register_info_page.dart';
import '../../features/auth/presentation/splash_page.dart';
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
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});