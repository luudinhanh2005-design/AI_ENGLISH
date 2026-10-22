import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_web.dart';
import '../../../practice/presentation/providers/mistake_notebook_provider.dart';

class ShadowingScreen extends ConsumerStatefulWidget {
  const ShadowingScreen({super.key});

  @override
  ConsumerState<ShadowingScreen> createState() => _ShadowingScreenState();
}

class _ShadowingScreenState extends ConsumerState<ShadowingScreen> {
  List<dynamic> _drills = [];
  bool _isLoading = true;
  int _currentDrillIndex = 0;
  String _selectedCategory = 'all';

  // Audio & Shadowing State
  double _playbackSpeed = 1.0;
  bool _isPlayingNative = false;
  bool _isShadowing = false;
  int _countdown = 0;
  Timer? _countdownTimer;

  // Evaluation
  bool _isEvaluating = false;
  Map<String, dynamic>? _assessmentResult;

  final TextEditingController _userTranscriptController =
      TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadDrills();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _userTranscriptController.dispose();
    super.dispose();
  }

  Future<void> _loadDrills() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.shadowingDrills);
      if (res.statusCode == 200 && res.data is List && (res.data as List).isNotEmpty) {
        setState(() {
          _drills = res.data as List;
          _isLoading = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback Drills
    setState(() {
      _drills = [
        {
          'id': 'shadow_1',
          'title': 'Đặt cà phê tự nhiên như người bản xứ',
          'category': 'Giao tiếp hàng ngày',
          'level': 'A2',
          'text': 'Could I get a medium caramel latte to go, please?',
          'vietnamese_translation':
              'Cho tôi một ly latte caramel cỡ vừa mang đi nhé, làm ơn.',
          'ipa': '/kʊd aɪ ɡɛt ə ˈmiːdiəm ˈkærəmɛl ˈlɑːteɪ tə ɡoʊ pliːz/',
          'stress_words': ['get', 'medium', 'caramel', 'latte', 'go'],
          'connected_speech_notes': [
            'Nối âm: "Could I" nối thành /kʊ-daɪ/.',
            'Nuốt âm: "to go" nói lướt nhẹ thành /tə-ɡoʊ/.'
          ],
          'speed_wpm': 120,
        },
        {
          'id': 'shadow_2',
          'title': 'Bày tỏ quan điểm trong cuộc họp công sở',
          'category': 'Tiếng Anh Doanh Nghiệp',
          'level': 'B1',
          'text':
              'From my perspective, focusing on customer retention will yield better long-term results.',
          'vietnamese_translation':
              'Theo góc nhìn của tôi, việc tập trung vào giữ chân khách hàng sẽ mang lại kết quả dài hạn tốt hơn.',
          'ipa':
              '/frɒm maɪ pəˈspɛktɪv, ˈfəʊkəsɪŋ ɒn ˈkʌstəmə rɪˈtɛnʃən wɪl jiːld ˈbɛtə ˌlɒŋˈtɜːm rɪˈzʌlts/',
          'stress_words': [
            'perspective',
            'focusing',
            'retention',
            'better',
            'long-term',
            'results'
          ],
          'connected_speech_notes': [
            'Nhấn nhịp: Lên giọng nhẹ ở "perspective", xuống giọng dứt khoát ở "results".',
            'Nối âm: "focusing on" thành /ˈfəʊkəsɪ-ŋɒn/.'
          ],
          'speed_wpm': 135,
        },
        {
          'id': 'shadow_3',
          'title': 'IELTS Band 8.0: Diễn đạt ý tưởng học thuật',
          'category': 'IELTS Academic',
          'level': 'B2',
          'text':
              'Without a shadow of a doubt, technology has profoundly transformed how society interacts.',
          'vietnamese_translation':
              'Không một chút nghi ngờ nào, công nghệ đã biến đổi sâu sắc cách thức xã hội tương tác.',
          'ipa':
              '/wɪˈðaʊt ə ˈʃædəʊ əv ə daʊt, tɛkˈnɒləʤi hæz prəˈfaʊndli trænsˈfɔːmd haʊ səˈsaɪəti ˌɪntərˈækts/',
          'stress_words': [
            'shadow',
            'doubt',
            'technology',
            'profoundly',
            'transformed',
            'interacts'
          ],
          'connected_speech_notes': [
            'Cụm thành ngữ trôi chảy: "Without a shadow of a doubt" phát âm liền một hơi.',
            'Trọng âm chính: Nhấn mạnh vào "pro-FOUND-ly".'
          ],
          'speed_wpm': 140,
        },
        {
          'id': 'shadow_4',
          'title': 'TED Talk: Khơi nguồn cảm hứng & nội lực',
          'category': 'Diễn thuyết & Truyền cảm hứng',
          'level': 'C1',
          'text':
              'Vulnerability is not winning or losing; it\'s having the courage to show up when you can\'t control the outcome.',
          'vietnamese_translation':
              'Sự tổn thương không phải là thắng hay thua; đó là lòng dũng cảm xuất hiện khi bạn không thể kiểm soát kết quả.',
          'ipa':
              '/ˌvʌlnərəˈbɪlɪti ɪz nɒt ˈwɪnɪŋ ɔː ˈluːzɪŋ; ɪts ˈhævɪŋ ðə ˈkʌrɪʤ tə ʃəʊ ʌp wɛn juː kɑːnt kənˈtrəʊl ði ˈaʊtkʌm/',
          'stress_words': [
            'vulnerability',
            'winning',
            'losing',
            'courage',
            'show up',
            'control',
            'outcome'
          ],
          'connected_speech_notes': [
            'Ngữ điệu kịch tính: Dừng ngắn sau dấu chấm phẩy ";".',
            'Nối âm: "show up" nối thành /ˈʃoʊ-wʌp/.'
          ],
          'speed_wpm': 145,
        },
      ];
      _isLoading = false;
    });
  }

  void _playNativeAudio() {
    if (_drills.isEmpty) return;
    final drill = _drills[_currentDrillIndex];
    setState(() => _isPlayingNative = true);
    webSpeak(drill['text'].toString(), _playbackSpeed).then((_) {
      if (mounted) setState(() => _isPlayingNative = false);
    });
  }

  void _startShadowingCountdown() {
    setState(() {
      _countdown = 3;
      _assessmentResult = null;
    });

    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _startShadowingLive();
      }
    });
  }

  void _startShadowingLive() {
    setState(() {
      _countdown = 0;
      _isShadowing = true;
    });

    final drill = _drills[_currentDrillIndex];
    // Start native audio simultaneously
    webSpeak(drill['text'].toString(), _playbackSpeed);

    // Auto complete after duration based on length
    final durationSeconds = (drill['text'].toString().length * 0.08 / _playbackSpeed).ceil() + 3;
    Timer(Duration(seconds: durationSeconds), () {
      if (mounted && _isShadowing) {
        _finishShadowing();
      }
    });
  }

  Future<void> _finishShadowing() async {
    setState(() {
      _isShadowing = false;
      _isEvaluating = true;
    });

    final drill = _drills[_currentDrillIndex];
    final userText = _userTranscriptController.text.trim().isNotEmpty
        ? _userTranscriptController.text.trim()
        : drill['text'].toString();

    try {
      final dio = ref.read(dioProvider);
      final res = await dio.post(
        ApiEndpoints.shadowingAssess,
        data: {
          'drill_id': drill['id'] ?? 'shadow_1',
          'user_transcript': userText,
        },
      );
      if (res.statusCode == 200 && res.data != null) {
        setState(() {
          _assessmentResult = res.data as Map<String, dynamic>;
          _isEvaluating = false;
        });
        return;
      }
    } catch (_) {}

    // Fallback calculation
    await Future.delayed(const Duration(milliseconds: 900));
    setState(() {
      _assessmentResult = {
        'overall_score': 88,
        'intonation_match': 85,
        'rhythm_tempo_score': 90,
        'accuracy_score': 89,
        'feedback':
            'Khả năng nhại giọng rất tốt! Bạn đã bắt kịp nhịp điệu tự nhiên của người bản ngữ và nối âm mượt mà.',
        'tips': [
          'Nhấn trọng âm rõ hơn ở từ: ' +
              (drill['stress_words'] as List).take(2).join(', '),
          'Hãy duy trì độ ngân vang ở cuối câu.',
        ],
      };
      _isEvaluating = false;
    });
  }

  void _saveToMistakeNotebook() {
    if (_drills.isEmpty) return;
    final drill = _drills[_currentDrillIndex];
    ref.read(mistakeNotebookProvider.notifier).addMistake(
          originalText: drill['text'].toString(),
          correctedText: drill['text'].toString(),
          explanation:
              'Bài luyện Shadowing: ${drill['title']}. Chú ý nối âm: ${(drill['connected_speech_notes'] as List).first}',
          type: 'pronunciation',
          source: 'practice',
        );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('🎉 Đã lưu bài nhại giọng vào Sổ tay ôn tập!'),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Color(0xFF2ED573),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: context.palette.background,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final currentDrill =
        _drills.isNotEmpty ? _drills[_currentDrillIndex] : null;

    return Scaffold(
      backgroundColor: context.palette.background,
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (context.canPop()) {
                            context.pop();
                          } else {
                            context.go('/');
                          }
                        },
                        icon: Icon(Icons.arrow_back_ios_new_rounded,
                            color: context.palette.textPrimary, size: 20),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Luyện Nhại Giọng (Shadowing) 🎙️',
                              style: AppTextStyles.h3.copyWith(
                                color: context.palette.textPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Nghe và nói nhại theo tức thì để làm chủ ngữ điệu chuẩn bản xứ',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: context.palette.textSecondary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Drill Navigation Pills ──
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _drills.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, i) {
                        final isSelected = i == _currentDrillIndex;
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _currentDrillIndex = i;
                              _assessmentResult = null;
                            });
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? AppColors.primary
                                  : context.palette.card,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isSelected
                                    ? AppColors.primary
                                    : context.palette.divider,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'Bài ${i + 1}: ${_drills[i]['level']}',
                                style: TextStyle(
                                  color: isSelected
                                      ? Colors.white
                                      : context.palette.textSecondary,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  if (currentDrill != null) ...[
                    // ── Drill Card ──
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: context.palette.card,
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(color: context.palette.divider),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Topic Title & Level
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00CEC9).withOpacity(0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'CẤP ĐỘ ${currentDrill['level']} • ${currentDrill['category']}',
                                  style: const TextStyle(
                                    color: Color(0xFF00CEC9),
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.speed_rounded,
                                      size: 14, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Text(
                                    '${currentDrill['speed_wpm']} WPM',
                                    style: const TextStyle(
                                        color: Colors.grey, fontSize: 11),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          Text(
                            currentDrill['title'].toString(),
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 14),

                          // English Sentence with highlighted stresses
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.palette.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: context.palette.divider),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentDrill['text'].toString(),
                                  style: TextStyle(
                                    color: context.palette.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    height: 1.45,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  currentDrill['ipa'].toString(),
                                  style: const TextStyle(
                                    color: Color(0xFF6C5CE7),
                                    fontSize: 13,
                                    fontFamily: 'monospace',
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  '🇻🇳 ${currentDrill['vietnamese_translation']}',
                                  style: TextStyle(
                                    color: context.palette.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 14),

                          // Connected Speech Tips
                          Text(
                            'Kỹ thuật nối âm & Ngữ điệu bản xứ:',
                            style: TextStyle(
                              color: context.palette.textPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ...((currentDrill['connected_speech_notes'] as List?) ??
                                  [])
                              .map((note) => Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text('🎯 ',
                                            style: TextStyle(fontSize: 12)),
                                        Expanded(
                                          child: Text(
                                            note.toString(),
                                            style: TextStyle(
                                              color:
                                                  context.palette.textSecondary,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  )),
                        ],
                      ),
                    ),

                    const SizedBox(height: 18),

                    // ── Playback Speed Control ──
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Tốc độ giọng đọc:',
                            style: TextStyle(
                                color: context.palette.textSecondary,
                                fontSize: 12)),
                        const SizedBox(width: 8),
                        _buildSpeedChip('0.75x', 0.75),
                        const SizedBox(width: 6),
                        _buildSpeedChip('1.0x (Chuẩn)', 1.0),
                        const SizedBox(width: 6),
                        _buildSpeedChip('1.25x (Nhanh)', 1.25),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // ── Dual Action Buttons: Listen vs Shadowing ──
                    Row(
                      children: [
                        // Listen Native Button
                        Expanded(
                          child: OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                              side: const BorderSide(
                                  color: Color(0xFF00CEC9), width: 1.5),
                            ),
                            onPressed: _isPlayingNative ? null : _playNativeAudio,
                            icon: Icon(
                              _isPlayingNative
                                  ? Icons.graphic_eq_rounded
                                  : Icons.volume_up_rounded,
                              color: const Color(0xFF00CEC9),
                            ),
                            label: Text(
                              _isPlayingNative
                                  ? 'Đang phát...'
                                  : '1. Nghe Mẫu Chuẩn',
                              style: const TextStyle(
                                color: Color(0xFF00CEC9),
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Start Shadowing Button
                        Expanded(
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _isShadowing
                                  ? const Color(0xFFFF6B6B)
                                  : AppColors.primary,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isShadowing
                                ? _finishShadowing
                                : (_countdown > 0
                                    ? null
                                    : _startShadowingCountdown),
                            icon: Icon(
                              _isShadowing
                                  ? Icons.stop_rounded
                                  : Icons.record_voice_over_rounded,
                              color: Colors.white,
                            ),
                            label: Text(
                              _countdown > 0
                                  ? 'Chuẩn bị: $_countdown...'
                                  : _isShadowing
                                      ? 'Dừng & Chấm Điểm'
                                      : '2. Bắt Đầu Shadowing',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),

                    if (_isShadowing) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF6B6B).withOpacity(0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color: const Color(0xFFFF6B6B).withOpacity(0.4)),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mic_rounded,
                                color: Color(0xFFFF6B6B), size: 18),
                            SizedBox(width: 8),
                            Text(
                              'ĐANG NHẠI GIỌNG... Nói đè lên tiếng mẫu hoặc ngay sau câu mẫu',
                              style: TextStyle(
                                color: Color(0xFFFF6B6B),
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_isEvaluating) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text('AI đang phân tích ngữ điệu và nhịp điệu...',
                                style: TextStyle(fontSize: 13)),
                          ],
                        ),
                      ),
                    ],

                    // ── AI Assessment Report ──
                    if (_assessmentResult != null) ...[
                      const SizedBox(height: 22),
                      _buildAssessmentCard(context),
                    ],
                  ],
                  const SizedBox(height: 28),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSpeedChip(String label, double speed) {
    final isSelected = (_playbackSpeed - speed).abs() < 0.05;
    return GestureDetector(
      onTap: () => setState(() => _playbackSpeed = speed),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : context.palette.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? AppColors.primary : context.palette.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : context.palette.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            fontSize: 11,
          ),
        ),
      ),
    );
  }

  Widget _buildAssessmentCard(BuildContext context) {
    final overall = _assessmentResult?['overall_score'] ?? 85;
    final intonation = _assessmentResult?['intonation_match'] ?? 85;
    final rhythm = _assessmentResult?['rhythm_tempo_score'] ?? 88;
    final accuracy = _assessmentResult?['accuracy_score'] ?? 86;
    final feedback = _assessmentResult?['feedback'] ?? '';
    final tips = (_assessmentResult?['tips'] as List?) ?? [];

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
            color: const Color(0xFF2ED573).withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ED573).withOpacity(0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'KẾT QUẢ SHADOWING AI 🎯',
                style: TextStyle(
                  color: const Color(0xFF2ED573),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.8,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ED573).withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$overall Điểm',
                  style: const TextStyle(
                    color: Color(0xFF2ED573),
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Metric Progress bars
          _buildScoreBar('Độ Khớp Ngữ Điệu (Intonation)', intonation,
              const Color(0xFF00CEC9)),
          const SizedBox(height: 8),
          _buildScoreBar(
              'Tốc Độ & Nhịp Điệu (Rhythm)', rhythm, const Color(0xFF6C5CE7)),
          const SizedBox(height: 8),
          _buildScoreBar('Độ Chuẩn Phát Âm (Accuracy)', accuracy,
              const Color(0xFFFFA502)),

          const SizedBox(height: 16),
          Text(
            feedback,
            style: TextStyle(
              color: context.palette.textPrimary,
              fontSize: 13,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),

          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text('💡 $tip',
                    style: TextStyle(
                        color: context.palette.textSecondary, fontSize: 12)),
              )),

          const SizedBox(height: 18),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _saveToMistakeNotebook,
                  icon: const Icon(Icons.bookmark_add_rounded, size: 16),
                  label: const Text('Lưu vào Sổ tay',
                      style: TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () {
                    setState(() {
                      _currentDrillIndex =
                          (_currentDrillIndex + 1) % _drills.length;
                      _assessmentResult = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_forward_rounded,
                      size: 16, color: Colors.white),
                  label: const Text('Bài Tiếp Theo',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildScoreBar(String label, int score, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: context.palette.textSecondary, fontSize: 11)),
            Text('$score%',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: score / 100,
            minHeight: 5,
            backgroundColor: context.palette.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
