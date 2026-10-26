import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../data/models/subtitle_line.dart';
import '../../data/models/video_lesson.dart';
import '../widgets/vocabulary_bottom_sheet.dart';

enum SubtitleDisplayMode { bilingual, englishOnly, hidden }

class VideoLearningScreen extends StatefulWidget {
  final VideoLesson lesson;

  const VideoLearningScreen({
    super.key,
    required this.lesson,
  });

  @override
  State<VideoLearningScreen> createState() => _VideoLearningScreenState();
}

class _VideoLearningScreenState extends State<VideoLearningScreen> {
  late VideoPlayerController _controller;
  bool _isInitialized = false;
  bool _hasError = false;
  String? _errorMessage;

  SubtitleDisplayMode _subtitleMode = SubtitleDisplayMode.bilingual;
  double _playbackSpeed = 1.0;
  final ScrollController _scrollController = ScrollController();
  final Map<String, GlobalKey> _subtitleKeys = {};

  SubtitleLine? _currentActiveSubtitle;
  Timer? _positionThrottleTimer;

  @override
  void initState() {
    super.initState();
    for (final sub in widget.lesson.subtitles) {
      _subtitleKeys[sub.id] = GlobalKey();
    }
    _initVideo();
  }

  Future<void> _initVideo() async {
    try {
      _controller = VideoPlayerController.networkUrl(
        Uri.parse(widget.lesson.videoUrl),
      );

      await _controller.initialize();
      _controller.addListener(_onVideoUpdate);
      setState(() {
        _isInitialized = true;
      });
      // Start playback automatically
      await _controller.play();
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasError = true;
          _errorMessage = 'Không thể tải video: $e';
        });
      }
    }
  }

  void _onVideoUpdate() {
    if (!mounted || !_controller.value.isInitialized) return;

    final position = _controller.value.position;
    SubtitleLine? matched;
    for (final sub in widget.lesson.subtitles) {
      if (sub.isActiveAt(position)) {
        matched = sub;
        break;
      }
    }

    if (matched?.id != _currentActiveSubtitle?.id) {
      setState(() {
        _currentActiveSubtitle = matched;
      });

      // Auto-scroll to active subtitle
      if (matched != null) {
        _scrollToSubtitle(matched.id);
      }
    }
  }

  void _scrollToSubtitle(String id) {
    final key = _subtitleKeys[id];
    if (key != null && key.currentContext != null) {
      Scrollable.ensureVisible(
        key.currentContext!,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        alignment: 0.3,
      );
    }
  }

  void _onSubtitleTapped(SubtitleLine sub) {
    // Pause video when viewing detail
    _controller.pause();
    // Seek to this subtitle's start position
    _controller.seekTo(sub.startDuration);

    VocabularyBottomSheet.show(
      context,
      subtitle: sub,
      lesson: widget.lesson,
    );
  }

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _positionThrottleTimer?.cancel();
    _controller.removeListener(_onVideoUpdate);
    _controller.dispose();
    _scrollController.dispose();
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
          widget.lesson.title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Luyện phản xạ toàn bài',
            icon: const Icon(Icons.record_voice_over_rounded,
                color: AppColors.speaking),
            onPressed: () {
              _controller.pause();
              context.push(
                '/video-learning/reflex',
                extra: {
                  'lesson': widget.lesson,
                },
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Video Player Area ──
            _buildVideoPlayerSection(isDark),

            // ── Subtitle Mode & Speed Bar ──
            _buildControlBar(isDark),

            // ── Subtitles List ──
            Expanded(
              child: _buildSubtitlesList(isDark),
            ),

            // ── Bottom Navigation to Reflex Practice ──
            _buildBottomActionBar(isDark),
          ],
        ),
      ),
    );
  }

  Widget _buildVideoPlayerSection(bool isDark) {
    final screenHeight = MediaQuery.of(context).size.height;
    final maxVideoHeight = (screenHeight * 0.36).clamp(180.0, 320.0);

    return Container(
      width: double.infinity,
      height: maxVideoHeight,
      color: Colors.black,
      child: Center(
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: _isInitialized
            ? Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        if (_controller.value.isPlaying) {
                          _controller.pause();
                        } else {
                          _controller.play();
                        }
                      });
                    },
                    child: Center(
                      child: AspectRatio(
                        aspectRatio: _controller.value.aspectRatio,
                        child: VideoPlayer(_controller),
                      ),
                    ),
                  ),

                  // Overlay when paused
                  if (!_controller.value.isPlaying)
                    GestureDetector(
                      onTap: () => setState(() => _controller.play()),
                      child: Container(
                        color: Colors.black38,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.9),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.5),
                                  blurRadius: 16,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.play_arrow_rounded,
                              size: 44,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),

                  // Real-time Subtitle Overlay on Video
                  if (_subtitleMode != SubtitleDisplayMode.hidden &&
                      _currentActiveSubtitle != null)
                    Positioned(
                      bottom: 40,
                      left: 16,
                      right: 16,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.75),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentActiveSubtitle!.englishText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.yellowAccent,
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black),
                                ],
                              ),
                            ),
                            if (_subtitleMode ==
                                SubtitleDisplayMode.bilingual) ...[
                              const SizedBox(height: 3),
                              Text(
                                _currentActiveSubtitle!.vietnameseText,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                  // Video timeline scrub bar
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 4),
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.transparent, Colors.black87],
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                        ),
                      ),
                      child: Row(
                        children: [
                          InkWell(
                            onTap: () {
                              setState(() {
                                _controller.value.isPlaying
                                    ? _controller.pause()
                                    : _controller.play();
                              });
                            },
                            child: Icon(
                              _controller.value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              color: Colors.white,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _formatDuration(_controller.value.position),
                            style: const TextStyle(
                                color: Colors.white, fontSize: 11),
                          ),
                          Expanded(
                            child: VideoProgressIndicator(
                              _controller,
                              allowScrubbing: true,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 8),
                              colors: VideoProgressColors(
                                playedColor: AppColors.primary,
                                bufferedColor: Colors.white24,
                                backgroundColor: Colors.white12,
                              ),
                            ),
                          ),
                          Text(
                            _formatDuration(_controller.value.duration),
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 11),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              )
            : _hasError
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.redAccent, size: 36),
                          const SizedBox(height: 8),
                          Text(
                            _errorMessage ?? 'Lỗi tải video do trình duyệt hoặc mạng',
                            style: const TextStyle(
                                color: Colors.white70, fontSize: 12),
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _hasError = false;
                                _errorMessage = null;
                              });
                              _initVideo();
                            },
                            icon: const Icon(Icons.refresh_rounded, size: 16),
                            label: const Text('Thử tải lại video'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
        ),
      ),
    );
  }

  Widget _buildControlBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: Row(
        children: [
          // Subtitle mode segmented popup
          PopupMenuButton<SubtitleDisplayMode>(
            initialValue: _subtitleMode,
            onSelected: (mode) => setState(() => _subtitleMode = mode),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.subtitles_rounded,
                      size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Text(
                    _subtitleMode == SubtitleDisplayMode.bilingual
                        ? 'Song ngữ (EN+VI)'
                        : _subtitleMode == SubtitleDisplayMode.englishOnly
                            ? 'Chỉ tiếng Anh'
                            : 'Ẩn phụ đề',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(Icons.arrow_drop_down,
                      size: 18, color: AppColors.primary),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: SubtitleDisplayMode.bilingual,
                child: Text('Song ngữ (Tiếng Anh + Tiếng Việt)'),
              ),
              const PopupMenuItem(
                value: SubtitleDisplayMode.englishOnly,
                child: Text('Chỉ hiện Tiếng Anh'),
              ),
              const PopupMenuItem(
                value: SubtitleDisplayMode.hidden,
                child: Text('Ẩn phụ đề (Thử thách nghe)'),
              ),
            ],
          ),

          const Spacer(),

          // Speed selector
          PopupMenuButton<double>(
            initialValue: _playbackSpeed,
            onSelected: (speed) {
              setState(() => _playbackSpeed = speed);
              _controller.setPlaybackSpeed(speed);
            },
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.speed_rounded, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${_playbackSpeed}x',
                    style: AppTextStyles.labelSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            itemBuilder: (context) => [
              const PopupMenuItem(value: 0.75, child: Text('0.75x (Chậm)')),
              const PopupMenuItem(value: 1.0, child: Text('1.0x (Chuẩn)')),
              const PopupMenuItem(value: 1.25, child: Text('1.25x (Nhanh)')),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSubtitlesList(bool isDark) {
    final subs = widget.lesson.subtitles;

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: subs.length,
      itemBuilder: (context, index) {
        final sub = subs[index];
        final isActive = _currentActiveSubtitle?.id == sub.id;

        return Container(
          key: _subtitleKeys[sub.id],
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: isActive
                ? (isDark
                    ? AppColors.primary.withOpacity(0.2)
                    : const Color(0xFFEEF2FF))
                : (isDark ? const Color(0xFF1E1F28) : Colors.white),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isActive
                  ? AppColors.primary
                  : (isDark ? Colors.white10 : Colors.grey.shade200),
              width: isActive ? 1.5 : 1,
            ),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => _onSubtitleTapped(sub),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time timestamp chip
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isActive
                            ? AppColors.primary
                            : (isDark ? Colors.white12 : Colors.grey.shade200),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _formatDuration(sub.startDuration),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: isActive
                              ? Colors.white
                              : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Texts
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            sub.englishText,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight:
                                  isActive ? FontWeight.bold : FontWeight.w500,
                              color: isActive
                                  ? AppColors.primary
                                  : (isDark ? Colors.white : Colors.black87),
                              height: 1.35,
                            ),
                          ),
                          if (_subtitleMode ==
                              SubtitleDisplayMode.bilingual) ...[
                            const SizedBox(height: 4),
                            Text(
                              sub.vietnameseText,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: isDark ? Colors.white60 : Colors.black54,
                              ),
                            ),
                          ],
                          if (sub.vocabulary.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              children: sub.vocabulary.map((v) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppColors.secondary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    '${v.word}: ${v.meaningVi}',
                                    style: AppTextStyles.labelSmall.copyWith(
                                      color: AppColors.secondary,
                                      fontSize: 10,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ],
                      ),
                    ),

                    const SizedBox(width: 8),

                    // Tap hint / detail icon
                    const Icon(
                      Icons.touch_app_rounded,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomActionBar(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1F28) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? Colors.white10 : Colors.grey.shade200,
          ),
        ),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton.icon(
          onPressed: () {
            _controller.pause();
            context.push(
              '/video-learning/reflex',
              extra: {
                'lesson': widget.lesson,
              },
            );
          },
          icon: const Icon(Icons.flash_on_rounded, color: Colors.white),
          label: Text(
            'Luyện Phản Xạ Toàn Bài (Bước 2)',
            style: AppTextStyles.titleSmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.speaking,
            elevation: 3,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
    );
  }
}
