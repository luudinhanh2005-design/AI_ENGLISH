import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/ai_tutor_models.dart';
import '../providers/ai_tutor_provider.dart';

class AiTutorChatScreen extends ConsumerStatefulWidget {
  const AiTutorChatScreen({super.key});

  @override
  ConsumerState<AiTutorChatScreen> createState() => _AiTutorChatScreenState();
}

class _AiTutorChatScreenState extends ConsumerState<AiTutorChatScreen> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingId;

  @override
  void dispose() {
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _playMessageAudio(ChatMessageModel msg, String persona) async {
    if (_currentlyPlayingId == msg.id) {
      await _audioPlayer.stop();
      if (mounted) setState(() => _currentlyPlayingId = null);
      return;
    }

    if (mounted) setState(() => _currentlyPlayingId = msg.id);

    try {
      final notifier = ref.read(aiTutorProvider.notifier);
      final audioUrl = await notifier.getAudioUrlForText(msg.content, persona);
      if (audioUrl != null && mounted) {
        await _audioPlayer.play(UrlSource(audioUrl));
        _audioPlayer.onPlayerComplete.listen((_) {
          if (mounted) setState(() => _currentlyPlayingId = null);
        });
      } else {
        if (mounted) setState(() => _currentlyPlayingId = null);
      }
    } catch (_) {
      if (mounted) setState(() => _currentlyPlayingId = null);
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(aiTutorProvider);
    final notifier = ref.read(aiTutorProvider.notifier);

    _scrollToBottom();

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryDark),
          onPressed: () => context.pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [AppColors.primary, AppColors.secondary],
                ),
              ),
              child: const Icon(Icons.smart_toy_rounded, color: Colors.white, size: 20),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Gia sư AI Tutor',
                  style: AppTextStyles.titleSmall.copyWith(
                    color: AppColors.textPrimaryDark,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Trực tuyến • Sửa lỗi tức thì',
                  style: AppTextStyles.labelSmall.copyWith(color: AppColors.success),
                ),
              ],
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Persona Switcher Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: AppColors.surfaceDark.withOpacity(0.5),
              child: Row(
                children: [
                  Text(
                    'Gia sư:',
                    style: AppTextStyles.labelMedium.copyWith(color: AppColors.textSecondaryDark),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildPersonaChip('sarah', 'Sarah (Giao tiếp)', state.currentPersona, notifier),
                          const SizedBox(width: 8),
                          _buildPersonaChip('harrison', 'Mr. Harrison (Business)', state.currentPersona, notifier),
                          const SizedBox(width: 8),
                          _buildPersonaChip('emma', 'Emma (IELTS)', state.currentPersona, notifier),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Messages List
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: state.messages.length + (state.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index == state.messages.length && state.isLoading) {
                    return _buildTypingIndicator();
                  }
                  final msg = state.messages[index];
                  return _buildMessageBubble(msg);
                },
              ),
            ),

            // Quick Suggestions Bar
            if (state.currentSuggestions.isNotEmpty) ...[
              Container(
                height: 42,
                margin: const EdgeInsets.only(bottom: 8),
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: state.currentSuggestions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final suggestion = state.currentSuggestions[index];
                    return ActionChip(
                      label: Text(
                        suggestion,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.textPrimaryDark),
                      ),
                      backgroundColor: AppColors.surfaceLightDark,
                      side: const BorderSide(color: AppColors.borderDark),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      onPressed: () {
                        notifier.sendMessage(suggestion);
                      },
                    );
                  },
                ),
              ),
            ],

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: const BoxDecoration(
                color: AppColors.surfaceDark,
                border: Border(top: BorderSide(color: AppColors.borderDark)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: AppColors.backgroundDark,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.borderDark),
                      ),
                      child: TextField(
                        controller: _textController,
                        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textPrimaryDark),
                        decoration: InputDecoration(
                          hintText: 'Nhắn tin bằng tiếng Anh...',
                          hintStyle: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondaryDark),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        ),
                        onSubmitted: (val) {
                          if (val.trim().isNotEmpty) {
                            notifier.sendMessage(val);
                            _textController.clear();
                          }
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () {
                      final text = _textController.text;
                      if (text.trim().isNotEmpty) {
                        notifier.sendMessage(text);
                        _textController.clear();
                      }
                    },
                    borderRadius: BorderRadius.circular(24),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                        ),
                      ),
                      child: const Icon(Icons.send_rounded, color: Colors.white, size: 20),
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

  Widget _buildPersonaChip(
    String personaKey,
    String label,
    String currentPersona,
    AiTutorNotifier notifier,
  ) {
    final isSelected = currentPersona == personaKey;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surfaceDark,
      labelStyle: AppTextStyles.labelSmall.copyWith(
        color: isSelected ? Colors.white : AppColors.textSecondaryDark,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      onSelected: (_) => notifier.setPersona(personaKey),
    );
  }

  Widget _buildMessageBubble(ChatMessageModel msg) {
    final isUser = msg.isUser;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Column(
        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.2),
                  ),
                  child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
                ),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser
                        ? AppColors.primary
                        : AppColors.surfaceDark,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(16),
                      topRight: const Radius.circular(16),
                      bottomLeft: Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4 : 16),
                    ),
                    border: Border.all(
                      color: isUser ? Colors.transparent : AppColors.borderDark,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        msg.content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isUser ? Colors.white : AppColors.textPrimaryDark,
                          height: 1.4,
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(height: 8),
                        InkWell(
                          onTap: () => _playMessageAudio(msg, ref.read(aiTutorProvider).currentPersona),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: (_currentlyPlayingId == msg.id)
                                  ? AppColors.primary.withOpacity(0.2)
                                  : AppColors.surfaceLightDark,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: (_currentlyPlayingId == msg.id)
                                    ? AppColors.primary
                                    : AppColors.borderDark,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  (_currentlyPlayingId == msg.id)
                                      ? Icons.stop_circle_rounded
                                      : Icons.volume_up_rounded,
                                  size: 16,
                                  color: (_currentlyPlayingId == msg.id)
                                      ? AppColors.accent
                                      : AppColors.textSecondaryDark,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  (_currentlyPlayingId == msg.id) ? 'Đang phát...' : 'Nghe phát âm',
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: (_currentlyPlayingId == msg.id)
                                        ? AppColors.accent
                                        : AppColors.textSecondaryDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Real-time Grammatical Feedback Box
          if (msg.corrections.isNotEmpty) ...[
            Container(
              margin: const EdgeInsets.only(top: 8, left: 40, right: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.warning.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.edit_note_rounded, color: AppColors.warning, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        'Phân tích ngữ pháp của AI Tutor:',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ...msg.corrections.map((corr) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                corr.original,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.error,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Icon(Icons.arrow_forward_rounded, color: AppColors.textSecondaryDark, size: 14),
                              const SizedBox(width: 6),
                              Text(
                                corr.correction,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: AppColors.success,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            corr.explanationVi,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.textSecondaryDark,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTypingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.2),
            ),
            child: const Icon(Icons.auto_awesome, color: AppColors.accent, size: 18),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceDark,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderDark),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Gia sư đang suy nghĩ...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondaryDark,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
