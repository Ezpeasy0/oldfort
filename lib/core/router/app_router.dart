import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/login_page.dart';
import '../../features/auth/presentation/otp_page.dart';
import '../../features/auth/presentation/register_info_page.dart';
import '../../features/home/presentation/home_page.dart';

class AppRoutes {
  AppRoutes._();

  static const login = '/login';
  static const otp = '/otp';
  static const registerInfo = '/register-info';
  static const home = '/home';
}

class OtpArgs {
  const OtpArgs({
    required this.phoneNumber,
    required this.verificationId,
    required this.isRegister,
    this.resendToken,
  });

  final String phoneNumber; 
  final String verificationId;
  final bool isRegister; 
  final int? resendToken;
}

class _AuthRefresh extends ChangeNotifier {
  _AuthRefresh(Stream<User?> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<User?> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = FirebaseAuth.instance;
  final refresh = _AuthRefresh(auth.authStateChanges());
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: AppRoutes.login,
    refreshListenable: refresh,
    redirect: (context, state) {
      final signedIn = auth.currentUser != null;
      final location = state.matchedLocation;
      final onAuthFlow =
          location == AppRoutes.login || location == AppRoutes.otp;

      if (!signedIn) return onAuthFlow ? null : AppRoutes.login;
      if (location == AppRoutes.login) return AppRoutes.home;
      return null; 
    },
    routes: [
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
        path: AppRoutes.home,
        builder: (context, state) => const HomePage(),
      ),
    ],
  );
});