import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/ai_tutor/presentation/screens/ai_tutor_chat_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/home/presentation/screens/home_screen.dart';
import '../../features/onboarding/presentation/screens/onboarding_screen.dart';
import '../../features/placement/presentation/screens/placement_test_screen.dart';
import '../../features/vocabulary/presentation/screens/flashcard_screen.dart';
import '../../features/vocabulary/presentation/screens/vocabulary_topics_screen.dart';
import '../../shared/widgets/main_scaffold.dart';
import 'route_names.dart';

/// GoRouter configuration with authentication-aware redirect logic.
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authStateProvider);

  return GoRouter(
    initialLocation: '/splash',
    debugLogDiagnostics: true,
    redirect: (context, state) {
      final isLoggedIn = authState.valueOrNull != null;
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
        return '/';
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
        builder: (context, state) => const OnboardingScreen(),
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

      // â”€â”€ Main App with Bottom Navigation â”€â”€
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainScaffold(navigationShell: navigationShell);
        },
        branches: [
          // Home Tab
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                name: RouteNames.home,
                builder: (context, state) => const HomeScreen(),
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
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF0F0F23),
              Color(0xFF1A1A2E),
              Color(0xFF16213E),
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
                        style: Theme.of(context)
                            .textTheme
                            .headlineLarge
                            ?.copyWith(
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your AI English Learning Assistant',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: const Color(0xFFB0B0C8),
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

// Placeholder screens for tabs that will be built in later phases
class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.menu_book_rounded,
      title: 'Learn',
      subtitle: 'Vocabulary, Grammar, Listening, Reading',
    );
  }
}

class PracticeScreen extends StatelessWidget {
  const PracticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.sports_esports_rounded,
      title: 'Practice',
      subtitle: 'Speaking, Pronunciation, Writing',
    );
  }
}

class AiTutorScreen extends StatelessWidget {
  const AiTutorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.smart_toy_rounded,
      title: 'AI Tutor',
      subtitle: 'Ask anything about English',
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _PlaceholderTab(
      icon: Icons.person_rounded,
      title: 'Profile',
      subtitle: 'Progress, Achievements, Settings',
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _PlaceholderTab({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: const Color(0xFF6C5CE7).withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              decoration: BoxDecoration(
                color: const Color(0xFF6C5CE7).withOpacity(0.1),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: const Color(0xFF6C5CE7).withOpacity(0.3),
                ),
              ),
              child: Text(
                'Coming in Phase 2+',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: const Color(0xFF6C5CE7),
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
