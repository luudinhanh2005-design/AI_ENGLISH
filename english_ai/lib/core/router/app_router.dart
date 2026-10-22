import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/ai_tutor/presentation/screens/ai_tutor_chat_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/learn/presentation/screens/learn_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/placement/presentation/screens/placement_test_screen.dart';
import '../../features/practice/presentation/screens/practice_screen.dart';
import '../../features/profile/presentation/screens/profile_screen.dart';
import '../../features/vocabulary/presentation/screens/flashcard_screen.dart';
import '../../features/vocabulary/presentation/screens/vocabulary_list_screen.dart';
import '../../features/vocabulary/presentation/screens/vocabulary_topics_screen.dart';
import '../../features/practice/presentation/screens/writing_practice_screen.dart';
import '../../features/learn/presentation/screens/listening_screen.dart';
import '../../features/learn/presentation/screens/reading_screen.dart';
import '../../features/learn/presentation/screens/grammar_screen.dart';
import '../../features/pronunciation/presentation/screens/pronunciation_home_screen.dart';
import '../../features/pronunciation/presentation/screens/pronunciation_practice_screen.dart';
import '../../features/ai_tutor/presentation/screens/voice_call_screen.dart';
import '../../features/ai_tutor/presentation/screens/voice_call_summary_screen.dart';
import '../../features/writing/presentation/screens/writing_editor_screen.dart';
import '../../features/writing/presentation/screens/writing_result_screen.dart';
import '../../features/grammar/presentation/screens/grammar_lesson_screen.dart';
import '../../features/practice/presentation/screens/ielts_speaking_mock_screen.dart';
import '../../features/practice/presentation/screens/mistake_notebook_screen.dart';
import '../../features/pronunciation/presentation/screens/shadowing_screen.dart';
import '../../features/profile/presentation/screens/leaderboard_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import 'route_names.dart';

