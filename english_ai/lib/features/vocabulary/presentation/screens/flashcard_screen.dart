import 'package:flutter/services.dart';
import '../../../../core/utils/speech_service.dart';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_button.dart';
import '../providers/vocabulary_provider.dart';

class FlashcardScreen extends ConsumerStatefulWidget {
  const FlashcardScreen({super.key});

  @override
  ConsumerState<FlashcardScreen> createState() => _FlashcardScreenState();
}

class _FlashcardScreenState extends ConsumerState<FlashcardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  void _flipCard(bool isCurrentlyFlipped) {
    if (isCurrentlyFlipped) {
      _animController.reverse();
    } else {
      _animController.forward();
    }
    ref.read(flashcardSessionProvider.notifier).flipCard();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(flashcardSessionProvider);
    final notifier = ref.read(flashcardSessionProvider.notifier);

    if (state.isLoading && state.cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryDark),
            tooltip: 'Thoát',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/vocabulary');
              }
            },
          ),
        ),
        body: const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    if (state.errorMessage != null && state.cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryDark),
            tooltip: 'Thoát',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/vocabulary');
              }
            },
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, color: AppColors.error, size: 48),
                const SizedBox(height: 16),
                Text(
                  state.errorMessage!,
                  style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimaryDark),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                AppButton(
                  text: 'Tải lại',
                  onPressed: () => notifier.loadDueWords(),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // ── Session Finished Screen ──
    if (state.isSessionFinished || state.cards.isEmpty) {
      return Scaffold(
        backgroundColor: AppColors.backgroundDark,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimaryDark),
            tooltip: 'Thoát',
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/vocabulary');
              }
            },
          ),
        ),
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.success.withOpacity(0.15),
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                    child: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 54),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Hoàn thành phiên ôn tập!',
                    style: AppTextStyles.headlineSmall.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Bạn đã hoàn thành củng cố từ vựng vào trí nhớ dài hạn với thuật toán SM-2.',
                    style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondaryDark),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      OutlinedButton(
                        onPressed: () => notifier.loadDueWords(),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(color: AppColors.primary),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                        ),
                        child: const Text('Ôn tập lại', style: TextStyle(color: AppColors.primary)),
                      ),
                      const SizedBox(width: 14),
                      ElevatedButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/vocabulary');
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                        ),
                        child: const Text('Thoát', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    final totalCards = state.cards.length;
    final currentCard = state.cards[state.currentIndex];
    final word = currentCard.word;

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textSecondaryDark),
          tooltip: 'Thoát',
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/vocabulary');
            }
          },
        ),
        title: Text(
          'Thẻ Flashcard ${state.currentIndex + 1}/$totalCards',
          style: AppTextStyles.titleMedium.copyWith(color: AppColors.textPrimaryDark),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
          child: Column(
            children: [
              // Progress Bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: (state.currentIndex + 1) / totalCards,
                  backgroundColor: AppColors.surfaceLightDark,
                  valueColor: const AlwaysStoppedAnimation<Color>(AppColors.primary),
                  minHeight: 6,
                ),
              ),

              const SizedBox(height: 24),

              // ── 3D Flipping Card ──
              Expanded(
                child: GestureDetector(
                  onTap: () => _flipCard(state.isFlipped),
                  child: AnimatedBuilder(
                    animation: _animation,
                    builder: (context, child) {
                      final angle = _animation.value * pi;
                      final isUnder = angle > (pi / 2);

                      return Transform(
                        transform: Matrix4.identity()
                          ..setEntry(3, 2, 0.001)
                          ..rotateY(angle),
                        alignment: Alignment.center,
                        child: isUnder
                            ? Transform(
                                transform: Matrix4.identity()..rotateY(pi),
                                alignment: Alignment.center,
                                child: _buildCardBack(word),
                              )
                            : _buildCardFront(word),
                      );
                    },
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // ── Rating Buttons (Only show when flipped or always available) ──
              if (state.isFlipped) ...[
                Text(
                  'Bạn nhớ từ này như thế nào?',
                  style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondaryDark),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildRatingButton(
                        text: 'Khó',
                        subtitle: '+1 ngày',
                        color: AppColors.warning,
                        onTap: () {
                          _animController.reset();
                          notifier.submitRating(3);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRatingButton(
                        text: 'Tốt',
                        subtitle: '+6 ngày',
                        color: AppColors.secondary,
                        onTap: () {
                          _animController.reset();
                          notifier.submitRating(4);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _buildRatingButton(
                        text: 'Dễ',
                        subtitle: '+14 ngày',
                        color: AppColors.success,
                        onTap: () {
                          _animController.reset();
                          notifier.submitRating(5);
                        },
                      ),
                    ),
                  ],
                ),
              ] else ...[
                Text(
                  '👆 Chạm vào thẻ để lật xem đáp án & ví dụ',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                ),
              ],
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCardFront(dynamic word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.borderDark),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              word.partOfSpeech.toUpperCase(),
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            word.word,
            style: AppTextStyles.displaySmall.copyWith(
              color: AppColors.textPrimaryDark,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            word.phonetic,
            style: AppTextStyles.titleMedium.copyWith(
              color: AppColors.secondary,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 36),
          GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              SpeechService.speak(word.word as String);
            },
            child: Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.surfaceLightDark,
              ),
              child: const Icon(Icons.volume_up_rounded, color: AppColors.primary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCardBack(dynamic word) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surfaceDark,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.primary.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                word.meaningVi,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 8),
            Center(
              child: Text(
                word.meaningEn,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondaryDark,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const Divider(color: AppColors.borderDark, height: 32),
            Text(
              'Ví dụ trong câu:',
              style: AppTextStyles.labelMedium.copyWith(
                color: AppColors.textSecondaryDark,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surfaceLightDark.withOpacity(0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    word.exampleSentence,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    word.exampleTranslation,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRatingButton({
    required String text,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.5)),
        ),
        child: Column(
          children: [
            Text(
              text,
              style: AppTextStyles.titleSmall.copyWith(
                color: color,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: AppTextStyles.labelSmall.copyWith(color: color.withOpacity(0.8)),
            ),
          ],
        ),
      ),
    );
  }
}
