import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart'; // Uint8List + kIsWeb
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:http_parser/http_parser.dart';

import '../../../../core/constants/api_endpoints.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/services/audio_recording_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/speech_service.dart';
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

  // Audio & Shadowing State
  double _playbackSpeed = 1.0;
  bool _isPlayingNative = false;
  bool _isShadowing = false;
  int _countdown = 0;
  Timer? _countdownTimer;
  Timer? _autoStopTimer;

  // Ghi âm & chấm điểm
  final AudioRecordingService _recorder = AudioRecordingService();
  final AudioPlayer _audioPlayer = AudioPlayer();
  Uint8List? _lastRecording;
  String? _errorMessage;

  // Evaluation
  bool _isEvaluating = false;
  Map<String, dynamic>? _assessmentResult;

  @override
  void initState() {
    super.initState();
    _loadDrills();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _autoStopTimer?.cancel();
    _recorder.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadDrills() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioProvider);
      final res = await dio.get(ApiEndpoints.shadowingDrills);
      if (res.statusCode == 200 &&
          res.data is List &&
          (res.data as List).isNotEmpty) {
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
    SpeechService.speak(drill['text'].toString(), rate: _playbackSpeed)
        .then((_) {
      if (mounted) setState(() => _isPlayingNative = false);
    });
  }

  Future<void> _startShadowingCountdown() async {
    _countdownTimer?.cancel();
    setState(() {
      _assessmentResult = null;
      _errorMessage = null;
    });

    // Không có quyền micro thì không chạy countdown, báo lỗi ngay.
    final hasPermission = await _recorder.hasPermission();
    if (!mounted) return;
    if (!hasPermission) {
      setState(() {
        _errorMessage =
            'Cần quyền micro để chấm điểm. Hãy cấp quyền trong Cài đặt.';
      });
      return;
    }

    setState(() => _countdown = 3);
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _startShadowingLive();
      }
    });
  }

  Future<void> _startShadowingLive() async {
    setState(() {
      _isPlayingNative = true; // đang phát câu mẫu, mic CHƯA mở
      _isShadowing = false;
      _errorMessage = null;
      _countdown = 0;
    });

    final drill = _drills[_currentDrillIndex];
    final text = drill['text'].toString();

    // Chế độ "nghe xong rồi nhại": phát câu mẫu trước,
    // đợi loa dứt rồi mới mở mic để không thu lại tiếng loa.
    try {
      await SpeechService.speak(text, rate: _playbackSpeed);
      await Future.delayed(const Duration(milliseconds: 250));
    } catch (_) {
      // Không phát được mẫu thì vẫn cho người học nhại.
    }

    if (!mounted) return;

    try {
      await _recorder.startRecording();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isPlayingNative = false;
        _isShadowing = false;
        _errorMessage = 'Không truy cập được micro. Hãy kiểm tra quyền micro.';
      });
      return;
    }

    if (!mounted) return;

    setState(() {
      _isPlayingNative = false;
      _isShadowing = true; // mic đã mở thật
    });

    // Tự dừng theo độ dài câu (đủ thời gian cho người học nhại).
    final durationSeconds = (text.length * 0.08 / _playbackSpeed).ceil() + 3;
    _autoStopTimer?.cancel();
    _autoStopTimer = Timer(Duration(seconds: durationSeconds), () {
      if (mounted && _isShadowing) {
        _finishShadowing();
      }
    });
  }

  Future<void> _finishShadowing() async {
    _autoStopTimer?.cancel();
    _autoStopTimer = null;
    setState(() {
      _isShadowing = false;
      _isEvaluating = true;
      _errorMessage = null;
    });

    final drill = _drills[_currentDrillIndex];

    Uint8List? bytes;
    try {
      bytes = await _recorder.stopRecording();
    } catch (_) {
      bytes = null;
    }

    if (bytes == null || bytes.isEmpty) {
      if (!mounted) return;
      setState(() {
        _isEvaluating = false;
        _errorMessage = 'Không thu được âm thanh. Hãy nói to hơn và thử lại.';
      });
      return;
    }

    _lastRecording = bytes;

    try {
      final formData = FormData.fromMap({
        'drill_id': drill['id'] ?? 'shadow_1',
        'audio': MultipartFile.fromBytes(
          bytes,
          filename: kIsWeb ? 'shadowing.webm' : 'shadowing.wav',
          contentType: MediaType('audio', kIsWeb ? 'webm' : 'wav'),
        ),
      });
      final res = await ref
          .read(dioProvider)
          .post(ApiEndpoints.shadowingAssess, data: formData);

      if (!mounted) return;

      final data = res.data;
      if (data is! Map) {
        setState(() {
          _assessmentResult = null;
          _isEvaluating = false;
          _errorMessage = 'Không chấm được điểm. Kiểm tra kết nối rồi thử lại.';
        });
        return;
      }

      // Backend có thể trả 200 nhưng không chấm được (scored = false).
      if (data['scored'] == false) {
        setState(() {
          _assessmentResult = null;
          _isEvaluating = false;
          _errorMessage =
              (data['feedback'] as String?) ?? 'Chưa nghe rõ giọng đọc.';
        });
        return;
      }

      setState(() {
        _assessmentResult = Map<String, dynamic>.from(data);
        _isEvaluating = false;
      });
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() {
        _assessmentResult = null;
        _isEvaluating = false;
        _errorMessage = e.response?.statusCode == 422
            ? 'Chưa nghe rõ giọng đọc. Hãy đọc to, rõ hơn và thử lại.'
            : 'Không chấm được điểm. Kiểm tra kết nối rồi thử lại.';
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _assessmentResult = null;
        _isEvaluating = false;
        _errorMessage = 'Không chấm được điểm. Kiểm tra kết nối rồi thử lại.';
      });
    }
  }

  Future<void> _saveToMistakeNotebook() async {
    if (_drills.isEmpty) return;

    final result = _assessmentResult;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Hãy đọc và chấm điểm trước khi lưu vào sổ tay.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final drill = _drills[_currentDrillIndex];
    final target = drill['text'].toString().trim();
    final overall = (result['overall_score'] as num?)?.toDouble() ?? 0.0;
    final accuracy = (result['accuracy_score'] as num?)?.toDouble();
    final score = accuracy ?? overall;

    if (score >= 80) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phát âm đã tốt (từ 80 điểm), không cần lưu lỗi.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Color(0xFF2ED573),
        ),
      );
      return;
    }

    final recognised = ((result['recognised_text'] as String?) ??
            (result['recognized_text'] as String?) ??
            '')
        .trim();
    final original = recognised.isEmpty ? 'Chưa nhận diện rõ lời đọc' : recognised;
    final notes = drill['connected_speech_notes'] as List?;
    final note = (notes != null && notes.isNotEmpty) ? notes.first : '';
    final feedback = (result['feedback'] as String?)?.trim() ?? '';

    final added = await ref.read(mistakeNotebookProvider.notifier).addMistake(
          originalText: original,
          correctedText: target,
          explanation: [
            'Shadowing: ${drill['title']} (${score.toStringAsFixed(0)} điểm).',
            if (feedback.isNotEmpty) feedback,
            if (note.toString().isNotEmpty) 'Chú ý nối âm: $note',
          ].join(' '),
          type: 'pronunciation',
          source: 'practice',
        );

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          added
              ? '🎉 Đã lưu lỗi phát âm vào Sổ tay ôn tập!'
              : 'Lỗi phát âm này đã có trong sổ tay rồi.',
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2ED573),
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
                              _errorMessage = null;
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
                                  color:
                                      const Color(0xFF00CEC9).withOpacity(0.15),
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
                              border:
                                  Border.all(color: context.palette.divider),
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
                          ...((currentDrill['connected_speech_notes']
                                      as List?) ??
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
                            onPressed:
                                _isPlayingNative ? null : _playNativeAudio,
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
                                : (_countdown > 0 || _isPlayingNative
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
                                  : _isPlayingNative
                                      ? 'Đang phát mẫu...'
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
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.mic_rounded,
                                color: Color(0xFFFF6B6B), size: 18),
                            SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                'ĐANG GHI ÂM — hãy nhại lại câu vừa nghe',
                                style: TextStyle(
                                  color: Color(0xFFFF6B6B),
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      _buildErrorBanner(context),
                    ],

                    if (_isEvaluating) ...[
                      const SizedBox(height: 24),
                      const Center(
                        child: Column(
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 10),
                            Text('AI đang chấm điểm bản ghi của bạn...',
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
          color: isSelected ? AppColors.primary : context.palette.card,
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

  Widget _buildErrorBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4757).withOpacity(0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF4757).withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF4757), size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage ?? '',
              style: const TextStyle(
                color: Color(0xFFFF4757),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
          TextButton(
            onPressed:
                _isShadowing || _isEvaluating ? null : _startShadowingCountdown,
            child: const Text('Thử lại', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildAssessmentCard(BuildContext context) {
    final result = _assessmentResult;
    // Không có điểm thật thì để 0, tuyệt đối không bịa điểm.
    final overall = (result?['overall_score'] as num?)?.toDouble() ?? 0.0;
    final accuracy = (result?['accuracy_score'] as num?)?.toDouble();
    final completeness = (result?['completeness_score'] as num?)?.toDouble();
    final rhythm = (result?['rhythm_tempo_score'] as num?)?.toDouble();
    final hasTiming = (result?['has_timing'] as bool?) ?? (rhythm != null);

    final recognised = ((result?['recognised_text'] as String?) ??
            (result?['recognized_text'] as String?) ??
            '')
        .trim();
    final feedback = (result?['feedback'] as String?) ?? '';
    final tips = (result?['tips'] as List?) ?? const [];
    final notes = (result?['scoring_notes'] as List?) ?? const [];

    final scoreColor = overall >= 80
        ? const Color(0xFF2ED573)
        : overall >= 60
            ? const Color(0xFFFFA502)
            : const Color(0xFFFF4757);

    // Bản ghi để nghe lại (null-safe, không dùng `!`).
    final recording = _lastRecording;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.palette.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: scoreColor.withOpacity(0.5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: scoreColor.withOpacity(0.12),
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
              Expanded(
                child: Text(
                  'KẾT QUẢ SHADOWING AI 🎯',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${overall.toStringAsFixed(1)} Điểm',
                  style: TextStyle(
                    color: scoreColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Các thanh điểm chỉ vẽ khi backend thật sự trả số liệu.
          if (accuracy != null) ...[
            _buildScoreBar('Phát âm', accuracy, const Color(0xFF6C5CE7)),
            const SizedBox(height: 8),
          ],
          if (completeness != null) ...[
            _buildScoreBar('Độ đầy đủ', completeness, const Color(0xFF00CEC9)),
            const SizedBox(height: 8),
          ],
          if (hasTiming && rhythm != null)
            _buildScoreBar('Tốc độ & nhịp', rhythm, const Color(0xFFFFA502))
          else
            Text(
              'Chưa đo được tốc độ/nhịp',
              style: TextStyle(
                color: context.palette.textSecondary,
                fontSize: 11,
                fontStyle: FontStyle.italic,
              ),
            ),

          const SizedBox(height: 8),
          Text(
            'Ngữ điệu: chưa phân tích',
            style: TextStyle(
              color: context.palette.textSecondary,
              fontSize: 11,
              fontStyle: FontStyle.italic,
            ),
          ),

          if (recognised.isNotEmpty) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.palette.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.palette.divider),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Máy nghe được',
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    recognised,
                    style: TextStyle(
                      color: context.palette.textPrimary,
                      fontSize: 12,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (feedback.isNotEmpty) ...[
            const SizedBox(height: 16),
            Text(
              feedback,
              style: TextStyle(
                color: context.palette.textPrimary,
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],

          ...tips.map((tip) => Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('💡 $tip',
                    style: TextStyle(
                        color: context.palette.textSecondary, fontSize: 12)),
              )),

          if (notes.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...notes.map((note) => Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    '• $note',
                    style: TextStyle(
                      color: context.palette.textSecondary,
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      height: 1.35,
                    ),
                  ),
                )),
          ],

          const SizedBox(height: 12),

          Row(
            children: [
              TextButton.icon(
                onPressed: recording == null
                    ? null
                    : () {
                        _audioPlayer.stop();
                        _audioPlayer.play(BytesSource(recording));
                      },
                icon: const Icon(Icons.play_circle_outline_rounded, size: 16),
                label: const Text('Nghe lại bản ghi',
                    style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 4),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _assessmentResult = null;
                    _errorMessage = null;
                  });
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Thử lại', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),

          const SizedBox(height: 6),

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
                      _errorMessage = null;
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

  Widget _buildScoreBar(String label, double score, Color color) {
    final clamped = score.clamp(0.0, 100.0);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    color: context.palette.textSecondary, fontSize: 11)),
            Text('${clamped.toStringAsFixed(0)}%',
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 11)),
          ],
        ),
        const SizedBox(height: 4),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: clamped / 100,
            minHeight: 5,
            backgroundColor: context.palette.divider,
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }
}
