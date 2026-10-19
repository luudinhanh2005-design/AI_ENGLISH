import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/writing_models.dart';
import '../providers/writing_provider.dart';

class WritingResultScreen extends ConsumerStatefulWidget {
  const WritingResultScreen({super.key});

  @override
  ConsumerState<WritingResultScreen> createState() =>
      _WritingResultScreenState();
}

class _WritingResultScreenState extends ConsumerState<WritingResultScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Color _getScoreColor(double score) {
    if (score >= 80) return const Color(0xFF2ED573);
    if (score >= 65) return const Color(0xFFFFA502);
    return const Color(0xFFFF4757);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(writingProvider);
    final result = state.result;

    if (result == null) {
      return Scaffold(
        backgroundColor: context.palette.background,
        appBar: AppBar(
          backgroundColor: context.palette.background,
          elevation: 0,
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Chưa có kết quả bài viết',
                  style: TextStyle(color: context.palette.textPrimary)),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: const Text('Quay lại soạn bài'),
              ),
            ],
          ),
        ),
      );
    }

    final scoreColor = _getScoreColor(result.overallScore);

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
          'Kết Quả Chấm Bài AI',
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Hero Score Card ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      context.palette.cardLight,
                      context.palette.card,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(color: scoreColor.withOpacity(0.3)),
                  boxShadow: [
                    BoxShadow(
                      color: scoreColor.withOpacity(0.12),
                      blurRadius: 18,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Score Circle
                    Container(
                      width: 76,
                      height: 76,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: scoreColor.withOpacity(0.15),
                        border: Border.all(color: scoreColor, width: 3),
                      ),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              result.overallScore.round().toString(),
                              style: TextStyle(
                                color: scoreColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                            Text(
                              '/100',
                              style: TextStyle(
                                color: scoreColor.withOpacity(0.8),
                                fontSize: 10,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            result.scoreGrade,
                            style: AppTextStyles.titleMedium.copyWith(
                              color: context.palette.textPrimary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            result.topic,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              _Badge(
                                label: 'CEFR ${result.cefrLevel}',
                                color: AppColors.primary,
                              ),
                              const SizedBox(width: 6),
                              _Badge(
                                label: 'IELTS ${result.ieltsEquivalent}',
                                color: const Color(0xFFFFA502),
                              ),
                              const SizedBox(width: 6),
                              _Badge(
                                label: '+25 XP',
                                color: const Color(0xFF2ED573),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab Bar ──
            TabBar(
              controller: _tabController,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              labelColor: context.palette.textPrimary,
              unselectedLabelColor: context.palette.textHint,
              labelStyle:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
              tabs: const [
                Tab(text: 'Nhận xét & Ngữ pháp'),
                Tab(text: 'Nâng cấp từ vựng'),
                Tab(text: 'Bài viết hoàn thiện'),
              ],
            ),

            // ── Tab Bar Views ──
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _buildGrammarAndFeedbackTab(result),
                  _buildVocabTab(result),
                  _buildRewriteTab(result),
                ],
              ),
            ),

            // ── Bottom Action ──
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.palette.textPrimary,
                        side: BorderSide(color: context.palette.divider),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.edit_note_rounded),
                      label: const Text('Viết bài mới'),
                      onPressed: () {
                        ref.read(writingProvider.notifier).resetForNewEssay();
                        context.pop();
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.home_rounded),
                      label: const Text('Về trang chủ'),
                      onPressed: () => context.go('/home'),
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

  Widget _buildGrammarAndFeedbackTab(WritingEvaluationResultModel result) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // General comment
        Container(
          padding: const EdgeInsets.all(16),
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
                  Icon(Icons.psychology_rounded,
                      color: Color(0xFFFFA502), size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Đánh giá tổng quát từ AI',
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                result.generalComment,
                style: TextStyle(
                  color: context.palette.textSecondary,
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        Text(
          'Lỗi ngữ pháp cần sửa (${result.grammarFeedback.length})',
          style: AppTextStyles.h4.copyWith(
            color: context.palette.textPrimary,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),

        if (result.grammarFeedback.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF2ED573).withOpacity(0.1),
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: const Color(0xFF2ED573).withOpacity(0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.check_circle_rounded,
                    color: Color(0xFF2ED573), size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bài viết của bạn chuẩn xác! Không phát hiện lỗi ngữ pháp nào.',
                    style: TextStyle(color: Color(0xFF2ED573), fontSize: 13),
                  ),
                ),
              ],
            ),
          )
        else
          ...result.grammarFeedback.map(
            (g) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: context.palette.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.palette.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close_rounded,
                          color: Color(0xFFFF4757), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          g.original,
                          style: const TextStyle(
                            color: Color(0xFFFF4757),
                            decoration: TextDecoration.lineThrough,
                            decorationColor: Color(0xFFFF4757),
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.check_rounded,
                          color: Color(0xFF2ED573), size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          g.correction,
                          style: const TextStyle(
                            color: Color(0xFF2ED573),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (g.explanationVi.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      '💡 ${g.explanationVi}',
                      style: TextStyle(
                        color: context.palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildVocabTab(WritingEvaluationResultModel result) {
    if (result.vocabSuggestions.isEmpty) {
      return Center(
        child: Text(
          'Vốn từ vựng của bạn rất phong phú và tự nhiên!',
          style: TextStyle(color: context.palette.textSecondary),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: result.vocabSuggestions.length,
      itemBuilder: (context, index) {
        final v = result.vocabSuggestions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
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
                  Text(
                    v.original,
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_rounded,
                      size: 14, color: Color(0xFFFFA502)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      v.suggestion,
                      style: const TextStyle(
                        color: Color(0xFFFFA502),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
              if (v.explanationVi.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  v.explanationVi,
                  style: TextStyle(
                    color: context.palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
              if (v.context.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: context.palette.card,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Ví dụ: "${v.context}"',
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _buildRewriteTab(WritingEvaluationResultModel result) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_rounded,
                color: Color(0xFF00D2D3), size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Phiên bản nâng cấp bản xứ (AI Native Polish)',
                style: TextStyle(
                  color: context.palette.textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.copy_rounded,
                  color: context.palette.textSecondary, size: 18),
              tooltip: 'Sao chép bài viết',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: result.revisedText));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Đã sao chép bài viết hoàn thiện!'),
                    backgroundColor: Color(0xFF2ED573),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: context.palette.card,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0xFF00D2D3).withOpacity(0.3)),
          ),
          child: Text(
            result.revisedText.isNotEmpty
                ? result.revisedText
                : result.userText,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 14,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;

  const _Badge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