/// GoRouter configuration with authentication-aware redirect logic.
final appRouterProvider = Provider<GoRouter>((ref) {
  final refreshNotifier = ValueNotifier<int>(0);
  ref.onDispose(refreshNotifier.dispose);

  // Re-run redirects when auth state changes without recreating the router.
  ref.listen(authStateProvider, (_, __) {
    refreshNotifier.value++;
  });

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    refreshListenable: refreshNotifier,
    redirect: (context, state) {
      final authState = ref.read(authStateProvider);

      // Keep the current screen while login/register is in progress.
      if (authState.isLoading) return null;

      final user = authState.valueOrNull;
      final isLoggedIn = user != null;
      final isAuthRoute = state.matchedLocation == '/login' ||
          state.matchedLocation == '/register' ||
          state.matchedLocation == '/forgot-password';
      final isSplash = state.matchedLocation == '/splash';

      // If on splash, don't redirect (splash handles its own navigation)
      if (isSplash) return null;

      // Not logged in and not on auth route â†’ go to login
      if (!isLoggedIn && !isAuthRoute) {
        return '/login';
      }

      // Logged in and on auth route â†’ go to home
      if (isLoggedIn && isAuthRoute) {
        return user.hasCompletedOnboarding ? '/' : '/onboarding';
      }

      return null;
    },
    routes: [
      // â”€â”€ Splash â”€â”€
      GoRoute(
        path: '/splash',
        name: RouteNames.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // â”€â”€ Auth Routes â”€â”€
      GoRoute(
        path: '/login',
        name: RouteNames.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        name: RouteNames.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        name: RouteNames.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      // â”€â”€ Onboarding â”€â”€
      GoRoute(
        path: '/onboarding',
        name: RouteNames.onboarding,
        pageBuilder: (context, state) =>
            const NoTransitionPage(child: OnboardingScreen()),
      ),

      // â”€â”€ Phase 2 Learning Routes â”€â”€
      GoRoute(
        path: '/placement',
        name: RouteNames.placementTest,
        builder: (context, state) => const PlacementTestScreen(),
      ),
      GoRoute(
        path: '/vocabulary',
        name: RouteNames.vocabulary,
        builder: (context, state) => const VocabularyTopicsScreen(),
      ),
      GoRoute(
        path: '/vocabulary/review',
        name: RouteNames.vocabularyReview,
        builder: (context, state) => const FlashcardScreen(),
      ),
      GoRoute(
        path: '/vocabulary/list',
        name: RouteNames.vocabularyDetail,
        builder: (context, state) => const VocabularyListScreen(),
      ),
      GoRoute(
        path: '/writing-practice',
        builder: (context, state) => const WritingPracticeScreen(),
      ),
      GoRoute(
        path: '/listening',
        name: RouteNames.listening,
        builder: (context, state) => const ListeningScreen(),
      ),
      GoRoute(
        path: '/reading',
        name: RouteNames.reading,
        builder: (context, state) => const ReadingScreen(),
      ),
      GoRoute(
        path: '/grammar',
        name: RouteNames.grammar,
        builder: (context, state) {
          final lessonId = state.uri.queryParameters['id'];
          return GrammarScreen(initialLessonId: lessonId);
        },
      ),

      // â”€â”€ Main App with Bottom Navigation â”€â”€
      GoRoute(
        path: '/pronunciation',
        builder: (context, state) => const PronunciationHomeScreen(),
      ),
      GoRoute(
        path: '/pronunciation/practice',
        builder: (context, state) => const PronunciationPracticeScreen(),
      ),
      GoRoute(
        path: '/ai-tutor/call',
        builder: (context, state) => VoiceCallScreen(
          persona: state.extra as String? ?? 'sarah',
        ),
      ),
      GoRoute(
        path: '/ai-tutor/call/summary',
        builder: (context, state) => const VoiceCallSummaryScreen(),
      ),
      GoRoute(
        path: '/writing',
        name: RouteNames.writing,
        builder: (context, state) => const WritingEditorScreen(),
      ),
      GoRoute(
        path: '/writing/feedback',
        name: RouteNames.writingFeedback,
        builder: (context, state) => const WritingResultScreen(),
      ),
      GoRoute(
        path: '/grammar/lesson/:id',
        name: RouteNames.grammarLesson,
        builder: (context, state) => GrammarLessonScreen(
          lessonId: state.pathParameters['id'] ?? '',
        ),
      ),
      // ── 4 New Advanced Features ──
      GoRoute(
        path: '/practice/ielts-speaking',
        builder: (context, state) => const IeltsSpeakingMockScreen(),
      ),
      GoRoute(
        path: '/ielts-speaking',
        redirect: (context, state) => '/practice/ielts-speaking',
      ),
      GoRoute(
        path: '/mistake-notebook',
        builder: (context, state) => const MistakeNotebookScreen(),
      ),
      GoRoute(
        path: '/practice/mistakes',
        redirect: (context, state) => '/mistake-notebook',
      ),
      GoRoute(
        path: '/pronunciation/shadowing',
        builder: (context, state) => const ShadowingScreen(),
      ),
      GoRoute(
        path: '/practice/shadowing',
        redirect: (context, state) => '/pronunciation/shadowing',
      ),
      GoRoute(
        path: '/leaderboard',
        builder: (context, state) => const LeaderboardScreen(),
      ),
      GoRoute(
        path: '/home',
        redirect: (context, state) => '/',
      ),

      StatefulShellRoute(
        pageBuilder: (context, state, navigationShell) =>
            NoTransitionPage(child: navigationShell),
        navigatorContainerBuilder: (context, navigationShell, children) {
          return MainScaffold(
            navigationShell: navigationShell,
            children: children,
          );
        },
        branches: [
          // Home Tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: RouteNames.home,
                pageBuilder: (context, state) =>
                    const NoTransitionPage(child: HomeScreen()),
              ),
            ],
          ),

          // Learn Tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/learn',
                name: RouteNames.learn,
                builder: (context, state) => const LearnScreen(),
              ),
            ],
          ),

          // Practice Tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/practice',
                name: RouteNames.practice,
                builder: (context, state) => const PracticeScreen(),
              ),
            ],
          ),

          // AI Tutor Tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ai-tutor',
                name: RouteNames.aiTutor,
                builder: (context, state) => const AiTutorChatScreen(),
              ),
            ],
          ),

          // Profile Tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                name: RouteNames.profile,
                builder: (context, state) => const ProfileScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page not found: ${state.matchedLocation}',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    ),
  );
});

// ---------------------------------------------// Placeholder Screens for tabs (Phase 1)
// ---------------------------------------------
/// Splash screen — checks auth state and navigates accordingly.
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.elasticOut),
    );

    _controller.forward();

    // Navigate after delay
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  Future<void> _checkAuthAndNavigate() async {
    final authState = ref.read(authStateProvider);
    authState.when(
      data: (user) {
        if (user != null) {
          if (user.hasCompletedOnboarding) {
            context.go('/');
          } else {
            context.go('/onboarding');
          }
        } else {
          context.go('/login');
        }
      },
      loading: () {
        // Wait a bit more
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) _checkAuthAndNavigate();
        });
      },
      error: (_, __) {
        context.go('/login');
      },
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              context.palette.background,
              context.palette.surface,
              context.palette.card,
            ],
          ),
        ),
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return Opacity(
                opacity: _fadeAnimation.value,
                child: Transform.scale(
                  scale: _scaleAnimation.value,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Logo icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6C5CE7), Color(0xFF00CEC9)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF6C5CE7).withOpacity(0.4),
                              blurRadius: 30,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          size: 48,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // App name
                      Text(
                        'EnglishAI',
                        style:
                            Theme.of(context).textTheme.headlineLarge?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your AI English Learning Assistant',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: context.palette.textSecondary,
                            ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
