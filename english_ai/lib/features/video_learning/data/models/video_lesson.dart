import 'subtitle_line.dart';

class VideoLesson {
  final String id;
  final String title;
  final String vietnameseTitle;
  final String description;
  final String category;
  final String level; // A1, A2, B1, B2
  final int durationSeconds;
  final String videoUrl;
  final String thumbnailUrl;
  final List<SubtitleLine> subtitles;
  final List<String> learningObjectives;
  final int xpReward;

  const VideoLesson({
    required this.id,
    required this.title,
    required this.vietnameseTitle,
    required this.description,
    required this.category,
    required this.level,
    required this.durationSeconds,
    required this.videoUrl,
    required this.thumbnailUrl,
    required this.subtitles,
    this.learningObjectives = const [],
    this.xpReward = 30,
  });

  String get durationFormatted {
    final minutes = durationSeconds ~/ 60;
    final seconds = durationSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'vietnameseTitle': vietnameseTitle,
        'description': description,
        'category': category,
        'level': level,
        'durationSeconds': durationSeconds,
        'videoUrl': videoUrl,
        'thumbnailUrl': thumbnailUrl,
        'subtitles': subtitles.map((s) => s.toJson()).toList(),
        'learningObjectives': learningObjectives,
        'xpReward': xpReward,
      };

  factory VideoLesson.fromJson(Map<String, dynamic> json) => VideoLesson(
        id: json['id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        vietnameseTitle: json['vietnameseTitle'] as String? ?? '',
        description: json['description'] as String? ?? '',
        category: json['category'] as String? ?? 'General',
        level: json['level'] as String? ?? 'A2',
        durationSeconds: json['durationSeconds'] as int? ?? 60,
        videoUrl: json['videoUrl'] as String? ?? '',
        thumbnailUrl: json['thumbnailUrl'] as String? ?? '',
        subtitles: (json['subtitles'] as List<dynamic>?)
                ?.map((e) => SubtitleLine.fromJson(e as Map<String, dynamic>))
                .toList() ??
            const [],
        learningObjectives: (json['learningObjectives'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        xpReward: json['xpReward'] as int? ?? 30,
      );
}
