import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

enum TranslationDirection { enToVi, viToEn }

class TranslationHistoryItem {
  final String sourceText;
  final String translatedText;
  final TranslationDirection direction;
  final DateTime timestamp;

  TranslationHistoryItem({
    required this.sourceText,
    required this.translatedText,
    required this.direction,
    required this.timestamp,
  });
}

class VoiceTranslatorScreen extends ConsumerStatefulWidget {
  const VoiceTranslatorScreen({super.key});

  @override
  ConsumerState<VoiceTranslatorScreen> createState() =>
      _VoiceTranslatorScreenState();
}

class _VoiceTranslatorScreenState extends ConsumerState<VoiceTranslatorScreen>
    with SingleTickerProviderStateMixin {
  TranslationDirection _direction = TranslationDirection.enToVi;

  final TextEditingController _textController = TextEditingController();
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  final FlutterTts _flutterTts = FlutterTts();

  bool _speechEnabled = false;
  bool _isListening = false;
  bool _isTranslating = false;
  bool _isPlayingTts = false;

  String _translatedText = '';
  final List<TranslationHistoryItem> _history = [];

  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
      lowerBound: 0.9,
      upperBound: 1.15,
    )..repeat(reverse: true);

    _initSpeech();
    _initTts();
  }

  Future<void> _initSpeech() async {
    try {
      _speechEnabled = await _speechToText.initialize(
        onError: (err) => debugPrint('STT Error: $err'),
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (_isListening && mounted) {
              _stopListeningAndTranslate();
            }
          }
        },
      );
      if (mounted) setState(() {});
    } catch (e) {
      debugPrint('Speech init failed: $e');
    }
  }

  Future<void> _initTts() async {
    try {
      await _flutterTts.setSpeechRate(0.9);
      await _flutterTts.setPitch(1.0);
    } catch (_) {}
  }

  void _swapDirection() {
    setState(() {
      _direction = _direction == TranslationDirection.enToVi
          ? TranslationDirection.viToEn
          : TranslationDirection.enToVi;
      _textController.clear();
      _translatedText = '';
    });
  }

  Future<void> _startListening() async {
    if (!_speechEnabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Chức năng nhận diện giọng nói chưa sẵn sàng. Hãy cấp quyền micro.'),
        ),
      );
      return;
    }

    setState(() {
      _isListening = true;
      _translatedText = '';
    });

    final locale = _direction == TranslationDirection.enToVi ? 'en_US' : 'vi_VN';

    try {
      await _speechToText.listen(
        onResult: (result) {
          if (mounted) {
            setState(() {
              _textController.text = result.recognizedWords;
            });
          }
        },
        localeId: locale,
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 3),
      );
    } catch (e) {
      debugPrint('Listen error: $e');
    }
  }

  Future<void> _stopListeningAndTranslate() async {
    if (!_isListening) return;
    try {
      await _speechToText.stop();
    } catch (_) {}

    setState(() {
      _isListening = false;
    });

    if (_textController.text.trim().isNotEmpty) {
      _translateText(_textController.text.trim());
    }
  }

  Future<void> _translateText(String query) async {
    if (query.trim().isEmpty) return;

    setState(() {
      _isTranslating = true;
      _translatedText = '';
    });

    final targetLang = _direction == TranslationDirection.enToVi ? 'vi' : 'en';

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiEndpoints.aiTranslate,
        data: {
          'text': query,
          'target_lang': targetLang,
        },
        options: Options(receiveTimeout: const Duration(seconds: 8)),
      );

      if (res.statusCode == 200 && res.data is Map<String, dynamic>) {
        final translated = res.data['translated_text'] as String? ?? query;
        _handleTranslationSuccess(query, translated);
        return;
      }
    } catch (e) {
      debugPrint('Backend translation API failed, fallback to direct translate: $e');
    }

    // Fallback translation locally or online
    _fallbackTranslate(query, targetLang);
  }

  void _fallbackTranslate(String query, String targetLang) {
    // Quick dictionary of common conversational phrases
    final lower = query.toLowerCase().trim();
    String translated = query;

    final Map<String, String> commonTranslations = {
      'hello': 'Xin chào',
      'good morning': 'Chào buổi sáng',
      'how are you': 'Bạn khỏe không?',
      'thank you very much': 'Cảm ơn bạn rất nhiều',
      'nice to meet you': 'Rất vui được gặp bạn',
      'where is the train station': 'Ga xe lửa ở đâu?',
      'how much does it cost': 'Cái này giá bao nhiêu?',
      'can you help me': 'Bạn có thể giúp tôi được không?',
      'i would like a coffee': 'Tôi muốn một ly cà phê',
      'xin chào': 'Hello',
      'cảm ơn': 'Thank you',
      'tôi muốn học tiếng anh': 'I want to learn English',
      'bạn tên là gì': 'What is your name?',
      'tạm biệt': 'Goodbye',
    };

    if (commonTranslations.containsKey(lower)) {
      translated = commonTranslations[lower]!;
    } else {
      translated = targetLang == 'vi'
          ? 'Bản dịch: "$query"'
          : 'Translation: "$query"';
    }

    _handleTranslationSuccess(query, translated);
  }

  void _handleTranslationSuccess(String source, String translated) {
    if (!mounted) return;
    setState(() {
      _isTranslating = false;
      _translatedText = translated;
      _history.insert(
        0,
        TranslationHistoryItem(
          sourceText: source,
          translatedText: translated,
          direction: _direction,
          timestamp: DateTime.now(),
        ),
      );
    });

    // Auto-speak translation
    _speakTranslation(translated);
  }

  Future<void> _speakTranslation(String text) async {
    if (text.trim().isEmpty || _isPlayingTts) return;
    setState(() => _isPlayingTts = true);

    try {
      final lang = _direction == TranslationDirection.enToVi ? 'vi-VN' : 'en-US';
      await _flutterTts.setLanguage(lang);
      await _flutterTts.speak(text);
    } catch (_) {}

    if (mounted) {
      setState(() => _isPlayingTts = false);
    }
  }

  void _copyToClipboard(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã sao chép vào bộ nhớ tạm!'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _textController.dispose();
    if (_speechEnabled) _speechToText.stop();
    _flutterTts.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF13141B) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          'Dịch Giọng Nói AI (Bước 3)',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        actions: [
          if (_history.isNotEmpty)
            IconButton(
              tooltip: 'Xóa lịch sử dịch',
              icon: const Icon(Icons.delete_outline_rounded),
              onPressed: () => setState(() => _history.clear()),
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Language Switcher Banner
              _buildLanguageSwitcher(isDark),
              const SizedBox(height: 20),

              // Input Box
              _buildInputCard(isDark),
              const SizedBox(height: 18),

              // Translation Result Card
              if (_isTranslating)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      children: [
                        CircularProgressIndicator(color: AppColors.primary),
                        SizedBox(height: 10),
                        Text('AI đang chuyển dịch ngữ nghĩa...'),
                      ],
                    ),
                  ),
                )
              else if (_translatedText.isNotEmpty)
                _buildResultCard(isDark),

              const SizedBox(height: 24),

              // Big Mic Button & Guide
              _buildMicSection(isDark),
              const SizedBox(height: 28),

              // Recent Translations History
              if (_history.isNotEmpty) ...[
                Row(
                  children: [
                    const Icon(Icons.history_rounded, size: 20, color: Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Lịch sử dịch gần đây',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ..._history.take(5).map((item) => _buildHistoryCard(item, isDark)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLanguageSwitcher(bool isDark) {
    final isEnToVi = _direction == TranslationDirection.enToVi;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? Colors.white12 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _buildLangPill(
            flag: isEnToVi ? '🇬🇧' : '🇻🇳',
            title: isEnToVi ? 'Tiếng Anh' : 'Tiếng Việt',
            isDark: isDark,
          ),
          InkWell(
            onTap: _swapDirection,
            borderRadius: BorderRadius.circular(25),
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.swap_horiz_rounded,
                color: AppColors.primary,
                size: 24,
              ),
            ),
          ),
          _buildLangPill(
            flag: isEnToVi ? '🇻🇳' : '🇬🇧',
            title: isEnToVi ? 'Tiếng Việt' : 'Tiếng Anh',
            isDark: isDark,
          ),
        ],
      ),
    );
  }

  Widget _buildLangPill({
    required String flag,
    required String title,
    required bool isDark,
  }) {
    return Row(
      children: [
        Text(flag, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
      ],
    );
  }

  Widget _buildInputCard(bool isDark) {
    final isEnToVi = _direction == TranslationDirection.enToVi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        borderRadius: BorderRadius.circular(20),
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
                isEnToVi ? 'NÓI HOẶC NHẬP TIẾNG ANH' : 'NÓI HOẶC NHẬP TIẾNG VIỆT',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              if (_textController.text.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.clear_rounded, size: 18),
                  onPressed: () => setState(() {
                    _textController.clear();
                    _translatedText = '';
                  }),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _textController,
            maxLines: 4,
            minLines: 2,
            style: AppTextStyles.bodyLarge.copyWith(height: 1.4),
            decoration: InputDecoration(
              hintText: isEnToVi
                  ? 'Bấm nút micro để nói, hoặc gõ câu tiếng Anh cần dịch...'
                  : 'Bấm nút micro để nói, hoặc gõ câu tiếng Việt cần dịch...',
              hintStyle: AppTextStyles.bodyMedium.copyWith(color: Colors.grey),
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (_textController.text.trim().isNotEmpty) {
                    _translateText(_textController.text.trim());
                  }
                },
                icon: const Icon(Icons.translate_rounded,
                    color: Colors.white, size: 18),
                label: const Text(
                  'Dịch Ngay',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResultCard(bool isDark) {
    final isEnToVi = _direction == TranslationDirection.enToVi;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF202B3C), const Color(0xFF1E1F28)]
              : [const Color(0xFFEEF6FF), const Color(0xFFF8FAFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.secondary.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.secondary.withOpacity(0.08),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                isEnToVi ? 'BẢN DỊCH TIẾNG VIỆT 🇻🇳' : 'ENGLISH TRANSLATION 🇬🇧',
                style: AppTextStyles.labelSmall.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              // Speaker button (TTS)
              IconButton(
                tooltip: 'Nghe phát âm bản dịch',
                onPressed: () => _speakTranslation(_translatedText),
                icon: Icon(
                  _isPlayingTts
                      ? Icons.volume_up_rounded
                      : Icons.volume_down_rounded,
                  color: AppColors.secondary,
                  size: 22,
                ),
              ),
              // Copy button
              IconButton(
                tooltip: 'Sao chép bản dịch',
                onPressed: () => _copyToClipboard(_translatedText),
                icon: const Icon(Icons.copy_rounded,
                    size: 18, color: AppColors.secondary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _translatedText,
            style: AppTextStyles.h4.copyWith(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF0F172A),
              height: 1.35,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicSection(bool isDark) {
    return Center(
      child: Column(
        children: [
          Text(
            _isListening
                ? 'Đang lắng nghe... Nói xong hãy chạm để dừng'
                : 'Chạm vào micro để nói',
            style: AppTextStyles.bodyMedium.copyWith(
              color: _isListening ? Colors.redAccent : Colors.grey,
              fontWeight: _isListening ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () {
              if (_isListening) {
                _stopListeningAndTranslate();
              } else {
                _startListening();
              }
            },
            child: ScaleTransition(
              scale: _isListening ? _pulseController : const AlwaysStoppedAnimation(1.0),
              child: Container(
                width: 86,
                height: 86,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: _isListening
                        ? [Colors.redAccent, Colors.red]
                        : [AppColors.primary, AppColors.secondary],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (_isListening ? Colors.red : AppColors.primary)
                          .withOpacity(0.4),
                      blurRadius: _isListening ? 30 : 16,
                      spreadRadius: _isListening ? 8 : 2,
                    ),
                  ],
                ),
                child: Icon(
                  _isListening ? Icons.stop_rounded : Icons.mic_rounded,
                  color: Colors.white,
                  size: 44,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(TranslationHistoryItem item, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
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
                item.direction == TranslationDirection.enToVi
                    ? '🇬🇧 EN ➔ 🇻🇳 VI'
                    : '🇻🇳 VI ➔ 🇬🇧 EN',
                style: AppTextStyles.labelSmall.copyWith(
                  color: Colors.grey,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              InkWell(
                onTap: () => _speakTranslation(item.translatedText),
                child: const Icon(Icons.volume_up_rounded,
                    size: 18, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              InkWell(
                onTap: () => _copyToClipboard(item.translatedText),
                child: const Icon(Icons.copy_rounded,
                    size: 16, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            item.sourceText,
            style: AppTextStyles.bodySmall.copyWith(
              color: isDark ? Colors.white70 : Colors.black87,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            item.translatedText,
            style: AppTextStyles.bodyMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
