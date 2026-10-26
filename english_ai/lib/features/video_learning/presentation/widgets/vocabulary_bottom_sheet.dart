import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
import '../../data/models/subtitle_line.dart';
import '../../data/models/video_lesson.dart';

class VocabularyBottomSheet extends StatefulWidget {
  final SubtitleLine subtitle;
  final VideoLesson lesson;

  const VocabularyBottomSheet({
    super.key,
    required this.subtitle,
    required this.lesson,
  });

  static Future<void> show(
    BuildContext context, {
    required SubtitleLine subtitle,
    required VideoLesson lesson,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VocabularyBottomSheet(
        subtitle: subtitle,
        lesson: lesson,
      ),
    );
  }

  @override
  State<VocabularyBottomSheet> createState() => _VocabularyBottomSheetState();
}

class _VocabularyBottomSheetState extends State<VocabularyBottomSheet> {
  bool _isPlayingAudio = false;

  Future<void> _playAudio() async {
    if (_isPlayingAudio) return;
    setState(() => _isPlayingAudio = true);
    try {
      await SpeechService.speak(widget.subtitle.englishText, rate: 0.85);
    } catch (_) {}
    if (mounted) {
      setState(() => _isPlayingAudio = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sub = widget.subtitle;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 25,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: isDark ? Colors.white24 : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.subtitles_rounded,
                          size: 15, color: AppColors.primary),
                      const SizedBox(width: 5),
                      Text(
                        'Chi Tiết Câu Thoại',
                        style: AppTextStyles.labelMedium.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  splashRadius: 20,
                ),
              ],
            ),
          ),

          const Divider(height: 16),

          // Scrollable content
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // English sentence card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: isDark
                            ? [const Color(0xFF2A2B3A), const Color(0xFF212230)]
                            : [const Color(0xFFF0F4FF), const Color(0xFFE8EFFF)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                sub.englishText,
                                style: AppTextStyles.h4.copyWith(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF1E293B),
                                  fontWeight: FontWeight.bold,
                                  height: 1.35,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                            InkWell(
                              onTap: _playAudio,
                              borderRadius: BorderRadius.circular(25),
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.primary.withOpacity(0.4),
                                      blurRadius: 8,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                                ),
                                child: Icon(
                                  _isPlayingAudio
                                      ? Icons.volume_up_rounded
                                      : Icons.play_arrow_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                          ],
                        ),
                        if (sub.ipa != null && sub.ipa!.isNotEmpty) ...[
                          const SizedBox(height: 8),
                          Text(
                            sub.ipa!,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.black.withOpacity(0.25)
                                : Colors.white.withOpacity(0.8),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('🇻🇳 ', style: TextStyle(fontSize: 16)),
                              Expanded(
                                child: Text(
                                  sub.vietnameseText,
                                  style: AppTextStyles.bodyMedium.copyWith(
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF334155),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Key Vocabulary Section
                  if (sub.vocabulary.isNotEmpty) ...[
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        const Icon(Icons.auto_stories_rounded,
                            size: 18, color: AppColors.secondary),
                        const SizedBox(width: 8),
                        Text(
                          'Từ vựng trọng tâm trong câu',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    ...sub.vocabulary.map((vocab) => _buildVocabCard(vocab, isDark)),
                  ],

                  // Grammar & Usage Notes
                  if (sub.grammarNotes.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_rounded,
                            size: 18, color: AppColors.accent),
                        const SizedBox(width: 8),
                        Text(
                          'Ngữ pháp & Cách dùng thực tế',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.accent.withOpacity(0.25),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: sub.grammarNotes.map((note) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('💡 ', style: TextStyle(fontSize: 14)),
                                Expanded(
                                  child: Text(
                                    note,
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],

                  const SizedBox(height: 26),

                  // Action Button: Luyện phản xạ câu này
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pop(context);
                        context.push(
                          '/video-learning/reflex',
                          extra: {
                            'lesson': widget.lesson,
                            'initialSubtitleId': sub.id,
                          },
                        );
                      },
                      icon: const Icon(Icons.record_voice_over_rounded,
                          color: Colors.white),
                      label: Text(
                        'Luyện Phản Xạ Câu Này (Bước 2)',
                        style: AppTextStyles.titleSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.speaking,
                        elevation: 4,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVocabCard(SubtitleVocabItem vocab, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF252636) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                vocab.word,
                style: AppTextStyles.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  vocab.partOfSpeech,
                  style: AppTextStyles.labelSmall.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                vocab.ipa,
                style: AppTextStyles.bodySmall.copyWith(
                  color: Colors.grey,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, size: 20),
                color: AppColors.primary,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: () => SpeechService.speak(vocab.word),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            vocab.meaningVi,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (vocab.exampleSentence.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Ví dụ: "${vocab.exampleSentence}"',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
