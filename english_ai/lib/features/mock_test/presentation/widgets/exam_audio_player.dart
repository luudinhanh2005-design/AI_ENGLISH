import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Audio player used by the Listening section.
///
/// Strict mode allows a single playback per part: once the audio starts it is
/// marked as consumed through [onConsumed], pausing and seeking are disabled
/// and stopping asks for confirmation. Practice mode supports pause, replay and
/// a retry button when the audio cannot be loaded.
class ExamAudioPlayer extends StatefulWidget {
  const ExamAudioPlayer({
    super.key,
    required this.audioUrl,
    required this.strict,
    this.playedBefore = false,
    this.onConsumed,
    this.label,
  });

  /// Server-relative or absolute audio URL.
  final String audioUrl;
  final bool strict;

  /// `true` when this part has already used its single strict-mode playback.
  final bool playedBefore;

  /// Called once when strict-mode playback has started/finished.
  final VoidCallback? onConsumed;

  /// Optional caption, e.g. "Part 1 audio".
  final String? label;

  @override
  State<ExamAudioPlayer> createState() => _ExamPlayerState();
}

class _ExamPlayerState extends State<ExamAudioPlayer> {
  AudioPlayer? _player;
  final List<StreamSubscription<dynamic>> _subscriptions = [];

  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _loading = false;
  bool _playing = false;
  bool _paused = false;
  bool _completed = false;
  bool _consumedLocally = false;
  bool _notified = false;
  String? _error;

  String get _resolvedUrl => AppConfig.resolveMediaUrl(widget.audioUrl);

  bool get _isConsumed =>
      widget.strict && (widget.playedBefore || _consumedLocally);

  @override
  void initState() {
    super.initState();
    _consumedLocally = widget.playedBefore;
    _createPlayer();
  }

