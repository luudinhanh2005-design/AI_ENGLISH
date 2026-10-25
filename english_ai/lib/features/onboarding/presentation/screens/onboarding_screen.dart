import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_dimensions.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  int _currentPage = 0;
  bool _isLoading = false;

  // Selections
  String? _selectedGoal;
  int _selectedMinutes = 20;
  final Set<String> _selectedTopics = {};

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _canProceed {
    switch (_currentPage) {
      case 0:
        return _selectedGoal != null;
      case 1:
        return true; // Minutes always has a selection
      case 2:
        return _selectedTopics.isNotEmpty;
      default:
        return false;
    }
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: AppDimensions.animNormal,
        curve: Curves.easeInOutCubic,
      );
    } else {
      _submitOnboarding();
    }
  }

  Future<void> _submitOnboarding() async {
    setState(() => _isLoading = true);

    try {
      await ref.read(authStateProvider.notifier).saveOnboarding(
            learningGoal: _selectedGoal!,
            dailyMinutes: _selectedMinutes,
            topics: _selectedTopics.toList(),
          );

      if (mounted) {
        // Navigate to placement test after onboarding
        context.go('/placement');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.palette.background,
              context.palette.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Top bar with progress
              Padding(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: Row(
                  children: [
                    if (_currentPage > 0)
                      IconButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: AppDimensions.animNormal,
                            curve: Curves.easeInOutCubic,
                          );
                        },
                        icon: Icon(
                          Icons.arrow_back_ios_rounded,
                          color: context.palette.textPrimary,
                          size: 20,
                        ),
                      )
                    else
                      const SizedBox(width: 48),
                    const Spacer(),
                    SmoothPageIndicator(
                      controller: _pageController,
                      count: 3,
                      effect: ExpandingDotsEffect(
                        dotWidth: 8,
                        dotHeight: 8,
                        expansionFactor: 3,
                        spacing: 6,
                        dotColor: context.palette.divider,
                        activeDotColor: AppColors.primary,
                      ),
                    ),
                    const Spacer(),
                    TextButton(
                      onPressed: () => context.go('/'),
                      child: Text(
                        'Skip',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: context.palette.textHint,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Pages
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (page) {
                    setState(() => _currentPage = page);
                  },
                  children: [
                    _GoalPage(
                      selectedGoal: _selectedGoal,
                      onSelected: (goal) {
                        setState(() => _selectedGoal = goal);
                      },
                    ),
                    _TimePage(
                      selectedMinutes: _selectedMinutes,
                      onSelected: (minutes) {
                        setState(() => _selectedMinutes = minutes);
                      },
                    ),
                    _TopicPage(
                      selectedTopics: _selectedTopics,
                      onToggle: (topic) {
                        setState(() {
                          if (_selectedTopics.contains(topic)) {
                            _selectedTopics.remove(topic);
                          } else {
                            _selectedTopics.add(topic);
                          }
                        });
                      },
                    ),
                  ],
                ),
              ),

              // Bottom button
              Padding(
                padding: const EdgeInsets.all(AppDimensions.screenPaddingH),
                child: AppButton(
                  text: _currentPage == 2 ? 'Get Started' : 'Continue',
                  isLoading: _isLoading,
                  onPressed: _canProceed ? _nextPage : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------// Step 1: Learning Goal
// ---------------------------------------------
class _GoalPage extends StatelessWidget {
  final String? selectedGoal;
  final ValueChanged<String> onSelected;

  const _GoalPage({
    required this.selectedGoal,
    required this.onSelected,
  });

  static const _goalIcons = {
    'Giao tiếp': Icons.chat_bubble_outline_rounded,
    'Công việc': Icons.business_center_outlined,
    'Phỏng vấn': Icons.record_voice_over_outlined,
    'TOEIC': Icons.assessment_outlined,
    'IELTS': Icons.school_outlined,
    'Du lịch': Icons.flight_outlined,
    'Khác': Icons.more_horiz_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'Why do you want to\nlearn English?',
            style: AppTextStyles.h1.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'This helps us personalize your learning path',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: AppConstants.learningGoals.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final goal = AppConstants.learningGoals[index];
                final isSelected = selectedGoal == goal;
                final icon = _goalIcons[goal] ?? Icons.star_outline_rounded;

                return _SelectionTile(
                  icon: icon,
                  text: goal,
                  isSelected: isSelected,
                  onTap: () => onSelected(goal),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------// Step 2: Daily Time
// ---------------------------------------------
class _TimePage extends StatelessWidget {
  final int selectedMinutes;
  final ValueChanged<int> onSelected;

  const _TimePage({
    required this.selectedMinutes,
    required this.onSelected,
  });

  static const _timeDescriptions = {
    10: 'Quick learner — 10 min/day',
    20: 'Regular pace — 20 min/day',
    30: 'Committed — 30 min/day',
    60: 'Intensive — 60 min/day',
  };

  static const _timeIcons = {
    10: Icons.bolt_rounded,
    20: Icons.timer_outlined,
    30: Icons.trending_up_rounded,
    60: Icons.rocket_launch_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'How much time can you\nstudy each day?',
            style: AppTextStyles.h1.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'We\'ll create a daily plan that fits your schedule',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: ListView.separated(
              itemCount: AppConstants.dailyMinutesOptions.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final minutes = AppConstants.dailyMinutesOptions[index];
                final isSelected = selectedMinutes == minutes;

                return _SelectionTile(
                  icon: _timeIcons[minutes] ?? Icons.timer_outlined,
                  text: '$minutes minutes per day',
                  subtitle: _timeDescriptions[minutes],
                  isSelected: isSelected,
                  onTap: () => onSelected(minutes),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------// Step 3: Topics
// ---------------------------------------------
class _TopicPage extends StatelessWidget {
  final Set<String> selectedTopics;
  final ValueChanged<String> onToggle;

  const _TopicPage({
    required this.selectedTopics,
    required this.onToggle,
  });

  static const _topicIcons = {
    'Technology': Icons.computer_rounded,
    'Business': Icons.business_rounded,
    'Travel': Icons.flight_rounded,
    'Daily Life': Icons.wb_sunny_rounded,
    'Food': Icons.restaurant_rounded,
    'Education': Icons.school_rounded,
    'Entertainment': Icons.movie_rounded,
    'Science': Icons.science_rounded,
  };

  static const _topicColors = [
    Color(0xFFFF6B6B),
    Color(0xFF6C5CE7),
    Color(0xFF00CEC9),
    Color(0xFFFFA502),
    Color(0xFF2ED573),
    Color(0xFF3742FA),
    Color(0xFFFF4757),
    Color(0xFF1E90FF),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.screenPaddingH,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 24),
          Text(
            'What topics interest you?',
            style: AppTextStyles.h1.copyWith(
              color: context.palette.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Select all that apply — we\'ll customize your content',
            style: AppTextStyles.bodyMedium.copyWith(
              color: context.palette.textSecondary,
            ),
          ),
          const SizedBox(height: 32),
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.6,
              ),
              itemCount: AppConstants.topics.length,
              itemBuilder: (context, index) {
                final topic = AppConstants.topics[index];
                final isSelected = selectedTopics.contains(topic);
                final color = _topicColors[index % _topicColors.length];
                final icon = _topicIcons[topic] ?? Icons.category_rounded;

                return GestureDetector(
                  onTap: () => onToggle(topic),
                  child: AnimatedContainer(
                    duration: AppDimensions.animFast,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? color.withOpacity(0.15)
                          : context.palette.card,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusLg,
                      ),
                      border: Border.all(
                        color: isSelected ? color : context.palette.divider,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icon,
                          color: isSelected ? color : context.palette.textHint,
                          size: 28,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          topic,
                          style: AppTextStyles.labelMedium.copyWith(
                            color: isSelected
                                ? color
                                : context.palette.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------// Shared Selection Tile
// ---------------------------------------------
class _SelectionTile extends StatelessWidget {
  final IconData icon;
  final String text;
  final String? subtitle;
  final bool isSelected;
  final VoidCallback onTap;

  const _SelectionTile({
    required this.icon,
    required this.text,
    this.subtitle,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDimensions.animFast,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.1)
              : context.palette.card,
          borderRadius: BorderRadius.circular(AppDimensions.radiusMd),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.palette.divider,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.2)
                    : context.palette.cardLight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color:
                    isSelected ? AppColors.primary : context.palette.textHint,
                size: 22,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    text,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isSelected
                          ? AppColors.primary
                          : context.palette.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: context.palette.textHint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedContainer(
              duration: AppDimensions.animFast,
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color:
                      isSelected ? AppColors.primary : context.palette.divider,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(
                      Icons.check_rounded,
                      size: 16,
                      color: Colors.white,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
