import 'dart:async';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/ai_tutor_models.dart';
import '../providers/ai_tutor_provider.dart';

class AiTutorChatScreen extends ConsumerStatefulWidget {
  const AiTutorChatScreen({super.key});

  @override
  ConsumerState<AiTutorChatScreen> createState() => _AiTutorChatScreenState();
}

class _AiTutorChatScreenState extends ConsumerState<AiTutorChatScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AudioRecordingService _recordingService = AudioRecordingService();

  String? _currentlyPlayingId;
  bool _isRecording = false;
  int _recordDuration = 0;
  Timer? _recordTimer;
  late AnimationController _pulseController;
  final Map<String, String> _translations = {};
  final Set<String> _translatingIds = {};
  final Set<String> _showTranslationIds = {};

  Future<void> _toggleTranslation(String msgId, String content) async {
    if (_showTranslationIds.contains(msgId)) {
      setState(() {
        _showTranslationIds.remove(msgId);
      });
      return;
    }

    if (_translations.containsKey(msgId)) {
      setState(() {
        _showTranslationIds.add(msgId);
      });
      return;
    }

    setState(() {
      _translatingIds.add(msgId);
    });

    try {
      final translated = await ref.read(aiTutorProvider.notifier).translateText(content);
      if (mounted) {
        setState(() {
          _translatingIds.remove(msgId);
          if (translated != null && translated.isNotEmpty) {
            _translations[msgId] = translated;
            _showTranslationIds.add(msgId);
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Không thể dịch lúc này. Vui lòng thử lại!')),
            );
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _translatingIds.remove(msgId);
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) setState(() => _currentlyPlayingId = null);
    });
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _pulseController.dispose();
    _recordingService.dispose();
    _audioPlayer.dispose();
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final hasPerm = await _recordingService.hasPermission();
      if (!hasPerm) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Vui lòng cấp quyền Microphone trên trình duyệt/thiết bị để luyện nói!'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }

      await _recordingService.startRecording();
      if (mounted) {
        setState(() {
          _isRecording = true;
          _recordDuration = 0;
        });
      }
      _recordTimer?.cancel();
      _recordTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() => _recordDuration++);
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Không thể bắt đầu ghi âm: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _stopRecordingAndSend() async {
    _recordTimer?.cancel();
    if (mounted) {
      setState(() => _isRecording = false);
    }

    try {
      final audioBytes = await _recordingService.stopRecording();
      if (audioBytes != null && audioBytes.isNotEmpty) {
        if (mounted) {
          await ref.read(aiTutorProvider.notifier).sendAudioMessage(
                audioBytes,
                filename: 'speaking_${DateTime.now().millisecondsSinceEpoch}.wav',
              );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Không thu được âm thanh. Hãy thử nói to hơn nhé!'),
              backgroundColor: AppColors.warning,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lỗi gửi âm thanh: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    _recordTimer?.cancel();
    await _recordingService.cancelRecording();
    if (mounted) {
      setState(() {
        _isRecording = false;
        _recordDuration = 0;
      });
    }
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final remainingSeconds = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
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
      if (audioUrl != null && audioUrl.isNotEmpty && mounted) {
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
      } else {
        if (mounted) {
          setState(() => _currentlyPlayingId = null);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Không thể phát âm thanh lúc này.')),
          );
        }
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

    ref.listen(aiTutorProvider.select((s) => s.messages.length), (previous, next) {
      if (previous != next) {
        _scrollToBottom();
      }
    });

    return Scaffold(
      backgroundColor: AppColors.backgroundDark,
      appBar: AppBar(
        backgroundColor: AppColors.surfaceDark,
        elevation: 1,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryDark),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
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
                  'Luyện nói & Sửa lỗi giọng Mỹ • Whisper AI',
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
                          _buildPersonaChip('sarah', 'Sarah (Giọng Mỹ Chuẩn)', state.currentPersona, notifier),
                          const SizedBox(width: 8),
                          _buildPersonaChip('harrison', 'Mr. Harrison (Business)', state.currentPersona, notifier),
                          const SizedBox(width: 8),
                          _buildPersonaChip('emma', 'Emma (IELTS Chuẩn)', state.currentPersona, notifier),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Error banner if any
            if (state.errorMessage != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: AppColors.error.withOpacity(0.15),
                child: Row(
                  children: [
                    const Icon(Icons.info_outline, color: AppColors.error, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: AppTextStyles.labelSmall.copyWith(color: AppColors.error),
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
                itemCount: state.messages.length +
                    (state.isTranscribing ? 1 : 0) +
                    (state.isLoading ? 1 : 0),
                itemBuilder: (context, index) {
                  if (index < state.messages.length) {
                    final msg = state.messages[index];
                    return _buildMessageBubble(msg);
                  }
                  if (state.isTranscribing && index == state.messages.length) {
                    return _buildTranscribingIndicator();
                  }
                  return _buildTypingIndicator();
                },
              ),
            ),

            // Quick Suggestions Bar
            if (state.currentSuggestions.isNotEmpty && !_isRecording) ...[
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

            // Input / Recording Bar
            _buildBottomBar(notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(AiTutorNotifier notifier) {
    if (_isRecording) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: AppColors.surfaceDark,
          border: Border(top: BorderSide(color: AppColors.borderDark)),
        ),
        child: Row(
          children: [
            // Cancel Button
            IconButton(
              icon: const Icon(Icons.close, color: AppColors.error),
              tooltip: 'Hủy ghi âm',
              onPressed: _cancelRecording,
            ),
            const SizedBox(width: 8),

            // Recording Status & Timer
            Expanded(
              child: Row(
                children: [
                  FadeTransition(
                    opacity: _pulseController,
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: const BoxDecoration(
                        color: AppColors.error,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Đang thu âm: ${_formatDuration(_recordDuration)}',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textPrimaryDark,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    '• Nói tiếng Anh...',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondaryDark,
                    ),
                  ),
                ],
              ),
            ),

            // Stop & Send Button
            InkWell(
              onTap: _stopRecordingAndSend,
              borderRadius: BorderRadius.circular(24),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.success, Color(0xFF10B981)],
                  ),
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.success.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check, color: Colors.white, size: 18),
                    const SizedBox(width: 6),
                    Text(
                      'Xong & Gửi',
                      style: AppTextStyles.labelMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: AppColors.surfaceDark,
        border: Border(top: BorderSide(color: AppColors.borderDark)),
      ),
      child: Row(
        children: [
          // Text Input Field
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
                  hintText: 'Nhắn tin hoặc bấm biểu tượng Mic để nói...',
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

          // Microphone Button (Voice Input)
          InkWell(
            onTap: _startRecording,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accent.withOpacity(0.15),
                border: Border.all(color: AppColors.accent.withOpacity(0.4)),
              ),
              child: const Icon(Icons.mic_rounded, color: AppColors.accent, size: 22),
            ),
          ),
          const SizedBox(width: 8),

          // Send Button
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
                      // Prominent Highlighted Grammar Correction Box on top
                      if (!isUser && msg.corrections.isNotEmpty) ...[
                        ...msg.corrections.map((corr) => _buildHighlightedCorrectionCard(corr)),
                        const SizedBox(height: 10),
                      ],
                      Text(
                        msg.content,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: isUser ? Colors.white : AppColors.textPrimaryDark,
                          height: 1.4,
                        ),
                      ),
                      if (!isUser) ...[
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          children: [
                            // 1. Audio button
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
                            // 2. Translation toggle button
                            InkWell(
                              onTap: () => _toggleTranslation(msg.id, msg.content),
                              borderRadius: BorderRadius.circular(16),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _showTranslationIds.contains(msg.id)
                                      ? AppColors.secondary.withOpacity(0.18)
                                      : AppColors.surfaceLightDark,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _showTranslationIds.contains(msg.id)
                                        ? AppColors.secondary
                                        : AppColors.borderDark,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    if (_translatingIds.contains(msg.id)) ...[
                                      const SizedBox(
                                        width: 12,
                                        height: 12,
                                        child: CircularProgressIndicator(strokeWidth: 1.5, color: AppColors.secondary),
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        'Đang dịch...',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.secondary,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ] else ...[
                                      Icon(
                                        Icons.translate_rounded,
                                        size: 14,
                                        color: _showTranslationIds.contains(msg.id)
                                            ? AppColors.secondary
                                            : AppColors.textSecondaryDark,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _showTranslationIds.contains(msg.id) ? 'Ẩn bản dịch' : 'Dịch tiếng Việt',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: _showTranslationIds.contains(msg.id)
                                              ? AppColors.secondary
                                              : AppColors.textSecondaryDark,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        // Expandable Vietnamese Translation Box
                        if (_showTranslationIds.contains(msg.id) && _translations.containsKey(msg.id)) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLightDark.withOpacity(0.7),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.secondary.withOpacity(0.35),
                              ),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Icon(
                                  Icons.g_translate_rounded,
                                  size: 16,
                                  color: AppColors.secondary,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Bản dịch tiếng Việt:',
                                        style: AppTextStyles.labelSmall.copyWith(
                                          color: AppColors.secondary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 10,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _translations[msg.id]!,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: AppColors.textPrimaryDark,
                                          height: 1.4,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

        ],
      ),
    );
  }

  List<TextSpan> _buildOriginalSpans(String orig, String corr) {
    final w1 = orig.trim().split(RegExp(r'\s+'));
    final w2 = corr.trim().split(RegExp(r'\s+'));
    if (w1.isEmpty || orig.trim().isEmpty) return [TextSpan(text: orig)];

    String cleanWord(String w) => w.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();

    int start = 0;
    while (start < w1.length && start < w2.length && cleanWord(w1[start]) == cleanWord(w2[start])) {
      start++;
    }

    int end1 = w1.length - 1;
    int end2 = w2.length - 1;
    while (end1 >= start && end2 >= start && cleanWord(w1[end1]) == cleanWord(w2[end2])) {
      end1--;
      end2--;
    }

    final spans = <TextSpan>[];
    if (start > 0) {
      spans.add(TextSpan(
        text: '${w1.sublist(0, start).join(' ')} ',
        style: const TextStyle(color: AppColors.textSecondaryDark),
      ),);
    }
    if (start <= end1) {
      spans.add(TextSpan(
        text: '${w1.sublist(start, end1 + 1).join(' ')} ',
        style: const TextStyle(
          color: Color(0xFFFF6B81),
          fontWeight: FontWeight.bold,
          decoration: TextDecoration.lineThrough,
          decorationColor: Color(0xFFFF4757),
          decorationThickness: 2.8,
          backgroundColor: Color(0x33FF4757),
        ),
      ),);
    }
    if (end1 + 1 < w1.length) {
      spans.add(TextSpan(
        text: w1.sublist(end1 + 1).join(' '),
        style: const TextStyle(color: AppColors.textSecondaryDark),
      ),);
    }
    return spans.isEmpty ? [TextSpan(text: orig)] : spans;
  }

  List<TextSpan> _buildCorrectedSpans(String orig, String corr) {
    final w1 = orig.trim().split(RegExp(r'\s+'));
    final w2 = corr.trim().split(RegExp(r'\s+'));
    if (w2.isEmpty || corr.trim().isEmpty) return [TextSpan(text: corr)];

    String cleanWord(String w) => w.replaceAll(RegExp(r'[^\w]'), '').toLowerCase();

    int start = 0;
    while (start < w1.length && start < w2.length && cleanWord(w1[start]) == cleanWord(w2[start])) {
      start++;
    }

    int end1 = w1.length - 1;
    int end2 = w2.length - 1;
    while (end1 >= start && end2 >= start && cleanWord(w1[end1]) == cleanWord(w2[end2])) {
      end1--;
      end2--;
    }

    final spans = <TextSpan>[];
    if (start > 0) {
      spans.add(TextSpan(
        text: '${w2.sublist(0, start).join(' ')} ',
        style: const TextStyle(color: Colors.white),
      ),);
    }
    if (start <= end2) {
      spans.add(TextSpan(
        text: '${w2.sublist(start, end2 + 1).join(' ')} ',
        style: const TextStyle(
          color: Color(0xFF2ED573),
          fontWeight: FontWeight.w900,
          backgroundColor: Color(0x402ED573),
        ),
      ),);
    }
    if (end2 + 1 < w2.length) {
      spans.add(TextSpan(
        text: w2.sublist(end2 + 1).join(' '),
        style: const TextStyle(color: Colors.white),
      ),);
    }
    return spans.isEmpty ? [TextSpan(text: corr)] : spans;
  }

  Widget _buildHighlightedCorrectionCard(AICorrectionModel corr) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF131726),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFFA502).withValues(alpha: 0.6),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFA502).withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Icon(Icons.spellcheck_rounded, color: Color(0xFFFFA502), size: 16),
              ),
              const SizedBox(width: 8),
              Text(
                'SỬA LỖI NGỮ PHÁP (GRAMMAR CHECK):',
                style: AppTextStyles.labelSmall.copyWith(
                  color: const Color(0xFFFFA502),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 1. Câu sai có gạch ngang đỏ tại vị trí lỗi
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.error.withValues(alpha: 0.35)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2.0),
                  child: Icon(Icons.cancel_rounded, color: AppColors.error, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textPrimaryDark,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                      children: _buildOriginalSpans(corr.original, corr.correction),
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 6),

          // 2. Câu đúng được Highline tô sáng xanh Neon
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF003820),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFF2ED573), width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF2ED573).withValues(alpha: 0.3),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.only(top: 2.0),
                  child: Icon(Icons.check_circle_rounded, color: Color(0xFF2ED573), size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
                      children: _buildCorrectedSpans(corr.original, corr.correction),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // 3. Giải thích ngắn gọn bằng Tiếng Việt
          if (corr.explanationVi.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.surfaceLightDark.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2.0),
                    child: Icon(Icons.lightbulb_rounded, color: AppColors.warning, size: 14),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      corr.explanationVi,
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.textSecondaryDark,
                        height: 1.35,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTranscribingIndicator() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.accent.withOpacity(0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.accent.withOpacity(0.4)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.mic, color: AppColors.accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  'Whisper AI đang nhận diện giọng nói...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.accent,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accent),
                ),
              ],
            ),
          ),
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
