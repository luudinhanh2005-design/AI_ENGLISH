import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/writing_models.dart';
import '../providers/writing_provider.dart';

class WritingEditorScreen extends ConsumerStatefulWidget {
  const WritingEditorScreen({super.key});

  @override
  ConsumerState<WritingEditorScreen> createState() =>
      _WritingEditorScreenState();
}

class _WritingEditorScreenState extends ConsumerState<WritingEditorScreen> {
  late final TextEditingController _textController;

  @override
  void initState() {
    super.initState();
    final currentContent = ref.read(writingProvider).content;
    _textController = TextEditingController(text: currentContent);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final success =
        await ref.read(writingProvider.notifier).submitForEvaluation();
    if (success && mounted) {
      context.push('/writing/result');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(writingProvider);
    final notifier = ref.read(writingProvider.notifier);

    return Scaffold(
      backgroundColor: context.palette.background,
      appBar: AppBar(
        backgroundColor: context.palette.background,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded,
              color: context.palette.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Luyện Viết & Chấm AI',
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh_rounded,
                color: context.palette.textSecondary),
            tooltip: 'Làm bài mới',
            onPressed: () {
              _textController.clear();
              notifier.resetForNewEssay();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Topic Selector Chips ──
            Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: state.prompts.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final prompt = state.prompts[index];
                  final isSelected = state.selectedPrompt?.id == prompt.id;
                  return ChoiceChip(
                    label: Text(
                      prompt.title,
                      style: TextStyle(
                        color: isSelected
                            ? Colors.white
                            : context.palette.textSecondary,
                        fontSize: 12,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: context.palette.card,
                    onSelected: (selected) {
                      if (selected) {
                        notifier.selectPrompt(prompt);
                      }
                    },
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // ── Prompt Details Card ──
            if (state.selectedPrompt != null) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.palette.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              state.selectedPrompt!.category,
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            'Mục tiêu: ${state.selectedPrompt!.targetBand}',
                            style: const TextStyle(
                              color: Color(0xFFFFA502),
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        state.selectedPrompt!.promptDescription,
                        style: TextStyle(
                          color: context.palette.textPrimary,
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                      if (state.selectedPrompt!.sampleOpening != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          'Gợi ý mở đầu: "${state.selectedPrompt!.sampleOpening}"',
                          style: TextStyle(
                            color: context.palette.textSecondary,
                            fontSize: 11,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],

            const SizedBox(height: 10),

            // ── Live Stats Pill Bar ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _StatPill(
                    icon: Icons.notes_rounded,
                    label: '${state.wordCount} từ',
                    color: state.wordCount >= 20
                        ? const Color(0xFF2ED573)
                        : context.palette.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  _StatPill(
                    icon: Icons.timer_outlined,
                    label: state.formattedTimer,
                    color: const Color(0xFF00D2D3),
                  ),
                  const Spacer(),
                  if (state.wordCount < 20)
                    Text(
                      'Cần tối thiểu 20 ký tự',
                      style: TextStyle(
                        color: context.palette.textHint,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Editor TextField ──
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: context.palette.divider),
                  ),
                  child: TextField(
                    controller: _textController,
                    onChanged: (val) => notifier.updateContent(val),
                    maxLines: null,
                    expands: true,
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 15,
                      height: 1.6,
                    ),
                    decoration: InputDecoration(
                      hintText:
                          'Bắt đầu soạn bài viết tiếng Anh của bạn tại đây...\n\nVí dụ: In recent years, technological progress has significantly transformed the way we communicate...',
                      hintStyle: TextStyle(
                        color: context.palette.textHint,
                        fontSize: 14,
                        height: 1.5,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.all(18),
                    ),
                  ),
                ),
              ),
            ),

            if (state.errorMessage != null) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: Text(
                  state.errorMessage!,
                  style: const TextStyle(
                    color: Color(0xFFFF4757),
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],

            // ── Bottom Action Button ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 4,
                  ),
                  onPressed: state.isEvaluating ? null : _submit,
                  icon: state.isEvaluating
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                  label: Text(
                    state.isEvaluating
                        ? 'AI đang chấm điểm & phân tích...'
                        : 'Nộp bài & Chấm điểm AI 🚀',
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _StatPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.palette.divider),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
