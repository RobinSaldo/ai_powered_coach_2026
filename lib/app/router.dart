import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:ai_powered_coach_2026/core/providers/firebase_providers.dart';
import 'package:ai_powered_coach_2026/features/auth/presentation/login_page.dart';
import 'package:ai_powered_coach_2026/features/auth/presentation/signup_page.dart';
import 'package:ai_powered_coach_2026/features/dashboard/presentation/dashboard_page.dart';
import 'package:ai_powered_coach_2026/features/onboarding/data/onboarding_local_storage.dart';
import 'package:ai_powered_coach_2026/features/onboarding/presentation/onboarding_page.dart';
import 'package:ai_powered_coach_2026/features/profile/presentation/profile_page.dart';
import 'package:ai_powered_coach_2026/features/progress_tracking/presentation/progress_tracking_page.dart';
import 'package:ai_powered_coach_2026/features/recommendations/presentation/recommendations_page.dart';
import 'package:ai_powered_coach_2026/features/settings/presentation/settings_page.dart';
import 'package:ai_powered_coach_2026/features/speech_analysis/presentation/speech_analysis_result_page.dart';
import 'package:ai_powered_coach_2026/features/speech_recording/presentation/speech_recording_page.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(firebaseAuthProvider);

  return GoRouter(
    initialLocation: '/onboarding',
    refreshListenable: GoRouterRefreshStream(auth.authStateChanges()),
    redirect: (context, state) async {
      final isLoggedIn = auth.currentUser != null;
      final onboardingCompleted = await OnboardingLocalStorage.isCompleted();
      final isOnboardingRoute = state.matchedLocation == '/onboarding';
      final isAuthRoute =
          state.matchedLocation == '/login' ||
          state.matchedLocation == '/signup';

      if (!onboardingCompleted && !isOnboardingRoute) {
        return '/onboarding';
      }

      if (onboardingCompleted && isOnboardingRoute) {
        return isLoggedIn ? '/dashboard' : '/login';
      }

      if (!isLoggedIn && !isAuthRoute && !isOnboardingRoute) {
        return '/login';
      }

      if (isLoggedIn && isAuthRoute) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingPage(),
      ),
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(path: '/signup', builder: (context, state) => const SignupPage()),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/recording',
        builder: (context, state) => const SpeechRecordingPage(),
      ),
      GoRoute(
        path: '/analysis-result',
        builder: (context, state) {
          final extra = state.extra;
          final result = extra is Map<String, dynamic>
              ? extra
              : <String, dynamic>{};
          return SpeechAnalysisResultPage(result: result);
        },
      ),
      GoRoute(
        path: '/progress',
        builder: (context, state) => const ProgressTrackingPage(),
      ),
      GoRoute(
        path: '/recommendations',
        builder: (context, state) => const RecommendationsPage(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfilePage(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => const SettingsPage(),
      ),
    ],
  );
});

class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.asBroadcastStream().listen((_) {
      notifyListeners();
    });
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