  @override
  void didUpdateWidget(covariant ExamAudioPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playedBefore && !_consumedLocally) {
      _consumedLocally = true;
    }
    if (oldWidget.audioUrl != widget.audioUrl) {
      _disposePlayer();
      _duration = Duration.zero;
      _position = Duration.zero;
      _playing = false;
      _paused = false;
      _completed = false;
      _error = null;
      _loading = false;
      _consumedLocally = widget.playedBefore;
      _notified = false;
      _createPlayer();
    }
  }

  void _createPlayer() {
    final player = AudioPlayer();
    _player = player;
    unawaited(
      player.setReleaseMode(ReleaseMode.stop).catchError((Object _) {}),
    );

    _subscriptions.add(
      player.onDurationChanged.listen((duration) {
        if (!mounted) return;
        setState(() => _duration = duration);
      }),
    );

    _subscriptions.add(
      player.onPositionChanged.listen((position) {
        if (!mounted) return;
        setState(() => _position = position);
      }),
    );

    _subscriptions.add(
      player.onPlayerStateChanged.listen((state) {
        if (!mounted) return;
        setState(() {
          _playing = state == PlayerState.playing;
          _paused = state == PlayerState.paused;
          if (_playing) {
            _loading = false;
            _error = null;
            _completed = false;
          }
        });
        if (state == PlayerState.playing) {
          _markConsumedIfNeeded();
        }
      }),
    );

    _subscriptions.add(
      player.onPlayerComplete.listen((_) {
        if (!mounted) return;
        setState(() {
          _playing = false;
          _paused = false;
          _completed = true;
          if (_duration > Duration.zero) _position = _duration;
        });
        _markConsumedIfNeeded();
      }),
    );
  }

  void _disposePlayer() {
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
    final player = _player;
    _player = null;
    if (player != null) {
      unawaited(player.dispose().catchError((Object _) {}));
    }
  }

  @override
  void dispose() {
    _disposePlayer();
    super.dispose();
  }

  void _markConsumedIfNeeded() {
    if (!widget.strict || _notified) return;
    _notified = true;
    _consumedLocally = true;
    if (mounted) {
      setState(() {});
    }
    widget.onConsumed?.call();
  }

  Future<void> _startPlayback({bool restart = false}) async {
    final player = _player;
    if (player == null || _loading) return;
    if (_isConsumed) return;
    if (_resolvedUrl.trim().isEmpty) {
      setState(() => _error = 'Không tải được audio');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _completed = false;
      _paused = false;
      if (restart) _position = Duration.zero;
    });

    try {
      if (restart) {
        await player.stop();
      }
      await player.play(UrlSource(_resolvedUrl));
      if (!mounted) return;
      setState(() => _loading = false);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _playing = false;
        _error = 'Không tải được audio';
      });
    }
  }

  Future<void> _pause() async {
    try {
      await _player?.pause();
    } catch (_) {
      // Ignore: the play button stays usable.
    }
  }

  Future<void> _resume() async {
    try {
      await _player?.resume();
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      await _startPlayback();
    }
  }

  Future<void> _stop() async {
    try {
      await _player?.stop();
    } catch (_) {
      // Ignore: stopping is best-effort.
    }
    if (!mounted) return;
    setState(() {
      _playing = false;
      _paused = false;
      _completed = true;
    });
    _markConsumedIfNeeded();
  }

  Future<void> _confirmStop() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Dừng audio?'),
          content: const Text(
            'Ở chế độ thi, mỗi phần audio chỉ được phát một lần. '
            'Nếu dừng, bạn sẽ không thể nghe lại phần này.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Tiếp tục nghe'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Dừng audio'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await _stop();
    }
  }

  void _primaryAction() {
    if (_loading) return;
    if (_playing) {
      if (widget.strict) {
        unawaited(_confirmStop());
      } else {
        unawaited(_pause());
      }
      return;
    }
    if (_isConsumed) return;
    if (_paused) {
      unawaited(_resume());
      return;
    }
    if (_completed) {
      unawaited(_startPlayback(restart: true));
      return;
    }
    unawaited(_startPlayback());
  }

  IconData get _primaryIcon {
    if (_loading) return Icons.hourglass_empty_rounded;
    if (_playing) {
      return widget.strict ? Icons.stop_rounded : Icons.pause_rounded;
    }
    if (_error != null) return Icons.refresh_rounded;
    if (_paused) return Icons.play_arrow_rounded;
    if (_completed) return Icons.replay_rounded;
    return Icons.play_arrow_rounded;
  }

  String get _statusText {
    if (_error != null) return 'Không tải được audio';
    if (_loading) return 'Đang tải audio…';
    if (_playing) return 'Đang phát…';
    if (_paused) return 'Tạm dừng';
    if (_completed && widget.strict) return 'Đã phát xong';
    if (_completed) return 'Đã phát xong';
    if (_isConsumed) return 'Đã sử dụng lượt nghe';
    return widget.strict
        ? 'Chạm để phát · 1 lần duy nhất'
        : 'Chạm để phát audio';
  }

  double get _progress {
    if (_duration.inMilliseconds <= 0) return 0;
    return (_position.inMilliseconds / _duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }

  String _formatDuration(Duration duration) {
    final total = duration.inSeconds;
    final hours = total ~/ 3600;
    final minutes = (total % 3600) ~/ 60;
    final seconds = total % 60;
    final mm = minutes.toString().padLeft(2, '0');
    final ss = seconds.toString().padLeft(2, '0');
    if (hours > 0) return '${hours.toString().padLeft(2, '0')}:$mm:$ss';
    return '$mm:$ss';
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final playEnabled = !_loading && !(_isConsumed && !_playing);
    final showRetry = _error != null && !widget.strict;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: palette.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: palette.divider.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _PlayButton(
                icon: _primaryIcon,
                busy: _loading,
                enabled: playEnabled,
                onPressed: _primaryAction,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label ?? 'Listening audio',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: palette.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      _statusText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: _error != null
                            ? AppColors.error
                            : palette.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.strict) ...[
                const SizedBox(width: 8),
                _StrictBadge(consumed: _isConsumed),
              ] else if (_duration > Duration.zero) ...[
                const SizedBox(width: 4),
                IconButton(
                  tooltip: 'Nghe lại từ đầu',
                  visualDensity: VisualDensity.compact,
                  onPressed: _playing || _paused || _completed
                      ? () => unawaited(_startPlayback(restart: true))
                      : null,
                  icon: Icon(
                    Icons.restart_alt_rounded,
                    size: 20,
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: _progress,
              minHeight: 6,
              backgroundColor: palette.divider.withValues(alpha: 0.6),
              valueColor: AlwaysStoppedAnimation<Color>(
                _isConsumed && widget.strict && !_playing
                    ? palette.textHint.withValues(alpha: 0.7)
                    : AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                _formatDuration(_position),
                style: AppTextStyles.caption.copyWith(
                  color: palette.textSecondary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                _duration > Duration.zero
                    ? _formatDuration(_duration)
                    : '--:--',
                style: AppTextStyles.caption.copyWith(
                  color: palette.textHint,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: AppColors.error,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    widget.strict
                        ? 'Không tải được audio. Hãy kiểm tra kết nối mạng.'
                        : 'Không tải được audio. Hãy kiểm tra kết nối rồi thử lại.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ),
                if (showRetry)
                  TextButton(
                    onPressed: () => unawaited(_startPlayback()),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    child: const Text('Thử lại'),
                  ),
              ],
            ),
          ],
          if (widget.strict && _isConsumed && !_playing) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 15,
                  color: palette.textHint,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Audio chỉ được nghe một lần',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: palette.textHint,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({
    required this.icon,
    required this.busy,
    required this.enabled,
    required this.onPressed,
  });

  final IconData icon;
  final bool busy;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;

    return Opacity(
      opacity: enabled ? 1 : 0.55,
      child: Material(
        color: enabled
            ? AppColors.primary.withValues(alpha: 0.12)
            : palette.divider.withValues(alpha: 0.4),
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: enabled ? onPressed : null,
          child: SizedBox(
            width: 48,
            height: 48,
            child: Center(
              child: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.2),
                    )
                  : Icon(
                      icon,
                      size: 26,
                      color: enabled ? AppColors.primary : palette.textHint,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StrictBadge extends StatelessWidget {
  const _StrictBadge({required this.consumed});

  final bool consumed;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final color = consumed ? palette.textHint : AppColors.warning;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            consumed ? Icons.lock_outline_rounded : Icons.headphones_rounded,
            size: 13,
            color: color,
          ),
          const SizedBox(width: 4),
          Text(
            consumed ? 'Đã nghe' : '1 lần',
            style: AppTextStyles.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
